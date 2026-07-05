extends Node2D
class_name HeavyAnchorGame

const VIEW_SIZE := Vector2i(960, 540)
const PlayerScript := preload("res://scripts/player.gd")
const AnchorScript := preload("res://scripts/anchor.gd")
const GeneratedLevelScene: PackedScene = preload("res://scenes/generated/full_level.tscn")
const MechanicsTestOverlayScene: PackedScene = preload("res://scenes/overlays/mechanics_test_overlay.tscn")
const CHAIN_LINK_TEXTURE: Texture2D = preload("res://assets/items/chain_link_glow.png")
const CHAIN_LINK_STEP: float = 16.0
const CHAIN_LINK_SCALE: float = 0.18
const INTRO_BACKGROUND_1: Texture2D = preload("res://assets/intro/intro_01_lost_anchor_2544x1422.png")
const INTRO_BACKGROUND_2: Texture2D = preload("res://assets/intro/intro_02_broken_city_2544x1422.png")
const INTRO_BACKGROUND_3: Texture2D = preload("res://assets/intro/intro_03_repairer_2544x1422.png")
const INTRO_BACKGROUND_5: Texture2D = preload("res://assets/intro/intro_05_regrowth_2544x1422.png")
const INTRO_SLIDE_SECONDS: float = 3.0
const INTRO_FADE_SECONDS: float = 0.45
const WORLD_RESTORE_SECONDS: float = 2.6
const ENABLE_MECHANICS_TEST_OVERLAY: bool = true
const INTRO_SCENES: Array[Dictionary] = [
	{"background": INTRO_BACKGROUND_1, "subtitle": "世界失去了锚点"},
	{"background": INTRO_BACKGROUND_2, "subtitle": "城市开始破碎，土地开始漂流"},
	{"background": INTRO_BACKGROUND_3, "subtitle": "你是最后的修复者"},
	{"background": INTRO_BACKGROUND_3, "subtitle": "投出它，固定它"},
	{"background": INTRO_BACKGROUND_5, "subtitle": "让世界重新生长"}
]

var player: CharacterBody2D
var anchor: CharacterBody2D
var world: Node2D
var level_root: Node2D
var chain_line: Line2D
var chain_links: Node2D
var camera: Camera2D
var hud: Label
var controls_label: Label
var finish_label: Label
var intro_canvas: CanvasLayer
var intro_curtain: ColorRect
var skip_intro_button: Button
var intro_backgrounds: Array[TextureRect] = []
var intro_subtitle_labels: Array[Label] = []

var buttons: Array[Node] = []
var pressure_plates: Array[Node] = []
var doors: Array[Node] = []
var repair_cores: Array[Node] = []
var repair_doors: Array[Node] = []
var water_switches: Array[Node] = []
var moving_platforms: Array[Node] = []
var drag_platforms: Array[Node] = []
var pullable_blocks: Array[Node] = []
var transition_zones: Array[Node] = []
var breakables: Array[StaticBody2D] = []
var winds: Array[Node] = []
var hazards: Array[Node] = []
var hooks: Array[StaticBody2D] = []
var exit_triggers: Array[Node] = []
var rooms: Array[Dictionary] = []
var validation_points: Dictionary = {}
var game_won := false
var current_room_index := 0
var active_checkpoint := Vector2(120, 476)
var intro_active: bool = true
var intro_timer: float = 0.0
var world_repaired := false
var water_restored := false
var transition_active := false
var transition_played := false
var transition_timer := 0.0

var _override_inputs := false
var _pressed_actions := {}
var _just_pressed_actions := {}


func _ready() -> void:
	get_viewport().size = VIEW_SIZE
	_configure_input_actions()
	_build_scene()
	_create_intro_overlay()
	_set_water_flow_visible(false)
	_update_room(true)


func _process(delta: float) -> void:
	if intro_active:
		_update_intro(delta)
	elif transition_active:
		_update_world_transition(delta)


func _physics_process(delta: float) -> void:
	if intro_active or transition_active:
		_consume_just_pressed()
		return
	if action_just_pressed("throw_anchor"):
		anchor.throw_toward(get_global_mouse_position())
	if action_just_pressed("release_anchor"):
		anchor.release_hook()
	if action_just_pressed("recall_anchor"):
		anchor.start_return()
	if action_just_pressed("restart_room"):
		respawn_player()

	_update_buttons()
	_update_water_switches()
	_update_drag_platforms(delta)
	_update_hazards()
	_update_exit()
	_update_room(false)
	_update_transition_zones()
	_update_chain()
	_update_hud()
	_consume_just_pressed()


