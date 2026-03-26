extends Control

@onready var ip_input: LineEdit = %IPInput
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var player_list: ItemList = %PlayerList
@onready var start_match_button: Button = %StartMatchButton

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.player_list_updated.connect(_update_lobby_ui)
	start_match_button.pressed.connect(_on_start_match_pressed)

func _on_host_pressed() -> void:
	NetworkManager.host_game()
	_disable_buttons()

func _on_join_pressed() -> void:
	var ip: String = ip_input.text if ip_input.text != "" else "127.0.0.1"
	NetworkManager.join_game(ip)
	_disable_buttons()

func _disable_buttons() -> void:
	host_button.disabled = true
	join_button.disabled = true
	ip_input.editable = false

func _update_lobby_ui() -> void:
	print("--- Updating Lobby UI ---")
	print("Current players dict: ", NetworkManager.players)
	
	if player_list == null:
		printerr("ERROR: PlayerList node is missing!")
		return
		
	player_list.clear()
	
	# Loop through the dictionary and add items
	for peer_id in NetworkManager.players:
		var p_name: String = NetworkManager.players[peer_id]["name"]
		player_list.add_item(p_name)
	
	# Safe check for the Start Match button
	if start_match_button != null:
		if multiplayer.is_server() and NetworkManager.players.size() > 1:
			start_match_button.show()
		else:
			start_match_button.hide()

func _on_start_match_pressed() -> void:
	# We will implement this in Phase 3
	NetworkManager.start_match()
