extends Control
## Screen-edge danger vignette (W5). Fills the viewport, draws a red edge glow
## whose intensity rises as the hull drops below 35%, plus a one-shot flash
## whenever the sentinel takes a hit. Purely a display of the frozen
## health_changed signal — it never changes gameplay.

const WARN_RATIO := 0.35
const CRITICAL_RATIO := 0.25
const CRITICAL_FLOOR := 0.55   # never let a critical hull read as "slightly warm"
const BANDS := 14
const MAX_THICKNESS := 132.0
const MAX_ALPHA := 0.42

var _target := 0.0
var _intensity := 0.0
var _flash := 0.0
var _time := 0.0
var _ratio := 1.0


func _ready() -> void:
	# Keep flat anchors and drive the rect ourselves: a Control added to a
	# CanvasLayer whose anchors are resolved before the first layout pass can end
	# up 0-sized, which silently draws nothing.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_size()
	set_process(true)


func _refresh_size() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var want := viewport.get_visible_rect().size
	if size != want:
		size = want


func set_health_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	_target = clampf((WARN_RATIO - _ratio) / WARN_RATIO, 0.0, 1.0)
	if _ratio <= CRITICAL_RATIO:
		_target = maxf(_target, CRITICAL_FLOOR)


func flash(strength: float = 1.0) -> void:
	_flash = maxf(_flash, clampf(strength, 0.0, 1.0))


func _process(delta: float) -> void:
	_time += delta
	_refresh_size()
	var dirty := false
	if absf(_intensity - _target) > 0.002:
		_intensity = lerpf(_intensity, _target, minf(1.0, 5.0 * delta))
		dirty = true
	elif _target > 0.0:
		_intensity = _target
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.6)
		dirty = true
	if _target > 0.0:
		dirty = true   # keep the pulse animating
	if dirty:
		queue_redraw()


func _draw() -> void:
	var view := size
	if view.x < 4.0 or view.y < 4.0:
		return
	if _intensity > 0.01:
		var pulse := 0.72 + 0.28 * sin(_time * 3.4)
		var strength := _intensity * pulse
		var thickness := MAX_THICKNESS * (0.55 + 0.45 * _intensity)
		for i in range(BANDS):
			var t := float(i) / float(BANDS)
			var alpha := (1.0 - t) * (1.0 - t) * MAX_ALPHA * strength
			if alpha <= 0.004:
				continue
			var band := thickness / float(BANDS)
			var off := t * thickness
			var col := Color(0.95, 0.16, 0.14, alpha)
			# four edge bands: top, bottom, left, right
			draw_rect(Rect2(Vector2(0, off), Vector2(view.x, band)), col, true)
			draw_rect(Rect2(Vector2(0, view.y - off - band), Vector2(view.x, band)), col, true)
			draw_rect(Rect2(Vector2(off, 0), Vector2(band, view.y)), col, true)
			draw_rect(Rect2(Vector2(view.x - off - band, 0), Vector2(band, view.y)), col, true)
	if _flash > 0.01:
		draw_rect(Rect2(Vector2.ZERO, view), Color(1.0, 0.25, 0.22, 0.28 * _flash), true)
