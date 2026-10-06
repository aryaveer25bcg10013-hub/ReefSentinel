extends Node2D
# A owns this file

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


func _physics_process(delta: float) -> void:
	is_beam_on = _wants_fire and not is_overheated

	if is_beam_on:
		current_heat = minf(max_heat, current_heat + heat_buildup_rate * delta)
		if current_heat >= max_heat:
			is_overheated = true
			is_beam_on = false
	else:
		current_heat = maxf(0.0, current_heat - cooling_rate * delta)
		if is_overheated and current_heat <= 0.0:
			is_overheated = false

	if is_beam_on:
		_ray.force_raycast_update()
		var target := _ray.get_collider() as Node
		if target and target.is_in_group("invasive") and target.has_method("receive_damage"):
			target.receive_damage(damage_per_second * delta, WEAPON_ID)

	if _nozzle:
		_nozzle.visible = is_beam_on
		_nozzle.scale = Vector2.ONE * (1.0 + 0.2 * sin(Time.get_ticks_msec() / 40.0))
	queue_redraw()


func _draw() -> void:
	if not is_beam_on:
		return
	var tip := Vector2(beam_length, 0.0)
	if _ray.is_colliding():
		tip = to_local(_ray.get_collision_point())
	# Colour shifts toward red as the beam heats up
	var heat := current_heat / max_heat
	var outer := Color("ff7a2e").lerp(Color("e0301e"), heat)
	var mid := Color("ffd27a").lerp(Color("ff7a2e"), heat)
	draw_line(Vector2.ZERO, tip, Color(outer, 0.45), 14.0)
	draw_line(Vector2.ZERO, tip, outer, 8.0)
	draw_line(Vector2.ZERO, tip, mid, 4.0)
	draw_line(Vector2.ZERO, tip, Color.WHITE, 1.5)
	if _ray.is_colliding():
		draw_circle(tip, 7.0, Color(mid, 0.9))
		draw_circle(tip, 3.5, Color.WHITE)
