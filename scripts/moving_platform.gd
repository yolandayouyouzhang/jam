@tool
extends AnimatableBody2D
class_name MovingPlatform

const WORLD_LAYER := 1

@export var size: Vector2 = Vector2(150, 28):
	set(value):
		size = value
		_refresh_editor_shape()
@export var travel: Vector2 = Vector2(220, 0):
	set(value):
		travel = value
		_update_target_position()
@export var speed: float = 130.0
@export var path_container_path: NodePath = ^"Path":
	set(value):
		path_container_path = value
		_refresh_path_points()
@export var active_on_start: bool = false
@export var ping_pong: bool = true
@export var wait_time: float = 0.2
@export var fill_color: Color = Color("#7dd3fc"):
	set(value):
		fill_color = value
		_rebuild_visual()

var active := false
var _start_position: Vector2
var _target_position: Vector2
var _path_points: Array[Vector2] = []
var _current_path_index := 0
var _target_path_index := 1
var _path_direction := 1
var _wait_timer := 0.0


func _ready() -> void:
	add_to_group("moving_platforms")
	collision_layer = WORLD_LAYER
	collision_mask = 0
	_start_position = global_position
	_update_target_position()
	_refresh_path_points()
	active = active_on_start
	_refresh_editor_shape()


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
	var auto_visual := Node2D.new()
	auto_visual.name = "AutoVisual"
	add_child(auto_visual)

	var visual := Polygon2D.new()
	visual.name = "Body"
	visual.color = fill_color
	visual.polygon = _rect_points(size)
	auto_visual.add_child(visual)

	var path_preview := Line2D.new()
	path_preview.name = "PathPreview"
	path_preview.width = 2.0
	path_preview.default_color = Color(0.80, 0.96, 1.0, 0.58)
	path_preview.points = _path_preview_points()
	auto_visual.add_child(path_preview)


func _clear_auto_visual() -> void:
	var old_visual := get_node_or_null("AutoVisual")
	if old_visual == null:
		return
	remove_child(old_visual)
	old_visual.free()


func _update_target_position() -> void:
	_target_position = _start_position + travel


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not active:
		return
	if _uses_path_points():
		_update_path_motion(delta)
		return
	_update_fallback_motion(delta)


func set_active(value: bool) -> void:
	active = value
	if active:
		_refresh_path_points()
		_wait_timer = 0.0


func _refresh_path_points() -> void:
	if not is_inside_tree():
		return
	_path_points.clear()
	var path_container := get_node_or_null(path_container_path)
	if path_container != null:
		for child in path_container.get_children():
			if child is Marker2D:
				_path_points.append(_start_position + (child as Marker2D).global_position - global_position)
	if _uses_path_points():
		_current_path_index = 0
		_target_path_index = 1
		_path_direction = 1
		global_position = _path_points[0]
	_rebuild_visual()


func _uses_path_points() -> bool:
	return _path_points.size() >= 2


func _update_path_motion(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer = maxf(0.0, _wait_timer - delta)
		return
	var target_position := _path_points[_target_path_index]
	var reached := _move_toward(target_position, delta)
	if reached:
		_current_path_index = _target_path_index
		_choose_next_path_target()
		_wait_timer = wait_time


func _update_fallback_motion(delta: float) -> void:
	_move_toward(_target_position, delta)


func _move_toward(target_position: Vector2, delta: float) -> bool:
	var offset := target_position - global_position
	if offset.length() <= 1.0:
		global_position = target_position
		return true
	global_position += offset.normalized() * min(speed * delta, offset.length())
	return false


func _choose_next_path_target() -> void:
	var next_index := _current_path_index + _path_direction
	if next_index >= 0 and next_index < _path_points.size():
		_target_path_index = next_index
		return

	if ping_pong:
		_path_direction *= -1
		_target_path_index = clampi(_current_path_index + _path_direction, 0, _path_points.size() - 1)
	else:
		_target_path_index = 0
		_path_direction = 1


func _path_preview_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if _uses_path_points():
		for point in _path_points:
			points.append(point - global_position)
	else:
		points.append(Vector2.ZERO)
		points.append(travel)
	return points


func _rect_points(rect_size: Vector2) -> PackedVector2Array:
	var hw := rect_size.x * 0.5
	var hh := rect_size.y * 0.5
	return PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	])
