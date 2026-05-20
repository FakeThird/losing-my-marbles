class_name Marble
extends RigidBody2D

const RADIUS: float = 15.0
const MARBLE_COLOR := Color(0.82, 0.82, 0.85, 1.0)

var marble_data: MarbleData = null
var owner_player_id: int = 0

const SPRITE_TARGET_DIAMETER: float = RADIUS * 2.0

var _sprite: AnimatedSprite2D = null

func _process(delta: float) -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	var speed = linear_velocity.length()
	if speed > 5.0:
		# scale animation speed with velocity, adjust 0.02 to taste
		_sprite.speed_scale = speed * 0.02
		if not _sprite.is_playing():
			_sprite.play("roll")
	else:
		# pause on current frame instead of resetting
		_sprite.pause()

static func make_circle_texture(color: Color) -> ImageTexture:
	var size := int(RADIUS * 2 + 4)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in size:
		for y in size:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= RADIUS:
				image.set_pixel(x, y, color)
			elif dist <= RADIUS + 2.0:
				image.set_pixel(x, y, color.darkened(0.3))
	return ImageTexture.create_from_image(image)


func setup(data: MarbleData, player_id: int) -> void:
	marble_data = data
	owner_player_id = player_id

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	if data and data.physics:
		linear_damp = data.physics.friction
		mass = data.physics.weight
		gravity_scale = data.physics.gravity_modifier

		var phys_mat := PhysicsMaterial.new()
		phys_mat.bounce = data.physics.elasticity
		physics_material_override = phys_mat

	add_to_group("field_marbles")

	var tex: Texture2D = null
	var tex_is_asset: bool = false
	if data and not data.card_name.is_empty():
		var path := "res://assets/sprites/marbles/%s.png" % data.card_name.to_snake_case()
		if ResourceLoader.exists(path):
			var loaded := ResourceLoader.load(path)
			if loaded is Texture2D:
				tex = loaded
				tex_is_asset = true
	if not tex:
		tex = make_circle_texture(MARBLE_COLOR)
		
	if not _sprite:
		_sprite = get_node("%Sprite") as AnimatedSprite2D
	
	# Force nearest neighbor filtering on the node
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Set texture on the sprite frames
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("roll")
	sprite_frames.set_animation_loop("roll", true)
	
	# Calculate frame size
	var frame_width := tex.get_width() / 4.0
	var frame_height := tex.get_height()
	
	for i in 4:
		var frame_tex := AtlasTexture.new()
		frame_tex.atlas = tex
		frame_tex.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		sprite_frames.add_frame("roll", frame_tex)
	
	_sprite.sprite_frames = sprite_frames
	_sprite.play("roll")
	
	# --- FIXING SIZE OVERWRITE LOGIC HERE ---
	if tex_is_asset:
		# Scale based on the size of a single frame, not the whole spritesheet width!
		_sprite.scale = Vector2(SPRITE_TARGET_DIAMETER / frame_width, SPRITE_TARGET_DIAMETER / frame_height)
	else:
		_sprite.scale = Vector2.ONE
		
	# --- Collision Sound Configuration ---
	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


# --- ADDED: Collision Handler Function ---
func _on_body_entered(_body: Node) -> void:
	AudioManager.play_ui_sound("collide")
