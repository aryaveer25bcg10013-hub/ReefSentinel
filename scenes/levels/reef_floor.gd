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

# Far-field backdrop per biome: the shelf band behind the dive site and the
# colour the distant reef silhouettes are painted in.
const COLOR_SHELF_FAR := [
	Color("1d5f86"),  # SHALLOW_REEF
	Color("17492f"),  # KELP_BELT
	Color("3a2029"),  # VOLCANIC_VENTS
]
const COLOR_SILHOUETTE := [
	Color("b6d6d2"),
	Color("7fb877"),
	Color("8a4030"),
]

# ================================================================ ZONES
# Named regions of the dive site. Waves pick a zone per spawn, and species have
# a home zone per island, so different species arrive from different directions.
# Rules that keep this honest:
#   * every zone is a disc inside the arena,
#   * points inside a zone must still satisfy the floor/centre/obstacle rules,
#   * species are only *weighted* towards their home, never restricted to it.

const ZONES := {
	Biome.SHALLOW_REEF: [
		{"id": "open_water", "centre": Vector2(800, 450), "radius": 640.0},
		{"id": "coral_shelf", "centre": Vector2(400, 280), "radius": 250.0},
		{"id": "sand_bar", "centre": Vector2(1210, 630), "radius": 250.0},
		{"id": "channel", "centre": Vector2(1240, 250), "radius": 240.0},
	],
	Biome.KELP_BELT: [
		{"id": "open_water", "centre": Vector2(800, 450), "radius": 640.0},
		{"id": "wreck_shallows", "centre": Vector2(1180, 300), "radius": 240.0},
		{"id": "kelp_trench", "centre": Vector2(400, 650), "radius": 250.0},
		{"id": "channel", "centre": Vector2(1250, 640), "radius": 240.0},
	],
	Biome.VOLCANIC_VENTS: [
		{"id": "open_water", "centre": Vector2(800, 450), "radius": 640.0},
		{"id": "vent_field", "centre": Vector2(400, 280), "radius": 250.0},
		{"id": "bone_flats", "centre": Vector2(1210, 270), "radius": 250.0},
		{"id": "ridge_ruins", "centre": Vector2(400, 660), "radius": 250.0},
		{"id": "ash_drift", "centre": Vector2(1210, 660), "radius": 250.0},
	],
}

# ================================================================ OBSTACLES
# Real level design: solid shapes the player AND the enemies collide with.
# All convex on purpose — a concave pocket narrower than the enemy body is the
# soft-lock bug class this project already paid for once.

const OBSTACLES := {
	Biome.SHALLOW_REEF: [
		{"kind": "bombie", "pos": Vector2(320, 240), "r": 66.0},
		{"kind": "bombie", "pos": Vector2(1280, 240), "r": 66.0},
		{"kind": "bombie", "pos": Vector2(320, 660), "r": 60.0},
		{"kind": "arch", "pos": Vector2(1260, 660), "size": Vector2(150, 92)},
		{"kind": "sandbar", "pos": Vector2(590, 470), "size": Vector2(230, 56)},
		{"kind": "rock", "pos": Vector2(1010, 610), "r": 58.0},
		{"kind": "bombie", "pos": Vector2(1060, 300), "r": 54.0},
	],
	Biome.KELP_BELT: [
		{"kind": "wreck", "pos": Vector2(1180, 300), "size": Vector2(230, 104)},
		{"kind": "wreck", "pos": Vector2(300, 430), "size": Vector2(190, 74)},
		{"kind": "rock", "pos": Vector2(700, 230), "r": 62.0},
		{"kind": "rock", "pos": Vector2(900, 680), "r": 62.0},
		{"kind": "rock", "pos": Vector2(660, 470), "r": 58.0},
		{"kind": "wreck", "pos": Vector2(1310, 470), "size": Vector2(110, 80)},
	],
	Biome.VOLCANIC_VENTS: [
		{"kind": "ridge", "pos": Vector2(620, 470), "size": Vector2(200, 52)},
		{"kind": "ridge", "pos": Vector2(1000, 470), "size": Vector2(200, 52)},
		{"kind": "rock", "pos": Vector2(300, 240), "r": 60.0},
		{"kind": "rock", "pos": Vector2(1300, 240), "r": 60.0},
		{"kind": "rock", "pos": Vector2(300, 660), "r": 60.0},
		{"kind": "rock", "pos": Vector2(1300, 660), "r": 60.0},
		{"kind": "ridge", "pos": Vector2(800, 190), "size": Vector2(150, 48)},
	]}

