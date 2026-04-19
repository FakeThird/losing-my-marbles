class_name MatchManager
extends Node2D

# 1. Define the game loop phases based on your PDF
enum MatchState { INITIALIZATION, DRAW, PLAY, AIM, SIMULATING, END_TURN }

var current_state: MatchState = MatchState.INITIALIZATION
var active_player_id: int = -1
var turn_order: Array =[]
var current_turn_index: int = 0
var players_loaded: int = 0
var player_stats: Dictionary = {}

const CARD_SCENE: PackedScene = preload("res://scenes/ui/card/card.tscn")

@onready var turn_label: Label = %TurnLabel
@onready var phase_label: Label = %PhaseLabel
@onready var next_phase_button: Button = %NextPhaseButton
@onready var hand_container: HBoxContainer = %HandContainer
@onready var play_area: Panel = %PlayArea
@onready var mana_label: Label = %ManaLabel

@export var card_database: Array[CardData]

# Test Functionalities for toggling between scenes:
@onready var switch_to_terrain_button: Button = %SwitchToTerrainButton
var terrain_node: Node = null

func _ready() -> void:
	# Hide the button by default
	next_phase_button.hide()
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	
	# Listen for when the player drops a card
	play_area.card_dropped_on_board.connect(_on_card_dropped)
	
	# Test Functionalities for toggling between scenes:
	switch_to_terrain_button.hide()
	switch_to_terrain_button.pressed.connect(_on_switch_to_terrain_pressed)

	# Determine if we are the server or the client
	if multiplayer.is_server():
		print("Server: Match node ready locally.")
		players_loaded += 1
		_check_all_players_loaded()
	else:
		print("Client: Match node ready locally. Waiting 1 frame to notify server...")
		# THE FIX: Wait exactly 1 frame so the network path is fully registered
		await get_tree().process_frame 
		_notify_server_loaded.rpc_id(1)
		


func _initialize_match() -> void:
	print("Server: All players loaded! Initializing Match...")
	
	# 1. Clear and populate stats first
	player_stats.clear()
	for id in NetworkManager.players:
		# Explicitly cast 'id' to int to avoid key-type errors
		var peer_id: int = int(id)
		player_stats[peer_id] = {"health": 20, "mana": 0}
	
	# 2. Setup turn order
	turn_order = NetworkManager.players.keys()
	turn_order.shuffle()
	
	current_turn_index = 0
	active_player_id = int(turn_order[current_turn_index])
	
	# 3. Only now do we change the state
	_set_state(MatchState.DRAW)

# --- SERVER LOGIC ---
# Only the server should ever call this function directly
func _set_state(new_state: MatchState) -> void:
	current_state = new_state
	print("Server: State changed to ", MatchState.keys()[current_state])
	
	if current_state == MatchState.DRAW and multiplayer.is_server():
		# Safety check: ensures the key exists before setting
		if player_stats.has(active_player_id):
			player_stats[active_player_id]["mana"] = 5
			_sync_stats.rpc(player_stats)
		else:
			printerr("Server Error: active_player_id ", active_player_id, " not found in player_stats!")
	
	# Broadcast the new state to ALL clients (including the server's local client)
	_sync_state.rpc(current_state, active_player_id, turn_order)

func _advance_turn() -> void:
	current_turn_index += 1
	if current_turn_index >= turn_order.size():
		current_turn_index = 0 # Loop back to the first player
	
	active_player_id = turn_order[current_turn_index]
	_set_state(MatchState.DRAW)

# --- RPCs (NETWORK SYNC) ---
# "authority" means only the Server can call this on clients. "call_local" runs it on the server's UI too.
@rpc("authority", "call_local", "reliable")
func _sync_state(state: int, active_id: int, order: Array) -> void:
	current_state = state as MatchState
	active_player_id = active_id
	turn_order = order
	
	_update_ui()

func _update_ui() -> void:
	# 1. Guard: If we don't have stats or a valid active player yet, don't update
	if player_stats.is_empty() or active_player_id <= 0:
		turn_label.text = "Waiting for players..."
		return
	
	# 2. Guard: Check local ID
	var my_id: int = multiplayer.get_unique_id()
	if my_id <= 0: 
		return
	
	# 3. Safe lookup for Active Player name
	if NetworkManager.players.has(active_player_id):
		var p_name: String = NetworkManager.players[active_player_id]["name"]
		turn_label.text = p_name + "'s Turn"
	
	phase_label.text = "Phase: " + MatchState.keys()[current_state]
	
	# 4. Safe lookup for Local Player Mana/HP
	if player_stats.has(my_id):
		var my_mana = player_stats[my_id]["mana"]
		var my_health = player_stats[my_id]["health"]
		mana_label.text = "HP: %d | Mana: %d" % [my_health, my_mana]
		
	# Test Functionalities for toggling between scenes:
	var is_my_turn: bool = (multiplayer.get_unique_id() == active_player_id)
	
	# 5. Safe button toggle
	#var is_my_turn: bool = (my_id == active_player_id)
	if is_my_turn and current_state != MatchState.SIMULATING:
		next_phase_button.show()
	else:
		next_phase_button.hide()
		
	# Test Functionalities for toggling between scenes:
	if is_my_turn and current_state == MatchState.AIM:
		switch_to_terrain_button.show()
	else:
		switch_to_terrain_button.hide()
		
	if current_state == MatchState.SIMULATING and terrain_node != null:
		_return_to_match()
		
	# --- NEW: Draw Dummy Cards on DRAW Phase ---
	if current_state == MatchState.DRAW and is_my_turn:
		# Clear existing cards
		for child in hand_container.get_children():
			child.queue_free()
			
		# Spawn 3 dummy cards
		for i in range(3):
			var random_card_data = card_database.pick_random()
			var card_node = CARD_SCENE.instantiate()
			card_node.setup(random_card_data) # Use the setup function
			hand_container.add_child(card_node)
			
