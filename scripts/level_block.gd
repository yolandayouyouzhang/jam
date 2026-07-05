@tool
extends StaticBody2D
class_name LevelBlock

enum BlockKind {
	GROUND,
	BLOCK,
	HOOK,
	BREAKABLE,
	PROTOTYPE,
	CORE,
	DOOR
}

const WORLD_LAYER := 1
const HOOK_LAYER := 8
const TILE_GROUND_TEXTURE: Texture2D = preload("res://assets/tiles/ground_mid.png")
const TILE_BLOCK_TEXTURE: Texture2D = preload("res://assets/tiles/block_fill.png")
const TILE_COLUMN_TEXTURE: Texture2D = preload("res://assets/tiles/wall_column.png")
const TILE_HOOK_TEXTURE: Texture2D = preload("res://assets/tiles/hook_stone.png")
const TILE_BREAKABLE_TEXTURE: Texture2D = preload("res://assets/tiles/breakable_stone.png")

@export var size: Vector2 = Vector2(160, 48):
	set(value):
		size = value
		_refresh_editor_shape()
@export var block_kind: BlockKind = BlockKind.GROUND:
	set(value):
		block_kind = value
		_refresh_editor_shape()
@export var fill_color: Color = Color("#37474f"):
	set(value):
		fill_color = value
		_refresh_editor_shape()
@export var use_texture_art: bool = true:
	set(value):
		use_texture_art = value
		_refresh_editor_shape()
@export var texture_override: Texture2D:
	set(value):
		texture_override = value
		_refresh_editor_shape()
@export var horizontal_texture_override: Texture2D:
	set(value):
		horizontal_texture_override = value
		_refresh_editor_shape()
@export var vertical_texture_override: Texture2D:
	set(value):
		vertical_texture_override = value
		_refresh_editor_shape()
@export var required_smash_speed: float = 560.0
@export var break_fx_color: Color = Color("#b08968")
@export var show_builtin_visual: bool = true:
	set(value):
		show_builtin_visual = value
		_refresh_editor_shape()

var _collision_shape: CollisionShape2D


func _ready() -> void:
	_refresh_editor_shape()


func is_hookable_block() -> bool:
	return block_kind == BlockKind.HOOK or block_kind == BlockKind.CORE


func is_breakable_block() -> bool:
	return block_kind == BlockKind.BREAKABLE


func smash_speed() -> float:
	return required_smash_speed


func smash_fx_color() -> Color:
	return break_fx_color


func break_apart() -> void:
	if has_meta("broken"):
		return
	set_meta("broken", true)
	visible = false
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)


func _setup_collision() -> void:
	collision_layer = HOOK_LAYER if is_hookable_block() else WORLD_LAYER
	collision_mask = 0
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_collision_shape.shape = rect


func _setup_metadata() -> void:
	add_to_group("level_blocks")
	remove_from_group("hook_points")
	remove_from_group("breakable_blocks")
	if has_meta("hookable"):
		remove_meta("hookable")
	if has_meta("breakable"):
		remove_meta("breakable")
	if is_hookable_block():
		set_meta("hookable", true)
		add_to_group("hook_points")
	if is_breakable_block():
		set_meta("breakable", true)
		add_to_group("breakable_blocks")


func _rebuild_visual() -> void:
	_clear_auto_visual()
	if not show_builtin_visual:
		return
	var visual := Node2D.new()
	visual.name = "AutoVisual"
	add_child(visual)

	var texture := _texture_for_kind()
	if use_texture_art and texture != null:
		if size.x >= size.y:
			_add_horizontal_tiles(visual, texture)
		else:
			_add_vertical_tiles(visual, texture)
	else:
		var polygon := Polygon2D.new()
		polygon.color = _color_for_kind()
		polygon.polygon = _rect_points(size)
		visual.add_child(polygon)

	if is_breakable_block():
		_add_breakable_overlay(visual)

	if is_hookable_block():
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color("#9fb3c8")
		line.points = PackedVector2Array([Vector2(-size.x * 0.38, 0), Vector2(size.x * 0.38, 0)])
		visual.add_child(line)


func _refresh_editor_shape() -> void:
	if not is_inside_tree():
		return
	_setup_collision()
	_setup_metadata()
	_rebuild_visual()


func _clear_auto_visual() -> void:
	var old_visual := get_node_or_null("AutoVisual")
	if old_visual == null:
		return
	remove_child(old_visual)
	old_visual.free()


func _texture_for_kind() -> Texture2D:
	var directional_override := horizontal_texture_override if size.x >= size.y else vertical_texture_override
	if directional_override != null:
		return directional_override
	if texture_override != null:
		return texture_override
	match block_kind:
		BlockKind.BREAKABLE:
			return TILE_BREAKABLE_TEXTURE
		BlockKind.HOOK:
			return TILE_HOOK_TEXTURE if size.x >= size.y else TILE_COLUMN_TEXTURE
		BlockKind.CORE:
			return TILE_HOOK_TEXTURE
		BlockKind.DOOR:
			return TILE_BLOCK_TEXTURE
		BlockKind.GROUND:
			return TILE_GROUND_TEXTURE
		BlockKind.BLOCK:
			return TILE_BLOCK_TEXTURE
		_:
			return null


