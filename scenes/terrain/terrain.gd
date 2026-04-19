extends Node2D

var using_zoom = false
var shake_amount: float = 0.0

func _ready():
	$"StickyHUD/SwitchCamera".pressed.connect(switch_camera)
	$FlickHUD.visible = false
	$FullCamera.make_current()
	GameState.marble_launched.connect(_on_marble_launched)
	GameState.marble_hit.connect(_on_marble_hit)

func _on_marble_launched():
	using_zoom = false
	$FullCamera.make_current()
	$"StickyHUD/SwitchCamera".text = "Flick"
	$FullHUD.visible = true
	$FlickHUD.visible = false

func _on_marble_hit():
	shake_amount = 5.0

func _process(delta):
	var camera = $FullCamera if not using_zoom else $ZoomCamera
	if shake_amount > 0:
		camera.offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_amount = lerp(shake_amount, 0.0, 0.2)
		if shake_amount < 0.1:
			shake_amount = 0.0
			camera.offset = Vector2.ZERO

func switch_camera():
	if GameState.active_marble and GameState.active_marble.linear_velocity.length() > 5:
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
