extends Node2D
## The coral colony as art, drawn once into a texture by scenes/levels/reef_site.gd.
##
## This is the only part of a reef site that needs drawing, and it only changes
## when the reef's health crosses a visible bucket — so it follows the same
## bake-once convention as the world map and the reef floor: hundreds of
## primitives become one quad, and the per-frame cost of a coral bed is a single
## sprite instead of ~100 draw calls.
##
## Drawn in its own local space with the colony centred on (0, 0); the site
## positions it inside its SubViewport.
##
## add_fragment() grows a brand-new head on the bed. That is the payoff for the
## planting action: the player does not just push a bar up, they can see the
## coral they planted sitting on the reef afterwards.
##
## Reading the states apart at a glance is the requirement:
##   healthy  : vivid coral heads, polyps open, pale rock base
##   smothered: a dark algae mat lies over the heads and the colour drains
##   bleached : bone-white skeleton, no polyps, the mat is gone with the tissue

const HEAD_COUNT := 5

## Living coral palette — same family as reef_floor.gd's CORAL list.
const CORAL_HEADS := [
	Color("ff7aa2"), Color("ffa04a"), Color("b98cff"), Color("ffd75a"), Color("ff6b6b"),
]
const BLEACHED := Color("f0ece2")
const BLEACHED_SHADE := Color("cfc8ba")
const MAT := Color("2f5a2a")
const ROCK := Color("9d9689")
const ROCK_DARK := Color("6f6a60")
const POLYP := Color("fff3c4")

## Each planted head is smaller than the colony it lands on, and it is placed on
## its own ring so two plantings never overlap.
const FRAGMENT_SCALE := 0.62

var radius := 120.0
var _seed := 1
var _health := 0.45
var _fragments := 0
var _heads: Array[Dictionary] = []
var _rocks: Array[Dictionary] = []


func configure(index: int, size_px: float, seed_value: int) -> void:
	radius = size_px
	_seed = seed_value
	_build(index)


func set_health(ratio: float) -> void:
	_health = clampf(ratio, 0.0, 1.0)
	queue_redraw()


## One coral head planted by the player. Deterministic per fragment index, so
## the same bed always grows the same colony back.
func add_fragment() -> void:
	_fragments += 1
	_heads.append(_make_head(_heads.size(), true))
	queue_redraw()


func fragment_count() -> int:
	return _fragments


func _build(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + index * 131
	_heads.clear()
	_rocks.clear()
	var grown := 0
	for i in HEAD_COUNT:
		_heads.append(_make_head(grown, false))
		grown += 1
	for i in range(7):
		var a := rng.randf() * TAU
		var dist := radius * rng.randf_range(0.30, 0.95)
		_rocks.append({
			"pos": Vector2(cos(a), sin(a)) * dist,
			"r": radius * rng.randf_range(0.05, 0.13),
			"tilt": rng.randf(),
		})


## One head of the colony. `planted` heads sit on an inner ring and lean
## upright, so a player-planted fragment reads as deliberately placed.
func _make_head(slot: int, planted: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + slot * 2617
	var count := float(HEAD_COUNT)
	var a := TAU * float(slot) / count + rng.randf_range(-0.35, 0.35)
	var dist := radius * rng.randf_range(0.32, 0.78)
	if planted:
		# planted fragments fill the ring the colony has not reached yet
		dist = radius * (0.30 + 0.16 * float(slot % 3))
	return {
		"pos": Vector2(cos(a), sin(a)) * dist,
		"scale": rng.randf_range(0.70, 1.25) * (FRAGMENT_SCALE if planted else 1.0),
		"colour": CORAL_HEADS[rng.randi() % CORAL_HEADS.size()],
		"lean": rng.randf_range(-0.28, 0.28) * (0.4 if planted else 1.0),
		"branches": rng.randi_range(3, 5),
	}


func _draw() -> void:
	var blend := _health
	for rock: Dictionary in _rocks:
		var p: Vector2 = rock["pos"]
		var r := float(rock["r"]) * (1.0 + 0.10 * blend)
		var shade := ROCK.lerp(ROCK_DARK, float(rock["tilt"]))
		draw_circle(p, r, shade)
		draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.62, shade.lightened(0.16))

	for head: Dictionary in _heads:
		var base: Vector2 = head["pos"]
		var scale: float = float(head["scale"]) * radius * 0.20
		var colour: Color = head["colour"]
		# colour is the state readout: bleached bone at 0, full coral at 1
		var live := BLEACHED.lerp(colour, blend)
		var shade := BLEACHED_SHADE.lerp(colour.darkened(0.35), blend)
		_draw_head(base, scale, live, shade, float(head["lean"]), int(head["branches"]), blend)

	# the algae mat the swarm leaves behind: gone when the reef is healthy
	if blend < 0.97:
		var mat_alpha := (1.0 - blend) * 0.50
		for head: Dictionary in _heads:
			var base: Vector2 = head["pos"]
			var scale: float = float(head["scale"]) * radius * 0.20
			for i in range(3):
				var a := float(i) * 2.1
				var p := base + Vector2(cos(a), sin(a) * 0.6) * scale * 1.15
				draw_circle(p, scale * 0.72, Color(MAT, mat_alpha))
		draw_circle(Vector2.ZERO, radius * 0.95, Color(MAT, mat_alpha * 0.22))


## A branching coral head: trunk, forks, and polyp tips that only exist while
## there is living tissue to grow them.
func _draw_head(base: Vector2, scale: float, live: Color, shade: Color, lean: float,
		branches: int, blend: float) -> void:
	var tip := base + Vector2(sin(lean) * scale * 1.4, -scale * 1.5)
	draw_line(base, tip, shade, maxf(2.0, scale * 0.34), true)
	draw_line(base, tip, live, maxf(1.2, scale * 0.20), true)
	for i in range(branches):
		var t := 0.35 + 0.55 * float(i) / float(maxi(1, branches - 1))
		var at := base.lerp(tip, t)
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := 0.55 + 0.35 * float(i % 3)
		var end := at + Vector2(side * scale * spread * (1.0 + lean), -scale * 0.85)
		draw_line(at, end, shade, maxf(1.6, scale * 0.26), true)
		draw_line(at, end, live, maxf(1.0, scale * 0.15), true)
		if blend > 0.30:
			# polyps: the living tissue, so they fade out on a bleaching reef
			var polyp_alpha := clampf((blend - 0.30) / 0.55, 0.0, 1.0)
			draw_circle(end, maxf(1.6, scale * 0.24), Color(POLYP, 0.85 * polyp_alpha))
			draw_circle(end, maxf(1.0, scale * 0.14), Color(1, 1, 1, 0.9 * polyp_alpha))
