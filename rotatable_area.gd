extends Area2D

@export var player_marble: RigidBody2D
var bodies_in_zone = []
var rotate_left = false
var rotate_right = false
var ejected_count = 0
var reset_timer: SceneTreeTimer = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
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
	print(body.name + " with sprite " + body.marble_color + " has been pushed out")
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(body):
		body.queue_free()
		ejected_count += 1
		update_multiplier()

func update_multiplier():
	var label = $"../FullHUD/Multiplier"
	var multiplier = 1.0 + ejected_count
	var size = 32 + (ejected_count * 4)
	label.text = "x%d" % multiplier
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

	ejected_count = 0
	reset_timer = null
	label.text = ""
	label.add_theme_font_size_override("font_size", 32)
	var shrink = create_tween()
	shrink.tween_property(label, "scale", Vector2(0.0, 0.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
	await shrink.finished
	label.scale = Vector2(1.0, 1.0)

func _physics_process(delta):
	if player_marble and player_marble.linear_velocity.length() > 5:
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
				# use physics server to move without breaking physics
				PhysicsServer2D.body_set_state(
					body.get_rid(),
					PhysicsServer2D.BODY_STATE_TRANSFORM,
					Transform2D(body.rotation, new_pos)
				)
			else:
				# fallback for non-rigidbody nodes
				var offset = body.global_position - global_position
				body.global_position = global_position + offset.rotated(delta_angle)
