@tool
extends AnimatableBody2D
class_name AnchorDragPlatform

const WORLD_LAYER := 1

@export var size: Vector2 = Vector2(220, 32):
	set(value):
		size = value
		_refresh_editor_shape()
@export var target_offset: Vector2 = Vector2(340, 0)
@export var drag_speed: float = 130.0
@export var drag_radius: float = 120.0
@export var enabled: bool = false
@export var fill_color: Color = Color("#7fb069"):
	set(value):
		fill_color = value
		_rebuild_visual()

var _start_position: Vector2


func _ready() -> void:
	add_to_group("anchor_drag_platforms")
	collision_layer = WORLD_LAYER
	collision_mask = 0
	_start_position = global_position
	_refresh_editor_shape()


func set_enabled(value: bool) -> void:
	enabled = value


func try_drag(anchor_position: Vector2, reel_active: bool, delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or not reel_active:
		return
	if anchor_position.distance_to(global_position) > drag_radius:
		return
	var target_position := _start_position + target_offset
	var offset := target_position - global_position
	if offset.length() <= 1.0:
		global_position = target_position
		return
	global_position += offset.normalized() * min(drag_speed * delta, offset.length())


func _refresh_editor_shape() -> void:
	if not is_inside_tree():
		return
	_setup_collision()
	_rebuild_visual()


func _setup_collision() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect


func _rebuild_visual() -> void:
	if not is_inside_tree():
		return
	_clear_auto_visual()
	var visual := Polygon2D.new()
	visual.name = "AutoVisual"
	visual.color = fill_color
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
