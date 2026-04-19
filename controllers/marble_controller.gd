extends Node

var is_rotating: bool = false
var aim_angle: float = -PI / 2

@export var aim_line: Line2D
@export var bounce_line: Line2D
@export var hit_indicator: Node2D

func _ready():
	GameState.marble_stopped.connect(_on_marble_stopped)

func _on_marble_stopped():
	is_rotating = false
	aim_angle = -PI / 2
	aim_line.visible = true
	bounce_line.visible = true
	hit_indicator.visible = true
	update_prediction(0.5)

func update_prediction(power: float = 0.5):
	if not GameState.active_marble:
		return
	if GameState.active_marble.linear_velocity.length() > 5:
		aim_line.visible = false
		bounce_line.visible = false
		hit_indicator.visible = false

	var start = GameState.active_marble.global_position
	var direction = Vector2(cos(aim_angle), sin(aim_angle))
	var line_length = lerp(50.0, 300.0, power)

	var space = GameState.active_marble.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start, start + direction * line_length)
	query.exclude = [GameState.active_marble.get_rid()]
	var result = space.intersect_ray(query)

	aim_line.clear_points()
	aim_line.add_point(start)
	bounce_line.clear_points()
	hit_indicator.visible = false

	if result:
		aim_line.add_point(result.position)
		if result.collider is RigidBody2D:
			hit_indicator.global_position = result.position
			hit_indicator.visible = true
			bounce_line.add_point(result.position)
			bounce_line.add_point(result.position + result.normal * 100.0)
		else:
			var bounce_dir = direction.bounce(result.normal)
			bounce_line.add_point(result.position)
			bounce_line.add_point(result.position + bounce_dir * 100.0)
	else:
		aim_line.add_point(start + direction * line_length)
	
func _input(event):
	if not GameState.active_marble:
		return
	if GameState.active_marble.linear_velocity.length() > 5:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var dist = get_viewport().get_camera_2d().get_global_mouse_position().distance_to(GameState.active_marble.global_position)
		if event.pressed and dist < 30.0:
			is_rotating = true
		else:
			is_rotating = false
	if event is InputEventMouseMotion and is_rotating:
		aim_angle = (GameState.active_marble.get_global_mouse_position() - GameState.active_marble.global_position).angle()
		update_prediction(0.5)

func launch(power: float):
	if not GameState.active_marble:
		return
	GameState.active_marble.launch(power, aim_angle)
