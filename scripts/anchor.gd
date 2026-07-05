extends CharacterBody2D
class_name HeavyAnchor

enum State {
	CARRIED,
	FLYING,
	HOOKED,
	GROUNDED,
	RETURNING
}

const THROW_SPEED := 680.0
const THROW_GRAVITY := 920.0
const FLYING_DRAG := 0.18
const RETURN_START_SPEED := 190.0
const RETURN_ACCELERATION := 1850.0
const RETURN_MAX_SPEED := 760.0
const RETURN_SLOW_RADIUS := 115.0
const RETURN_CATCH_DISTANCE := 24.0
const REEL_SPEED := 285.0
const REEL_PULL := 2600.0
const GROUND_REEL_PULL := 5200.0
const MIN_CHAIN_LENGTH := 58.0
const MAX_CHAIN_LENGTH := 440.0
const DEFAULT_CHAIN_LENGTH := MAX_CHAIN_LENGTH
const CHAIN_END_DAMPING := 0.72
const SMASH_SPEED := 560.0
const RELEASE_TANGENT_SPEED := 560.0
const ANCHOR_TEXTURE: Texture2D = preload("res://assets/items/anchor_glow.png")
const ANCHOR_VISUAL_SCALE: float = 0.075
const ANCHOR_EDGE_GLOW_SCALE: float = 0.078

var game
var player
var state: State = State.CARRIED
var chain_length := DEFAULT_CHAIN_LENGTH
var hook_normal := Vector2.UP
var last_collision_speed := 0.0
var hooked_body: Node2D = null
var hook_local_position := Vector2.ZERO
var _return_speed := 0.0

var _anchor_visual: Sprite2D
var _anchor_edge_glow: Sprite2D
var _shape: CollisionShape2D


static func state_label(value: int) -> String:
	match value:
		State.CARRIED:
			return "carried"
		State.FLYING:
			return "flying"
		State.HOOKED:
			return "hooked"
		State.GROUNDED:
			return "grounded"
		State.RETURNING:
			return "returning"
	return "unknown"


func state_text() -> String:
	return state_label(state)


func state_text_cn() -> String:
	match state:
		State.CARRIED:
			return "背着锚"
		State.FLYING:
			return "锚飞出"
		State.HOOKED:
			return "锚钩住"
		State.GROUNDED:
			return "锚落地"
		State.RETURNING:
			return "锚回收中"
	return "未知"


func is_carried() -> bool:
	return state == State.CARRIED


func is_hooked() -> bool:
	return state == State.HOOKED


func is_grounded() -> bool:
	return state == State.GROUNDED


func is_returning() -> bool:
	return state == State.RETURNING


func _ready() -> void:
	collision_layer = 4
	collision_mask = 9

	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	_shape.shape = circle
	add_child(_shape)

	_anchor_edge_glow = Sprite2D.new()
	_anchor_edge_glow.name = "AnchorEdgeGlow"
	_anchor_edge_glow.texture = ANCHOR_TEXTURE
	_anchor_edge_glow.centered = true
	_anchor_edge_glow.scale = Vector2.ONE * ANCHOR_EDGE_GLOW_SCALE
	_anchor_edge_glow.position = Vector2(0.0, 8.0)
	_anchor_edge_glow.modulate = Color(1.0, 0.72, 0.28, 0.08)
	add_child(_anchor_edge_glow)

	_anchor_visual = Sprite2D.new()
	_anchor_visual.name = "AnchorVisual"
	_anchor_visual.texture = ANCHOR_TEXTURE
	_anchor_visual.centered = true
	_anchor_visual.scale = Vector2.ONE * ANCHOR_VISUAL_SCALE
	_anchor_visual.position = Vector2(0.0, 8.0)
	add_child(_anchor_visual)

	_set_collision_enabled(false)


func setup(game_ref, player_ref) -> void:
	game = game_ref
	player = player_ref


func throw_toward(target: Vector2) -> bool:
	if state != State.CARRIED:
		return false
	var direction: Vector2 = target - player.global_position
	if direction.length() < 18.0:
		direction = Vector2(float(player.facing), -0.35)
	throw_direction(direction.normalized())
	return true


func throw_direction(direction: Vector2) -> void:
	state = State.FLYING
	global_position = player.global_position + Vector2(22.0 * player.facing, -32.0)
	velocity = direction.normalized() * THROW_SPEED
	chain_length = DEFAULT_CHAIN_LENGTH
	_return_speed = 0.0
	_clear_hooked_body()
	_set_collision_enabled(true)
	_update_visual_state()


func release_hook() -> void:
	if state == State.HOOKED:
		if not _hooked_body_is_pullable():
			_apply_release_boost()
		start_return()


func start_return() -> void:
	if state == State.CARRIED:
		return
	state = State.RETURNING
	velocity = Vector2.ZERO
	_return_speed = RETURN_START_SPEED
	_clear_hooked_body()
	_set_collision_enabled(false)
	_update_visual_state()


