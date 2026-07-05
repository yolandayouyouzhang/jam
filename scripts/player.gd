extends CharacterBody2D
class_name HeavyAnchorPlayer

const BODY_SIZE: Vector2 = Vector2(32.0, 54.0)
const GRAVITY: float = 1260.0
const MAX_FALL_SPEED: float = 760.0
const CARRIED_GRAVITY_SCALE: float = 1.08
const FREE_GRAVITY_SCALE: float = 0.96
const CARRIED_MAX_SPEED: float = 200.0
const FREE_MAX_SPEED: float = 285.0
const ACCELERATION: float = 1950.0
const FRICTION: float = 2350.0
const AIR_DRAG: float = 170.0
const CARRIED_JUMP_SPEED: float = 345.0
const FREE_JUMP_SPEED: float = 445.0
const IDLE_ANIMATION_TEXTURE: Texture2D = preload("res://assets/characters/player_idle_strip.png")
const IDLE_TO_RUN_ANIMATION_TEXTURE: Texture2D = preload("res://assets/characters/player_idle_to_run_strip.png")
const RUN_LOOP_ANIMATION_TEXTURE: Texture2D = preload("res://assets/characters/player_run_loop_strip.png")
const RUN_TO_IDLE_ANIMATION_TEXTURE: Texture2D = preload("res://assets/characters/player_run_to_idle_strip.png")
const JUMP_ANIMATION_TEXTURE: Texture2D = preload("res://assets/characters/player_jump_strip.png")
const PLAYER_LIGHT_TEXTURE: Texture2D = preload("res://assets/items/soft_player_light.png")
const IDLE_FRAME_COUNT: int = 7
const IDLE_TO_RUN_FRAME_COUNT: int = 3
const RUN_LOOP_FRAME_COUNT: int = 7
const RUN_TO_IDLE_FRAME_COUNT: int = 3
const JUMP_FRAME_COUNT: int = 7
const IDLE_FRAME_SIZE: Vector2 = Vector2(115.0, 288.0)
const IDLE_TO_RUN_FRAME_SIZE: Vector2 = Vector2(175.0, 259.0)
const RUN_LOOP_FRAME_SIZE: Vector2 = Vector2(196.0, 254.0)
const RUN_TO_IDLE_FRAME_SIZE: Vector2 = Vector2(186.0, 275.0)
const JUMP_FRAME_SIZE: Vector2 = Vector2(153.0, 261.0)
const PLAYER_VISUAL_SCALE: float = 0.32
const IDLE_ANIMATION_FPS: float = 6.0
const TRANSITION_ANIMATION_FPS: float = 9.0
const RUN_LOOP_ANIMATION_FPS: float = 10.0
const JUMP_ANIMATION_FPS: float = 10.0

var game
var anchor
var spawn_position: Vector2 = Vector2.ZERO
var facing: int = 1
var is_disabled: bool = false

var _sprite_visual: Sprite2D
var _move_light: PointLight2D
var _animation_time: float = 0.0
var _current_animation: String = ""


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y * 0.5)
	add_child(shape)

	_sprite_visual = Sprite2D.new()
	_sprite_visual.name = "PlayerVisual"
	_sprite_visual.region_enabled = true
	_sprite_visual.centered = true
	_sprite_visual.scale = Vector2.ONE * PLAYER_VISUAL_SCALE
	add_child(_sprite_visual)
	_set_animation("idle")

	_move_light = PointLight2D.new()
	_move_light.name = "MoveLight"
	_move_light.texture = PLAYER_LIGHT_TEXTURE
	_move_light.energy = 0.18
	_move_light.texture_scale = 1.7
	_move_light.color = Color(1.0, 0.78, 0.45, 1.0)
	_move_light.position = Vector2(0.0, -36.0)
	add_child(_move_light)


func setup(game_ref, anchor_ref) -> void:
	game = game_ref
	anchor = anchor_ref


func respawn(at_position: Vector2) -> void:
	global_position = at_position
	spawn_position = at_position
	velocity = Vector2.ZERO
	is_disabled = false


