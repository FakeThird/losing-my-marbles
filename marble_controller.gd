extends Node

@export var active_marble: RigidBody2D

var is_rotating: bool = false
var aim_angle: float = -PI / 2

func _ready():
	if active_marble:
		active_marble.update_aim_line(0.5, aim_angle)

func set_active(marble: RigidBody2D):
	active_marble = marble
	is_rotating = false
	aim_angle = -PI / 2
	active_marble.update_aim_line(0.5, aim_angle)

func _input(event):
	if not active_marble:
		return
	if active_marble.linear_velocity.length() > 5:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var dist = get_viewport().get_camera_2d().get_global_mouse_position().distance_to(active_marble.global_position)
		if event.pressed and dist < 30.0:
			is_rotating = true
		else:
			is_rotating = false

	if event is InputEventMouseMotion and is_rotating:
		var dir = active_marble.get_global_mouse_position() - active_marble.global_position
		aim_angle = dir.angle()
		active_marble.update_aim_line(0.5, aim_angle)

func launch(power: float):
	if not active_marble:
		return
	active_marble.launch(power, aim_angle)