func action_pressed(action_name: String) -> bool:
	if _override_inputs:
		return bool(_pressed_actions.get(action_name, false))
	return Input.is_action_pressed(action_name)


func action_just_pressed(action_name: String) -> bool:
	if _override_inputs:
		return bool(_just_pressed_actions.get(action_name, false))
	return Input.is_action_just_pressed(action_name)


func set_validation_action(action_name: String, pressed: bool, just_pressed := false) -> void:
	_finish_intro()
	_override_inputs = true
	_pressed_actions[action_name] = pressed
	if just_pressed:
		_just_pressed_actions[action_name] = true


func clear_validation_actions() -> void:
	_finish_intro()
	_override_inputs = true
	_pressed_actions.clear()
	_just_pressed_actions.clear()


func disable_validation_override() -> void:
	_finish_intro()
	_override_inputs = false
	_pressed_actions.clear()
	_just_pressed_actions.clear()


func respawn_player(position := active_checkpoint) -> void:
	player.respawn(position)
	anchor.force_carried()
	game_won = false
	finish_label.visible = false


func get_wind_force_at(point: Vector2) -> Vector2:
	for wind in winds:
		if wind.has_method("contains_point") and bool(wind.call("contains_point", point)):
			var force = wind.get("force")
			if force is Vector2:
				return force
	return Vector2.ZERO


func smash_breakable(body: StaticBody2D) -> void:
	if body == null or body.has_meta("broken"):
		return
	if body.has_method("break_apart"):
		body.call("break_apart")
	else:
		body.set_meta("broken", true)
		body.visible = false
		for child in body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	var dust := CPUParticles2D.new()
	dust.amount = 18
	dust.lifetime = 0.45
	dust.one_shot = true
	dust.explosiveness = 0.85
	dust.gravity = Vector2(0, 500)
	dust.initial_velocity_min = 90
	dust.initial_velocity_max = 190
	dust.scale_amount_min = 2
	dust.scale_amount_max = 5
	dust.color = body.call("smash_fx_color") if body.has_method("smash_fx_color") else Color("#b08968")
	dust.global_position = body.global_position
	world.add_child(dust)
	dust.emitting = true
	if body.has_meta("restores_water"):
		_restore_water_flow()


func anchor_hooked(collider: Object) -> void:
	if collider != null and collider.has_meta("repair_core"):
		_restore_world()


func anchor_grounded(_collider: Object, _position: Vector2) -> void:
	_update_water_switches()


func validation_summary() -> Dictionary:
	return {
		"rooms": rooms.size(),
		"hooks": hooks.size(),
		"buttons": buttons.size(),
		"pressure_plates": pressure_plates.size(),
		"doors": doors.size(),
		"breakables": breakables.size(),
		"winds": winds.size(),
		"hazards": hazards.size(),
		"pullable_blocks": pullable_blocks.size(),
		"moving_platforms": moving_platforms.size(),
		"has_exit": validation_points.has("exit"),
		"anchor_state": anchor.state_text()
	}


