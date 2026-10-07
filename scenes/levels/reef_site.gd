extends Node2D
## One coral bed on the reef floor.
##
## It is an entity rather than baked floor art because its whole point is to
## change: the colour is driven live by the reef health in
## systems/reef_restoration.gd, so the player can see the coral they are saving.
##
## Cost shape (this matters — the first version drew the colony every frame and
## cost 2.7 ms/frame on its own):
##   * the colony itself is drawn by scenes/levels/reef_coral.gd into a
##     SubViewport and rendered as ONE sprite, re-baked only when the reef
##     crosses a visible health bucket — the same bake-once convention the world
##     map and the reef floor use
##   * only a handful of twinkle primitives live in the per-frame layer, and they
##     are the only thing that redraws (20 Hz, and only when the reef is thriving)
##
## A bed also hosts the planting action: level_base tells it when the sentinel is
## in range and how far through a planting it is, and plant() grows a real new
## head on the colony (re-baking once, so the cost stays one quad per frame).
##
## configure() must run BEFORE add_child() — the same trap the biome bug came from.

const ReefCoral := preload("res://scenes/levels/reef_coral.gd")

const BAKE_SCALE := 1.25        # crisper edges on the baked colony
const BAKE_PAD := 44.0          # room for branches poking past the radius
const FX_INTERVAL := 1.0 / 20.0
const BUCKET := 0.04            # re-bake when the visible colour actually moves

var reef_index := 0
var radius := 120.0
var _seed := 1
var _health := 0.45
var _time := 0.0
var _fx_timer := 0.0
var _bake: SubViewport
var _coral: Node2D
var _view: Sprite2D
var _fx: Node2D
# planting state, driven by level_base
var _in_range := false
var _planting := false
var _plant_progress := 0.0
var _just_planted := 0.0


func configure(index: int, centre: Vector2, size_px: float, seed_value: int) -> void:
	reef_index = index
	position = centre
	radius = size_px
	_seed = seed_value


func _ready() -> void:
	name = "ReefSite%d" % reef_index
	z_index = -6
	add_to_group("reef_site")
	_build_bake()
	_fx = Node2D.new()
	_fx.name = "ReefSiteFx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	set_process(true)
	queue_redraw()


# ================================================================ PUBLIC API

## 0.0 bleached, 1.0 fully restored. level_base pushes this every frame; the bake
## only runs when the visible colour has actually moved.
func set_health_ratio(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if absf(next - _health) < 0.005:
		return
	var moved_bucket := int(next / BUCKET) != int(_health / BUCKET)
	_health = next
	if moved_bucket:
		_rebake()


func health_ratio() -> float:
	return _health


func centre() -> Vector2:
	return position


func contains(point: Vector2) -> bool:
	return position.distance_to(point) <= radius


func fragment_count() -> int:
	return int(_coral.call("fragment_count"))


## The planting action, as this bed experiences it.
##   in_range  the sentinel is close enough to work here
##   planting  a planting is actually running
##   progress  0..1 through it
func set_plant_state(in_range: bool, planting: bool, progress: float) -> void:
	var changed := in_range != _in_range or planting != _planting or _fx == null
	_in_range = in_range
	_planting = planting
	_plant_progress = clampf(progress, 0.0, 1.0)
	if changed or planting:
		_fx.queue_redraw()


## Grow one head of coral on this bed. Returns the bed's total planted count.
func plant() -> int:
	_coral.call("add_fragment")
	_rebake()
	_just_planted = 1.0
	_fx.queue_redraw()
	return fragment_count()


# ================================================================ BAKE

func _build_bake() -> void:
	var span := radius * 2.0 + BAKE_PAD
	_coral = Node2D.new()
	_coral.name = "Coral"
	_coral.set_script(ReefCoral)
	_coral.call("configure", reef_index, radius, _seed)
	_coral.call("set_health", _health)
	# the colony is drawn around (0, 0), so park it in the middle of the bake
	_coral.position = Vector2(span, span) * 0.5

	_bake = SubViewport.new()
	_bake.name = "ReefBake"
	_bake.disable_3d = true
	_bake.transparent_bg = true
	_bake.size_2d_override_stretch = true
	_bake.size_2d_override = Vector2i(int(span), int(span))
	_bake.size = Vector2i((Vector2(span, span) * BAKE_SCALE).ceil())
	_bake.add_child(_coral)
	add_child(_bake)

	_view = Sprite2D.new()
	_view.name = "CoralBake"
	_view.texture = _bake.get_texture()
	_view.centered = true
	_view.scale = Vector2.ONE / BAKE_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_view)