# Kelp slows and hides (non-solid); geysers erupt on a timed cycle and hurt the
# sentinel — the invasives are natives here and ignore them.
const SLOW_FIELDS := {
	Biome.SHALLOW_REEF: [],
	Biome.KELP_BELT: [
		{"pos": Vector2(400, 660), "r": 250.0, "factor": 0.62},
		{"pos": Vector2(860, 470), "r": 200.0, "factor": 0.74},
	],
	Biome.VOLCANIC_VENTS: [],
}
const HAZARDS := {
	Biome.SHALLOW_REEF: [],
	Biome.KELP_BELT: [],
	Biome.VOLCANIC_VENTS: [
		{"kind": "geyser", "pos": Vector2(800, 240), "r": 74.0},
		{"kind": "geyser", "pos": Vector2(800, 690), "r": 74.0},
	],
}

const SPAWN_MIN_CENTRE_DIST := 340.0
const SPAWN_CLEARANCE := 34.0   # enemy body radius 14 + margin
const ZONE_POOL_SIZE := 26
const GEYSER_PERIOD := 4.2
const GEYSER_WARN := 1.1
const FX_INTERVAL := 1.0 / 30.0
const MOTE_COUNT := 48

# ================================================================ STATE

var _biome := Biome.SHALLOW_REEF
var _arena := Vector2(1600, 900)
var _seed := 4242
var _noise := FastNoiseLite.new()

var _obstacles: Array[Dictionary] = []
var _zone_defs: Array[Dictionary] = []
var _zone_pools: Dictionary = {}      # zone id -> Array[Vector2]
var _zone_cursors: Dictionary = {}    # zone id -> int
var _slow_fields: Array[Dictionary] = []
var _hazards: Array[Dictionary] = []
var _shoals: Array[Dictionary] = []
var _motes: Array[Vector3] = []       # x, y, phase (drifting particulate)
var _hurt_cooldown := 0.0
var _fx_timer := 0.0

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

	add_to_group("reef_floor")
	_build_geometry()
	_build_props()
	_build_obstacles()
	_build_particles()
	_build_zone_data()
	_bake_floor()

	_fx = Node2D.new()
	_fx.name = "ReefFx"
	_fx.z_index = -8
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _process(delta: float) -> void:
	_time += delta
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	_erupt_hazards()
	# The animated layer is a few hundred primitives; 30 Hz is plenty for slow
	# particulate and shafts, and halves its CPU cost during a big wave.
	_fx_timer += delta
	if _fx != null and _fx_timer >= FX_INTERVAL:
		_fx_timer = 0.0
		_fx.queue_redraw()


# ================================================================ OBSTACLES / HAZARDS

func _build_obstacles() -> void:
	_obstacles.clear()
	var defs: Array = OBSTACLES.get(_biome, [])
	for d: Dictionary in defs:
		var entry := d.duplicate()
		if not entry.has("r"):
			entry["r"] = maxf((entry["size"] as Vector2).x, (entry["size"] as Vector2).y) * 0.5
		_obstacles.append(entry)
	_slow_fields.clear()
	for s: Dictionary in SLOW_FIELDS.get(_biome, []):
		_slow_fields.append(s.duplicate())
	_hazards.clear()
	for h: Dictionary in HAZARDS.get(_biome, []):
		var entry := h.duplicate()
		entry["phase"] = randf() * GEYSER_PERIOD
		_hazards.append(entry)
	# Background shoals that scatter when the sentinel swims through them.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 313
	for _i in range(4):
		var c := _pick(rng, Rect2(Vector2(300, 220), _arena - Vector2(600, 440)))
		_shoals.append({"centre": c, "phase": rng.randf() * TAU,
				"tint": rng.randf(), "flee": Vector2.ZERO})


