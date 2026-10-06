extends Node2D
# C owns this file — the procedural reef floor for a dive level.
#
# Same convention as scenes/ui/world_map.gd: every piece of art is generated in
# code and baked ONCE into an off-screen texture, so a frame costs a single quad
# instead of thousands of draw calls. Tune the BIOME section; the rest is
# plumbing.

enum Biome { SHALLOW_REEF, KELP_BELT, VOLCANIC_VENTS }

const BAKE_SCALE := 1.5   # bake above arena resolution so outlines stay crisp
const RIM := 78.0         # dark open-water band kept inside the arena edge
const FLOOR_INSET := 26.0 # how far the sand floor sits inside the rock rim

# ================================================================ BIOME DATA
# Indexed by Biome. Adding a biome means adding one entry to each list.

const FLOOR_SAND := [
	Color("efdda6"),  # SHALLOW_REEF — bright sand
	Color("c6cba0"),  # KELP_BELT — olive silt
	Color("7a6c5e"),  # VOLCANIC_VENTS — dark gravel
]
const FLOOR_SHADE := [
	Color("d3b979"),
	Color("9fa877"),
	Color("584e45"),
]
const FLOOR_ACCENT := [
	Color("ffd75a"),  # sand ripple highlight
	Color("8fae5e"),  # algae bloom
	Color("e0662e"),  # lava glow
]

# ================================================================ PALETTE

const DEEP := Color("062a45")
const WATER := Color("0d3f65")
const SHELF := Color("17608f")
const SHELF_LIGHT := Color("2a86b8")
const INK := Color("33231a")
const ROCK := Color("b9b2a6")
const ROCK_DARK := Color("847b70")
const CORAL := [Color("ff7aa2"), Color("ffa04a"), Color("b98cff"), Color("ffd75a"), Color("ff6b6b")]
const KELP := Color("2f6e43")
const KELP_LIGHT := Color("57a05c")
const KELP_DARK := Color("1d4a2c")
const LAVA := Color("ff7a2e")
const LAVA_HOT := Color("ffd27a")
const ASH := Color("4a4038")
const CAUSTIC := Color(1, 1, 1, 0.05)
const SHADOW := Color(0.02, 0.10, 0.08, 0.22)

# ================================================================ STATE

var _biome := Biome.SHALLOW_REEF
var _arena := Vector2(1600, 900)
var _seed := 4242
var _noise := FastNoiseLite.new()

var _bake: SubViewport
var _art: Node2D
var _view: Sprite2D
var _fx: Node2D                    # animated layer: caustics + bubbles
var _time := 0.0

var _floor := PackedVector2Array() # sand polygon
var _rim := PackedVector2Array()   # rock band polygon
var _props: Array[Dictionary] = []
var _bubbles: Array[Vector3] = []  # x, y, phase
var _lights: Array[Vector3] = []   # x, y, phase


func configure(biome: int, arena: Vector2, seed_value: int) -> void:
	_biome = biome
	_arena = arena
	_seed = seed_value


func _ready() -> void:
	z_index = -10
	_noise.seed = _seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.035
	_noise.fractal_octaves = 3

	_build_geometry()
	_build_props()
	_build_particles()
	_bake_floor()

	_fx = Node2D.new()
	_fx.name = "ReefFx"
	_fx.z_index = -8
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _process(delta: float) -> void:
	_time += delta
	if _fx:
		_fx.queue_redraw()


# ================================================================ GEOMETRY

func _build_geometry() -> void:
	# Rock rim: a rounded-rect ring that reads as the wall of the dive site.
	var outer := _roughen(_rounded_rect(Rect2(Vector2(RIM, RIM), _arena - Vector2(RIM, RIM) * 2.0), 120.0, 96), 9.0, 3.0)
	_rim = outer
	# Sand floor sits inside the rim.
	_floor = _roughen(_rounded_rect(Rect2(Vector2(RIM + FLOOR_INSET, RIM + FLOOR_INSET),
			_arena - Vector2(RIM + FLOOR_INSET, RIM + FLOOR_INSET) * 2.0), 108.0, 88), 7.0, 9.0)


