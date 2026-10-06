extends CharacterBody2D
# A owns this file

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
# Sonic 0.25 s is from the contract. Bubble 0.8 s is a placeholder value.
const COOLDOWNS := {
	"sonic": 0.25,
	"bubble": 0.8,
}
const THERMAL_LOG_INTERVAL := 0.25
const SPRITE_PATH := "res://scenes/player/submarine.svg"
const DEFAULT_MUZZLE_DISTANCE := 50.0

var current_health: int
var current_weapon_id: String = "sonic"

var _is_dead := false
var _next_fire_time := 0.0
var _beam: Node2D = null
var _thermal_log_timer := 0.0
var _fire_was_down := false
var _sprite: Sprite2D = null

@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	current_health = max_health
	health_changed.emit(current_health, max_health)
	_setup_sprite()


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
	if _sprite != null:
		return
	draw_rect(Rect2(-30, -15, 60, 30), Color.YELLOW)
	draw_circle(Vector2(30, 0), 15.0, Color.ORANGE)


func _fire_down() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _physics_process(delta: float) -> void:
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
				_try_fire_projectile()
		"thermal":
			_handle_thermal(delta, fire_down)


func _update_facing(delta: float) -> void:
	if _sprite == null:
		return
	var aim := _aim_angle()
	_sprite.rotation = lerp_angle(_sprite.rotation, aim, minf(1.0, 18.0 * delta))
	# Keep the sub's "top" facing up when it swims left
	_sprite.flip_v = cos(_sprite.rotation) < 0.0


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
	current_health = clampi(current_health - int(amount), 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_is_dead = true
		_stop_beam()
		died.emit()


# ---------- Weapons ----------

func switch_weapon(id: String) -> void:
	if not WEAPON_PATHS.has(id) or id == current_weapon_id:
		return
	_stop_beam()
	current_weapon_id = id


func _try_fire_projectile() -> void:
	var now := Time.get_ticks_msec() / 1000.0
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
	_log_shot(current_weapon_id)


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


func _muzzle_position() -> Vector2:
	# The sprite turns to face the aim direction, so the muzzle follows it
	var dist := muzzle.position.length() if muzzle else DEFAULT_MUZZLE_DISTANCE
	return global_position + Vector2.RIGHT.rotated(_aim_angle()) * dist


func _aim_angle() -> float:
	return (get_global_mouse_position() - global_position).angle()


func _log_shot(weapon_id: String) -> void:
	# Telemetry is B's autoload (already registered in project.godot)
	var telemetry := get_node_or_null("/root/Telemetry")
	if telemetry:
		telemetry.log_shot(weapon_id)
