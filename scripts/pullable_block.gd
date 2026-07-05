@tool
extends AnimatableBody2D
class_name PullableBlock

enum MoveState {
	LOCKED,
	PULLING
}

const WORLD_LAYER := 1
const HOOK_LAYER := 8
const PULL_DOT_THRESHOLD := 0.35

@export var size: Vector2 = Vector2(160, 48):
	set(value):
		size = value
		_refresh_editor_shape()
@export var dock_paths: Array[NodePath] = []
@export var starting_dock_index: int = 0
@export var pull_speed: float = 105.0
@export var pull_acceleration: float = 260.0
@export var return_speed: float = 80.0
@export var snap_distance: float = 14.0
@export var snap_cooldown: float = 0.2
@export var fill_color: Color = Color("#90a4ae"):
	set(value):
		fill_color = value
		_rebuild_visual()
@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild_visual()

var current_dock_index: int = 0

var _collision_shape: CollisionShape2D
var _dock_positions: Array[Vector2] = []
var _move_state: MoveState = MoveState.LOCKED
var _target_dock_index: int = -1
var _segment_start_dock_index: int = 0
var _segment_end_dock_index: int = 0
var _move_speed: float = 0.0
var _snap_timer: float = 0.0
var _last_anchor_frame: int = -1000
var _visual_root: Node2D


func _ready() -> void:
	collision_layer = WORLD_LAYER | HOOK_LAYER
	collision_mask = 0
	add_to_group("pullable_blocks")
	add_to_group("hook_points")
	set_meta("hookable", true)
	set_meta("pullable_anchor_target", true)
	_refresh_editor_shape()
	_resolve_docks()
	_snap_to_starting_dock()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_snap_timer = maxf(0.0, _snap_timer - delta)
	if _move_state == MoveState.PULLING and Engine.get_physics_frames() - _last_anchor_frame > 1:
		_stop_at_current_position()
	_update_visual_state()


func handle_anchor_pull(source_position: Vector2, delta: float, reel_active: bool) -> void:
	_last_anchor_frame = Engine.get_physics_frames()
	if _dock_positions.is_empty():
		_resolve_docks()
	if _dock_positions.size() < 2:
		return
	if _snap_timer > 0.0:
		return

	if not reel_active:
		_stop_at_current_position()
		return

	if _move_state != MoveState.PULLING or not _is_valid_dock_index(_target_dock_index):
		_target_dock_index = _choose_pull_target(source_position)
		if not _is_valid_dock_index(_target_dock_index):
			_stop_at_current_position()
			return
		_segment_start_dock_index = current_dock_index
		_segment_end_dock_index = _target_dock_index
		_move_state = MoveState.PULLING
		_move_speed = 0.0

	_move_toward_dock(_target_dock_index, delta, true)
	_update_visual_state()


func is_pullable_anchor_target() -> bool:
	return true


func _refresh_editor_shape() -> void:
	if not is_inside_tree():
		return
	_setup_collision()
	_rebuild_visual()


func _setup_collision() -> void:
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_collision_shape.shape = rect


func _rebuild_visual() -> void:
	if not is_inside_tree():
		return
	_clear_auto_visual()
	_visual_root = Node2D.new()
	_visual_root.name = "AutoVisual"
	add_child(_visual_root)

	if texture != null:
		var body_sprite := Sprite2D.new()
		body_sprite.name = "BodyTexture"
		body_sprite.texture = texture
		body_sprite.centered = true
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			body_sprite.scale = Vector2(size.x / texture_size.x, size.y / texture_size.y)
		_visual_root.add_child(body_sprite)
	else:
		var body := Polygon2D.new()
		body.name = "Body"
		body.color = fill_color
		body.polygon = _rect_points(size)
		_visual_root.add_child(body)

	var outline := Line2D.new()
	outline.name = "Outline"
	outline.width = 3.0
	outline.default_color = Color("#e0f2f1")
	outline.points = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, -size.y * 0.5)
	])
	_visual_root.add_child(outline)

	var hook_line := Line2D.new()
	hook_line.name = "HookLine"
	hook_line.width = 3.0
	hook_line.default_color = Color("#ffe082")
	hook_line.points = PackedVector2Array([Vector2(-size.x * 0.34, 0), Vector2(size.x * 0.34, 0)])
	_visual_root.add_child(hook_line)


