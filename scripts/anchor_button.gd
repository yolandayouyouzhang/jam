@tool
extends Node2D
class_name AnchorButton

@export var size: Vector2 = Vector2(86, 22):
	set(value):
		size = value
		_rebuild_visual()
@export var door_path: NodePath
@export var idle_color: Color = Color("#ffc857"):
	set(value):
		idle_color = value
		_update_visual_color()
@export var pressed_color: Color = Color("#fff176"):
	set(value):
		pressed_color = value
		_update_visual_color()
@export var target_path: NodePath
@export var target_paths: Array = []

var pressed := false
var door: AnchorDoor
var targets: Array = []
var _visual: Polygon2D


func _ready() -> void:
	add_to_group("anchor_buttons")
	door = get_node_or_null(door_path) as AnchorDoor
	_resolve_targets()
	_rebuild_visual()
	set_pressed(false)


func _rebuild_visual() -> void:
	if not is_inside_tree():
		return
	_clear_auto_visual()
	_visual = Polygon2D.new()
	_visual.name = "AutoVisual"
	_visual.polygon = _rect_points(size)
	add_child(_visual)
	_update_visual_color()


func _clear_auto_visual() -> void:
	var old_visual := get_node_or_null("AutoVisual")
	if old_visual == null:
		return
	remove_child(old_visual)
	old_visual.free()


func contains_point(point: Vector2) -> bool:
	return abs(point.x - global_position.x) <= (size.x + 42.0) * 0.5 and abs(point.y - global_position.y) <= (size.y + 42.0) * 0.5


func set_pressed(value: bool) -> void:
	pressed = value
	_update_visual_color()
	if door != null and not Engine.is_editor_hint():
		door.set_open(pressed)
	if not Engine.is_editor_hint():
		for target in targets:
			if target != null and target.has_method("set_open"):
				target.call("set_open", pressed)
			elif target != null and target.has_method("set_active"):
				target.call("set_active", pressed)


func _update_visual_color() -> void:
	if _visual != null:
		_visual.color = pressed_color if pressed else idle_color


func _resolve_targets() -> void:
	targets.clear()
	if not target_path.is_empty():
		var primary_target := get_node_or_null(target_path)
		if primary_target != null:
			targets.append(primary_target)
	for extra_target_path in target_paths:
		if not (extra_target_path is NodePath):
			continue
		var target := get_node_or_null(extra_target_path as NodePath)
		if target != null:
			targets.append(target)


func _rect_points(rect_size: Vector2) -> PackedVector2Array:
	var hw := rect_size.x * 0.5
	var hh := rect_size.y * 0.5
	return PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	])
