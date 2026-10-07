extends CharacterBody2D
# A owns this file
#
# W1 — THE LOADOUT IS 2 OFFENSIVE + 1 DEFENSIVE.
#   "sonic"    rapid-fire shot      (10 dmg, 0.25 s cooldown — contract)
#   "thermal"  sustained beam       (30 dps + overheat — contract)
#   "bubble"   DEFENSIVE dome       (0 dmg, radius 80, roots 1.5 s — contract)
# Frozen API is untouched: health_changed(current, max_health), died,
# take_health_damage(amount). Weapon switching stays on keys 1/2/3 and
# switch_weapon(id) still works exactly as before.
#
# Additive helpers used by the HUD: weapon_status().

signal health_changed(current: int, max_health: int)
signal died

@export var max_health := 100
@export var speed := 300.0

# Weapon IDs are fixed by the contract: "sonic" | "bubble" | "thermal"
const WEAPON_PATHS := {
	"sonic": "res://scenes/weapons/sonic_pulse.tscn",
	"bubble": "res://scenes/weapons/bubble_trap.tscn",
	"thermal": "res://scenes/weapons/thermal_beam.tscn",
}
# Sonic 0.25 s is from the contract. Bubble is the dome's rearm time (the
# contract defines no cooldown for it, and the dome itself expires on its own).
const COOLDOWNS := {
	"sonic": 0.25,
	"bubble": 6.0,
}
const THERMAL_LOG_INTERVAL := 0.25
const SPRITE_PATH := "res://scenes/player/submarine.svg"
const DEFAULT_MUZZLE_DISTANCE := 50.0
const WeaponFx := preload("res://scenes/player/weapon_fx.gd")

# Impact feel.
const RECOIL_PUSH := 7.0
const RECOIL_RECOVER := 30.0
const FLASH_TIME := 0.085

var current_health: int
var current_weapon_id: String = "sonic"

var _is_dead := false
var _next_fire_time := 0.0
var _beam: Node2D = null
var _thermal_log_timer := 0.0
var _fire_was_down := false
var _sprite: Sprite2D = null
var _fx: Node = null
var _recoil := 0.0
var _muzzle_flash := 0.0
var _dome: Node2D = null
var _dome_ready_at := 0.0

@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	current_health = max_health
	health_changed.emit(current_health, max_health)
	_setup_sprite()
	_setup_fx()


func _setup_fx() -> void:
	_fx = Node.new()
	_fx.name = "WeaponFx"
	_fx.set_script(WeaponFx)
	add_child(_fx)


func _setup_sprite() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null and ResourceLoader.exists(SPRITE_PATH):
		var tex := load(SPRITE_PATH) as Texture2D
		if tex:
			_sprite = Sprite2D.new()
			_sprite.texture = tex
			add_child(_sprite)
	queue_redraw()


func _draw() -> void:
	# Fallback placeholder, only drawn when the sprite file is missing
	if _sprite == null:
		draw_rect(Rect2(-30, -15, 60, 30), Color.YELLOW)
		draw_circle(Vector2(30, 0), 15.0, Color.ORANGE)
	if _muzzle_flash <= 0.0:
		return
	# muzzle flash: a hot core, a soft bloom and a spray of hot gas along the aim
	var dist := muzzle.position.length() if muzzle else DEFAULT_MUZZLE_DISTANCE
	var aim := _aim_angle()
	var m := Vector2.RIGHT.rotated(aim) * dist
	var a := clampf(_muzzle_flash, 0.0, 1.0)
	draw_circle(m, 15.0 * a, Color(1.0, 0.85, 0.5, 0.32 * a))
	draw_circle(m, 8.0 * a, Color(1.0, 0.96, 0.78, 0.72 * a))
	for i in range(4):
		var ang := aim + randf_range(-0.55, 0.55)
		var len := (16.0 + 22.0 * float(i % 2)) * a
		draw_line(m, m + Vector2.RIGHT.rotated(ang) * len, Color(1.0, 0.92, 0.66, 0.5 * a), 2.0)


func _fire_down() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _physics_process(delta: float) -> void:
	_muzzle_flash = maxf(0.0, _muzzle_flash - delta / FLASH_TIME)
	_recoil = maxf(0.0, _recoil - RECOIL_RECOVER * delta)
	if _is_dead:
		return

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

	_update_facing(delta)

	var fire_down := _fire_down()
	var fire_just_pressed := fire_down and not _fire_was_down
	_fire_was_down = fire_down

	match current_weapon_id:
		"sonic":
			if fire_down:
				_try_fire_projectile()
		"bubble":
			if fire_just_pressed:
				_try_deploy_dome()
		"thermal":
			_handle_thermal(delta, fire_down)
	queue_redraw()


func _update_facing(delta: float) -> void:
	if _sprite == null:
		return
	var aim := _aim_angle()
	_sprite.rotation = lerp_angle(_sprite.rotation, aim, minf(1.0, 18.0 * delta))
	# Keep the sub's "top" facing up when it swims left
	_sprite.flip_v = cos(_sprite.rotation) < 0.0
	# recoil nudge: the hull kicks back along the firing axis and settles
	_sprite.position = -Vector2.RIGHT.rotated(aim) * _recoil


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				switch_weapon("sonic")
			KEY_2:
				switch_weapon("bubble")
			KEY_3:
				switch_weapon("thermal")


# ---------- Public API (frozen by contract) ----------