func _color_for_kind() -> Color:
	match block_kind:
		BlockKind.HOOK:
			return Color("#596a73")
		BlockKind.CORE:
			return Color("#76a7c8")
		BlockKind.BREAKABLE:
			return Color("#8d6e63")
		BlockKind.DOOR:
			return Color("#1f2933")
		BlockKind.PROTOTYPE:
			return _visible_fill_color(Color("#5f7f65"))
		_:
			return _visible_fill_color(Color("#5f7f65"))


func _visible_fill_color(fallback: Color) -> Color:
	var brightest: float = maxf(fill_color.r, maxf(fill_color.g, fill_color.b))
	if fill_color.a > 0.95 and brightest < 0.08:
		return fallback
	return fill_color


func _add_horizontal_tiles(parent: Node, texture: Texture2D) -> void:
	var texture_size: Vector2 = texture.get_size()
	var scale_factor: float = size.y / texture_size.y
	var tile_width: float = texture_size.x * scale_factor
	var tile_count: int = max(1, int(ceil(size.x / tile_width)))
	for i in tile_count:
		var visible_width: float = minf(tile_width, size.x - float(i) * tile_width)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, Vector2(visible_width / scale_factor, texture_size.y))
		sprite.scale = Vector2.ONE * scale_factor
		sprite.position = Vector2(-size.x * 0.5 + i * tile_width, -size.y * 0.5)
		parent.add_child(sprite)


func _add_vertical_tiles(parent: Node, texture: Texture2D) -> void:
	var texture_size: Vector2 = texture.get_size()
	var scale_factor: float = size.x / texture_size.x
	var tile_height: float = texture_size.y * scale_factor
	var tile_count: int = max(1, int(ceil(size.y / tile_height)))
	for i in tile_count:
		var visible_height: float = minf(tile_height, size.y - float(i) * tile_height)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, Vector2(texture_size.x, visible_height / scale_factor))
		sprite.scale = Vector2.ONE * scale_factor
		sprite.position = Vector2(-size.x * 0.5, -size.y * 0.5 + i * tile_height)
		parent.add_child(sprite)


func _add_breakable_overlay(parent: Node) -> void:
	var tint := Polygon2D.new()
	tint.color = Color(0.82, 0.34, 0.18, 0.28)
	tint.polygon = _rect_points(size)
	parent.add_child(tint)

	var outline := Line2D.new()
	outline.width = 4.0
	outline.default_color = Color("#ffd166")
	outline.points = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, -size.y * 0.5)
	])
	parent.add_child(outline)

	if size.x >= size.y:
		_add_crack_line(parent, PackedVector2Array([
			Vector2(-size.x * 0.42, -size.y * 0.18),
			Vector2(-size.x * 0.20, size.y * 0.12),
			Vector2(-size.x * 0.02, -size.y * 0.08),
			Vector2(size.x * 0.22, size.y * 0.20),
			Vector2(size.x * 0.44, -size.y * 0.12)
		]), 4.0)
		_add_crack_line(parent, PackedVector2Array([
			Vector2(-size.x * 0.08, -size.y * 0.05),
			Vector2(-size.x * 0.16, -size.y * 0.38)
		]), 3.0)
		_add_crack_line(parent, PackedVector2Array([
			Vector2(size.x * 0.18, size.y * 0.10),
			Vector2(size.x * 0.08, size.y * 0.40)
		]), 3.0)
	else:
		_add_crack_line(parent, PackedVector2Array([
			Vector2(-size.x * 0.18, -size.y * 0.42),
			Vector2(size.x * 0.12, -size.y * 0.24),
			Vector2(-size.x * 0.06, -size.y * 0.04),
			Vector2(size.x * 0.18, size.y * 0.20),
			Vector2(-size.x * 0.14, size.y * 0.43)
		]), 4.0)
		_add_crack_line(parent, PackedVector2Array([
			Vector2(size.x * 0.06, -size.y * 0.06),
			Vector2(size.x * 0.38, -size.y * 0.14)
		]), 3.0)
		_add_crack_line(parent, PackedVector2Array([
			Vector2(-size.x * 0.10, size.y * 0.18),
			Vector2(-size.x * 0.38, size.y * 0.30)
		]), 3.0)


func _add_crack_line(parent: Node, points: PackedVector2Array, width: float) -> void:
	var shadow := Line2D.new()
	shadow.width = width + 2.0
	shadow.default_color = Color(0.10, 0.06, 0.04, 0.82)
	shadow.points = points
	parent.add_child(shadow)

	var highlight := Line2D.new()
	highlight.width = width
	highlight.default_color = Color("#ffeda3")
	highlight.points = points
	parent.add_child(highlight)


func _rect_points(rect_size: Vector2) -> PackedVector2Array:
	var hw := rect_size.x * 0.5
	var hh := rect_size.y * 0.5
	return PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	])
