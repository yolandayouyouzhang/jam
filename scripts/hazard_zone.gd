@tool
extends Node2D
class_name HazardZone

@export var size: Vector2 = Vector2(90, 72):
	set(value):
		size = value
		_rebuild_visual()
@export var color: Color = Color("#d64545"):
	set(value):
		color = value
		_rebuild_visual()


func _ready() -> void:
	add_to_group("hazard_zones")
	_rebuild_visual()


func _rebuild_visual() -> void:
	if not is_inside_tree():
		return
	_clear_auto_visual()
	var visual := Polygon2D.new()
	visual.name = "AutoVisual"
	visual.color = color
	var points := PackedVector2Array()
	var count := 6
	var half_w := size.x * 0.5
	var half_h := size.y * 0.5
	for i in count:
		var x0 := -half_w + size.x * float(i) / float(count)
		var x1 := -half_w + size.x * float(i + 1) / float(count)
		points.append(Vector2(x0, half_h))
		points.append(Vector2((x0 + x1) * 0.5, -half_h))
		points.append(Vector2(x1, half_h))
	visual.polygon = points
	add_child(visual)


func _clear_auto_visual() -> void:
	var old_visual := get_node_or_null("AutoVisual")
	if old_visual == null:
		return
	remove_child(old_visual)
	old_visual.free()


func contains_point(point: Vector2) -> bool:
	return abs(point.x - global_position.x) <= size.x * 0.5 and abs(point.y - global_position.y) <= size.y * 0.5
