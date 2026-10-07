extends Node2D
## Floating damage number for one hit. Code-drawn (no font or texture assets),
## so it matches the project's procedural-art convention.
##
## Colour carries the message:
##   bright amber = the swarm is weak to this weapon (multiplier > 1.05)
##   white        = normal hit
##   cold grey    = the hit was absorbed (multiplier < 0.5) — "they're tanking it"

const LIFETIME := 0.72
const RISE := 46.0

var _text := ""
var _colour := Color.WHITE
var _font_size := 17
var _age := 0.0
var _rise := RISE
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 40
	queue_redraw()


func show_hit(amount: float, multiplier: float, absorbed: bool) -> void:
	_text = str(maxi(1, int(round(amount))))
	if absorbed:
		_colour = Color("9fb4c0")
		_font_size = 13
		_rise = RISE * 0.45
		if multiplier < 0.25:
			_text = "%s absorbed" % _text
	elif multiplier > 1.05:
		_colour = Color("ffd45e")
		_font_size = 20
	else:
		_colour = Color("f2f7fb")
		_font_size = 17
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFETIME
	position.y -= _rise * delta * (1.0 - t * 0.6)
	queue_redraw()
	if _age >= LIFETIME:
		queue_free()


func _draw() -> void:
	if _font == null:
		return
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	var col := _colour
	col.a = 1.0 - t * t
	var scale_pop := 1.0 + 0.35 * (1.0 - minf(1.0, t * 5.0))
	var width := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	# cheap outline so numbers stay readable over bright sand
	draw_string(_font, Vector2(-width * 0.5 + 1.5, 1.5), _text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_font_size * scale_pop, Color(0, 0, 0, col.a * 0.7))
	draw_string(_font, Vector2(-width * 0.5, 0.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_font_size * scale_pop, col)