## Solid shapes the level turns into StaticBody2D collision. Convex circles and
## rectangles only.
func obstacles() -> Array[Dictionary]:
	return _obstacles.duplicate()


func hazard_list() -> Array[Dictionary]:
	return _hazards.duplicate()


## Speed multiplier for a point (kelp hides and slows). 1.0 = unaffected.
func slow_factor_at(p: Vector2) -> float:
	var factor := 1.0
	for s: Dictionary in _slow_fields:
		if p.distance_to(s["pos"]) <= s["r"]:
			factor = minf(factor, float(s["factor"]))
	return factor


func _erupt_hazards() -> void:
	if _hazards.is_empty():
		return
	if _hurt_cooldown > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for h: Dictionary in _hazards:
		var t := fmod(_time + float(h["phase"]), GEYSER_PERIOD)
		if t > GEYSER_WARN * 0.5:
			continue
		if player.global_position.distance_to(h["pos"]) <= float(h["r"]):
			_hurt_cooldown = 1.0
			if player.has_method("take_health_damage"):
				player.take_health_damage(8.0)
			return


## Is this a legal place to drop an enemy? Inside the sand, clear of the arena
## centre (so nothing lands on the player) and clear of every solid.
func is_spawn_clear(p: Vector2, require_centre_distance: bool = true) -> bool:
	var safe := _grow(_floor, -60.0)
	if safe.size() < 3 or not Geometry2D.is_point_in_polygon(p, safe):
		return false
	if require_centre_distance and p.distance_to(_arena * 0.5) < SPAWN_MIN_CENTRE_DIST:
		return false
	for o: Dictionary in _obstacles:
		var pos: Vector2 = o["pos"]
		if o.has("size"):
			var half: Vector2 = (o["size"] as Vector2) * 0.5 + Vector2.ONE * SPAWN_CLEARANCE
			if absf(p.x - pos.x) <= half.x and absf(p.y - pos.y) <= half.y:
				return false
		elif p.distance_to(pos) <= float(o["r"]) + SPAWN_CLEARANCE:
			return false
	return true


# ================================================================ ZONES

func zone_ids() -> Array[String]:
	var out: Array[String] = []
	for z: Dictionary in _zone_defs:
		out.append(String(z["id"]))
	return out


func _build_zone_data() -> void:
	_zone_defs = []
	_zone_pools = {}
	_zone_cursors = {}
	var defs: Array = ZONES.get(_biome, ZONES[Biome.SHALLOW_REEF])
	var zone_rng := RandomNumberGenerator.new()
	zone_rng.seed = _seed + 909
	for d: Dictionary in defs:
		var zone := d.duplicate()
		_zone_defs.append(zone)
		var pool: Array[Vector2] = []
		var centre: Vector2 = zone["centre"]
		var radius: float = zone["radius"]
		var tries := 0
		while pool.size() < ZONE_POOL_SIZE and tries < ZONE_POOL_SIZE * 120:
			tries += 1
			var a := zone_rng.randf() * TAU
			var rr := sqrt(zone_rng.randf()) * radius
			var p := centre + Vector2(cos(a), sin(a)) * rr
			var inside := Rect2(Vector2(RIM, RIM), _arena - Vector2(RIM, RIM) * 2.0)
			if not inside.has_point(p):
				continue
			if not is_spawn_clear(p):
				continue
			var clear := true
			for q in pool:
				if q.distance_to(p) < 100.0:
					clear = false
					break
			if clear:
				pool.append(p)
		_zone_pools[String(zone["id"])] = pool
		_zone_cursors[String(zone["id"])] = 0


## Zone descriptors for the wave manager: id, label, centre, radius and a
## pre-validated pool of spawn points inside the zone.
## Every declared zone is reported, even one whose pool came up empty: the wave
## manager and the audit must agree on the zone list, otherwise a species' home
## zone would silently fall back to another region.
func spawn_zones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for zone: Dictionary in _zone_defs:
		var id := String(zone["id"])
		var pool: Array = _zone_pools.get(id, [])
		out.append({
			"id": id,
			"label": _zone_label(id),
			"centre": zone["centre"],
			"radius": zone["radius"],
			"points": pool,
		})
	return out