func _clear_auto_visual() -> void:
	var old_visual := get_node_or_null("AutoVisual")
	if old_visual == null:
		return
	remove_child(old_visual)
	old_visual.free()
	_visual_root = null


func _resolve_docks() -> void:
	_dock_positions.clear()
	for dock_path in dock_paths:
		if dock_path.is_empty():
			continue
		var dock := get_node_or_null(dock_path)
		if dock is Node2D:
			_dock_positions.append((dock as Node2D).global_position)
	if _dock_positions.is_empty():
		_dock_positions.append(global_position)
		if not Engine.is_editor_hint():
			push_warning("%s has no dock_paths; using current position as its only dock." % name)


func _snap_to_starting_dock() -> void:
	current_dock_index = clampi(starting_dock_index, 0, _dock_positions.size() - 1)
	global_position = _dock_positions[current_dock_index]
	_target_dock_index = -1
	_segment_start_dock_index = current_dock_index
	_segment_end_dock_index = current_dock_index
	_move_state = MoveState.LOCKED
	_move_speed = 0.0


func _choose_pull_target(source_position: Vector2) -> int:
	var source_direction := source_position - global_position
	if source_direction.length() < 1.0:
		return -1
	source_direction = source_direction.normalized()

	var best_index := -1
	var best_dot := PULL_DOT_THRESHOLD
	for candidate_index in _pull_candidate_indices():
		if not _is_valid_dock_index(candidate_index):
			continue
		var candidate_direction := _dock_positions[candidate_index] - global_position
		if candidate_direction.length() < 1.0:
			continue
		var score := source_direction.dot(candidate_direction.normalized())
		if score > best_dot:
			best_dot = score
			best_index = candidate_index
	return best_index


func _pull_candidate_indices() -> Array[int]:
	if _is_valid_dock_index(_segment_start_dock_index) \
			and _is_valid_dock_index(_segment_end_dock_index) \
			and _segment_start_dock_index != _segment_end_dock_index:
		return [_segment_start_dock_index, _segment_end_dock_index]

	var candidates: Array[int] = []
	for candidate_index in [current_dock_index - 1, current_dock_index + 1]:
		if _is_valid_dock_index(candidate_index):
			candidates.append(candidate_index)
	return candidates


func _move_toward_dock(dock_index: int, delta: float, use_acceleration: bool) -> void:
	if not _is_valid_dock_index(dock_index):
		return
	var target_position := _dock_positions[dock_index]
	var offset := target_position - global_position
	var distance := offset.length()
	if distance <= snap_distance:
		_snap_to_dock(dock_index, use_acceleration)
		return

	if use_acceleration:
		_move_speed = minf(pull_speed, _move_speed + pull_acceleration * delta)
	else:
		_move_speed = return_speed
	global_position += offset.normalized() * minf(_move_speed * delta, distance)


func _stop_at_current_position() -> void:
	_target_dock_index = -1
	_move_state = MoveState.LOCKED
	_move_speed = 0.0


func _snap_to_dock(dock_index: int, use_cooldown: bool) -> void:
	if not _is_valid_dock_index(dock_index):
		return
	global_position = _dock_positions[dock_index]
	current_dock_index = dock_index
	_target_dock_index = -1
	_segment_start_dock_index = dock_index
	_segment_end_dock_index = dock_index
	_move_state = MoveState.LOCKED
	_move_speed = 0.0
	if use_cooldown:
		_snap_timer = snap_cooldown


func _is_valid_dock_index(dock_index: int) -> bool:
	return dock_index >= 0 and dock_index < _dock_positions.size()


func _update_visual_state() -> void:
	if _visual_root == null:
		return
	match _move_state:
		MoveState.PULLING:
			_visual_root.modulate = Color(1.0, 0.92, 0.68, 1.0)
		_:
			_visual_root.modulate = Color.WHITE


func _rect_points(rect_size: Vector2) -> PackedVector2Array:
	var hw := rect_size.x * 0.5
	var hh := rect_size.y * 0.5
	return PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	])