func _build_scene() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	level_root = GeneratedLevelScene.instantiate() as Node2D
	level_root.name = "GeneratedLevel"
	world.add_child(level_root)
	_add_mechanics_test_overlay()

	_load_level_metadata()
	_collect_level_nodes()

	player = PlayerScript.new()
	player.name = "Player"
	world.add_child(player)

	anchor = AnchorScript.new()
	anchor.name = "Anchor"
	world.add_child(anchor)

	player.setup(self, anchor)
	anchor.setup(self, player)
	player.respawn(active_checkpoint)
	anchor.force_carried()

	chain_line = Line2D.new()
	chain_line.name = "Chain"
	chain_line.width = 4.0
	chain_line.default_color = Color("#c9d6df")
	chain_line.joint_mode = Line2D.LINE_JOINT_ROUND
	chain_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	chain_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	world.add_child(chain_line)

	chain_links = Node2D.new()
	chain_links.name = "ChainLinks"
	world.add_child(chain_links)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_configure_camera_limits()
	player.add_child(camera)
	camera.make_current()

	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	hud = Label.new()
	hud.position = Vector2(18, 16)
	hud.add_theme_font_size_override("font_size", 17)
	hud.add_theme_color_override("font_color", Color("#f4f7fb"))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(hud)

	controls_label = Label.new()
	controls_label.position = Vector2(18, 424)
	controls_label.size = Vector2(924, 104)
	controls_label.text = "操作：A/D 或 ←/→ 移动    Space/W/↑ 跳跃\n左键/J 投锚    右键/K 收链拉向锚点    Shift/L 松开飞出\nE/R 回收地上的锚    F5 重开当前房间"
	controls_label.add_theme_font_size_override("font_size", 16)
	controls_label.add_theme_color_override("font_color", Color("#f4f7fb"))
	controls_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.62))
	controls_label.add_theme_constant_override("shadow_offset_x", 2)
	controls_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(controls_label)

	finish_label = Label.new()
	finish_label.visible = false
	finish_label.text = "通关！重锚挑战完成"
	finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finish_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	finish_label.position = Vector2(0, 190)
	finish_label.size = Vector2(VIEW_SIZE.x, 80)
	finish_label.add_theme_font_size_override("font_size", 34)
	finish_label.add_theme_color_override("font_color", Color("#ffe082"))
	finish_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	finish_label.add_theme_constant_override("shadow_offset_x", 3)
	finish_label.add_theme_constant_override("shadow_offset_y", 3)
	canvas.add_child(finish_label)


func _load_level_metadata() -> void:
	rooms.clear()
	var level_rooms: Array = level_root.get("rooms")
	for room in level_rooms:
		if room is Dictionary:
			rooms.append(room)
	if not rooms.is_empty():
		active_checkpoint = rooms[0]["checkpoint"]

	validation_points.clear()
	var markers := level_root.get_node_or_null("Markers")
	if markers == null:
		return
	for child in markers.get_children():
		if child is Marker2D:
			validation_points[String(child.name)] = child.global_position


func _add_mechanics_test_overlay() -> void:
	if not ENABLE_MECHANICS_TEST_OVERLAY:
		return
	var overlay := MechanicsTestOverlayScene.instantiate()
	overlay.name = "MechanicsTestOverlay"
	level_root.add_child(overlay)


func _collect_level_nodes() -> void:
	buttons = _nodes_in_level_group("anchor_buttons")
	pressure_plates = _nodes_in_level_group("anchor_pressure_plates")
	doors = _nodes_in_level_group("anchor_doors")
	repair_cores = _nodes_in_level_group("repair_cores")
	repair_doors = _nodes_in_level_group("repair_doors")
	water_switches = _nodes_in_level_group("water_switches")
	moving_platforms = _nodes_in_level_group("moving_platforms")
	drag_platforms = _nodes_in_level_group("anchor_drag_platforms")
	pullable_blocks = _nodes_in_level_group("pullable_blocks")
	transition_zones = _nodes_in_level_group("transition_zones")
	winds = _nodes_in_level_group("wind_zones")
	hazards = _nodes_in_level_group("hazard_zones")
	exit_triggers = _nodes_in_level_group("exit_triggers")

	hooks.clear()
	for node in _nodes_in_level_group("hook_points"):
		if node is StaticBody2D:
			hooks.append(node)

	breakables.clear()
	for node in _nodes_in_level_group("breakable_blocks"):
		if node is StaticBody2D:
			breakables.append(node)