func zone_spawn_point(zone_id: String, jitter: float = 0.0) -> Vector2:
	var pool: Array = _zone_pools.get(zone_id, [])
	if pool.is_empty():
		return _fallback_spawn_point()
	var cursor := int(_zone_cursors.get(zone_id, 0))
	for attempt in range(pool.size()):
		var idx := (cursor + attempt) % pool.size()
		var base: Vector2 = pool[idx]
		var p := base
		if jitter > 0.0:
			p += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		if is_spawn_clear(p):
			_zone_cursors[zone_id] = (idx + 1) % pool.size()
			return p
	# Nothing nearby was clear; take the raw point rather than skipping the spawn.
	_zone_cursors[zone_id] = (cursor + 1) % pool.size()
	return pool[cursor % pool.size()]


func _zone_label(zone_id: String) -> String:
	const SpeciesDB := preload("res://systems/species_db.gd")
	return SpeciesDB.zone_label(zone_id)


## Last-resort legal spawn point, used when a zone's pool could not be filled.
## Never returns a point inside a wall or on top of the player.
func _fallback_spawn_point() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + _time_frames()
	for _i in range(200):
		var a := rng.randf() * TAU
		var rr := rng.randf_range(SPAWN_MIN_CENTRE_DIST, 520.0)
		var p := _arena * 0.5 + Vector2(cos(a), sin(a)) * rr
		if is_spawn_clear(p):
			return p
	return _arena * 0.5 + Vector2(0.0, -SPAWN_MIN_CENTRE_DIST)


func _time_frames() -> int:
	return int(Time.get_ticks_msec() % 997)


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
	for _i in range(MOTE_COUNT):
		var p := _pick(rng, inner)
		_motes.append(Vector3(p.x, p.y, rng.randf() * TAU))


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
	_draw_backdrop(ci)
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
	_draw_slow_fields(ci)
	_draw_obstacles(ci)
	_draw_hazard_rings(ci)