func _rebake() -> void:
	_coral.call("set_health", _health)
	_bake.render_target_update_mode = SubViewport.UPDATE_ONCE


# ================================================================ LIVE LAYER

func _process(delta: float) -> void:
	_time += delta
	_fx_timer += delta
	if _just_planted > 0.0:
		_just_planted = maxf(0.0, _just_planted - delta * 1.2)
	if _fx != null and (_fx_timer >= FX_INTERVAL or _just_planted > 0.0):
		_fx_timer = 0.0
		_fx.queue_redraw()


## The planting feedback: a dashed ring when the sentinel is in range, a filling
## arc while a planting runs, and a burst when a head actually lands. When the
## reef is thriving, a few sparkles are added — this whole layer is a handful of
## primitives, and it is the only per-frame cost of a coral bed.
func _draw_fx() -> void:
	if _in_range:
		_draw_plant_ring()
	if _just_planted > 0.0:
		_draw_plant_burst()
	if _health <= 0.86:
		return
	var glow := (_health - 0.86) / 0.14
	_fx.draw_arc(Vector2.ZERO, radius * 0.92, 0.0, TAU, 32,
			Color(1.0, 0.94, 0.72, 0.18 * glow), 2.0)
	for i in range(6):
		var a := _time * 0.7 + TAU * float(i) / 6.0
		var p := Vector2(cos(a), sin(a) * 0.7) * radius * 0.55
		var twinkle := 0.5 + 0.5 * sin(_time * 3.0 + float(i) * 1.7)
		_fx.draw_circle(p, 2.2 + 1.4 * twinkle, Color(1.0, 0.98, 0.85, 0.55 * glow * twinkle))


## Solid ring = the bed is ready for you; the arc that fills it is the planting.
func _draw_plant_ring() -> void:
	var ring_r := radius * 1.02
	for i in range(28):
		if i % 2 == 0:
			continue
		var a0 := TAU * float(i) / 28.0
		var a1 := TAU * float(i + 1) / 28.0
		var alpha := 0.35 + 0.15 * sin(_time * 3.0)
		_fx.draw_arc(Vector2.ZERO, ring_r, a0, a1, 4, Color(0.72, 1.0, 0.85, alpha), 2.4, true)
	if not _planting:
		return
	# a bright sweep from the top, matching the HUD bar, so the two read as one act
	_fx.draw_arc(Vector2.ZERO, ring_r, -PI * 0.5, -PI * 0.5 + TAU * _plant_progress, 48,
			Color(1.0, 0.96, 0.72, 0.95), 4.0, true)
	var tip := Vector2(0.0, -ring_r).rotated(TAU * _plant_progress)
	_fx.draw_circle(tip, 6.0, Color(1.0, 0.99, 0.86, 0.9))
	_fx.draw_circle(tip, 3.0, Color(1, 1, 1, 0.95))


## New coral landing on the bed: a ring of polyps that expands and fades.
func _draw_plant_burst() -> void:
	var t := 1.0 - _just_planted
	var r := radius * (0.16 + 0.5 * t)
	_fx.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.92, 0.70, _just_planted * 0.8), 2.6, true)
	for i in range(9):
		var a := TAU * float(i) / 9.0 + t
		var p := Vector2(cos(a), sin(a) * 0.8) * r
		_fx.draw_circle(p, 3.0 + 2.0 * _just_planted, Color(1.0, 0.96, 0.80, _just_planted))
		_fx.draw_circle(p, 1.6, Color(0.55, 1.0, 0.80, _just_planted * 0.9))
