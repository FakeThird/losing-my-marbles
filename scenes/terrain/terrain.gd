extends Node2D

var using_zoom = false
var shake_amount: float = 0.0

# Test Functionalities for toggling between scenes:
var match_node: Node = null

func _ready():
	$"StickyHUD/SwitchCamera".pressed.connect(switch_camera)
	# Start fully hidden — MatchManager will show us after one frame
	$FlickHUD.hide()
	$FullHUD.hide()
	$StickyHUD.hide()
	self.visible = false
	# DO NOT call make_current() here
	GameState.marble_launched.connect(_on_marble_launched)
	GameState.marble_hit.connect(_on_marble_hit)

	# Test Functionalities for toggling between scenes:
	var return_canvas := CanvasLayer.new()
	add_child(return_canvas)
	# Use a full-rect container so anchoring works
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_canvas.add_child(anchor)
	var return_btn := Button.new()
	return_btn.text = "Back to Match"
	return_btn.name = "ReturnToMatchButton"
	# Anchor to bottom-left
	return_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	return_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return_btn.size = Vector2(150, 40)
	anchor.add_child(return_btn)
	return_btn.pressed.connect(_on_return_to_match_pressed)

# Test Functionalities for toggling between scenes:
# Called by MatchManager to show/hide this entire scene cleanly
func set_visible_terrain(show: bool) -> void:
	if show:
		self.visible = true
		$FullHUD.show()
		$StickyHUD.show()
		$FlickHUD.hide()  # FlickHUD always starts hidden
		$FullCamera.make_current()  # only activate camera when actually visible
	else:
		$FullHUD.hide()
		$StickyHUD.hide()
		$FlickHUD.hide()
		self.visible = false

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

# Test Functionalities for toggling between scenes:
func _on_return_to_match_pressed() -> void:
	if match_node == null:
		push_warning("Terrain: match_node not assigned.")
		return
	match_node._return_to_match()

func _exit_tree() -> void:
	if GameState.marble_launched.is_connected(_on_marble_launched):
		GameState.marble_launched.disconnect(_on_marble_launched)
	if GameState.marble_hit.is_connected(_on_marble_hit):
		GameState.marble_hit.disconnect(_on_marble_hit)
