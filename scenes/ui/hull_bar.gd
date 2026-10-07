extends Control
## Hull-integrity bar (W5). Drawn entirely in code, like the rest of the UI.
##
## Driven ONLY by the frozen signal player.health_changed(current, max_health)
## (level_hud forwards it), so it needs no knowledge of weapons or enemies.
##
## Reads as a pressure hull rather than a progress bar: a chamfered frame, a
## segmented body, a tick every 10 HP, a lagging "damage ghost" that shows what
## was just lost, a white hit flash, a scanline wash and a red pulse when the
## hull is critical.

const BAR_SIZE := Vector2(268, 30)
const INK := Color("08192a")
const PLATE_DARK := Color("0b2233")
const PLATE_MID := Color("16405c")
const PLATE_LIGHT := Color("2a6a8e")
const GOOD := Color("35c98a")
const WARN := Color("ffd45e")
const BAD := Color("ff5a44")
const GHOST := Color("ffd9a8")
const TEXT := Color("eaf4fb")

const GHOST_DRAIN := 46.0   # hp per second the ghost lags behind
const FLASH_TIME := 0.32
const SEGMENTS := 8

var _current := 100.0
var _maximum := 100.0
var _ghost := 100.0
var _flash := 0.0
var _pulse := 0.0
var _ready_time := 0.0


func _ready() -> void:
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func set_health(current: int, maximum: int) -> void:
	var mx := maxf(1.0, float(maximum))
	var value := clampf(float(current), 0.0, mx)
	if value < _current:
		_flash = 1.0
		if _ghost < _current:
			_ghost = _current
	_current = value
	_maximum = mx
	if _ghost < _current:
		_ghost = _current
	queue_redraw()


func health_ratio() -> float:
	return clampf(_current / maxf(1.0, _maximum), 0.0, 1.0)


func state_label() -> String:
	var ratio := health_ratio()
	if _current <= 0.0:
		return "LOST"
	if ratio <= 0.25:
		return "CRITICAL"
	if ratio <= 0.5:
		return "STRAINED"
	return "HULL"


func state_colour() -> Color:
	var ratio := health_ratio()
	if ratio <= 0.25:
		return BAD
	if ratio <= 0.5:
		return WARN
	return GOOD


func _process(delta: float) -> void:
	_ready_time += delta
	var dirty := false
	if _ghost > _current + 0.01:
		_ghost = maxf(_current, _ghost - GHOST_DRAIN * delta)
		dirty = true
	elif _ghost < _current:
		_ghost = _current
		dirty = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta / FLASH_TIME)
		dirty = true
	if health_ratio() <= 0.25 and _current > 0.0:
		_pulse = fmod(_ready_time * 2.2, TAU)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var size_v := BAR_SIZE
	var chamfer := 7.0
	var outer := _chamfered(Rect2(Vector2.ZERO, size_v), chamfer)
	draw_colored_polygon(outer, INK)
	draw_polyline(_ring(outer), Color(0, 0, 0, 0.65), 2.0, true)

	# inner well the hull fluid sits in
	var inset := 3.0
	var well := _chamfered(Rect2(Vector2(inset, inset), size_v - Vector2(inset, inset) * 2.0), chamfer - 2.0)
	draw_colored_polygon(well, PLATE_DARK)

	var ratio := health_ratio()
	var ghost_ratio := clampf(_ghost / maxf(1.0, _maximum), 0.0, 1.0)
	var inner_x := inset + 2.0
	var inner_w := size_v.x - (inset + 2.0) * 2.0
	var inner_y := inset + 2.0
	var inner_h := size_v.y - (inset + 2.0) * 2.0

	# segment cells (read as pressure compartments)
	for i in range(SEGMENTS):
		var x := inner_x + inner_w * float(i) / float(SEGMENTS)
		var w := inner_w / float(SEGMENTS) - 1.6
		var cell := Rect2(Vector2(x, inner_y), Vector2(w, inner_h))
		var fill_ratio := (ghost_ratio - float(i) / float(SEGMENTS)) * float(SEGMENTS)
		var real_ratio := (ratio - float(i) / float(SEGMENTS)) * float(SEGMENTS)
		if fill_ratio > 0.0:
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, cell.size.y)), PLATE_MID, true)
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, cell.size.y * clampf(fill_ratio, 0.0, 1.0))), GHOST.darkened(0.35), true)
		if real_ratio > 0.0:
			var col := state_colour()
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, cell.size.y * clampf(real_ratio, 0.0, 1.0))), col, true)
			# glass highlight along the top of each filled cell
			var hi := clampf(real_ratio, 0.0, 1.0) * cell.size.y
			draw_rect(Rect2(cell.position + Vector2(1.0, 1.0), Vector2(cell.size.x - 2.0, minf(3.0, hi - 2.0))),
					Color(1, 1, 1, 0.28), true)
		draw_rect(Rect2(cell.position, cell.size), Color(0, 0, 0, 0.18), false, 1.0)

	# tick every 10 hp
	if _maximum >= 20.0:
		var ticks := int(_maximum / 10.0)
		for t in range(1, ticks):
			var x := inner_x + inner_w * float(t) / float(ticks)
			draw_line(Vector2(x, inner_y), Vector2(x, inner_y + inner_h), Color(0, 0, 0, 0.35), 1.0, true)
			draw_line(Vector2(x + 1.0, inner_y), Vector2(x + 1.0, inner_y + inner_h), Color(1, 1, 1, 0.10), 1.0, true)

	# scanline wash + frame plating
	for y in range(int(size_v.y), 0, -3):
		draw_line(Vector2(inset, float(y)), Vector2(size_v.x - inset, float(y)), Color(0, 0, 0, 0.06), 1.0)
	draw_polyline(_ring(well), PLATE_LIGHT, 1.6, true)

	# critical pulse
	if ratio <= 0.25 and _current > 0.0:
		var pulse_alpha := 0.28 + 0.30 * (0.5 + 0.5 * sin(_pulse))
		draw_polyline(_ring(outer), Color(BAD, pulse_alpha), 3.0, true)

	# one-shot hit flash
	if _flash > 0.0:
		draw_colored_polygon(well, Color(1, 1, 1, 0.55 * _flash))
		draw_polyline(_ring(outer), Color(1, 1, 1, 0.8 * _flash), 3.0, true)


func _chamfered(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	return PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c),
		Vector2(e.x, e.y - c), Vector2(e.x - c, e.y), Vector2(p.x + c, e.y),
		Vector2(p.x, e.y - c), Vector2(p.x, p.y + c),
	])


func _ring(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out