func _physics_process(delta: float) -> void:
	if game == null or is_disabled:
		return

	var input_dir: float = 0.0
	if game.action_pressed("move_left"):
		input_dir -= 1.0
	if game.action_pressed("move_right"):
		input_dir += 1.0
	if input_dir != 0.0:
		facing = sign(input_dir)

	var carrying_anchor: bool = anchor == null or anchor.is_carried()
	var max_speed: float = CARRIED_MAX_SPEED if carrying_anchor else FREE_MAX_SPEED
	var jump_speed: float = CARRIED_JUMP_SPEED if carrying_anchor else FREE_JUMP_SPEED

	if input_dir != 0.0:
		if sign(velocity.x) == sign(input_dir) and abs(velocity.x) > max_speed:
			velocity.x += input_dir * ACCELERATION * 0.08 * delta
		else:
			velocity.x = move_toward(velocity.x, input_dir * max_speed, ACCELERATION * delta)
	else:
		var slowdown: float = FRICTION if is_on_floor() else AIR_DRAG
		velocity.x = move_toward(velocity.x, 0.0, slowdown * delta)

	if is_on_floor() and game.action_just_pressed("jump"):
		velocity.y = -jump_speed

	if not is_on_floor():
		var gravity_scale: float = CARRIED_GRAVITY_SCALE if carrying_anchor else FREE_GRAVITY_SCALE
		velocity.y = minf(velocity.y + GRAVITY * gravity_scale * delta, MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	velocity += game.get_wind_force_at(global_position) * delta

	if anchor != null:
		anchor.apply_player_forces(self, delta, game.action_pressed("reel_chain"))

	move_and_slide()

	if anchor != null:
		anchor.post_player_move(self)

	_update_move_light(input_dir, delta)
	_update_visuals(input_dir, not is_on_floor(), delta)


func _update_move_light(input_dir: float, delta: float) -> void:
	var target_energy: float = 0.18
	if input_dir != 0.0:
		target_energy = 0.34
	elif not is_on_floor():
		target_energy = 0.28
	_move_light.energy = lerpf(_move_light.energy, target_energy, minf(delta * 8.0, 1.0))


func _update_visuals(input_dir: float, is_airborne: bool, delta: float) -> void:
	_update_animation_state(input_dir != 0.0, is_airborne)
	_animation_time += delta

	if _is_animation_finished():
		if _current_animation == "idle_to_run":
			_set_animation("run_loop")
		elif _current_animation == "run_to_idle":
			_set_animation("idle")

	var frame_size: Vector2 = _animation_frame_size(_current_animation)
	var frame_count: int = _animation_frame_count(_current_animation)
	var raw_frame: int = int(floor(_animation_time * _animation_fps(_current_animation)))
	var frame: int = raw_frame % frame_count if _animation_loops(_current_animation) else mini(raw_frame, frame_count - 1)
	_sprite_visual.region_rect = Rect2(
		Vector2(frame * frame_size.x, 0),
		frame_size
	)
	_sprite_visual.flip_h = facing < 0


func _update_animation_state(wants_run: bool, is_airborne: bool) -> void:
	if is_airborne:
		if _current_animation != "jump":
			_set_animation("jump")
		return

	if _current_animation == "jump":
		_set_animation("run_loop" if wants_run else "idle")
		return

	if wants_run:
		if _current_animation == "idle" or _current_animation == "run_to_idle":
			_set_animation("idle_to_run")
	else:
		if _current_animation == "idle_to_run" or _current_animation == "run_loop":
			_set_animation("run_to_idle")


func _set_animation(animation_name: String) -> void:
	if _current_animation == animation_name:
		return

	_current_animation = animation_name
	_animation_time = 0.0
	var frame_size: Vector2 = _animation_frame_size(animation_name)
	_sprite_visual.texture = _animation_texture(animation_name)
	_sprite_visual.region_rect = Rect2(Vector2.ZERO, frame_size)
	_sprite_visual.position = Vector2(
		0.0,
		-frame_size.y * PLAYER_VISUAL_SCALE * 0.5 + 4.0
	)


func _is_animation_finished() -> bool:
	if _animation_loops(_current_animation):
		return false
	return _animation_time * _animation_fps(_current_animation) >= _animation_frame_count(_current_animation)


func _animation_loops(animation_name: String) -> bool:
	return animation_name == "idle" or animation_name == "run_loop"


func _animation_texture(animation_name: String) -> Texture2D:
	match animation_name:
		"idle_to_run":
			return IDLE_TO_RUN_ANIMATION_TEXTURE
		"run_loop":
			return RUN_LOOP_ANIMATION_TEXTURE
		"run_to_idle":
			return RUN_TO_IDLE_ANIMATION_TEXTURE
		"jump":
			return JUMP_ANIMATION_TEXTURE
		_:
			return IDLE_ANIMATION_TEXTURE


func _animation_frame_size(animation_name: String) -> Vector2:
	match animation_name:
		"idle_to_run":
			return IDLE_TO_RUN_FRAME_SIZE
		"run_loop":
			return RUN_LOOP_FRAME_SIZE
		"run_to_idle":
			return RUN_TO_IDLE_FRAME_SIZE
		"jump":
			return JUMP_FRAME_SIZE
		_:
			return IDLE_FRAME_SIZE


func _animation_frame_count(animation_name: String) -> int:
	match animation_name:
		"idle_to_run":
			return IDLE_TO_RUN_FRAME_COUNT
		"run_loop":
			return RUN_LOOP_FRAME_COUNT
		"run_to_idle":
			return RUN_TO_IDLE_FRAME_COUNT
		"jump":
			return JUMP_FRAME_COUNT
		_:
			return IDLE_FRAME_COUNT


func _animation_fps(animation_name: String) -> float:
	match animation_name:
		"idle_to_run":
			return TRANSITION_ANIMATION_FPS
		"run_to_idle":
			return TRANSITION_ANIMATION_FPS
		"run_loop":
			return RUN_LOOP_ANIMATION_FPS
		"jump":
			return JUMP_ANIMATION_FPS
		_:
			return IDLE_ANIMATION_FPS
