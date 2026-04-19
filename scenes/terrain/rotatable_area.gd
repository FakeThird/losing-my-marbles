extends Area2D

var bodies_in_zone = []
var rotate_left = false
var rotate_right = false
var reset_timer: SceneTreeTimer = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.marble_ejected.connect(_on_marble_ejected)
	$"../FullHUD/RotateLeft".button_down.connect(func(): rotate_left = true)
	$"../FullHUD/RotateLeft".button_up.connect(func(): rotate_left = false)
	$"../FullHUD/RotateRight".button_down.connect(func(): rotate_right = true)
	$"../FullHUD/RotateRight".button_up.connect(func(): rotate_right = false)

func _on_body_entered(body):
	bodies_in_zone.append(body)

func _on_body_exited(body):
	bodies_in_zone.erase(body)
	if body.is_player:
		return
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(body):
		body.queue_free()
		GameState.on_marble_ejected()

func _on_marble_ejected(count: int):
	update_multiplier(count)

func update_multiplier(count: int):
	var label = $"../FullHUD/Multiplier"
	var size = 32 + (count * 4)
	label.text = "x%d" % (1 + count)
	$"../FullHUD/Multiplier/Multiplier".play()
	label.add_theme_font_size_override("font_size", size)
	label.scale = Vector2(1.5, 1.5)
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
	var my_timer = get_tree().create_timer(3.0)
	reset_timer = my_timer
	await my_timer.timeout
	if reset_timer != my_timer:
		return
	GameState.reset_ejected()
	label.text = ""
	label.add_theme_font_size_override("font_size", 32)
	var shrink = create_tween()
	shrink.tween_property(label, "scale", Vector2(0.0, 0.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
	await shrink.finished
	label.scale = Vector2(1.0, 1.0)

func _physics_process(delta):
	if GameState.active_marble and GameState.active_marble.linear_velocity.length() > 5:
		return
	var delta_angle = 0.0
	if rotate_left:
		delta_angle = deg_to_rad(-90.0 * delta)
	elif rotate_right:
		delta_angle = deg_to_rad(90.0 * delta)
	if delta_angle != 0.0:
		rotation += delta_angle
		for body in bodies_in_zone:
			if body is RigidBody2D:
				var offset = body.global_position - global_position
				var new_pos = global_position + offset.rotated(delta_angle)
				PhysicsServer2D.body_set_state(
					body.get_rid(),
					PhysicsServer2D.BODY_STATE_TRANSFORM,
					Transform2D(body.rotation, new_pos)
				)
			else:
				var offset = body.global_position - global_position
				body.global_position = global_position + offset.rotated(delta_angle)
