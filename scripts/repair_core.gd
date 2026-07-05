@tool
extends LevelBlock
class_name RepairCore


func _ready() -> void:
	block_kind = BlockKind.CORE
	fill_color = Color("#6bb7c8")
	super._ready()
	set_meta("repair_core", true)
	add_to_group("repair_cores")