## Layered background inside the dive site: shallower shelves, coral silhouettes
## fading into the murk, light shafts and a caustic wash. All baked once.
func _draw_backdrop(ci: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 71
	# far shelf band
	_fill(ci, _grow(_rim, 78.0), COLOR_SHELF_FAR[_biome])
	# distant reef silhouettes around the rim
	for _i in range(46):
		var a := rng.randf_range(PI, TAU)
		var base := _arena * 0.5 + Vector2(cos(a), sin(a)) * rng.randf_range(560.0, 900.0)
		var h := rng.randf_range(40.0, 120.0)
		var w := rng.randf_range(30.0, 90.0)
		var col: Color = COLOR_SILHOUETTE[_biome]
		col.a = rng.randf_range(0.10, 0.26)
		var pts := PackedVector2Array([
			base + Vector2(-w, h * 0.5), base + Vector2(-w * 0.4, -h * 0.5),
			base + Vector2(w * 0.15, -h * 0.32), base + Vector2(w, h * 0.5)])
		ci.draw_colored_polygon(pts, col)
		ci.draw_polyline(_closed(pts), Color(col, col.a * 1.6), 1.5, true)
	# light shafts
	for _i in range(7):
		var x := rng.randf_range(120.0, _arena.x - 120.0)
		var w := rng.randf_range(46.0, 130.0)
		var lean := rng.randf_range(-70.0, 70.0)
		var shaft := PackedVector2Array([Vector2(x - w * 0.5, -40.0), Vector2(x + w * 0.5, -40.0),
				Vector2(x + w * 0.5 + lean, _arena.y + 40.0), Vector2(x - w * 0.5 + lean, _arena.y + 40.0)])
		ci.draw_colored_polygon(shaft, Color(1, 1, 1, rng.randf_range(0.025, 0.055)))
	# caustic wash
	for _i in range(90):
		var p := _pick(rng, Rect2(Vector2(60, 60), _arena - Vector2(120, 120)))
		var rad := rng.randf_range(18.0, 54.0)
		var ring := PackedVector2Array()
		var n := 12
		for k in range(n):
			var ang := TAU * float(k) / float(n)
			ring.append(p + Vector2(cos(ang) * rad, sin(ang) * rad * 0.7))
		ci.draw_polyline(_closed(ring), Color(1, 1, 1, rng.randf_range(0.03, 0.075)), 2.0, true)


func _draw_slow_fields(ci: CanvasItem) -> void:
	for s: Dictionary in _slow_fields:
		var p: Vector2 = s["pos"]
		var r: float = s["r"]
		var tint: Color = Color(KELP_DARK, 0.30)
		_fill(ci, _blob(p, Vector2(r, r * 0.78), _seed + int(p.x), 40), tint)


func _draw_obstacles(ci: CanvasItem) -> void:
	for o: Dictionary in _obstacles:
		match String(o["kind"]):
			"bombie":
				_draw_bombie(ci, o["pos"], float(o["r"]))
			"arch":
				_draw_arch(ci, o["pos"], o["size"])
			"sandbar":
				_draw_sandbar(ci, o["pos"], o["size"])
			"rock":
				_draw_boulder(ci, o["pos"], float(o["r"]))
			"wreck":
				_draw_wreck(ci, o["pos"], o["size"])
			"ridge":
				_draw_ridge(ci, o["pos"], o["size"])


func _draw_bombie(ci: CanvasItem, p: Vector2, r: float) -> void:
	_shadow(ci, p + Vector2(r * 0.25, r * 0.35), r * 1.05, r * 0.42)
	var dome := PackedVector2Array()
	for i in range(28):
		var a := PI + PI * float(i) / 27.0
		var w := 1.0 + 0.10 * sin(a * 4.0)
		dome.append(p + Vector2(cos(a) * r * w, sin(a) * r * 0.92 * w))
	dome.append(p + Vector2(r, r * 0.30))
	dome.append(p + Vector2(-r, r * 0.30))
	ci.draw_colored_polygon(dome, Color("9a8468"))
	ci.draw_colored_polygon(_grow(dome, -r * 0.34), Color("c2a988"))
	# coral lobes clinging to the head
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x) * 7 + int(p.y)
	for i in range(5):
		var a := PI + rng.randf_range(0.25, PI - 0.25)
		var col: Color = CORAL[int(rng.randf() * CORAL.size()) % CORAL.size()]
		var tip := p + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.75, 1.05)
		var mid := p.lerp(tip, 0.5) + Vector2(rng.randf_range(-6.0, 6.0), 0.0)
		ci.draw_polyline(PackedVector2Array([p, mid, tip]), col, rng.randf_range(4.0, 8.0), true)
		ci.draw_circle(tip, rng.randf_range(2.5, 5.0), col.lightened(0.25))
	ci.draw_polyline(_closed(dome), INK, 2.4, true)


func _draw_arch(ci: CanvasItem, p: Vector2, size: Vector2) -> void:
	var half := size * 0.5
	_shadow(ci, p + Vector2(0, half.y * 0.9), half.x * 1.0, half.y * 0.4)
	# two pillars and a lintel: a solid arch, convex per piece
	var pillar := size.x * 0.24
	for side: float in [-1.0, 1.0]:
		var px := p.x + side * (half.x - pillar * 0.5)
		var r := Rect2(px - pillar * 0.5, p.y - half.y, pillar, size.y)
		ci.draw_rect(r, ROCK, true)
		ci.draw_rect(r.grow(-pillar * 0.22), ROCK_DARK, true)
		ci.draw_rect(r, INK, false, 2.4)
	var lintel := Rect2(p.x - half.x, p.y - half.y, size.x, size.y * 0.30)
	ci.draw_rect(lintel, ROCK, true)
	ci.draw_rect(lintel.grow(-6.0), ROCK_DARK, true)
	ci.draw_rect(lintel, INK, false, 2.4)


func _draw_sandbar(ci: CanvasItem, p: Vector2, size: Vector2) -> void:
	var half := size * 0.5
	var r := Rect2(p - half, size)
	_shadow(ci, p + Vector2(half.x * 0.2, half.y * 0.9), half.x * 1.05, half.y * 0.5)
	ci.draw_rect(r.grow(6.0), Color(FLOOR_SHADE[_biome], 0.85), true)
	ci.draw_rect(r, Color(FLOOR_SAND[_biome], 0.98), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x) + int(p.y) * 3
	for _i in range(14):
		var q := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		ci.draw_arc(q, rng.randf_range(5.0, 12.0), PI * 1.1, PI * 1.9, 7, Color(FLOOR_SHADE[_biome], 0.6), 1.6, true)
	ci.draw_rect(r, Color(FLOOR_SHADE[_biome], 0.9), false, 2.4)


