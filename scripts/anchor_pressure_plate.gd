@tool
extends AnchorButton
class_name AnchorPressurePlate


func _ready() -> void:
	super._ready()
	remove_from_group("anchor_buttons")
	add_to_group("anchor_pressure_plates")
