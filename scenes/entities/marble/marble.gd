extends RigidBody2D

@export var is_player: bool = false
@export var speed: float = 350.0

# Connects to DebugData in StickyHUD
@export var stats_label: Label

# Initialize color to playable marble
var marble_color: String = "white"
var launched: bool = false
var screensize: Vector2 = DisplayServer.window_get_size()

# Initial RigidBody Data:
# Mass: 1kg
# Gravity Scale: 0
# Linear Damp: 0.3
# Angular Damp: 1.0

# Initial PhysicsMat Data:
# Bounce: 1.0
# Friction: 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_player:
		GameState.set_active_marble(self)
		reset_position()
	else:
		call_deferred("setup_animation")

func setup_animation() -> void:
	$AnimatedSprite2D.animation = marble_color + "_idle"
	$AnimatedSprite2D.play()

func reset_position() -> void:
	position = Vector2(screensize.x / 2, 450)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	launched = false
	GameState.on_marble_stopped()

func launch(power: float, aim_angle: float) -> void:
	var direction = Vector2(cos(aim_angle), sin(aim_angle))
	apply_central_impulse(direction * power * speed)
	launched = true
	GameState.on_marble_launched()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
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

func _on_body_entered(body) -> void:
	var spd = linear_velocity.length()
	$Bounce.volume_db = clamp(linear_to_db(spd / speed), -20.0, 0.0)
	$Bounce.play()
	if is_player and spd > 300.0:
		GameState.on_marble_hit()
