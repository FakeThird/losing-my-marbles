extends Control

var lever_dragging: bool = false
var track_height: float = 200.0
var min_pull_threshold: float = 0.05
var idle_y: float = 0.0
var wiggling: bool = false

@onready var controller: Node = get_node("../../MarbleController")

func _ready():
	$Container/Lever.gui_input.connect(_on_lever_input)
	idle_y = $Container/Lever.position.y
	var lever_height = $Container/Lever.size.y
	$Container/Track.size.y = track_height + lever_height
	var border_size = 4
	$Container.size = $Container/Track.size + Vector2(border_size, border_size)

func _on_lever_input(event):
	if not GameState.active_marble:
		return
	if GameState.active_marble.linear_velocity.length() > 5:
		return
	if controller.is_rotating:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			lever_dragging = true
		else:
			if lever_dragging:
				var pull = ($Container/Lever.position.y - idle_y) / track_height
				pull = clamp(pull, 0.0, 1.0)
				if pull > min_pull_threshold:
					controller.launch(pull * 3.0)
				else:
					GameState.active_marble.update_aim_line(0.5, controller.aim_angle)
				wiggling = false
				$Container/Lever.rotation = 0.0
				var tween = create_tween()
				tween.tween_property($Container/Lever, "position:y", idle_y, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
			lever_dragging = false

func _input(event):
	if not lever_dragging:
		return
	if event is InputEventMouseMotion:
		var new_y = $Container/Lever.position.y + event.relative.y
		$Container/Lever.position.y = clamp(new_y, idle_y, idle_y + track_height)

func _process(_delta):
	var pull = ($Container/Lever.position.y - idle_y) / track_height
	pull = clamp(pull, 0.0, 1.0)
	$Container/Lever.color = Color(pull, 1.0 - pull, 0.2)
	if GameState.active_marble and controller:
		controller.update_prediction(lerp(0.5, 1.0, pull))
	if lever_dragging and pull >= 0.95:
		if not wiggling:
			wiggling = true
			wiggle()
	else:
		wiggling = false
		$Container/Lever.rotation = 0.0

func wiggle():
	if not wiggling:
		return
	var tween = create_tween()
	tween.tween_property($Container/Lever, "rotation", deg_to_rad(3.0), 0.05)
	tween.tween_property($Container/Lever, "rotation", deg_to_rad(-3.0), 0.05)
	tween.tween_property($Container/Lever, "rotation", deg_to_rad(2.0), 0.05)
	tween.tween_property($Container/Lever, "rotation", deg_to_rad(-2.0), 0.05)
	tween.tween_property($Container/Lever, "rotation", 0.0, 0.05)
	tween.tween_callback(wiggle)
