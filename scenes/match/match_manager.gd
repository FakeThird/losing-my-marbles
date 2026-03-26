class_name MatchManager
extends Node2D

# 1. Define the game loop phases based on your PDF
enum MatchState { INITIALIZATION, DRAW, PLAY, AIM, SIMULATING, END_TURN }

var current_state: MatchState = MatchState.INITIALIZATION
var active_player_id: int = 0
var turn_order: Array =[]
var current_turn_index: int = 0
var players_loaded: int = 0

@onready var turn_label: Label = %TurnLabel
@onready var phase_label: Label = %PhaseLabel
@onready var next_phase_button: Button = %NextPhaseButton

func _ready() -> void:
	# Hide the button by default
	next_phase_button.hide()
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	
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
	print("Server: Initializing Match...")
	
	# Grab the dictionary keys (peer IDs) from our NetworkManager and convert to Array
	turn_order = NetworkManager.players.keys()
	
	# Randomize turn order!
	turn_order.shuffle()
	
	# Set the first player and start their turn
	current_turn_index = 0
	active_player_id = turn_order[current_turn_index]
	
	# Wait a tiny fraction of a second to ensure clients have loaded the scene
	#await get_tree().create_timer(0.5).timeout 
	_set_state(MatchState.DRAW)

# --- SERVER LOGIC ---
# Only the server should ever call this function directly
func _set_state(new_state: MatchState) -> void:
	current_state = new_state
	print("Server: State changed to ", MatchState.keys()[current_state])
	
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
	# Look up the active player's name from the global NetworkManager
	var p_name: String = NetworkManager.players[active_player_id]["name"]
	
	turn_label.text = p_name + "'s Turn"
	phase_label.text = "Phase: " + MatchState.keys()[current_state]
	
	# Does the current client own this turn?
	var is_my_turn: bool = (multiplayer.get_unique_id() == active_player_id)
	
	# Only show the "Next Phase" button if it's MY turn, and we aren't simulating physics
	if is_my_turn and current_state != MatchState.SIMULATING:
		next_phase_button.show()
	else:
		next_phase_button.hide()

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