func _rounded_rect(rect: Rect2, radius: float, segments: int) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(r, r), PI, PI * 1.5],
		[rect.position + Vector2(rect.size.x - r, r), PI * 1.5, TAU],
		[rect.position + rect.size - Vector2(r, r), 0.0, PI * 0.5],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5, PI],
	]
	var per := maxi(4, segments / 4)
	for c: Array in corners:
		var centre: Vector2 = c[0]
		var a0: float = c[1]
		var a1: float = c[2]
		for i in range(per):
			var a := lerpf(a0, a1, float(i) / float(per))
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


func _roughen(pts: PackedVector2Array, amount: float, phase: float) -> PackedVector2Array:
	# Seamless wobble: sample looping noise around the path so ends still meet.
	var n := pts.size()
	var total := 0.0
	for i in range(n):
		total += pts[i].distance_to(pts[(i + 1) % n])
	var radius := maxf(1.0, total / TAU)
	var out := PackedVector2Array()
	var dist := 0.0
	for i in range(n):
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var a := dist / radius
		var t := (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized()
		var nrm := Vector2(t.y, -t.x)
		out.append(pts[i] + nrm * _noise.get_noise_3d(cos(a) * radius, sin(a) * radius, phase * 91.0) * amount)
	return out


# ================================================================ PROPS

func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var inner := Rect2(Vector2(RIM + FLOOR_INSET + 40.0, RIM + FLOOR_INSET + 40.0),
			_arena - Vector2(RIM + FLOOR_INSET + 40.0, RIM + FLOOR_INSET + 40.0) * 2.0)

	match _biome:
		Biome.SHALLOW_REEF:
			# Dense coral gardens, a few rocks, open sand between them.
			for _i in range(96):
				var p := _pick(rng, inner)
				if not Geometry2D.is_point_in_polygon(p, _floor):
					continue
				_props.append({"kind": "coral", "p": p, "s": rng.randf_range(11.0, 24.0),
						"tint": rng.randf(), "y": p.y})
			for _i in range(26):
				var p := _pick(rng, inner)
				if Geometry2D.is_point_in_polygon(p, _floor):
					_props.append({"kind": "anemone", "p": p, "s": rng.randf_range(7.0, 12.0),
							"tint": rng.randf(), "y": p.y})
			for _i in range(18):
				var p := _pick(rng, inner)
				if Geometry2D.is_point_in_polygon(p, _floor):
					_props.append({"kind": "rock", "p": p, "s": rng.randf_range(9.0, 18.0), "y": p.y})
		Biome.KELP_BELT:
			# Tall kelp groves with rocks between them.
			for _i in range(22):
				var centre := _pick(rng, inner)
				if not Geometry2D.is_point_in_polygon(centre, _floor):
					continue
				for _k in range(rng.randi_range(5, 11)):
					var p := centre + Vector2(rng.randf_range(-105.0, 105.0), rng.randf_range(-78.0, 78.0))
					if Geometry2D.is_point_in_polygon(p, _floor):
						_props.append({"kind": "kelp", "p": p, "s": rng.randf_range(38.0, 82.0),
								"tint": rng.randf(), "y": p.y})
			for _i in range(30):
				var p := _pick(rng, inner)
				if Geometry2D.is_point_in_polygon(p, _floor):
					_props.append({"kind": "rock", "p": p, "s": rng.randf_range(10.0, 22.0), "y": p.y})
			for _i in range(20):
				var p := _pick(rng, inner)
				if Geometry2D.is_point_in_polygon(p, _floor):
					_props.append({"kind": "anemone", "p": p, "s": rng.randf_range(6.0, 10.0),
							"tint": rng.randf(), "y": p.y})
		Biome.VOLCANIC_VENTS:
			# Smoking vents, ash flats, jagged rock.
			for _i in range(12):
				var p := _pick(rng, inner)
				if Geometry2D.is_point_in_polygon(p, _floor):
					_props.append({"kind": "vent", "p": p, "s": rng.randf_range(20.0, 34.0), "y": p.y})
			for _i in range(54):
				var p := _pick(rng, inner)
				if Geometry2D.is_point_in_polygon(p, _floor):
					_props.append({"kind": "rock", "p": p, "s": rng.randf_range(11.0, 26.0), "y": p.y})
			for _i in range(16):
				var p := _pick(rng, inner)
				if Geometry2D.is_point_in_polygon(p, _floor):
					_props.append({"kind": "coral", "p": p, "s": rng.randf_range(8.0, 16.0),
							"tint": rng.randf(), "y": p.y})

	# Keep the centre open so the player always has room to spawn and fight.
	var centre := _arena * 0.5
	var keep_out := 190.0
	var kept: Array[Dictionary] = []
	for prop: Dictionary in _props:
		if (prop["p"] as Vector2).distance_to(centre) > keep_out:
			kept.append(prop)
	_props = kept
	_props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["y"] < b["y"])