func _nodes_in_level_group(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if level_root != null and level_root.is_ancestor_of(node):
			result.append(node)
	return result


func _create_intro_overlay() -> void:
	intro_canvas = $IntroCurtain as CanvasLayer
	intro_canvas.visible = true

	intro_curtain = $IntroCurtain/WhiteCurtain as ColorRect
	skip_intro_button = $IntroCurtain/SkipIntroButton as Button
	skip_intro_button.pressed.connect(_finish_intro)

	intro_backgrounds.clear()
	intro_backgrounds.append($IntroCurtain/IntroBackground0 as TextureRect)
	intro_backgrounds.append($IntroCurtain/IntroBackground1 as TextureRect)

	intro_subtitle_labels.clear()
	intro_subtitle_labels.append($IntroCurtain/IntroSubtitle0 as Label)
	intro_subtitle_labels.append($IntroCurtain/IntroSubtitle1 as Label)

	intro_active = true
	intro_timer = 0.0
	_update_intro(0.0)


func _update_intro(delta: float) -> void:
	intro_timer += delta
	var total_time: float = INTRO_SLIDE_SECONDS * float(INTRO_SCENES.size())
	if intro_timer >= total_time:
		_finish_intro()
		return
	var next_scene_index: int = clampi(int(intro_timer / INTRO_SLIDE_SECONDS), 0, INTRO_SCENES.size() - 1)
	var local_time: float = fmod(intro_timer, INTRO_SLIDE_SECONDS)
	_update_intro_layers(next_scene_index, local_time)


func _finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	if intro_canvas != null:
		intro_canvas.visible = false


func _update_intro_layers(scene_index: int, local_time: float) -> void:
	var scene_data: Dictionary = INTRO_SCENES[scene_index]
	var intro_alpha: float = clampf(intro_timer / INTRO_FADE_SECONDS, 0.0, 1.0)
	var transition_alpha: float = 0.0
	if scene_index < INTRO_SCENES.size() - 1:
		transition_alpha = clampf((local_time - (INTRO_SLIDE_SECONDS - INTRO_FADE_SECONDS)) / INTRO_FADE_SECONDS, 0.0, 1.0)
	var next_scene_index: int = mini(scene_index + 1, INTRO_SCENES.size() - 1)
	var bottom_scene_index: int = next_scene_index if transition_alpha > 0.0 else scene_index
	var bottom_scene_data: Dictionary = INTRO_SCENES[bottom_scene_index]
	var next_scene_data: Dictionary = INTRO_SCENES[next_scene_index]

	intro_backgrounds[0].texture = bottom_scene_data["background"] as Texture2D
	intro_backgrounds[0].modulate = Color(1.0, 1.0, 1.0, intro_alpha)
	intro_backgrounds[1].texture = scene_data["background"] as Texture2D
	intro_backgrounds[1].modulate = Color(1.0, 1.0, 1.0, intro_alpha * (1.0 - transition_alpha))

	intro_subtitle_labels[0].text = str(next_scene_data["subtitle"])
	intro_subtitle_labels[0].modulate = Color(1.0, 1.0, 1.0, intro_alpha * transition_alpha)
	intro_subtitle_labels[1].text = str(scene_data["subtitle"])
	intro_subtitle_labels[1].modulate = Color(1.0, 1.0, 1.0, intro_alpha * (1.0 - transition_alpha))


func _update_buttons() -> void:
	_update_anchor_switches(buttons)
	_update_anchor_switches(pressure_plates)


func _update_water_switches() -> void:
	for water_switch in water_switches:
		if not water_switch.has_method("contains_point") or not water_switch.has_method("set_active"):
			continue
		var is_pressed: bool = anchor.is_grounded() and bool(water_switch.call("contains_point", anchor.global_position))
		water_switch.call("set_active", water_restored or is_pressed)


func _restore_world() -> void:
	if world_repaired:
		return
	world_repaired = true
	for repair_door in repair_doors:
		if repair_door != null and repair_door.has_method("set_open"):
			repair_door.call("set_open", true)
	for platform in drag_platforms:
		if platform != null and platform.has_method("set_enabled"):
			platform.call("set_enabled", true)
	level_root.modulate = Color(0.78, 1.0, 0.82, 1.0)


func _update_transition_zones() -> void:
	if transition_played or player == null:
		return
	for zone in transition_zones:
		if zone.has_method("contains_point") and bool(zone.call("contains_point", player.global_position)):
			_start_world_transition()
			return


func _start_world_transition() -> void:
	transition_played = true
	transition_active = true
	transition_timer = 0.0
	player.velocity = Vector2.ZERO
	player.is_disabled = true
	anchor.force_carried()
	_set_restore_fx_visible(true)
	var restore_sfx := level_root.find_child("RestoreSfx", true, false) as AudioStreamPlayer2D
	if restore_sfx != null and restore_sfx.stream != null:
		restore_sfx.play()


func _update_world_transition(delta: float) -> void:
	transition_timer += delta
	var t := clampf(transition_timer / WORLD_RESTORE_SECONDS, 0.0, 1.0)
	level_root.modulate = Color(lerpf(1.0, 0.78, t), 1.0, lerpf(1.0, 0.82, t), 1.0)
	_update_restore_fx_frames(t)
	if transition_timer >= WORLD_RESTORE_SECONDS:
		transition_active = false
		player.is_disabled = false
		_set_restore_fx_visible(false)
		_restore_world()


func _set_restore_fx_visible(value: bool) -> void:
	var fx_root := level_root.find_child("RestoreTransitionFX", true, false)
	if fx_root != null:
		fx_root.visible = value


func _update_restore_fx_frames(t: float) -> void:
	var fx_root := level_root.find_child("RestoreTransitionFX", true, false)
	if fx_root == null:
		return
	for child in fx_root.get_children():
		if child is CanvasItem:
			child.visible = false
	var frame_index := clampi(int(floor(t * 3.0)), 0, 2)
	var frame := fx_root.get_node_or_null("Frame%s" % (frame_index + 1))
	if frame is CanvasItem:
		frame.visible = true


func _restore_water_flow() -> void:
	if water_restored:
		return
	water_restored = true
	_set_water_flow_visible(true)


func _set_water_flow_visible(value: bool) -> void:
	for platform in moving_platforms:
		if platform != null and platform.has_meta("water_platform"):
			platform.visible = value
			_set_collision_enabled_for(platform, value)
			if platform.has_method("set_active"):
				platform.call("set_active", value)
	var restored_water := level_root.find_child("RestoredWater", true, false)
	if restored_water != null:
		restored_water.visible = value


func _set_collision_enabled_for(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not enabled)


func _update_drag_platforms(delta: float) -> void:
	if not world_repaired:
		return
	for platform in drag_platforms:
		if platform != null and platform.has_method("try_drag"):
			platform.call("try_drag", anchor.global_position, anchor.is_grounded() and action_pressed("reel_chain"), delta)


func _update_anchor_switches(switches: Array[Node]) -> void:
	for anchor_switch in switches:
		if not anchor_switch.has_method("contains_point") or not anchor_switch.has_method("set_pressed"):
			continue
		var is_pressed: bool = anchor.is_grounded() and bool(anchor_switch.call("contains_point", anchor.global_position))
		anchor_switch.call("set_pressed", is_pressed)


func _update_hazards() -> void:
	if player.global_position.y > 820.0:
		respawn_player()
		return
	for hazard in hazards:
		if hazard.has_method("contains_point") and bool(hazard.call("contains_point", player.global_position + Vector2(0, -24))):
			respawn_player()
			return


func _update_exit() -> void:
	if validation_points.has("exit") and player.global_position.distance_to(validation_points["exit"]) < 90.0:
		_complete_game()
		return
	for exit_trigger in exit_triggers:
		if exit_trigger.has_method("contains_point") and bool(exit_trigger.call("contains_point", player.global_position)):
			_complete_game()
			return


func _complete_game() -> void:
	if game_won:
		return
	game_won = true
	finish_label.visible = true
	var finish_fx := level_root.find_child("FinishGlow", true, false)
	if finish_fx != null:
		finish_fx.visible = true
	var finish_sfx := level_root.find_child("FinishSfx", true, false) as AudioStreamPlayer2D
	if finish_sfx != null and finish_sfx.stream != null:
		finish_sfx.play()


func _update_room(force := false) -> void:
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		if player != null and player.global_position.x >= float(room["start"]) and player.global_position.x < float(room["end"]):
			if current_room_index != i or force:
				current_room_index = i
				active_checkpoint = room["checkpoint"]
			return


func _update_chain() -> void:
	if anchor.is_carried():
		chain_line.visible = false
		chain_links.visible = false
		return
	chain_line.visible = true
	chain_links.visible = true
	var chain_start: Vector2 = player.global_position + Vector2(0, -32)
	var chain_end: Vector2 = anchor.global_position
	chain_line.points = PackedVector2Array([chain_start, chain_end])
	var tension: float = clamp((player.global_position.distance_to(anchor.global_position) / max(anchor.chain_length, 1.0)) - 0.8, 0.0, 1.0)
	chain_line.width = lerpf(4.0, 8.0, tension)
	chain_line.default_color = Color(1.0, 0.76, 0.24, 0.08 + tension * 0.12)
	_update_chain_links(chain_start, chain_end)


func _update_chain_links(chain_start: Vector2, chain_end: Vector2) -> void:
	for child in chain_links.get_children():
		child.queue_free()
	var offset: Vector2 = chain_end - chain_start
	var distance: float = offset.length()
	if distance < 8.0:
		return
	var direction: Vector2 = offset / distance
	var link_count: int = maxi(1, int(distance / CHAIN_LINK_STEP))
	for i in link_count:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = CHAIN_LINK_TEXTURE
		sprite.centered = true
		sprite.scale = Vector2.ONE * CHAIN_LINK_SCALE
		sprite.rotation = direction.angle() + PI * 0.5
		sprite.position = chain_start + direction * (float(i) + 0.5) * CHAIN_LINK_STEP
		sprite.modulate = Color.WHITE
		chain_links.add_child(sprite)


func _update_hud() -> void:
	var room_name: String = str(rooms[current_room_index]["name"]) if current_room_index < rooms.size() else ""
	hud.text = "%s\n锚状态：%s" % [room_name, anchor.state_text_cn()]


func _level_width() -> float:
	var width := 5760.0
	for room in rooms:
		width = maxf(width, float(room["end"]) + 160.0)
	return width


func _configure_camera_limits() -> void:
	var bounds := _level_content_bounds()
	camera.limit_left = int(floor(bounds.position.x))
	camera.limit_top = int(floor(bounds.position.y))
	camera.limit_right = int(ceil(bounds.end.x))
	camera.limit_bottom = int(ceil(bounds.end.y))


func _level_content_bounds() -> Rect2:
	var state := {
		"has_bounds": false,
		"bounds": Rect2()
	}
	_accumulate_level_bounds(level_root, state)

	if bool(state["has_bounds"]):
		return _expand_rect(state["bounds"], 260.0, 220.0, 340.0, 220.0)

	return Rect2(Vector2(-120, -160), Vector2(_level_width() + 240.0, 920.0))


func _accumulate_level_bounds(node: Node, state: Dictionary) -> void:
	if node is Node2D:
		var node_bounds := _node_content_bounds(node as Node2D)
		if node_bounds.size.x > 0.0 and node_bounds.size.y > 0.0:
			_merge_bounds(state, node_bounds)

	for child in node.get_children():
		_accumulate_level_bounds(child, state)


func _node_content_bounds(node: Node2D) -> Rect2:
	var node_size = node.get("size")
	if node_size is Vector2:
		var block_size: Vector2 = node_size
		return _global_rect_from_center(node, block_size)

	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			var texture_size := sprite.texture.get_size()
			var rect := Rect2(Vector2.ZERO, texture_size)
			if sprite.centered:
				rect.position = -texture_size * 0.5
			return _global_rect_from_local_rect(sprite, rect)

	if node is Polygon2D:
		var polygon := node as Polygon2D
		if not polygon.polygon.is_empty():
			return _global_rect_from_points(polygon, polygon.polygon)

	return Rect2()


func _global_rect_from_center(node: Node2D, node_size: Vector2) -> Rect2:
	return _global_rect_from_local_rect(node, Rect2(-node_size * 0.5, node_size))


func _global_rect_from_local_rect(node: Node2D, rect: Rect2) -> Rect2:
	return _global_rect_from_points(node, PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]))