func force_carried() -> void:
	state = State.CARRIED
	velocity = Vector2.ZERO
	_return_speed = 0.0
	chain_length = DEFAULT_CHAIN_LENGTH
	_clear_hooked_body()
	_set_collision_enabled(false)
	_update_visual_state()


func force_grounded(at_position: Vector2, length_override := -1.0) -> void:
	state = State.GROUNDED
	global_position = at_position
	velocity = Vector2.ZERO
	_return_speed = 0.0
	chain_length = length_override if length_override > 0.0 else DEFAULT_CHAIN_LENGTH
	_clear_hooked_body()
	_set_collision_enabled(false)
	_update_visual_state()
	if game != null and game.has_method("anchor_grounded"):
		game.anchor_grounded(null, global_position)


func begin_validation_flight(at_position: Vector2, start_velocity: Vector2) -> void:
	state = State.FLYING
	global_position = at_position
	velocity = start_velocity
	last_collision_speed = start_velocity.length()
	chain_length = DEFAULT_CHAIN_LENGTH
	_return_speed = 0.0
	_clear_hooked_body()
	_set_collision_enabled(true)
	_update_visual_state()


func _apply_release_boost() -> void:
	if player == null:
		return
	var radial: Vector2 = player.global_position - global_position
	if radial.length() < 1.0:
		return
	radial = radial.normalized()
	var tangent: Vector2 = Vector2(-radial.y, radial.x)
	if tangent.x * float(player.facing) < 0.0:
		tangent = -tangent
	var current_tangent_speed: float = player.velocity.dot(tangent)
	if current_tangent_speed < RELEASE_TANGENT_SPEED:
		player.velocity += tangent * (RELEASE_TANGENT_SPEED - current_tangent_speed)
	var forward_speed := float(player.facing) * RELEASE_TANGENT_SPEED
	if sign(player.velocity.x) != player.facing or abs(player.velocity.x) < RELEASE_TANGENT_SPEED * 0.85:
		player.velocity.x = forward_speed
	player.velocity.y = min(player.velocity.y, -180.0)


func _physics_process(delta: float) -> void:
	if player == null:
		return

	match state:
		State.CARRIED:
			global_position = player.global_position + Vector2(-22.0 * player.facing, -18.0)
		State.FLYING:
			velocity.y += THROW_GRAVITY * delta
			velocity *= maxf(0.0, 1.0 - FLYING_DRAG * delta)
			last_collision_speed = velocity.length()
			var collision := move_and_collide(_motion_limited_by_chain(velocity * delta))
			if collision != null:
				_handle_collision(collision)
			elif state == State.FLYING:
				_apply_flying_chain_limit()
		State.HOOKED:
			velocity = Vector2.ZERO
			_follow_hooked_body()
		State.GROUNDED:
			velocity = Vector2.ZERO
		State.RETURNING:
			_update_returning(delta)

	_update_visual_state()


func apply_player_forces(target_player: CharacterBody2D, delta: float, reel_active: bool) -> void:
	if state != State.HOOKED and state != State.GROUNDED:
		return

	var offset := target_player.global_position - global_position
	var distance := offset.length()
	if distance < 1.0:
		return
	var direction := offset / distance

	if state == State.HOOKED and _hooked_body_is_pullable():
		if hooked_body.has_method("handle_anchor_pull"):
			hooked_body.call("handle_anchor_pull", target_player.global_position, delta, reel_active)
			_follow_hooked_body()
		offset = target_player.global_position - global_position
		distance = offset.length()
		if distance >= 1.0:
			_constrain_player(target_player, offset / distance, distance)
		return

	if state == State.HOOKED and reel_active:
		chain_length = max(MIN_CHAIN_LENGTH, chain_length - REEL_SPEED * delta)
		target_player.velocity += -direction * REEL_PULL * delta
	elif state == State.GROUNDED and reel_active:
		target_player.velocity += -direction * GROUND_REEL_PULL * delta

	_constrain_player(target_player, direction, distance)


func post_player_move(target_player: CharacterBody2D) -> void:
	if state != State.HOOKED and state != State.GROUNDED:
		return
	var offset := target_player.global_position - global_position
	var distance := offset.length()
	if distance < 1.0:
		return
	_constrain_player(target_player, offset / distance, distance)


func _constrain_player(target_player: CharacterBody2D, direction: Vector2, distance: float) -> void:
	if distance <= chain_length:
		return
	target_player.global_position -= direction * (distance - chain_length)
	var outward_speed := target_player.velocity.dot(direction)
	if outward_speed > 0.0:
		target_player.velocity -= direction * outward_speed


func _motion_limited_by_chain(motion: Vector2) -> Vector2:
	if motion.length_squared() <= 0.0001:
		return motion
	var offset := global_position - _chain_origin()
	var distance := offset.length()
	if distance >= chain_length - 0.5 and distance > 1.0:
		var direction := offset / distance
		var outward_motion := motion.dot(direction)
		if outward_motion > 0.0:
			motion -= direction * outward_motion

	var projected := offset + motion
	if projected.length() <= chain_length:
		return motion

	var a := motion.length_squared()
	var b := 2.0 * offset.dot(motion)
	var c := offset.length_squared() - chain_length * chain_length
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return Vector2.ZERO

	var root := sqrt(discriminant)
	var t := (-b + root) / (2.0 * a)
	if c > 0.0:
		t = (-b - root) / (2.0 * a)
	t = clampf(t, 0.0, 1.0)
	return motion * t


