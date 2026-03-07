extends RigidBody2D

signal ball_pushed
signal ball_stopped

@export var is_player: bool = false
@export var speed: float = 350.0
@export var stats_label: Label

var marble_color: String = "white"
var launched: bool = false
var screensize: Vector2 = DisplayServer.window_get_size()

func _ready():
	body_entered.connect(_on_body_entered)
	if is_player:
		reset_position()
	else:
		call_deferred("setup_animation")

func setup_animation():
	$AnimatedSprite2D.animation = marble_color + "_idle"
	$AnimatedSprite2D.play()

func reset_position() -> void:
	position.x = screensize.x / 2
	position.y = 450
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	launched = false
	$AimLine.visible = true
	ball_stopped.emit()

func launch(power: float, aim_angle: float):
	var direction = Vector2(cos(aim_angle), sin(aim_angle))
	apply_central_impulse(direction * power * speed)
	launched = true
	$AimLine.visible = false
	ball_pushed.emit()

func update_aim_line(power: float, aim_angle: float):
	if not is_player:
		return
	$AimLine.clear_points()
	$AimLine.add_point(Vector2.ZERO)
	var line_length = lerp(50.0, 300.0, power)
	$AimLine.add_point(Vector2(cos(aim_angle), sin(aim_angle)) * line_length)

func _integrate_forces(state: PhysicsDirectBodyState2D):
	if stats_label and is_player:
		stats_label.text = "Velocity: %.1f\nMass: %.1f" % [state.linear_velocity.length(), mass]
	if state.linear_velocity.length() > 5:
		$AnimatedSprite2D.animation = marble_color + "_pushed"
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.animation = marble_color + "_idle"
		$AnimatedSprite2D.play()
		if is_player and launched:
			reset_position()

func _on_body_entered(body):
	var spd = linear_velocity.length()
	$Bounce.volume_db = clamp(linear_to_db(spd / speed), -20.0, 0.0)
	$Bounce.play()
