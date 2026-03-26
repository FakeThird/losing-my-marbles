extends Node

const PORT: int = 7000
const DEFAULT_SERVER_IP: String = "127.0.0.1"

var multiplayer_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var players: Dictionary = {}

signal player_list_updated
signal match_started

func _ready() -> void:
	# Connect multiplayer signals to handle peer events
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game() -> void:
	var error: int = multiplayer_peer.create_server(PORT)
	if error != OK:
		printerr("Failed to host: ", error)
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# Host is always ID 1. Add self to list.
	players[1] = {"id": 1, "name": "Player (Host)"}
	player_list_updated.emit()
	print("Hosting on port ", PORT)
	

func join_game(ip: String = DEFAULT_SERVER_IP) -> void:
	var error: int = multiplayer_peer.create_client(ip, PORT)
	if error != OK:
		printerr("Failed to join: ", error)
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Joining server at ", ip)

# --- Signal Callbacks ---
func _on_peer_connected(id: int) -> void:
	print("Peer connected! ID: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected! ID: ", id)
	if multiplayer.is_server():
		players.erase(id)
		player_list_updated.emit()
		_send_full_player_list.rpc(players)

func _on_connected_to_server() -> void:
	print("Successfully connected to the server!")
	# Tell the server (and everyone else) who we are
	var my_id: int = multiplayer.get_unique_id()
	_register_player.rpc_id(1, my_id, "Player " + str(my_id))

func _on_connection_failed() -> void:
	print("Failed to connect to the server.")

# "any_peer" means clients are allowed to call this on the server
# "call_remote" means it only runs on the machine receiving the RPC, not the caller
@rpc("any_peer", "call_remote", "reliable")
func _register_player(id: int, player_name: String) -> void:
	# Double-check that only the server is processing this request
	if multiplayer.is_server():
		print("Server received registration for: ", player_name)
		players[id] = {"id": id, "name": player_name}
		
		# Update the Server's own UI
		player_list_updated.emit()
		
		# Broadcast the new, full dictionary to ALL connected clients
		_send_full_player_list.rpc(players)

# "authority" means ONLY the server (ID 1) is allowed to call this on clients
@rpc("authority", "call_remote", "reliable")
func _send_full_player_list(updated_players: Dictionary) -> void:
	print("Client received new player list from server!")
	players = updated_players
	player_list_updated.emit()

# Only the server calls this
func start_match() -> void:
	if not multiplayer.is_server():
		return
	
	var match_scene = load("res://scenes/match/match.tscn").instantiate()
	# Add it to the tree. The MultiplayerSpawner will detect this
	# and automatically replicate it to all connected clients!
	get_tree().root.get_node("Main/LevelContainer").add_child(match_scene)
	
	# Tell all clients to hide their menus
	_hide_menus.rpc()

@rpc("call_local", "reliable")
func _hide_menus() -> void:
	match_started.emit()
