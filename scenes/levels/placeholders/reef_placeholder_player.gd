extends CharacterBody2D
# C-owned PLACEHOLDER — scaffolding only, NOT Role A's real submarine.
#
# Why this exists: the level scenes must be walkable and testable before
# res://scenes/player/submarine.tscn exists. level_base.gd prefers A's scene when
# it is present, so this file becomes dead weight the moment A ships. Delete it
# then.
#
# Frozen player API implemented verbatim:
#   signal health_changed(current: int, max_health: int)
#   signal died
#   func take_health_damage(amount: float) -> void
#
# The test pulse below is deliberately NOT a weapon implementation. It is a
# hitscan stub that calls the frozen enemy API so the full contract chain
# (log_shot -> receive_damage -> genome multiplier -> died -> log_kill) can be
# exercised before Role A lands the real sonic/bubble/thermal rig.

signal health_changed(current: int, max_health: int)
signal died

const SPEED := 300.0          # contract
const MAX_HEALTH := 100       # contract
const BODY_RADIUS := 18.0
const PULSE_COOLDOWN := 0.25  # matches the contract's sonic cooldown
const PULSE_DAMAGE := 10.0    # matches the contract's sonic base damage
const PULSE_WEAPON_ID := "sonic"
const PULSE_RANGE := 900.0
const BODY := Color("f2c14e")
const BODY_EDGE := Color("33231a")
const GLASS := Color("6fd3e8")

var current_health := MAX_HEALTH
var current_weapon_id := PULSE_WEAPON_ID

var _next_fire := 0.0
var _dead := false
var _aim := 0.0
var _fire_was_down := false


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_ensure_shape()
	current_health = MAX_HEALTH
	health_changed.emit(current_health, MAX_HEALTH)


func _ensure_shape() -> void:
	if find_children("*", "CollisionShape2D", false).is_empty():
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = BODY_RADIUS
		shape.shape = circle
		add_child(shape)


# ---------- Frozen API ----------

func take_health_damage(amount: float) -> void:
	if _dead:
		return
	current_health = clampi(current_health - int(amount), 0, MAX_HEALTH)
	health_changed.emit(current_health, MAX_HEALTH)
	if current_health <= 0:
		_dead = true
		died.emit()


# ---------- Behaviour ----------

func _physics_process(delta: float) -> void:
	if _dead:
		return
	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * SPEED
	move_and_slide()

	_aim = (get_global_mouse_position() - global_position).angle()
	rotation = _aim

	var fire_down := _fire_down()
	if fire_down and not _fire_was_down:
		_fire_pulse()
	_fire_was_down = fire_down
	queue_redraw()


func _fire_down() -> bool:
	# Prefer a real "fire" action if a teammate has already added one.
	if InputMap.has_action("fire"):
		return Input.is_action_pressed("fire")
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)


func _fire_pulse() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_fire:
		return
	_next_fire = now + PULSE_COOLDOWN
	_log_shot(PULSE_WEAPON_ID)

	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2.RIGHT.rotated(_aim) * BODY_RADIUS
	var to := from + Vector2.RIGHT.rotated(_aim) * PULSE_RANGE
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Node
	if collider == null or not collider.is_in_group("invasive"):
		return
	if collider.has_method("receive_damage"):
		collider.receive_damage(PULSE_DAMAGE, PULSE_WEAPON_ID)


func _log_shot(weapon_id: String) -> void:
	var telemetry := get_node_or_null("/root/Telemetry")
	if telemetry:
		telemetry.log_shot(weapon_id)


# ---------- Placeholder art ----------

func _draw() -> void:
	draw_circle(Vector2.ZERO, BODY_RADIUS, BODY)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 28, BODY_EDGE, 2.4, true)
	draw_circle(Vector2(6, 0), 5.5, GLASS)
	draw_circle(Vector2(6, 0), 2.6, BODY_EDGE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-BODY_RADIUS, 0), Vector2(-BODY_RADIUS - 8.0, -6.0), Vector2(-BODY_RADIUS - 8.0, 6.0),
	]), BODY.darkened(0.2))
