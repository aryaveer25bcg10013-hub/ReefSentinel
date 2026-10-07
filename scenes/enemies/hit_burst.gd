extends Node2D
## Short-lived impact burst: sparks plus an ink puff. Drawn in code, self-frees.
##
## Used for every landed hit (throttled for sustained weapons) and for deaths,
## so a hit is never silent even when the enemy art is busy.

const LIFETIME := 0.34

var _dir := Vector2.RIGHT
var _colour := Color.WHITE
var _count := 7
var _spread := 1.0
var _age := 0.0
var _rng := RandomNumberGenerator.new()


func configure(direction: Vector2, colour: Color, count: int, spread: float) -> void:
	_dir = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	_colour = colour
	_count = count
	_spread = spread
	_rng.seed = hash(Vector2i(direction * 32.0)) + count * 977


func _ready() -> void:
	z_index = 30
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFETIME:
		queue_free()


func _draw() -> void:
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	var fade := 1.0 - t
	var spread := _spread * (0.35 + t)
	# ink puff
	draw_circle(Vector2.ZERO, 5.0 + t * 16.0, Color(0.05, 0.12, 0.16, 0.28 * fade))
	# sparks thrown along the impact normal and around it
	for i in _count:
		var jitter := _rng.randf_range(-spread, spread)
		var dir := _dir.rotated(jitter)
		var len := _rng.randf_range(7.0, 16.0) * (1.0 - t * 0.4)
		var p := dir * (4.0 + len * t * 3.4)
		draw_line(p, p - dir * len * 0.5, Color(_colour, 0.95 * fade), 2.0, true)
		draw_circle(p, 1.6, Color(1, 1, 1, 0.9 * fade))
	# expanding shock ring
	draw_arc(Vector2.ZERO, 3.0 + t * 20.0, 0.0, TAU, 20, Color(_colour, 0.55 * fade), 2.0, true)
	# absorbed hits get a hard "clang" ring instead of sparks
	if _count <= 3:
		draw_arc(Vector2.ZERO, 6.0 + t * 10.0, 0.0, TAU, 16, Color(0.85, 0.95, 1.0, 0.8 * fade), 2.6, true)
