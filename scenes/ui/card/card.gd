class_name Card
extends PanelContainer

@export var card_id: int = 0
@export var card_name: String = "Test Card"

@onready var name_label: Label = %NameLabel
@onready var type_label: Label = %TypeLabel
@onready var desc_label: Label = %DescriptionLabel

var data: CardData

func _ready() -> void:
	#name_label.text = card_name
	pass

# Built-in Godot function for dragging Control nodes
func _get_drag_data(at_position: Vector2) -> Variant:
	# 1. Create a visual preview that follows the mouse
	var preview: Control = _create_drag_preview()
	set_drag_preview(preview)
	
	# 2. Hide the actual card in the hand while dragging
	modulate.a = 0.5 
	
	# 3. Return the data payload
	return {
		"type": "card",
		"card_id": card_id,
		"original_node": self
	}

func _create_drag_preview() -> Control:
	var preview: PanelContainer = duplicate()
	preview.modulate.a = 1.0
	# Offset the preview so the mouse is in the center of the card
	preview.position = -size / 2.0 
	
	# Wrap it in a bare Control node to respect the offset
	var wrapper := Control.new()
	wrapper.add_child(preview)
	return wrapper

# If the player lets go of the mouse and it ISN'T on a valid drop zone
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if not get_viewport().gui_is_drag_successful():
			# Snap it back to full opacity if drag failed/was cancelled
			modulate.a = 1.0

func setup(card_resource: CardData) -> void:
	data = card_resource
	card_id = data.get_instance_id() # Unique ID for this specific card instance
	%NameLabel.text = data.card_name
	%TypeLabel.text = CardData.Type.keys()[data.type]
	%DescriptionLabel.text = data.description
	if has_node("%CostLabel"):
		get_node("%CostLabel").text = str(data.mana_cost)
