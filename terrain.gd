extends Node2D

@export var player_ball: RigidBody2D
var using_zoom = false

func _ready():
	$"StickyHUD/SwitchCamera".pressed.connect(switch_camera)
	$FlickHUD.visible = false
	$FullCamera.make_current()
	player_ball.ball_pushed.connect(_on_ball_pushed)

func _on_ball_pushed():
	using_zoom = false
	$FullCamera.make_current()
	$"StickyHUD/SwitchCamera".text = "Flick"
	$FullHUD.visible = true
	$FlickHUD.visible = false

func switch_camera():
	if player_ball and player_ball.linear_velocity.length() > 5:
		return
	using_zoom = !using_zoom
	if using_zoom:
		$ZoomCamera.make_current()
		$"StickyHUD/SwitchCamera".text = "Move Around"
		$FullHUD.visible = false
		$FlickHUD.visible = true
	else:
		$FullCamera.make_current()
		$"StickyHUD/SwitchCamera".text = "Flick"
		$FullHUD.visible = true
		$FlickHUD.visible = false