func _global_rect_from_points(node: Node2D, points: PackedVector2Array) -> Rect2:
	var first := node.to_global(points[0])
	var min_point := first
	var max_point := first
	for point in points:
		var global_point := node.to_global(point)
		min_point.x = minf(min_point.x, global_point.x)
		min_point.y = minf(min_point.y, global_point.y)
		max_point.x = maxf(max_point.x, global_point.x)
		max_point.y = maxf(max_point.y, global_point.y)
	return Rect2(min_point, max_point - min_point)


func _merge_bounds(state: Dictionary, rect: Rect2) -> void:
	if not bool(state["has_bounds"]):
		state["bounds"] = rect
		state["has_bounds"] = true
		return
	var existing_bounds: Rect2 = state["bounds"]
	state["bounds"] = existing_bounds.merge(rect)


func _expand_rect(rect: Rect2, left: float, top: float, right: float, bottom: float) -> Rect2:
	return Rect2(
		Vector2(rect.position.x - left, rect.position.y - top),
		Vector2(rect.size.x + left + right, rect.size.y + top + bottom)
	)


func _configure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_mouse_action("throw_anchor", MOUSE_BUTTON_LEFT)
	_add_key_action("throw_anchor", [KEY_J])
	_add_mouse_action("reel_chain", MOUSE_BUTTON_RIGHT)
	_add_key_action("reel_chain", [KEY_K])
	_add_key_action("release_anchor", [KEY_SHIFT, KEY_L])
	_add_key_action("recall_anchor", [KEY_E, KEY_R])
	_add_key_action("restart_room", [KEY_F5])


func _add_key_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)


func _add_mouse_action(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _consume_just_pressed() -> void:
	if _override_inputs:
		_just_pressed_actions.clear()