func _pick(rng: RandomNumberGenerator, box: Rect2) -> Vector2:
	return Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))


func _build_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 77
	var inner := Rect2(Vector2(RIM, RIM), _arena - Vector2(RIM, RIM) * 2.0)
	for _i in range(34):
		var p := _pick(rng, inner)
		_bubbles.append(Vector3(p.x, p.y, rng.randf() * TAU))
	for _i in range(6):
		var p := _pick(rng, inner)
		_lights.append(Vector3(p.x, p.y, rng.randf() * TAU))


# ================================================================ BAKE

func _bake_floor() -> void:
	_art = Node2D.new()
	_art.name = "ReefArt"
	_art.draw.connect(_draw_floor)

	_bake = SubViewport.new()
	_bake.name = "ReefBake"
	_bake.disable_3d = true
	_bake.transparent_bg = false
	_bake.size_2d_override = Vector2i(_arena)
	_bake.size_2d_override_stretch = true
	_bake.size = Vector2i((_arena * BAKE_SCALE).ceil())
	_bake.add_child(_art)
	add_child(_bake)

	_view = Sprite2D.new()
	_view.name = "ReefArtView"
	_view.texture = _bake.get_texture()
	_view.centered = false
	_view.scale = Vector2.ONE / BAKE_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.z_index = -9
	add_child(_view)

	_art.queue_redraw()
	_bake.render_target_update_mode = SubViewport.UPDATE_ONCE


# ================================================================ DRAW: STATIC

func _draw_floor() -> void:
	var ci := _art
	# open water, then the lighter shelf ring around the dive site
	ci.draw_rect(Rect2(-200, -200, _arena.x + 400, _arena.y + 400), DEEP)
	ci.draw_colored_polygon(_rim, WATER)
	_fill(ci, _grow(_rim, -18.0), SHELF)
	_fill(ci, _grow(_rim, -46.0), SHELF_LIGHT)

	# rock rim band
	_fill(ci, _rim, ROCK_DARK)
	_outline(ci, _rim, INK, 3.0)
	_draw_rim_rocks(ci)

	# sand floor
	_fill(ci, _floor, FLOOR_SAND[_biome])
	_outline(ci, _floor, FLOOR_SHADE[_biome], 3.0)

	_draw_zones(ci)
	_draw_floor_detail(ci)
	for prop: Dictionary in _props:
		_draw_prop(ci, prop)


func _draw_rim_rocks(ci: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 41
	var n := _rim.size()
	for i in range(n):
		var p := _rim[i]
		if rng.randf() > 0.10:
			continue
		var t := (_rim[(i + 1) % n] - _rim[(i - 1 + n) % n]).normalized()
		var outward := Vector2(t.y, -t.x)
		var s := rng.randf_range(14.0, 30.0)
		var base := p + outward * rng.randf_range(6.0, 26.0)
		var pts := PackedVector2Array([base + Vector2(-s, 0), base + Vector2(-s * 0.6, -s * 0.8),
				base + Vector2(s * 0.3, -s * 1.05), base + Vector2(s, 0)])
		ci.draw_colored_polygon(pts, ROCK)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(s * 0.3, -s * 1.05), base + Vector2(s, 0),
				base + Vector2(0, 0)]), ROCK_DARK)
		ci.draw_polyline(_closed(pts), INK, 2.0, true)


