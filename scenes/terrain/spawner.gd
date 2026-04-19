extends Marker2D

# Marble Count, amount placeholder for summoning marbles 
# SpawnRadius, area of spawning
# MarbleRadius, to avoid spawning in same location

@export var marble_scene: PackedScene
@export var marble_count: int = 10
@export var spawn_radius: float = 170.0
@export var marble_radius: float = 16.0

func _ready():
	$"../FullHUD/SpawnMarbles".pressed.connect(spawn_marbles)

func spawn_marbles():
	if GameState.active_marble and GameState.active_marble.linear_velocity.length() > 5:
		return
	var colors = ["red", "blue", "yellow"]
	var placed_positions = []
	for i in marble_count:
		var marble = marble_scene.instantiate()
		var spawn_pos = find_valid_position(placed_positions)
		marble.position = spawn_pos
		placed_positions.append(spawn_pos)
		get_parent().add_child.call_deferred(marble)
		marble.marble_color = colors[randi() % colors.size()]

func find_valid_position(placed_positions: Array) -> Vector2:
	var attempts = 0
	while attempts < 100:
		var angle = randf() * TAU
		var distance = randf() * spawn_radius
		var candidate = position + Vector2(cos(angle), sin(angle)) * distance
		var overlapping = false
		for placed in placed_positions:
			if candidate.distance_to(placed) < marble_radius * 2:
				overlapping = true
				break
		if not overlapping:
			return candidate
		attempts += 1
	return position
