extends Node2D
# A owns this file
#
# W1 — the burst-damage tool with a hard cost. Frozen numbers: 30 damage per
# second while held, with an overheat meter. What is new:
#   * a visible charge ramp on the nozzle and a heat-driven beam profile,
#   * sparks at the contact point (B's enemy throttles them for sustained fire),
#   * an explicit VENTING state after a lockout, with steam that reads at a
#     glance, and a kill punch (shake + hitstop) when the beam finishes something.

const WEAPON_ID := "thermal"
const NOZZLE_PATH := "res://scenes/weapons/thermal_nozzle.svg"

@export var damage_per_second := 30.0 # per contract
@export var beam_length := 500.0
@export var max_heat := 100.0
@export var heat_buildup_rate := 30.0
@export var cooling_rate := 50.0

var current_heat := 0.0
var is_overheated := false
var is_beam_on := false

var _wants_fire := false
var _ray := RayCast2D.new()
var _nozzle: Sprite2D = null
var _ramp := 0.0        # 0..1 charge-up, for the nozzle glow
var _vent_timer := 0.0
var _hit_timer := 0.0
var _time := 0.0


func _ready() -> void:
	_ray.target_position = Vector2(beam_length, 0.0)
	_ray.collide_with_areas = false
	var parent := get_parent() as CollisionObject2D
	if parent:
		_ray.add_exception(parent)
	add_child(_ray)
	if ResourceLoader.exists(NOZZLE_PATH):
		var tex := load(NOZZLE_PATH) as Texture2D
		if tex:
			_nozzle = Sprite2D.new()
			_nozzle.texture = tex
			_nozzle.visible = false
			add_child(_nozzle)


# The submarine calls this. The beam does not read Input itself.
func set_firing(firing: bool) -> void:
	_wants_fire = firing


## 0..1 heat, for the HUD dial.
func heat_ratio() -> float:
	return clampf(current_heat / max_heat, 0.0, 1.0)


func heat_state() -> String:
	if is_overheated:
		return "venting"
	if is_beam_on:
		return "firing"
	if current_heat > 1.0:
		return "cooling"
	return "ready"


func _physics_process(delta: float) -> void:
	_time += delta
	is_beam_on = _wants_fire and not is_overheated

	if is_beam_on:
		current_heat = minf(max_heat, current_heat + heat_buildup_rate * delta)
		_ramp = minf(1.0, _ramp + delta * 2.6)
		if current_heat >= max_heat:
			is_overheated = true
			is_beam_on = false
			_vent_timer = 0.6
	else:
		current_heat = maxf(0.0, current_heat - cooling_rate * delta)
		_ramp = maxf(0.0, _ramp - delta * 1.6)
		if is_overheated and current_heat <= 0.0:
			is_overheated = false
	_vent_timer = maxf(0.0, _vent_timer - delta)

	if is_beam_on:
		_ray.force_raycast_update()
		var target := _ray.get_collider() as Node2D
		if target != null and target.is_in_group("invasive") and target.has_method("receive_damage"):
			target.receive_damage(damage_per_second * delta, WEAPON_ID)
			# zero-strength impulse: no knockback from a beam, but the enemy
			# throttles and places the contact sparks for us
			if target.has_method("apply_impulse"):
				target.call("apply_impulse", Vector2.RIGHT.rotated(global_rotation), 0.0)
			_hit_timer -= delta
			if _hit_timer <= 0.0:
				_hit_timer = 0.5
				var killed := target.has_method("is_dead") and bool(target.call("is_dead"))
				var fx := get_tree().get_first_node_in_group("weapon_fx")
				if fx != null:
					fx.call("shake", 5.0 if killed else 1.2)
					if killed:
						fx.call("hitstop", 0.35, 0.055)

	if _nozzle:
		_nozzle.visible = is_beam_on
		_nozzle.scale = Vector2.ONE * (0.85 + 0.45 * _ramp + 0.12 * sin(_time * 26.0))
	queue_redraw()


func _draw() -> void:
	var heat := current_heat / max_heat
	if is_beam_on:
		var tip := Vector2(beam_length, 0.0)
		if _ray.is_colliding():
			tip = to_local(_ray.get_collision_point())
		var outer := Color("ff7a2e").lerp(Color("e0301e"), heat)
		var mid := Color("ffd27a").lerp(Color("ff7a2e"), heat)
		# charge ramp: the beam starts thin and unstable, then bites
		var width_scale := 0.55 + 0.45 * _ramp
		var jitter := (1.0 - _ramp) * 2.4
		draw_line(Vector2.ZERO, tip, Color(outer, 0.45), 14.0 * width_scale)
		draw_line(Vector2.ZERO, tip, outer, 8.0 * width_scale)
		draw_line(Vector2.ZERO, tip, mid, 4.0 * width_scale)
		draw_line(Vector2.ZERO + Vector2(0, randf_range(-jitter, jitter)),
				tip + Vector2(0, randf_range(-jitter, jitter)), Color.WHITE, 1.5)
		if _ray.is_colliding():
			draw_circle(tip, 7.0 * width_scale, Color(mid, 0.9))
			draw_circle(tip, 3.5, Color.WHITE)
			# splash ring at the contact point
			draw_arc(tip, 10.0 + 6.0 * _ramp, 0.0, TAU, 18, Color(mid, 0.55), 2.0)
		# nozzle core
		draw_circle(Vector2.ZERO, 5.0 + 4.0 * _ramp, Color(mid, 0.85))
	elif is_overheated:
		# VENTING: the nozzle blows heat off instead of firing
		for i in range(5):
			var t := fmod(_time * 1.6 + float(i) / 5.0, 1.0)
			var p := Vector2(-12.0 - t * 26.0, sin(_time * 4.0 + float(i)) * 9.0)
			draw_circle(p, 4.0 + t * 7.0, Color(0.85, 0.88, 0.9, (1.0 - t) * 0.45))