func _apply_flying_chain_limit() -> void:
	var origin := _chain_origin()
	var offset := global_position - origin
	var distance := offset.length()
	if distance < 1.0:
		return
	var direction := offset / distance
	if distance > chain_length:
		global_position = origin + direction * chain_length

	if distance >= chain_length - 0.5:
		var outward_speed := velocity.dot(direction)
		if outward_speed > 0.0:
			velocity -= direction * outward_speed
			velocity *= CHAIN_END_DAMPING


func _update_returning(delta: float) -> void:
	var to_player: Vector2 = player.global_position + Vector2(0, -24) - global_position
	var distance: float = to_player.length()
	if distance <= RETURN_CATCH_DISTANCE:
		force_carried()
		return

	_return_speed = minf(RETURN_MAX_SPEED, _return_speed + RETURN_ACCELERATION * delta)
	var target_speed := _return_speed
	if distance < RETURN_SLOW_RADIUS:
		target_speed = minf(target_speed, maxf(RETURN_START_SPEED, RETURN_MAX_SPEED * distance / RETURN_SLOW_RADIUS))
	global_position += to_player.normalized() * minf(target_speed * delta, distance)


func _chain_origin() -> Vector2:
	return player.global_position + Vector2(0, -32)


func _follow_hooked_body() -> bool:
	if hooked_body == null:
		return true
	if not is_instance_valid(hooked_body):
		start_return()
		return false
	global_position = hooked_body.to_global(hook_local_position)
	return true


func _hooked_body_is_pullable() -> bool:
	if hooked_body == null or not is_instance_valid(hooked_body):
		return false
	if hooked_body.has_method("is_pullable_anchor_target"):
		return bool(hooked_body.call("is_pullable_anchor_target"))
	return hooked_body.has_meta("pullable_anchor_target")


func _clear_hooked_body() -> void:
	hooked_body = null
	hook_local_position = Vector2.ZERO


func _handle_collision(collision: KinematicCollision2D) -> void:
	var collider := collision.get_collider()
	var normal := collision.get_normal()
	global_position = collision.get_position() + normal * 12.0

	if collider != null and collider.has_meta("breakable"):
		var required_smash_speed: float = SMASH_SPEED
		if collider.has_method("smash_speed"):
			required_smash_speed = float(collider.call("smash_speed"))
		if last_collision_speed >= required_smash_speed:
			game.smash_breakable(collider)
			velocity = velocity.bounce(normal) * 0.18 + Vector2.DOWN * 230.0
			global_position += velocity.normalized() * 10.0
			return

	if collider != null and collider.has_meta("hookable"):
		state = State.HOOKED
		hook_normal = normal
		velocity = Vector2.ZERO
		chain_length = clamp(global_position.distance_to(player.global_position), MIN_CHAIN_LENGTH, MAX_CHAIN_LENGTH)
		if collider is Node2D:
			hooked_body = collider as Node2D
			hook_local_position = hooked_body.to_local(global_position)
		else:
			_clear_hooked_body()
		_set_collision_enabled(false)
		if game != null and game.has_method("anchor_hooked"):
			game.anchor_hooked(collider)
	else:
		state = State.GROUNDED
		velocity = Vector2.ZERO
		chain_length = MAX_CHAIN_LENGTH
		_clear_hooked_body()
		_set_collision_enabled(false)
		if game != null and game.has_method("anchor_grounded"):
			game.anchor_grounded(collider, global_position)


func _set_collision_enabled(enabled: bool) -> void:
	if _shape != null:
		_shape.disabled = not enabled
	collision_mask = 9 if enabled else 0


func _update_visual_state() -> void:
	match state:
		State.CARRIED:
			_anchor_visual.modulate = Color.WHITE
			_anchor_edge_glow.modulate = Color(1.0, 0.72, 0.28, 0.06)
		State.FLYING:
			_anchor_visual.modulate = Color.WHITE
			_anchor_edge_glow.modulate = Color(1.0, 0.82, 0.35, 0.12)
			rotation += 0.18
		State.HOOKED:
			_anchor_visual.modulate = Color.WHITE
			_anchor_edge_glow.modulate = Color(1.0, 0.86, 0.35, 0.16)
			rotation = hook_normal.angle() + PI * 0.5
		State.GROUNDED:
			_anchor_visual.modulate = Color.WHITE
			_anchor_edge_glow.modulate = Color(1.0, 0.72, 0.28, 0.08)
			rotation = 0.0
		State.RETURNING:
			_anchor_visual.modulate = Color.WHITE
			_anchor_edge_glow.modulate = Color(1.0, 0.86, 0.38, 0.12)
			rotation += 0.22