func _draw_zones(ci: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 13
	match _biome:
		Biome.SHALLOW_REEF:
			# sunlit patches on the sand
			for _i in range(7):
				var c := _pick(rng, Rect2(Vector2(240, 200), _arena - Vector2(480, 400)))
				_fill(ci, _blob(c, Vector2(rng.randf_range(80.0, 150.0), rng.randf_range(50.0, 90.0)),
						_seed + int(c.x), 32), Color(FLOOR_ACCENT[0], 0.18))
		Biome.KELP_BELT:
			# algae drift beds
			for _i in range(6):
				var c := _pick(rng, Rect2(Vector2(240, 200), _arena - Vector2(480, 400)))
				_fill(ci, _clip(_blob(c, Vector2(rng.randf_range(110.0, 190.0), rng.randf_range(60.0, 100.0)),
						_seed + int(c.y), 30), _floor), Color(FLOOR_ACCENT[1], 0.35))
		Biome.VOLCANIC_VENTS:
			# scorched ash flats
			for _i in range(6):
				var c := _pick(rng, Rect2(Vector2(240, 200), _arena - Vector2(480, 400)))
				var ash := _clip(_blob(c, Vector2(rng.randf_range(100.0, 170.0), rng.randf_range(60.0, 110.0)),
						_seed + int(c.x), 30), _floor)
				_fill(ci, ash, Color(ASH, 0.55))
			for _i in range(3):
				var c := _pick(rng, Rect2(Vector2(300, 260), _arena - Vector2(600, 520)))
				var glow := _clip(_blob(c, Vector2(46.0, 30.0), _seed + int(c.y), 24), _floor)
				_fill(ci, glow, Color(FLOOR_ACCENT[2], 0.35))
				_fill(ci, _grow(glow, -10.0), Color(LAVA, 0.55))


func _draw_floor_detail(ci: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 29
	var safe := _grow(_floor, -46.0)
	# sand ripples / gravel speckle
	for _i in range(300):
		var p := _pick(rng, Rect2(Vector2(RIM, RIM), _arena - Vector2(RIM, RIM) * 2.0))
		if not Geometry2D.is_point_in_polygon(p, safe):
			continue
		match _biome:
			Biome.SHALLOW_REEF:
				ci.draw_arc(p, rng.randf_range(9.0, 20.0), PI * 1.15, PI * 1.85, 8,
						Color(FLOOR_SHADE[_biome], 0.55), 1.6, true)
			Biome.KELP_BELT:
				ci.draw_line(p, p + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-5.0, 5.0)),
						Color(KELP_DARK, 0.35), 1.4, true)
			Biome.VOLCANIC_VENTS:
				ci.draw_circle(p, rng.randf_range(1.4, 3.2), Color(ROCK_DARK, 0.5))


func _draw_prop(ci: CanvasItem, d: Dictionary) -> void:
	var p: Vector2 = d["p"]
	match d["kind"]:
		"coral":
			_draw_coral(ci, p, d["s"], d["tint"])
		"kelp":
			_draw_kelp(ci, p, d["s"], d["tint"])
		"rock":
			_draw_rock(ci, p, d["s"])
		"anemone":
			_draw_anemone(ci, p, d["s"], d["tint"])
		"vent":
			_draw_vent(ci, p, d["s"])


func _shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	ci.draw_circle(Vector2.ZERO, rx, SHADOW)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_coral(ci: CanvasItem, p: Vector2, s: float, tint: float) -> void:
	var col: Color = CORAL[int(tint * CORAL.size()) % CORAL.size()]
	_shadow(ci, p + Vector2(s * 0.3, 1.0), s * 0.95, s * 0.34)
	# a few branching lobes
	for k in range(3):
		var a := -PI * 0.5 + (k - 1) * 0.5
		var tip := p + Vector2(cos(a), sin(a)) * s * rng_branch(tint, k)
		var mid := p.lerp(tip, 0.55) + Vector2((k - 1) * s * 0.16, 0)
		ci.draw_polyline(PackedVector2Array([p, mid, tip]), col, s * 0.34, true)
		ci.draw_circle(tip, s * 0.20, col.lightened(0.25))
	ci.draw_circle(p, s * 0.26, col.darkened(0.2))
	ci.draw_circle(p, s * 0.18, col)


func rng_branch(tint: float, k: int) -> float:
	return 1.0 + fmod(tint * 7.0 + float(k) * 0.37, 0.45)