# --- CLIENT REQUESTS ---
func _on_next_phase_pressed() -> void:
	# The client clicks the button, sending a request ONLY to the Server (ID 1)
	_request_next_phase.rpc_id(1)

# "any_peer" means a client can call this on the server
@rpc("any_peer", "call_local", "reliable")
func _request_next_phase() -> void:
	if not multiplayer.is_server():
		return
		
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	# SECURITY CHECK: Did a player try to change the phase when it isn't their turn?
	if sender_id != active_player_id:
		printerr("Cheat detected! Peer %s tried to advance turn, but it is %s's turn." % [sender_id, active_player_id])
		return
		
	# State Machine Logic
	match current_state:
		MatchState.DRAW:
			_set_state(MatchState.PLAY)
		MatchState.PLAY:
			_set_state(MatchState.AIM)
		MatchState.AIM:
			_set_state(MatchState.SIMULATING)
			# Simulate a 2-second physics delay where marbles are bouncing
			await get_tree().create_timer(2.0).timeout
			_advance_turn()

# --- LOADING SYNC LOGIC ---

@rpc("any_peer", "call_remote", "reliable")
func _notify_server_loaded() -> void:
	# Double check that only the server processes this
	if not multiplayer.is_server(): 
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	players_loaded += 1
	print("Server: Received ready signal from Peer ", sender_id, ". Total loaded: ", players_loaded, "/", NetworkManager.players.size())
	
	_check_all_players_loaded()

func _check_all_players_loaded() -> void:
	print("Server: Checking if all players are loaded... (", players_loaded, "/", NetworkManager.players.size(), ")")
	
	if players_loaded == NetworkManager.players.size():
		_initialize_match()

# --- CARD PLAYING LOGIC ---

func _on_card_dropped(card_id: int, card_node: Node) -> void:
	var is_my_turn: bool = (multiplayer.get_unique_id() == active_player_id)
	
	# Rule check: Can only play cards on YOUR turn, during the PLAY phase
	if not is_my_turn or current_state != MatchState.PLAY:
		print("Client: Cannot play cards right now!")
		card_node.modulate.a = 1.0 # Reset visual
		return
		
	print("Client: Requesting to play card ", card_id)
	# Ask the Server for permission
	_request_play_card.rpc_id(1, card_id)
	
	# Temporarily hide the card while waiting for server response
	card_node.hide()

@rpc("any_peer", "call_local", "reliable")
func _request_play_card(card_instance_id: int) -> void:
	if not multiplayer.is_server(): return
	
	# Find the card data being played (for now we simulate finding it in player hand)
	# In a real deck, you'd track the hand on the server.
	var played_card: CardData = null
	for c in card_database:
		if c.get_instance_id() == card_instance_id:
			played_card = c
			break
			
	if played_card == null: return

	# 1. MANA CHECK
	var current_mana = player_stats[active_player_id]["mana"]
	if current_mana < played_card.mana_cost:
		print("Server: Not enough mana!")
		return
	
	# 2. DEDUCT MANA
	player_stats[active_player_id]["mana"] -= played_card.mana_cost
	_sync_stats.rpc(player_stats)
	
	# 3. TRIGGER EFFECT
	EffectHandler.execute_card_effect(played_card, active_player_id)
	
	# 4. NOTIFY CLIENTS
	_card_successfully_played.rpc(card_instance_id)

@rpc("authority", "call_local", "reliable")
func _card_successfully_played(card_id: int) -> void:
	print("Network: Player played Card ID: ", card_id)
	
	# Look through the local hand. If we have the card, permanently delete it
	for card in hand_container.get_children():
		if card is Card and card.card_id == card_id:
			card.queue_free()
			break

@rpc("authority", "call_local", "reliable")
func _sync_stats(updated_stats: Dictionary) -> void:
	player_stats = updated_stats
	_update_ui()
	
# Test Functionalities for toggling between scenes:
func _on_switch_to_terrain_pressed() -> void:
	$Node2D.visible = false
	$HUD.visible = false
	terrain_node = load("res://scenes/terrain/terrain.tscn").instantiate()
	terrain_node.name = "Terrain_" + str(multiplayer.get_unique_id())
	terrain_node.match_node = self
	get_tree().root.add_child(terrain_node)
	await get_tree().process_frame
	terrain_node.set_visible_terrain(true)

func _return_to_match() -> void:
	if terrain_node != null:
		terrain_node.queue_free()
		terrain_node = null
	$HUD.visible = true
	$Node2D.visible = true

func _set_terrain_visible(show: bool) -> void:
	if terrain_node != null:
		terrain_node.set_visible_terrain(show)