func _draw_boulder(ci: CanvasItem, p: Vector2, r: float) -> void:
	_shadow(ci, p + Vector2(r * 0.3, r * 0.4), r * 1.05, r * 0.34)
	var pts := PackedVector2Array([p + Vector2(-r, r * 0.35), p + Vector2(-r * 0.62, -r * 0.55),
			p + Vector2(-r * 0.05, -r * 0.92), p + Vector2(r * 0.60, -r * 0.48), p + Vector2(r, r * 0.35)])
	ci.draw_colored_polygon(pts, ROCK)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.05, -r * 0.92), p + Vector2(r * 0.60, -r * 0.48),
			p + Vector2(r, r * 0.35), p + Vector2(0, r * 0.35)]), ROCK_DARK)
	ci.draw_polyline(_closed(pts), INK, 2.6, true)


func _draw_wreck(ci: CanvasItem, p: Vector2, size: Vector2) -> void:
	var half := size * 0.5
	_shadow(ci, p + Vector2(half.x * 0.2, half.y * 0.9), half.x * 1.05, half.y * 0.45)
	var hull := PackedVector2Array([p + Vector2(-half.x, 0), p + Vector2(-half.x * 0.72, -half.y),
			p + Vector2(half.x * 0.62, -half.y * 0.86), p + Vector2(half.x, -half.y * 0.1),
			p + Vector2(half.x * 0.82, half.y * 0.7), p + Vector2(-half.x * 0.55, half.y)])
	ci.draw_colored_polygon(hull, Color("5b6660"))
	ci.draw_colored_polygon(_grow(hull, -minf(half.x, half.y) * 0.30), Color("74807a"))
	ci.draw_polyline(_closed(hull), INK, 2.8, true)
	# broken deck ribs
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x) * 5 + int(p.y)
	for i in range(5):
		var t := float(i) / 4.0
		var x := lerpf(p.x - half.x * 0.7, p.x + half.x * 0.6, t)
		ci.draw_line(Vector2(x, p.y - half.y * 0.75), Vector2(x, p.y + half.y * 0.55),
				Color(0.72, 0.76, 0.75, 0.55), 3.0, true)
	for i in range(3):
		var a := rng.randf_range(-PI, 0.0)
		var q := p + Vector2(cos(a), sin(a)) * half.y * rng.randf_range(0.6, 1.0)
		ci.draw_circle(q, rng.randf_range(3.0, 6.0), Color(KELP_LIGHT, 0.8))


func _draw_ridge(ci: CanvasItem, p: Vector2, size: Vector2) -> void:
	var half := size * 0.5
	_shadow(ci, p + Vector2(0, half.y * 0.9), half.x * 1.02, half.y * 0.45)
	var pts := PackedVector2Array()
	var n := 9
	for i in range(n):
		var t := float(i) / float(n - 1)
		var x := lerpf(p.x - half.x, p.x + half.x, t)
		var jag := sin(t * PI * 3.0) * half.y * 0.5
		pts.append(Vector2(x, p.y - half.y - jag))
	pts.append(Vector2(p.x + half.x, p.y + half.y))
	pts.append(Vector2(p.x - half.x, p.y + half.y))
	ci.draw_colored_polygon(pts, Color("453d38"))
	ci.draw_polyline(_closed(pts), INK, 2.6, true)
	# molten seams through the glass
	ci.draw_line(Vector2(p.x - half.x * 0.75, p.y - half.y * 0.2),
			Vector2(p.x + half.x * 0.8, p.y - half.y * 0.05), Color(LAVA, 0.85), 3.0, true)
	ci.draw_line(Vector2(p.x - half.x * 0.4, p.y + half.y * 0.3),
			Vector2(p.x + half.x * 0.35, p.y + half.y * 0.15), Color(LAVA_HOT, 0.7), 2.0, true)