func _draw_kelp(ci: CanvasItem, p: Vector2, s: float, tint: float) -> void:
	var col: Color = KELP.lerp(KELP_LIGHT, tint * 0.7)
	_shadow(ci, p + Vector2(4.0, 1.0), s * 0.22, s * 0.09)
	var blades := 3
	for b in range(blades):
		var lean := (float(b) - float(blades - 1) * 0.5) * s * 0.22
		var tip := p + Vector2(lean * 2.4, -s)
		var mid := p.lerp(tip, 0.5) + Vector2(lean * 0.6, 0)
		ci.draw_polyline(PackedVector2Array([p, mid, tip]), col, s * 0.09 + 2.0, true)
		# leaf pairs
		for l in range(1, 4):
			var t := float(l) / 4.0
			var q := p.lerp(tip, t)
			var w := s * 0.20 * (1.0 - t * 0.4)
			ci.draw_line(q, q + Vector2(-w, -w * 0.5), col.darkened(0.15), 2.2, true)
			ci.draw_line(q, q + Vector2(w, -w * 0.5), col.darkened(0.15), 2.2, true)
	ci.draw_circle(p, 3.0, KELP_DARK)


func _draw_rock(ci: CanvasItem, p: Vector2, s: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-s, 0), p + Vector2(-s * 0.65, -s * 0.75),
			p + Vector2(-s * 0.05, -s * 1.05), p + Vector2(s * 0.62, -s * 0.6), p + Vector2(s, 0)])
	_shadow(ci, p + Vector2(s * 0.3, 1.0), s * 1.05, s * 0.3)
	ci.draw_colored_polygon(pts, ROCK)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.05, -s * 1.05), p + Vector2(s * 0.62, -s * 0.6),
			p + Vector2(s, 0), p + Vector2(0, 0)]), ROCK_DARK)
	ci.draw_polyline(_closed(pts), INK, 2.0, true)


func _draw_anemone(ci: CanvasItem, p: Vector2, s: float, tint: float) -> void:
	var col: Color = CORAL[(int(tint * 5.0) + 2) % CORAL.size()]
	_shadow(ci, p + Vector2(2.0, 1.0), s * 0.7, s * 0.26)
	ci.draw_circle(p, s * 0.34, col.darkened(0.25))
	for k in range(9):
		var a := -PI * 0.5 + (float(k) - 4.0) * 0.34
		var tip := p + Vector2(cos(a), sin(a)) * s
		ci.draw_line(p, tip, col, 2.4, true)
		ci.draw_circle(tip, 1.9, col.lightened(0.2))


func _draw_vent(ci: CanvasItem, p: Vector2, s: float) -> void:
	_shadow(ci, p + Vector2(s * 0.2, 1.0), s * 1.1, s * 0.34)
	var cone := PackedVector2Array([p + Vector2(-s, 0), p + Vector2(-s * 0.24, -s),
			p + Vector2(s * 0.24, -s), p + Vector2(s, 0)])
	ci.draw_colored_polygon(cone, Color("4a4038"))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(s * 0.24, -s),
			p + Vector2(s, 0)]), Color("332c26"))
	ci.draw_set_transform(p + Vector2(0, -s), 0.0, Vector2(1.0, 0.34))
	ci.draw_circle(Vector2.ZERO, s * 0.24, Color(LAVA, 0.9))
	ci.draw_circle(Vector2.ZERO, s * 0.14, LAVA_HOT)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_polyline(_closed(cone), INK, 2.2, true)


# ================================================================ DRAW: ANIMATED