func take_health_damage(amount: float) -> void:
	if _is_dead:
		return
	# The bubble dome is the defensive tool: while it is up it eats the hit
	# instead of the hull. Everything else is unchanged.
	if _dome != null and is_instance_valid(_dome) and _dome.has_method("absorb_hit"):
		if bool(_dome.call("absorb_hit")):
			if _fx != null:
				_fx.call("shake", 3.0)
			return
	current_health = clampi(current_health - int(amount), 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_is_dead = true
		_stop_beam()
		if _fx != null:
			_fx.call("shake", 12.0)
			_fx.call("hitstop", 0.25, 0.18)
		died.emit()


## Additive (W8): the reef-restoration reward. Restoring a coral bed patches the
## hull that did the work. Deliberately additive — no frozen name or number is
## touched, and it is the only way to regain health, so it stays a reward.
func repair(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	current_health = clampi(current_health + int(amount), 0, max_health)
	health_changed.emit(current_health, max_health)


## Additive (W1): weapon readiness for the HUD. Read-only, never influences play.
func weapon_status() -> Dictionary:
	match current_weapon_id:
		"thermal":
			var beam := _get_beam()
			if beam == null:
				return {}
			var state := String(beam.call("heat_state"))
			var ratio := float(beam.call("heat_ratio"))
			if state == "venting":
				return {"weapon": "thermal", "state": "venting", "detail": "VENTING", "value": ratio}
			if ratio > 0.01:
				return {"weapon": "thermal", "state": "charging", "detail": "HEAT %d%%" % int(ratio * 100.0),
						"value": ratio}
			return {"weapon": "thermal", "state": "ready", "detail": "BEAM READY", "value": 0.0}
		"bubble":
			if _dome != null and is_instance_valid(_dome):
				return {"weapon": "bubble", "state": "ready",
						"detail": "DOME UP  %d" % int(_dome.call("charges_left")), "value": 1.0}
			var dome_remain := maxf(0.0, _dome_ready_at - _now())
			if dome_remain > 0.0:
				return {"weapon": "bubble", "state": "recharging",
						"detail": "DOME %.1fs" % dome_remain,
						"value": 1.0 - dome_remain / float(COOLDOWNS["bubble"])}
			return {"weapon": "bubble", "state": "ready", "detail": "DOME READY", "value": 1.0}
		_:
			var remain := maxf(0.0, _next_fire_time - _now())
			if remain > 0.0:
				return {"weapon": "sonic", "state": "cooling", "detail": "SONIC %.2fs" % remain,
						"value": 1.0 - remain / float(COOLDOWNS["sonic"])}
			return {"weapon": "sonic", "state": "ready", "detail": "SONIC READY", "value": 1.0}


# ---------- Weapons ----------

func switch_weapon(id: String) -> void:
	if not WEAPON_PATHS.has(id) or id == current_weapon_id:
		return
	_stop_beam()
	current_weapon_id = id
	if _fx != null:
		_fx.call("shake", 0.8)


func _try_fire_projectile() -> void:
	var now := _now()
	if now < _next_fire_time:
		return
	var scene := _load_weapon(current_weapon_id)
	if scene == null:
		return
	var node := scene.instantiate() as Node2D
	get_tree().current_scene.add_child(node)
	node.global_position = _muzzle_position()
	node.global_rotation = _aim_angle()
	_next_fire_time = now + float(COOLDOWNS.get(current_weapon_id, 0.25))
	_kick()
	_log_shot(current_weapon_id)


## The defensive tool: a dome around the sentinel that roots what touches it and
## absorbs a couple of hits before popping. Base damage stays 0.
func _try_deploy_dome() -> void:
	var now := _now()
	if now < _dome_ready_at:
		return
	if _dome != null and is_instance_valid(_dome):
		return
	var scene := _load_weapon("bubble")
	if scene == null:
		return
	var dome := scene.instantiate() as Node2D
	add_child(dome)
	if dome.has_method("deploy_on"):
		dome.call("deploy_on", self)
	dome.global_position = global_position
	_dome = dome
	_dome_ready_at = now + float(COOLDOWNS["bubble"])
	if _fx != null:
		_fx.call("shake", 3.2)
	_log_shot("bubble")


func _handle_thermal(delta: float, firing: bool) -> void:
	var beam := _get_beam()
	if beam == null:
		return
	beam.set_firing(firing)
	beam.global_position = _muzzle_position()
	beam.global_rotation = _aim_angle()
	if beam.is_beam_on:
		# A continuous beam has no discrete shots, so log once per interval.
		_thermal_log_timer -= delta
		if _thermal_log_timer <= 0.0:
			_thermal_log_timer = THERMAL_LOG_INTERVAL
			_log_shot("thermal")
	else:
		_thermal_log_timer = 0.0


func _stop_beam() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.set_firing(false)
	_thermal_log_timer = 0.0


func _get_beam() -> Node2D:
	if _beam == null or not is_instance_valid(_beam):
		var scene := _load_weapon("thermal")
		if scene == null:
			return null
		_beam = scene.instantiate() as Node2D
		add_child(_beam)
		_beam.global_position = _muzzle_position()
	return _beam


func _load_weapon(id: String) -> PackedScene:
	var path: String = WEAPON_PATHS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Weapon scene missing for '%s': %s" % [id, path])
		return null
	return load(path) as PackedScene


func _kick() -> void:
	_recoil = RECOIL_PUSH
	_muzzle_flash = 1.0
	if _fx != null:
		_fx.call("shake", 1.8)


func _muzzle_position() -> Vector2:
	# The sprite turns to face the aim direction, so the muzzle follows it
	var dist := muzzle.position.length() if muzzle else DEFAULT_MUZZLE_DISTANCE
	return global_position + Vector2.RIGHT.rotated(_aim_angle()) * dist


func _aim_angle() -> float:
	return (get_global_mouse_position() - global_position).angle()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _log_shot(weapon_id: String) -> void:
	# Telemetry is B's autoload (already registered in project.godot)
	var telemetry := get_node_or_null("/root/Telemetry")
	if telemetry:
		telemetry.log_shot(weapon_id)
