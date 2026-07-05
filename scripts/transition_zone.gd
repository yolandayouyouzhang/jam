@tool
extends Node2D
class_name TransitionZone

@export var size: Vector2 = Vector2(260, 220):
	set(value):
		size = value
		_rebuild_visual()
@export var color: Color = Color(0.75, 1.0, 0.72, 0.16):
	set(value):
		color = value
		_rebuild_visual()


func _ready() -> void:
	add_to_group("transition_zones")
	_rebuild_visual()


func contains_point(point: Vector2) -> bool:
	return abs(point.x - global_position.x) <= size.x * 0.5 and abs(point.y - global_position.y) <= size.y * 0.5


func _rebuild_visual() -> void:
	if not is_inside_tree():
		return
	_clear_auto_visual()
	var visual := Polygon2D.new()
	visual.name = "AutoVisual"
	visual.color = color
	visual.polygon = _rect_points(size)
	add_child(visual)


func _clear_auto_visual() -> void:
	var old_visual := get_node_or_null("AutoVisual")
	if old_visual == null:
		return
	remove_child(old_visual)
	old_visual.free()


func _rect_points(rect_size: Vector2) -> PackedVector2Array:
	var hw := rect_size.x * 0.5
	var hh := rect_size.y * 0.5
	return PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	])
