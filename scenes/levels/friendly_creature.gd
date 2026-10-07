extends Node2D
## A friendly reef species: a helper, never a target.
##
## Deliberately NOT in group "invasive" — which is the whole guarantee. Every
## weapon in the game filters on that one group (scenes/weapons/sonic_pulse.gd,
## bubble_trap.gd, thermal_beam.gd), the wave manager only spawns that group and
## the genetic algorithm only ever sees it, so a helper can be swum through,
## shot straight through and still be there afterwards. tools/verify_weapons.gd
## asserts that, rather than trusting it.
##
## Each helper patrols one coral bed (scenes/levels/reef_site.gd) and reports the
## restore rate its species is worth; systems/reef_restoration.gd turns that into
## reef health.
##
## configure() must run BEFORE add_child().

const SpeciesDB := preload("res://systems/species_db.gd")
const ReefArt := preload("res://scenes/levels/reef_art.gd")

const REDRAW_INTERVAL := 0.05    # 20 Hz, same budget as the enemy art
const BODY_RADIUS := 12.0

var species_id := "reef_parrotfish"
var anchor := Vector2.ZERO
var orbit := 96.0
var orbit_speed := 0.34

var _phase := 0.0
var _time := 0.0
var _redraw_timer := 0.0
var _facing := 0.0
var _health := 1.0          # reef health, for the "grieving" behaviour
var _effort := 1.0


## species_id   one of SpeciesDB.FRIENDLY_ORDER
## centre       the coral bed it works
## orbit_radius how far it wanders from that bed
## seed_value   keeps the swimmers from moving in lockstep
func configure(id: String, centre: Vector2, orbit_radius: float, seed_value: int) -> void:
	species_id = id if SpeciesDB.is_friendly(id) else SpeciesDB.FRIENDLY_ORDER[0]
	anchor = centre
	orbit = maxf(24.0, orbit_radius)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_phase = rng.randf() * TAU
	var data := SpeciesDB.get_helper(species_id)
	match String(data.get("shape", "parrotfish")):
		"crab":
			# the crab walks, it does not swim
			orbit *= 0.45
			orbit_speed = 0.22
		"wrasse":
			orbit *= 0.80
			orbit_speed = 0.58
		_:
			orbit_speed = 0.30 + rng.randf_range(-0.05, 0.05)


func _ready() -> void:
	add_to_group("friendly")
	queue_redraw()


# ================================================================ PUBLIC API

## How much reef this animal gives back per second, before the restoration
## system applies its own scaling. Never zero: helpers are always worth having.
func restore_power() -> float:
	return SpeciesDB.restore_rate(species_id)


func is_helper() -> bool:
	return true


func helper_name() -> String:
	return String(SpeciesDB.get_helper(species_id).get("name", species_id))


## The reef state, as the animals experience it: on a bleached reef they slow
## down and dim instead of pretending everything is fine.
func set_reef_ratio(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if absf(next - _health) < 0.01:
		return
	_health = next
	_effort = 1.0 if next >= 0.22 else 0.35
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_position_on_path(delta)
	_redraw_timer += delta
	if _redraw_timer >= REDRAW_INTERVAL:
		_redraw_timer = 0.0
		queue_redraw()


func _position_on_path(delta: float) -> void:
	# A lazily precessing ellipse around the coral bed: enough motion to read as
	# alive, and it never leaves the reef it is responsible for.
	_phase += delta * orbit_speed * _effort
	var wobble := sin(_phase * 2.0) * 0.14
	var p := anchor + Vector2(cos(_phase) * orbit * (1.0 + wobble), sin(_phase) * orbit * 0.55)
	p += Vector2(cos(_phase * 3.0), sin(_phase * 2.0)) * orbit * 0.07
	var moved := p - global_position
	global_position = p
	if moved.length() > 0.05:
		_facing = lerp_angle(_facing, moved.angle(), minf(1.0, 6.0 * delta))


# ================================================================ DRAW

func _draw() -> void:
	var data := SpeciesDB.get_helper(species_id)
	var shape := String(data.get("shape", "parrotfish"))
	var tint: Color = data.get("tint", Color("2fb3a0"))
	var accent: Color = data.get("accent", Color("ffd05e"))
	var r := BODY_RADIUS * float(data.get("size", 1.0))
	# the crab is a walker: draw it upright, fish bank into their heading
	var facing := 0.0 if shape == "crab" else _facing
	ReefArt.draw_shadow(self, Vector2.ZERO, r)
	var fade := 0.62 + 0.38 * _health
	ReefArt.draw_creature(self, shape, Vector2.ZERO, r, Color(tint, fade), Color(accent, fade),
			_time, facing)
	# a faint "working" arc while it is actually restoring coral
	if _effort >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_time * 2.0)
		draw_arc(Vector2.ZERO, r * 2.1, -PI * 0.7, -PI * 0.3, 8,
				Color(0.72, 1.0, 0.82, 0.16 + 0.14 * pulse), 1.6, true)