func _draw_fx() -> void:
	var ci := _fx
	# drifting light shafts
	for l in _lights:
		var x := l.x + sin(_time * 0.25 + l.z) * 40.0
		var a := 0.05 + 0.03 * sin(_time * 0.5 + l.z)
		var shaft := PackedVector2Array([Vector2(x - 40.0, 0), Vector2(x - 10.0, 0),
				Vector2(x + 90.0, _arena.y), Vector2(x + 30.0, _arena.y)])
		ci.draw_colored_polygon(shaft, Color(1, 1, 1, a))
	# rising bubbles
	for b in _bubbles:
		var t := fmod(_time * 0.16 + b.z, 1.0)
		var y := _arena.y - t * _arena.y
		var x := b.x + sin(t * 6.0 + b.z) * 12.0
		var a := (1.0 - t) * minf(t * 8.0, 1.0) * 0.5
		ci.draw_circle(Vector2(x, y), 2.0 + t * 3.0, Color(0.85, 0.96, 1.0, a))
	# vent smoke on the volcanic site
	if _biome == Biome.VOLCANIC_VENTS:
		for prop: Dictionary in _props:
			if prop["kind"] != "vent":
				continue
			var p: Vector2 = prop["p"]
			var s: float = prop["s"]
			for k in range(4):
				var t := fmod(_time * 0.22 + float(k) / 4.0 + p.x * 0.001, 1.0)
				var q := p + Vector2(sin(t * 5.0 + float(k)) * 10.0, -s - t * 90.0)
				var a := (1.0 - t) * minf(t * 6.0, 1.0) * 0.35
				ci.draw_circle(q, 5.0 + t * 13.0, Color(0.75, 0.72, 0.7, a))


# ================================================================ HELPERS

func _fill(ci: CanvasItem, poly: PackedVector2Array, col: Color, soft_edge: bool = true) -> void:
	if poly.size() < 3:
		return
	ci.draw_colored_polygon(poly, col)
	if soft_edge:
		ci.draw_polyline(_closed(poly), col, 1.0, true)


func _outline(ci: CanvasItem, poly: PackedVector2Array, col: Color, width: float) -> void:
	if poly.size() >= 3:
		ci.draw_polyline(_closed(poly), col, width, true)


func _blob(center: Vector2, radius: Vector2, seed_value: int, count: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var pts := PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var w := 1.0 + 0.12 * sin(a * 2.0 + p1) + 0.07 * sin(a * 3.0 + p2) + 0.04 * sin(a * 5.0 + p3)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * w)
	return pts


func _grow(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	var out := Geometry2D.offset_polygon(poly, delta, Geometry2D.JOIN_ROUND)
	return _biggest(out)


func _clip(poly: PackedVector2Array, inside: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3 or inside.size() < 3:
		return PackedVector2Array()
	return _biggest(Geometry2D.intersect_polygons(poly, inside))


func _biggest(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	for p in polys:
		var a := absf(_area(p))
		if a > best_area:
			best_area = a
			best = p
	return best


func _area(pts: PackedVector2Array) -> float:
	if pts.size() < 3:
		return 0.0
	var a := 0.0
	for i in range(pts.size()):
		a += pts[i].cross(pts[(i + 1) % pts.size()])
	return a * 0.5


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	if poly.size() > 0:
		out.append(poly[0])
	return out


## Solid rectangles that block the player, one per arena wall.
func wall_rects() -> Array[Rect2]:
	var t := 40.0
	var inner := Rect2(Vector2(RIM + FLOOR_INSET, RIM + FLOOR_INSET),
			_arena - Vector2(RIM + FLOOR_INSET, RIM + FLOOR_INSET) * 2.0)
	return [
		Rect2(inner.position.x - t, inner.position.y - t, inner.size.x + t * 2.0, t),
		Rect2(inner.position.x - t, inner.end.y, inner.size.x + t * 2.0, t),
		Rect2(inner.position.x - t, inner.position.y - t, t, inner.size.y + t * 2.0),
		Rect2(inner.end.x, inner.position.y - t, t, inner.size.y + t * 2.0),
	]


## Points on the floor where a wave can drop enemies, kept away from the centre.
func spawn_points(count: int, rng_seed: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var out: Array[Vector2] = []
	var centre := _arena * 0.5
	var safe := _grow(_floor, -70.0)
	var tries := 0
	while out.size() < count and tries < count * 60:
		tries += 1
		var p := _pick(rng, Rect2(Vector2(RIM, RIM), _arena - Vector2(RIM, RIM) * 2.0))
		if not Geometry2D.is_point_in_polygon(p, safe):
			continue
		if p.distance_to(centre) < 340.0:
			continue
		var clear := true
		for q in out:
			if q.distance_to(p) < 120.0:
				clear = false
				break
		if clear:
			out.append(p)
	return out
