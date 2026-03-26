extends Node

@onready var main_menu: Control = $MainMenu
@onready var level_container: Node = $LevelContainer
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
	# Listen for a custom signal from the network manager to hide UI
	NetworkManager.match_started.connect(_on_match_started)
	spawner.add_spawnable_scene("res://scenes/match/match.tscn")

func _on_match_started() -> void:
	main_menu.hide()
