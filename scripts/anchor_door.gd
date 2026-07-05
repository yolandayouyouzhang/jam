@tool
extends LevelBlock
class_name AnchorDoor

@export var starts_open: bool = false
@export var opens_on_repair: bool = false

var open: bool = false


func _ready() -> void:
	block_kind = BlockKind.DOOR
	super._ready()
	add_to_group("anchor_doors")
	if opens_on_repair:
		add_to_group("repair_doors")
	set_open(starts_open)


func set_open(value: bool) -> void:
	open = value
	visible = not open
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", open)