func _draw_hazard_rings(ci: CanvasItem) -> void:
	for h: Dictionary in _hazards:
		var p: Vector2 = h["pos"]
		var r: float = h["r"]
		var ring := PackedVector2Array()
		for i in range(30):
			var a := TAU * float(i) / 30.0
			ring.append(p + Vector2(cos(a) * r, sin(a) * r * 0.82))
		_fill(ci, ring, Color(0.5, 0.20, 0.06, 0.28))
		ci.draw_polyline(_closed(ring), Color(LAVA, 0.5), 2.0, true)


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
	# drifting particulate
	for m in _motes:
		var t := fmod(_time * 0.05 + m.z, 1.0)
		var x := m.x + sin(_time * 0.5 + m.z) * 14.0 + t * 40.0
		var y := m.y - t * 60.0
		ci.draw_circle(Vector2(x, y), 1.4, Color(0.85, 0.95, 1.0, 0.22 * (1.0 - t)))
	# shoals that scatter when the sentinel swims near
	var player := get_tree().get_first_node_in_group("player") as Node2D
	for s: Dictionary in _shoals:
		var centre: Vector2 = s["centre"]
		var phase: float = s["phase"]
		var flee: Vector2 = s["flee"]
		if player != null:
			var d := player.global_position.distance_to(centre)
			var want := Vector2.ZERO
			if d < 190.0:
				want = (centre - player.global_position).normalized() * (190.0 - d) * 0.9
			s["flee"] = flee.lerp(want, 0.08)
			flee = s["flee"]
		else:
			s["flee"] = flee.lerp(Vector2.ZERO, 0.05)
			flee = s["flee"]
		var origin := centre + flee + Vector2(0, sin(_time * 0.8 + phase) * 6.0)
		for i in range(6):
			var a := phase + TAU * float(i) / 6.0
			var q := origin + Vector2(cos(a), sin(a) * 0.55) * (26.0 + float(i % 3) * 12.0)
			var col := Color(0.9, 0.95, 0.98, 0.35)
			ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-6, 0), q + Vector2(0, -2.2),
					q + Vector2(6, 0), q + Vector2(0, 2.2)]), col)
	# gentler light movement inside the site
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
	_draw_geysers(ci)


# ================================================================ GEYSERS (fx)

## Eruption columns for the volcanic vents. The damage window lives in
## _erupt_hazards(); this is the telegraph the player reads.
func _draw_geysers(ci: CanvasItem) -> void:
	for h: Dictionary in _hazards:
		var p: Vector2 = h["pos"]
		var r: float = h["r"]
		var t := fmod(_time + float(h["phase"]), GEYSER_PERIOD)
		if t < GEYSER_WARN:
			# swell build-up
			var k := 1.0 - t / GEYSER_WARN
			ci.draw_circle(p, r * (1.0 - k * 0.35), Color(LAVA, 0.18 + 0.25 * k))
			ci.draw_arc(p, r, 0.0, TAU, 32, Color(LAVA_HOT, 0.5 + 0.4 * k), 2.5, true)
		elif t < GEYSER_WARN + 0.55:
			# eruption
			var k := (t - GEYSER_WARN) / 0.55
			var hgt := r * (2.6 - k * 1.4)
			var col := Color(LAVA_HOT, 0.75 * (1.0 - k))
			ci.draw_colored_polygon(PackedVector2Array([
					p + Vector2(-r * 0.85, 0), p + Vector2(-r * 0.25, -hgt),
					p + Vector2(r * 0.25, -hgt), p + Vector2(r * 0.85, 0)]), col)
			ci.draw_circle(p, r * (0.8 + k * 0.5), Color(LAVA, 0.30 * (1.0 - k)))


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
	var tries := 0
	while out.size() < count and tries < count * 80:
		tries += 1
		var p := _pick(rng, Rect2(Vector2(RIM, RIM), _arena - Vector2(RIM, RIM) * 2.0))
		if not is_spawn_clear(p):
			continue
		var clear := true
		for q in out:
			if q.distance_to(p) < 120.0:
				clear = false
				break
		if clear:
			out.append(p)
	return out
