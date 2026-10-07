extends Control
## Reef health readout for the in-level HUD (W8).
##
## Code-drawn like hull_bar.gd and damage_vignette.gd, so there is no new asset
## to keep in sync. It draws the coral glyph, the bar itself, the restoration
## threshold marker and a small algae mat that retreats as the reef heals — the
## same visual language as the coral beds in the water
## (scenes/levels/reef_site.gd), so the meter and the reef clearly mean the same
## thing.
##
## Text is owned by level_hud (it keeps the labels); this only draws.

const TRACK := Color(0.02, 0.09, 0.15, 0.85)
const TRACK_EDGE := Color(0.45, 0.68, 0.80, 0.55)
const MAT := Color(0.18, 0.35, 0.17, 0.75)
const MARK := Color(0.92, 0.85, 0.55, 0.75)
## Where the bar starts for an island, drawn as a ghost so the player can see
## how far the reef has come since they arrived.
const BUCKET := 0.01

## Fraction of the reef's maximum where a dive counts as restored — mirrors
## ReefRestoration.THRIVING_ABOVE.
const RESTORED_MARK := 0.80

var _ratio := 0.45
var _start_ratio := 0.45
var _colour := Color("ffd45e")
var _bleached := false
var _time := 0.0
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_reef(ratio: float, start_ratio: float, colour: Color, bleached: bool) -> void:
	var next := clampf(ratio, 0.0, 1.0)
	var moved := absf(next - _ratio) >= BUCKET or bleached != _bleached \
			or absf(start_ratio - _start_ratio) >= BUCKET
	_ratio = next
	_start_ratio = clampf(start_ratio, 0.0, 1.0)
	_colour = colour
	_bleached = bleached
	if moved:
		queue_redraw()


## One-shot pop when the reef changes state, so a restore is felt, not read.
func pulse() -> void:
	_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.6)
		queue_redraw()
	elif _ratio > 0.0 and _ratio < 1.0:
		# slow breathing so the bar reads as alive even when nothing changes
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var bar := Rect2(0.0, h * 0.34, w, h * 0.42)
	# ---- track
	draw_rect(bar, TRACK, true)
	draw_rect(bar, TRACK_EDGE, false, 1.0)
	# ---- where this dive started
	var start_x := bar.position.x + bar.size.x * _start_ratio
	draw_line(Vector2(start_x, bar.position.y - 2.0), Vector2(start_x, bar.end.y + 2.0),
			Color(0.85, 0.90, 0.95, 0.35), 1.0)
	# ---- the health itself
	var fill := Rect2(bar.position, Vector2(bar.size.x * _ratio, bar.size.y))
	if fill.size.x > 0.5:
		var glow := 1.0 + 0.10 * sin(_time * 2.0) + _flash * 0.8
		draw_rect(fill, Color(_colour, 0.95 * minf(1.4, glow)), true)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.42)),
				Color(1, 1, 1, 0.20), true)
	# ---- the mat that is still smothering it
	if _ratio < 0.99:
		var mat_w := bar.size.x * (1.0 - _ratio) * 0.55
		draw_rect(Rect2(bar.end.x - mat_w, bar.position.y, mat_w, bar.size.y),
				Color(MAT, MAT.a * (1.0 - _ratio)), true)
	# ---- restoration threshold
	var mark_x := bar.position.x + bar.size.x * RESTORED_MARK
	draw_line(Vector2(mark_x, bar.position.y - 3.0), Vector2(mark_x, bar.end.y + 3.0), MARK, 1.4)
	_draw_glyph(Vector2(h * 0.42, h * 0.42), h * 0.30)
	draw_rect(bar, Color(_colour, 0.9) if _bleached else TRACK_EDGE, false, 1.0)


## A little coral head: it bleaches white and loses its polyps with the reef.
func _draw_glyph(centre: Vector2, r: float) -> void:
	var live := Color("ff7aa2").lerp(Color("f0ece2"), 1.0 - _ratio)
	draw_line(centre + Vector2(0, r * 0.9), centre + Vector2(0, -r * 0.2), live.darkened(0.25),
			maxf(1.6, r * 0.5), true)
	for i in range(3):
		var side := -1.0 if i == 0 else (1.0 if i == 1 else 0.0)
		var tip := centre + Vector2(side * r * 0.75, -r * (0.55 if side != 0.0 else 1.0))
		draw_line(centre + Vector2(0, -r * 0.2), tip, live, maxf(1.4, r * 0.36), true)
		if _ratio > 0.30:
			draw_circle(tip, maxf(1.2, r * 0.22), Color(1.0, 0.96, 0.78, _ratio))
