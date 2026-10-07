extends Control
# C owns this file — world map / level select.
# Every piece of map art is drawn in code: no textures, no extra scenes.
# Tweak the CONSTANTS section; everything below it is plumbing.

const GUIDEBOOK_SCRIPT := preload("res://scenes/ui/guidebook.gd")

const ISLAND_BUTTONS := {
	"redwake": "Redwake",
	"quiet_belt": "QuietBelt",
	"harrow": "Harrow",
	"second_watch": "SecondWatch",
	"mire": "Mire",
}

# Dive scene for each island. Levels 4 and 5 are not built yet, so pressing
# their banner reports that instead of failing a scene change.
const LEVEL_SCENES := {
	"redwake": "res://scenes/levels/level_redwake.tscn",
	"quiet_belt": "res://scenes/levels/level_quiet_belt.tscn",
	"harrow": "res://scenes/levels/level_harrow.tscn",
}

# ================================================================ CONSTANTS

# Dive-site pin for each level (same order as above). The banner floats above it.
const LEVEL_SPOTS := {
	"redwake": Vector2(140, 374),
	"quiet_belt": Vector2(598, 216),
	"harrow": Vector2(1004, 362),
	"second_watch": Vector2(858, 606),
	"mire": Vector2(288, 610),
}
const BANNER_SIZE := Vector2(126, 38)
const BANNER_LIFT := 44.0                           # banner centre sits this far above its pin
const BANNER_TILT := [-2.0, 1.5, -1.5, 2.0, -1.0]   # degrees, hand-placed look

const MAP_SEED := 42            # coast wobble + tree / rock placement
const CLIFF_HEIGHT := 13.0      # thickness of the island "slab"
const ROUTE_GAP := 34.0         # how far the sea route keeps from the coast
const AMBIENT_MOTION := true    # waves, volcano smoke, bobbing submarine

# Rough outline of the main island, clockwise. Smoothed + roughened in code.
const COAST := [
	Vector2(186, 432), Vector2(178, 404), Vector2(172, 380), Vector2(180, 350),
	Vector2(194, 322), Vector2(208, 296), Vector2(224, 270), Vector2(238, 248),
	Vector2(244, 222), Vector2(256, 200), Vector2(282, 190), Vector2(306, 200),
	Vector2(320, 222), Vector2(340, 240), Vector2(372, 238), Vector2(404, 222),
	Vector2(440, 210), Vector2(480, 212), Vector2(520, 218), Vector2(556, 232),
	Vector2(584, 250), Vector2(612, 252), Vector2(640, 236), Vector2(668, 214),
	Vector2(704, 200), Vector2(744, 198), Vector2(788, 206), Vector2(830, 220),
	Vector2(866, 238), Vector2(898, 262), Vector2(926, 290), Vector2(948, 316),
	Vector2(962, 340), Vector2(960, 366), Vector2(970, 392), Vector2(966, 420),
	Vector2(950, 444), Vector2(934, 464), Vector2(940, 490), Vector2(956, 514),
	Vector2(956, 542), Vector2(940, 566), Vector2(912, 580), Vector2(878, 576),
	Vector2(842, 564), Vector2(804, 566), Vector2(764, 576), Vector2(722, 586),
	Vector2(680, 590), Vector2(648, 576), Vector2(628, 548), Vector2(612, 516),
	Vector2(588, 498), Vector2(556, 494), Vector2(530, 506), Vector2(514, 532),
	Vector2(500, 562), Vector2(474, 586), Vector2(434, 596), Vector2(392, 590),
	Vector2(352, 596), Vector2(316, 590), Vector2(284, 576), Vector2(256, 566),
	Vector2(230, 546), Vector2(212, 516), Vector2(200, 484), Vector2(192, 458),
]

# Small islands: [centre, radius, style]  style 0 = pines, 1 = sandy palms, 2 = rocks
const ISLETS := [
	[Vector2(100, 206), Vector2(42, 24), 0],
	[Vector2(1078, 178), Vector2(46, 26), 1],
	[Vector2(1078, 540), Vector2(34, 20), 2],
	[Vector2(62, 500), Vector2(26, 16), 1],
]

const COMPASS_POS := Vector2(84, 84)

# Mountain range: [base x, base y, width, height, snow cap]
const MOUNTAINS := [
	[318, 300, 64, 46, false], [354, 286, 72, 62, true], [392, 298, 66, 52, false],
	[428, 280, 80, 76, true], [468, 292, 70, 58, true], [504, 284, 64, 50, false],
	[540, 298, 58, 42, false], [378, 320, 56, 36, false], [452, 320, 60, 40, false],
	[500, 318, 52, 34, false],
]
const VOLCANO := Vector2(872, 356)
const LAKE := Vector2(420, 400)
const RIVER := [
	Vector2(450, 322), Vector2(440, 340), Vector2(428, 362), Vector2(426, 382),
	Vector2(452, 420), Vector2(488, 446), Vector2(526, 462), Vector2(556, 478),
	Vector2(572, 500),
]
const VILLAGE := [Vector2(222, 352), Vector2(248, 370), Vector2(214, 398), Vector2(242, 414), Vector2(270, 392)]
const LIGHTHOUSE := Vector2(938, 548)
const PYRAMIDS := [[Vector2(716, 436), 52.0, 38.0], [Vector2(672, 450), 30.0, 22.0]]

# Forest patches: [centre, radius, pine share 0..1]
const FORESTS := [
	[Vector2(296, 336), Vector2(50, 40), 0.3],
	[Vector2(398, 470), Vector2(84, 34), 0.1],
	[Vector2(724, 266), Vector2(96, 36), 0.6],
	[Vector2(822, 490), Vector2(78, 44), 0.2],
	[Vector2(566, 418), Vector2(46, 34), 0.0],
	[Vector2(274, 230), Vector2(30, 18), 0.8],
]

# ---------------------------------------------------------------- PALETTE
const SEA_TOP := Color("1d6198")
const SEA_BOTTOM := Color("174f82")
const SEA_EDGE := Color("0c2f52")
const SHELF := Color(0.45, 0.78, 0.95, 0.13)
const SHALLOW := Color("4fb0d6")
const SHALLOW_LIGHT := Color("7dd0e4")
const FOAM := Color(1, 1, 1, 0.85)
const INK := Color("33231a")
const CLIFF_TOP := Color("a9784a")
const CLIFF_DARK := Color("6b4428")
const SAND := Color("f0dca0")
const GRASS := Color("7cbd4c")
const GRASS_LIGHT := Color("96cd60")
const GRASS_DARK := Color("4e8a34")
const TREE := Color("3f8a3b")
const TREE_LIGHT := Color("5ea847")
const TREE_DARK := Color("234f26")
const PINE := Color("2f6e43")
const TRUNK := Color("6b4426")
const ROCK := Color("b9b2a6")
const ROCK_DARK := Color("847b70")
const SNOW := Color("f8f8f3")
const ASH := Color("8c6f58")
const LAVA := Color("ff7a2e")
const DESERT := Color("e6c97e")
const SWAMP := Color("7a9550")
const SWAMP_WATER := Color("4c7466")
const LAKE_WATER := Color("4aa9d8")
const PATH := Color("e3cf98")
const ROOF := Color("c9533c")
const WALL := Color("f5ead2")
const SHADOW := Color(0.05, 0.12, 0.05, 0.22)

const BANNER_OPEN := Color("fff2d2")
const BANNER_NEXT := Color("ffd45e")
const BANNER_LOCKED := Color("5d6976")
const BANNER_EDGE := Color("7a4a1f")
const BANNER_EDGE_LOCKED := Color("38414c")
const BANNER_TEXT := Color("4a2a10")
const BANNER_TEXT_LOCKED := Color("d6dde5")
const PIN_DONE := Color("2fb67c")
const PIN_NEXT := Color("ff8a2a")
const PIN_LOCKED := Color("7c8794")

enum { LOCKED, CLEARED, CURRENT }

# ================================================================ STATE

var _art: Node2D                 # static art, drawn once into _bake
var _bake: SubViewport
var _bake_view: TextureRect
var _fx: Node2D                  # small animated layer, redrawn each frame
var _time := 0.0
var _noise := FastNoiseLite.new()
var _masses: Array[Dictionary] = []
var _grass_safe := PackedVector2Array()
var _lake := PackedVector2Array()
var _river := PackedVector2Array()
var _blocked: Array[PackedVector2Array] = []
var _props: Array[Dictionary] = []
var _route_loop := PackedVector2Array()
var _waves: Array[Vector3] = []
var _spots: Array[Vector2] = []
var _states: Array[int] = []
var _banners: Array[Button] = []
var _current := -1
var _sub_pos := Vector2.ZERO
var _guidebook: Control = null
var _guidebook_button: Button = null


func _ready() -> void:
	$Background.z_index = -10
	_setup_levels()
	_build_world()

	# The static art is drawn ONCE into an off-screen texture (at up to 3x the
	# screen resolution for smooth edges), so each frame costs a single quad
	# instead of thousands of draw calls.
	_art = Node2D.new()
	_art.draw.connect(_draw_map)
	_bake = SubViewport.new()
	_bake.name = "MapBake"
	_bake.disable_3d = true
	_bake.size_2d_override_stretch = true
	_bake.add_child(_art)
	add_child(_bake)

	_bake_view = TextureRect.new()
	_bake_view.name = "MapArt"
	_bake_view.texture = _bake.get_texture()
	_bake_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bake_view.stretch_mode = TextureRect.STRETCH_SCALE
	_bake_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bake_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bake_view.z_index = -6
	$Islands.add_child(_bake_view)
	$Islands.move_child(_bake_view, 0)

	# small animated layer on top (waves, smoke, sub, pulse)
	_fx = Node2D.new()
	_fx.name = "MapFx"
	_fx.z_index = -5
	_fx.draw.connect(_draw_fx)
	$Islands.add_child(_fx)

	_setup_guidebook()
	_rebake()
	get_viewport().size_changed.connect(_rebake)


func _rebake() -> void:
	var view := get_viewport_rect().size
	var px := Vector2(get_viewport().get_texture().get_size())
	var k := minf(minf(px.x / view.x, px.y / view.y) * 2.0, 3.0)
	_bake.size_2d_override = Vector2i(view)
	_bake.size = Vector2i((view * k).ceil())
	_bake_view.position = Vector2.ZERO
	_bake_view.size = view
	_art.queue_redraw()
	_bake.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	_time += delta
	if _fx:
		_fx.queue_redraw()

# ================================================================ BUTTONS

func _setup_levels() -> void:
	var ids: Array[String] = []
	for id: String in ISLAND_BUTTONS:
		ids.append(id)
	for i in range(ids.size()):
		if GameProgress.is_unlocked(ids[i]):
			_current = i

	var bold := FontVariation.new()
	bold.base_font = get_theme_default_font()
	bold.variation_embolden = 0.6

	for i in range(ids.size()):
		var id := ids[i]
		var unlocked: bool = GameProgress.is_unlocked(id)
		var state := LOCKED
		if unlocked:
			state = CURRENT if i == _current else CLEARED
		_states.append(state)
		var spot: Vector2 = LEVEL_SPOTS[id]
		_spots.append(spot)

		var btn: Button = get_node("Islands/" + ISLAND_BUTTONS[id])
		btn.text = "Level %d" % (i + 1)
		btn.custom_minimum_size = BANNER_SIZE
		btn.size = BANNER_SIZE
		btn.position = spot + Vector2(0, -BANNER_LIFT) - btn.size / 2.0
		btn.pivot_offset = btn.size / 2.0
		btn.rotation_degrees = BANNER_TILT[i]
		_style_island(btn, unlocked, state == CURRENT, bold)
		btn.pressed.connect(_on_island_pressed.bind(id))
		_banners.append(btn)


func _style_island(btn: Button, unlocked: bool, is_next: bool, font: Font) -> void:
	# NEVER disable the button — disabled buttons ignore the mouse entirely.
	# Locking is enforced in _on_island_pressed by checking is_unlocked().
	btn.disabled = false
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 19)

	var face := BANNER_LOCKED
	var edge := BANNER_EDGE_LOCKED
	var text := BANNER_TEXT_LOCKED
	if unlocked:
		face = BANNER_NEXT if is_next else BANNER_OPEN
		edge = BANNER_EDGE
		text = BANNER_TEXT
	var normal := _banner_box(face, edge)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_stylebox_override("hover", _banner_box(face.lightened(0.15), edge))
	btn.add_theme_stylebox_override("pressed", _banner_box(face.darkened(0.12), edge))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, text)

	if unlocked:
		btn.tooltip_text = "Dive in!"
	else:
		btn.tooltip_text = "Locked — clear the previous reef first"

	if is_next:  # gentle pulse on the level you should play next
		var tw := create_tween().set_loops()
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func _banner_box(face: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = edge
	box.set_border_width_all(2)
	box.border_width_bottom = 4
	box.set_corner_radius_all(5)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 5.0
	box.anti_aliasing = true
	return box


## W8: the guidebook, opened from the map. It is a child of this Control so it
## simply scales with the viewport, like every other overlay here. The book owns
## its own rect (see scenes/ui/guidebook.gd::_layout) instead of trusting
## anchors, and it paints an opaque backdrop, so the map cannot show through it.
func _setup_guidebook() -> void:
	_guidebook = Control.new()
	_guidebook.name = "Guidebook"
	_guidebook.set_script(GUIDEBOOK_SCRIPT)
	add_child(_guidebook)
	var button := Button.new()
	button.name = "GuidebookButton"
	button.text = "GUIDEBOOK"
	button.custom_minimum_size = Vector2(148, 38)
	button.size = Vector2(148, 38)
	button.add_theme_font_size_override("font_size", 16)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("4a2f18")
	box.border_color = Color("8dc24a")
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_color_override("font_color", Color("f2e3bd"))
	button.add_theme_color_override("font_hover_color", Color("8dc24a"))
	button.pressed.connect(_open_guidebook)
	add_child(button)
	_guidebook_button = button
	get_viewport().size_changed.connect(_place_guidebook_button)
	_place_guidebook_button()


func _place_guidebook_button() -> void:
	if _guidebook_button == null:
		return
	var view := get_viewport_rect().size
	_guidebook_button.position = Vector2(view.x - _guidebook_button.size.x - 22.0, 20.0)


func _open_guidebook() -> void:
	if _guidebook != null:
		_guidebook.call("open")


func _on_island_pressed(id: String) -> void:
	if not GameProgress.is_unlocked(id):
		print("Locked! Clear the previous reef to dive at %s." % id)
		return
	var path: String = LEVEL_SCENES.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		print("No dive scene yet for %s." % id)
		return
	get_tree().change_scene_to_file(path)

# ================================================================ BUILD (geometry + layout, runs once)

func _build_world() -> void:
	_noise.seed = MAP_SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.03
	_noise.fractal_octaves = 3

	# main island + islets
	var coast := _smooth_loop(COAST, 6)
	var main_grass := _inset(coast, 9.0, 20.0, 1.0)
	_add_mass(_clean(_roughen(coast, 4.0, 0.0), coast), _clean(_roughen(main_grass, 3.0, 2.0), main_grass), 0, 1.0)
	for i in range(ISLETS.size()):
		var def: Array = ISLETS[i]
		var c: Vector2 = def[0]
		var r: Vector2 = def[1]
		var style: int = def[2]
		var land := _blob(c, r, MAP_SEED + 17 * (i + 1), 40)
		var grass_r := r * (0.45 if style == 1 else 0.72)
		var grass := _blob(c + Vector2(0, -2), grass_r, MAP_SEED + 17 * (i + 1), 40)
		_add_mass(land, grass, style, 0.65)

	var main_top: PackedVector2Array = _masses[0]["top"]
	_grass_safe = _biggest(Geometry2D.offset_polygon(main_top, -8.0))

	# sea route: a smooth loop around the main island
	var main_sil: PackedVector2Array = _masses[0]["sil"]
	_route_loop = _resample(_chaikin(_closing(main_sil, ROUTE_GAP, 110.0), 2), 6.0)

	# inland water
	_lake = _blob(LAKE, Vector2(56, 32), MAP_SEED + 3, 40)
	_river = _cut_at_coast(_smooth_open(RIVER, 5), _masses[0]["land"])

	# zones where trees must not grow
	_blocked.append(_blob(LAKE, Vector2(70, 44), MAP_SEED + 3, 32))
	_blocked.append(_blob(Vector2(432, 296), Vector2(140, 46), MAP_SEED + 5, 32))     # mountains
	_blocked.append(_blob(VOLCANO + Vector2(0, -6), Vector2(96, 50), MAP_SEED + 6, 32))
	_blocked.append(_blob(Vector2(700, 436), Vector2(90, 46), MAP_SEED + 7, 32))     # desert
	_blocked.append(_blob(Vector2(330, 516), Vector2(80, 36), MAP_SEED + 8, 32))     # swamp
	_blocked.append(_blob(Vector2(240, 386), Vector2(46, 46), MAP_SEED + 9, 32))     # village
	_blocked.append(_blob(LIGHTHOUSE, Vector2(26, 24), MAP_SEED + 10, 24))

	_build_props()
	_build_waves()
	if _current >= 0:  # park the sub beside the next level's pin, on the open-water side
		var spot := _spots[_current]
		var sil: PackedVector2Array = _masses[0]["sil"]
		var west := spot + Vector2(-42, 6)
		var east := spot + Vector2(42, 6)
		var centre := _centroid(sil)
		if Geometry2D.is_point_in_polygon(west, sil):
			_sub_pos = east
		elif Geometry2D.is_point_in_polygon(east, sil):
			_sub_pos = west
		else:
			_sub_pos = west if west.distance_to(centre) > east.distance_to(centre) else east


func _add_mass(land: PackedVector2Array, top: PackedVector2Array, style: int, k: float) -> void:
	var cliff := CLIFF_HEIGHT * k
	var rk := k * k  # small islands get proportionally thinner water rings
	var sil := _biggest(Geometry2D.merge_polygons(land, _moved(land, Vector2(0, cliff))))
	var clipped := _biggest(Geometry2D.intersect_polygons(top, _biggest(Geometry2D.offset_polygon(land, -3.0))))
	var rings: Array[PackedVector2Array] = []
	for d: float in [64.0 * rk, 30.0 * rk, 14.0 * rk]:
		var ring := _closing(sil, d, 70.0 * rk) if d > 60.0 * rk else _grow(sil, d)
		rings.append(_clean(_roughen(ring, 3.0, d), ring))
	var foam := _grow(sil, 4.0)
	_masses.append({"land": land, "top": clipped, "sil": sil, "rings": rings, "foam": foam,
			"cliff": cliff, "style": style})


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED

	for m: Array in MOUNTAINS:
		_props.append({"kind": "mountain", "p": Vector2(m[0], m[1]), "w": float(m[2]),
				"h": float(m[3]), "snow": m[4], "y": float(m[1])})
	_props.append({"kind": "volcano", "p": VOLCANO, "y": VOLCANO.y})
	for d: Array in PYRAMIDS:
		var base: Vector2 = d[0]
		_props.append({"kind": "pyramid", "p": base, "w": d[1], "h": d[2], "y": base.y})
	_props.append({"kind": "lighthouse", "p": LIGHTHOUSE, "y": LIGHTHOUSE.y})
	for i in range(VILLAGE.size()):
		var hp: Vector2 = VILLAGE[i]
		_props.append({"kind": "house", "p": hp, "s": rng.randf_range(10.0, 13.0),
				"roof": ROOF.lerp(Color("8f4a3a"), rng.randf() * 0.6), "y": hp.y})

	# forests
	var planted: Array[Vector2] = []
	for f: Array in FORESTS:
		var fc: Vector2 = f[0]
		var fr: Vector2 = f[1]
		var pine_share: float = f[2]
		var area := _blob(fc, fr, MAP_SEED + int(fc.x), 28)
		for _t in range(int(fr.x * fr.y / 22.0)):
			var p := fc + Vector2(rng.randf_range(-fr.x, fr.x), rng.randf_range(-fr.y, fr.y)) * 1.15
			if not Geometry2D.is_point_in_polygon(p, area) or not _can_plant(p, planted, 10.5):
				continue
			planted.append(p)
			var pine := rng.randf() < pine_share
			_props.append({"kind": "pine" if pine else "tree", "p": p, "s": rng.randf_range(6.5, 9.0),
					"tint": rng.randf(), "y": p.y})

	# lone trees sprinkled over open grass
	for _t in range(70):
		var p := Vector2(rng.randf_range(200, 960), rng.randf_range(220, 580))
		if _can_plant(p, planted, 26.0):
			planted.append(p)
			_props.append({"kind": "tree", "p": p, "s": rng.randf_range(5.5, 7.5), "tint": rng.randf(), "y": p.y})

	# islet decorations
	for i in range(1, _masses.size()):
		var m: Dictionary = _masses[i]
		var top: PackedVector2Array = m["top"]
		var c := _centroid(top)
		var style: int = m["style"]
		if style == 0:
			for off: Vector2 in [Vector2(-14, 2), Vector2(4, -4), Vector2(18, 4)]:
				_props.append({"kind": "pine", "p": c + off, "s": 6.5, "tint": rng.randf(), "y": c.y + off.y})
		elif style == 1:
			_props.append({"kind": "palm", "p": c + Vector2(-8, 4), "s": 9.0, "y": c.y + 4.0})
			_props.append({"kind": "palm", "p": c + Vector2(10, 0), "s": 8.0, "y": c.y})
		else:
			_props.append({"kind": "rock", "p": c + Vector2(-6, 2), "s": 9.0, "y": c.y + 2.0})
			_props.append({"kind": "rock", "p": c + Vector2(9, -2), "s": 6.0, "y": c.y - 2.0})

	# boulders around the volcano
	for _t in range(9):
		var a := rng.randf_range(0.0, TAU)
		var p := VOLCANO + Vector2(cos(a) * rng.randf_range(62, 86), sin(a) * rng.randf_range(10, 30) + 4)
		_props.append({"kind": "rock", "p": p, "s": rng.randf_range(3.5, 6.0), "y": p.y})

	# reeds in the swamp
	var swamp := _blob(Vector2(330, 516), Vector2(70, 30), MAP_SEED + 8, 32)
	for _t in range(30):
		var p := Vector2(330, 516) + Vector2(rng.randf_range(-70, 70), rng.randf_range(-30, 30))
		if Geometry2D.is_point_in_polygon(p, swamp):
			_props.append({"kind": "reed", "p": p, "s": rng.randf_range(6.0, 9.0), "y": p.y})

	_props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["y"] < b["y"])


func _can_plant(p: Vector2, planted: Array[Vector2], gap: float) -> bool:
	if not Geometry2D.is_point_in_polygon(p, _grass_safe):
		return false
	for zone in _blocked:
		if Geometry2D.is_point_in_polygon(p, zone):
			return false
	if _dist_to_path(p, _river) < 11.0:
		return false
	for q in planted:
		if q.distance_to(p) < gap:
			return false
	return true


func _build_waves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED + 99
	var view := get_viewport_rect().size
	var keep_out: Array[PackedVector2Array] = []
	for m in _masses:
		var sil: PackedVector2Array = m["sil"]
		keep_out.append(_biggest(Geometry2D.offset_polygon(sil, 60.0)))
	var tries := 0
	while _waves.size() < 26 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(20, view.x - 40), rng.randf_range(20, view.y - 16))
		if p.distance_to(COMPASS_POS) < 70.0 or Rect2(330, 20, 500, 110).has_point(p):
			continue
		var ok := true
		for poly in keep_out:
			if Geometry2D.is_point_in_polygon(p, poly):
				ok = false
				break
		for w in _waves:
			if Vector2(w.x, w.y).distance_to(p) < 70.0:
				ok = false
		if ok:
			_waves.append(Vector3(p.x, p.y, rng.randf() * TAU))

# ================================================================ DRAW: STATIC ART

func _draw_map() -> void:
	var ci := _art
	_draw_sea(ci)

	# water rings around every landmass (shelf -> shallow -> light shallow)
	var ring_cols := [SHELF, SHALLOW, SHALLOW_LIGHT]
	for level in range(3):
		for m in _masses:
			var rings: Array = m["rings"]
			_fill(ci, rings[level], ring_cols[level], level > 0)
	for m in _masses:
		var sil: PackedVector2Array = m["sil"]
		_fill(ci, _moved(sil, Vector2(3, 7)), Color(0.02, 0.15, 0.25, 0.25), false)
		var foam: PackedVector2Array = m["foam"]
		_outline(ci, foam, FOAM, 2.0)

	_draw_reefs(ci)

	# island slabs: cliff, then sand, then grass
	for m in _masses:
		var land: PackedVector2Array = m["land"]
		var cliff: float = m["cliff"]
		_fill(ci, _moved(land, Vector2(0, cliff)), CLIFF_DARK)
		_fill(ci, _moved(land, Vector2(0, cliff - 3.0)), CLIFF_TOP)
		_draw_cliff_lines(ci, land, cliff)
		var sil: PackedVector2Array = m["sil"]
		_outline(ci, sil, INK, 1.6)
	for m in _masses:
		var land: PackedVector2Array = m["land"]
		var top: PackedVector2Array = m["top"]
		var style: int = m["style"]
		_fill(ci, land, SAND)
		_fill(ci, top, GRASS_LIGHT if style == 1 else GRASS)
		_outline(ci, top, GRASS_DARK, 1.4)

	_draw_ground(ci)
	_draw_water_inland(ci)
	_draw_dock(ci, Vector2(198, 430), Vector2(150, 438))
	_draw_boat(ci, Vector2(566, 560), 11.0)
	for prop in _props:
		_draw_prop(ci, prop)

	_draw_route(ci)
	for i in range(_spots.size()):
		_draw_pin(ci, _spots[i], _states[i])
	_draw_compass(ci, COMPASS_POS, 44.0)


func _draw_sea(ci: CanvasItem) -> void:
	var view := get_viewport_rect().size
	ci.draw_rect(Rect2(-500, -500, view.x + 1000, view.y + 1000), SEA_EDGE)
	var quad := PackedVector2Array([Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)])
	ci.draw_polygon(quad, PackedColorArray([SEA_TOP, SEA_TOP, SEA_BOTTOM, SEA_BOTTOM]))
	# soft vignette towards the screen edges
	var c := view * 0.5 + Vector2(0, 30)
	var inner := Vector2(view.x * 0.46, view.y * 0.52)
	var outer := Vector2(view.x * 0.82, view.y * 0.95)
	var clear := Color(SEA_EDGE, 0.0)
	var steps := 64
	for i in range(steps):
		var a0 := TAU * float(i) / steps
		var a1 := TAU * float(i + 1) / steps
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var pts := PackedVector2Array([c + d0 * inner, c + d1 * inner, c + d1 * outer, c + d0 * outer])
		ci.draw_polygon(pts, PackedColorArray([clear, clear, SEA_EDGE, SEA_EDGE]))


func _draw_cliff_lines(ci: CanvasItem, land: PackedVector2Array, cliff: float) -> void:
	var n := land.size()
	var sgn := 1.0 if _area(land) > 0.0 else -1.0
	var since := 0.0
	for i in range(n):
		var t := (land[(i + 1) % n] - land[(i - 1 + n) % n]).normalized()
		var outward := Vector2(t.y, -t.x) * sgn
		since += land[i].distance_to(land[(i + 1) % n])
		if outward.y > 0.5 and since > 7.0:
			since = 0.0
			var a := land[i] + Vector2(0, 3.0)
			var b := a + Vector2(0, cliff - 5.0 - fmod(float(i) * 2.7, 3.0))
			ci.draw_line(a, b, CLIFF_DARK, 1.3, true)


func _draw_reefs(ci: CanvasItem) -> void:
	var cols := [Color("ff7aa2"), Color("ffa04a"), Color("b98cff"), Color("ffd75a")]
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED + 7
	for spot in _spots:
		for k in range(9):
			var a := rng.randf_range(-0.2, PI + 0.2)
			var p := spot + Vector2(cos(a), sin(a)) * rng.randf_range(15.0, 30.0)
			var r := rng.randf_range(2.0, 3.6)
			var col: Color = cols[k % cols.size()]
			ci.draw_circle(p, r + 1.0, Color(col.darkened(0.45), 0.7))
			ci.draw_circle(p, r, col)


func _draw_ground(ci: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED + 21
	var main_top: PackedVector2Array = _masses[0]["top"]

	# soft lighter meadows and darker patches
	for d: Array in [[Vector2(590, 370), Vector2(86, 44), GRASS_LIGHT], [Vector2(300, 270), Vector2(50, 28), GRASS_LIGHT],
			[Vector2(640, 520), Vector2(70, 30), GRASS_LIGHT], [Vector2(800, 410), Vector2(60, 40), Color("6fb244")]]:
		var c: Vector2 = d[0]
		var r: Vector2 = d[1]
		var col: Color = d[2]
		_fill(ci, _clip(_blob(c, r, int(c.x), 32), main_top), col)

	# swamp, desert, ash, foothills
	var swamp := _clip(_blob(Vector2(330, 516), Vector2(80, 36), MAP_SEED + 8, 36), main_top)
	_fill(ci, swamp, SWAMP)
	for pc: Vector2 in [Vector2(304, 512), Vector2(352, 526), Vector2(336, 500), Vector2(282, 530)]:
		var pool := _blob(pc, Vector2(17, 8), int(pc.x), 20)
		_fill(ci, _biggest(Geometry2D.offset_polygon(pool, 2.0)), Color("9bb56a"))
		_fill(ci, pool, SWAMP_WATER)
		ci.draw_circle(pc + Vector2(-5, -1), 2.6, Color("5fa64a"))
		ci.draw_circle(pc + Vector2(6, 2), 2.0, Color("5fa64a"))
	var desert := _clip(_blob(Vector2(700, 436), Vector2(92, 46), MAP_SEED + 7, 36), main_top)
	_fill(ci, desert, DESERT)
	_outline(ci, desert, Color("c9a75a"), 1.2)
	for k in range(5):
		var dc := Vector2(650 + k * 22, 410 + (k % 2) * 30)
		ci.draw_arc(dc, 10.0, PI * 1.15, PI * 1.85, 8, Color("c9a75a"), 1.4, true)
	var ash := _clip(_blob(VOLCANO + Vector2(0, -8), Vector2(98, 52), MAP_SEED + 6, 36), main_top)
	_fill(ci, ash, Color(ASH, 0.35))
	_fill(ci, _clip(_blob(VOLCANO + Vector2(0, -12), Vector2(78, 38), MAP_SEED + 16, 36), main_top), Color(ASH, 0.4))
	var hills := _clip(_blob(Vector2(432, 300), Vector2(150, 40), MAP_SEED + 5, 40), main_top)
	_fill(ci, hills, Color("6e9c46"))
	_outline(ci, hills, Color(GRASS_DARK, 0.6), 1.2)

	# farm fields near the village
	for fd: Array in [[Vector2(268, 440), 0.25], [Vector2(296, 458), -0.15]]:
		var fc: Vector2 = fd[0]
		var rot: float = fd[1]
		var field := PackedVector2Array([Vector2(-18, -10), Vector2(18, -10), Vector2(18, 10), Vector2(-18, 10)])
		field = Transform2D(rot, fc) * field
		_fill(ci, field, Color("d9b866"))
		_outline(ci, field, Color("9c7a3a"), 1.0)
		for s in range(1, 5):
			var t := float(s) / 5.0
			ci.draw_line(field[0].lerp(field[3], t), field[1].lerp(field[2], t), Color("b38f45"), 1.0, true)

	# paths
	for path: Array in [[Vector2(258, 392), Vector2(300, 398), Vector2(340, 402), Vector2(364, 404)],
			[Vector2(476, 404), Vector2(530, 398), Vector2(590, 404), Vector2(640, 424)]]:
		ci.draw_polyline(_smooth_open(path, 6), PATH, 3.0, true)

	# grass tufts + flowers
	for _t in range(170):
		var p := Vector2(rng.randf_range(190, 970), rng.randf_range(210, 590))
		if not Geometry2D.is_point_in_polygon(p, _grass_safe):
			continue
		if rng.randf() < 0.75:
			ci.draw_line(p, p + Vector2(-2.5, -4), GRASS_DARK, 1.0, true)
			ci.draw_line(p, p + Vector2(0.5, -5), GRASS_DARK, 1.0, true)
			ci.draw_line(p, p + Vector2(3, -3.5), GRASS_DARK, 1.0, true)
		else:
			var fcol: Color = [Color("fff6e0"), Color("ffd75a"), Color("ff9fbf")][rng.randi() % 3]
			ci.draw_circle(p, 1.7, fcol)


func _draw_water_inland(ci: CanvasItem) -> void:
	# river (tapered strip) + waterfall where it leaves the cliff
	if _river.size() >= 2:
		var strip := _strip(_river, 3.0, 9.0)
		_fill(ci, strip, LAKE_WATER)
		ci.draw_polyline(_river, Color(1, 1, 1, 0.35), 1.2, true)
		var mouth := _river[_river.size() - 1]
		var fall := Rect2(mouth.x - 4.5, mouth.y - 1, 9, CLIFF_HEIGHT + 2)
		ci.draw_rect(fall, Color("bfe9f5"))
		ci.draw_line(Vector2(mouth.x - 1.5, mouth.y), Vector2(mouth.x - 1.5, mouth.y + CLIFF_HEIGHT), Color.WHITE, 1.2)
		ci.draw_line(Vector2(mouth.x + 2.0, mouth.y), Vector2(mouth.x + 2.0, mouth.y + CLIFF_HEIGHT), Color.WHITE, 1.0)
		for k in range(4):
			ci.draw_circle(Vector2(mouth.x - 6 + k * 4, mouth.y + CLIFF_HEIGHT + 2), 2.6, Color(1, 1, 1, 0.9))
	# lake
	_fill(ci, _biggest(Geometry2D.offset_polygon(_lake, 4.0)), SAND)
	_fill(ci, _lake, LAKE_WATER)
	_fill(ci, _biggest(Geometry2D.offset_polygon(_lake, -6.0)), Color("6cc3e6"))
	_outline(ci, _lake, Color(INK, 0.5), 1.2)
	for k in range(3):
		var wp := LAKE + Vector2(-20 + k * 18, -6 + (k % 2) * 10)
		ci.draw_arc(wp, 5.0, PI * 1.2, PI * 1.8, 6, Color(1, 1, 1, 0.6), 1.2, true)


func _draw_dock(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x) * 3.5
	for k in range(3):
		var post := a.lerp(b, 0.45 + k * 0.25)
		ci.draw_line(post + nrm, post + nrm + Vector2(0, 6), Color("4a3020"), 2.0)
	var deck := PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm])
	ci.draw_colored_polygon(deck, Color("a87442"))
	for k in range(1, 9):
		var q := a.lerp(b, float(k) / 9.0)
		ci.draw_line(q + nrm, q - nrm, Color("7a4f2b"), 1.0)
	ci.draw_polyline(_closed(deck), INK, 1.2, true)


func _draw_boat(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_arc(p + Vector2(-s * 1.6, s * 0.3), s * 0.5, PI * 0.1, PI * 0.9, 6, Color(1, 1, 1, 0.6), 1.2, true)
	ci.draw_arc(p + Vector2(-s * 2.4, s * 0.3), s * 0.4, PI * 0.1, PI * 0.9, 6, Color(1, 1, 1, 0.4), 1.2, true)
	var hull := PackedVector2Array([p + Vector2(-s, -s * 0.15), p + Vector2(s * 1.05, -s * 0.15),
			p + Vector2(s * 0.7, s * 0.4), p + Vector2(-s * 0.75, s * 0.4)])
	ci.draw_colored_polygon(hull, Color("9a6236"))
	ci.draw_polyline(_closed(hull), INK, 1.2, true)
	ci.draw_line(p + Vector2(0, -s * 0.15), p + Vector2(0, -s * 1.9), INK, 1.4, true)
	var sail := PackedVector2Array([p + Vector2(1.5, -s * 1.8), p + Vector2(1.5, -s * 0.35), p + Vector2(s * 0.95, -s * 0.4)])
	ci.draw_colored_polygon(sail, Color("fbf6ea"))
	ci.draw_polyline(_closed(sail), INK, 1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.9), p + Vector2(-s * 0.55, -s * 1.75),
			p + Vector2(0, -s * 1.6)]), Color("d0453a"))


func _draw_route(ci: CanvasItem) -> void:
	for i in range(_spots.size() - 1):
		var path := _route_between(_spots[i], _spots[i + 1])
		var done := i < _current
		if done:
			_draw_dashed(ci, _moved(path, Vector2(0, 1.5)), Color(0, 0, 0, 0.25), 3.5, 10.0, 7.0)
			_draw_dashed(ci, path, Color("fff6dc"), 3.0, 10.0, 7.0)
		else:
			_draw_dashed(ci, path, Color(1, 1, 1, 0.5), 2.2, 8.0, 7.0)


func _draw_pin(ci: CanvasItem, p: Vector2, state: int) -> void:
	var top := p + Vector2(0, -BANNER_LIFT + BANNER_SIZE.y * 0.5)
	ci.draw_line(p + Vector2(0, -8), top, INK, 2.0, true)
	ci.draw_circle(p + Vector2(0, 2), 10.0, Color(0, 0, 0, 0.25))
	ci.draw_circle(p, 10.0, INK)
	ci.draw_circle(p, 8.5, Color.WHITE)
	var col := PIN_LOCKED
	if state == CLEARED:
		col = PIN_DONE
	elif state == CURRENT:
		col = PIN_NEXT
	ci.draw_circle(p, 6.5, col)
	if state == CLEARED:
		ci.draw_polyline(PackedVector2Array([p + Vector2(-3.2, 0), p + Vector2(-0.8, 2.6), p + Vector2(3.4, -2.6)]),
				Color.WHITE, 1.8, true)
	elif state == LOCKED:
		ci.draw_rect(Rect2(p.x - 3.2, p.y - 1.0, 6.4, 4.6), Color.WHITE)
		ci.draw_arc(p + Vector2(0, -1.2), 2.2, PI, TAU, 8, Color.WHITE, 1.4, true)
	else:
		ci.draw_circle(p, 2.4, Color.WHITE)


func _draw_compass(ci: CanvasItem, c: Vector2, r: float) -> void:
	var light := Color("f3e2b3")
	var dark := Color("b98a4c")
	ci.draw_circle(c, r * 0.68, Color(1, 1, 1, 0.08))
	ci.draw_arc(c, r * 0.68, 0, TAU, 48, Color(light, 0.8), 1.5, true)
	ci.draw_arc(c, r * 0.58, 0, TAU, 48, Color(light, 0.5), 1.0, true)
	for k in range(8):
		var a := -PI * 0.5 + k * PI * 0.25
		var reach := r if k % 2 == 0 else r * 0.55
		var tip := c + Vector2(cos(a), sin(a)) * reach
		var sl := c + Vector2(cos(a - PI * 0.25), sin(a - PI * 0.25)) * r * 0.16
		var sr := c + Vector2(cos(a + PI * 0.25), sin(a + PI * 0.25)) * r * 0.16
		var lit := Color("e0553f") if k == 0 else light
		var shade := Color("a63a2a") if k == 0 else dark
		ci.draw_colored_polygon(PackedVector2Array([c, sl, tip]), lit)
		ci.draw_colored_polygon(PackedVector2Array([c, tip, sr]), shade)
		ci.draw_polyline(PackedVector2Array([sl, tip, sr]), Color(INK, 0.6), 1.0, true)
	ci.draw_circle(c, 3.0, INK)
	var font := get_theme_default_font()
	ci.draw_string(font, c + Vector2(-20, -r - 6), "N", HORIZONTAL_ALIGNMENT_CENTER, 40, 16, light)

# ---------------------------------------------------------------- props

func _draw_prop(ci: CanvasItem, d: Dictionary) -> void:
	var p: Vector2 = d["p"]
	match d["kind"]:
		"tree":
			_draw_tree(ci, p, d["s"], d["tint"])
		"pine":
			_draw_pine(ci, p, d["s"], d["tint"])
		"palm":
			_draw_palm(ci, p, d["s"])
		"mountain":
			_draw_mountain(ci, p, d["w"], d["h"], d["snow"])
		"volcano":
			_draw_volcano(ci, p)
		"pyramid":
			_draw_pyramid(ci, p, d["w"], d["h"])
		"house":
			_draw_house(ci, p, d["s"], d["roof"])
		"lighthouse":
			_draw_lighthouse(ci, p)
		"rock":
			_draw_rock(ci, p, d["s"])
		"reed":
			_draw_reed(ci, p, d["s"])


func _shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, SHADOW)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tree(ci: CanvasItem, p: Vector2, s: float, tint: float) -> void:
	_shadow(ci, p + Vector2(s * 0.35, 0.5), s * 1.05, s * 0.45)
	ci.draw_rect(Rect2(p.x - s * 0.16, p.y - s * 0.75, s * 0.32, s * 0.75), TRUNK)
	var c := p + Vector2(0, -s * 1.2)
	var leaf := TREE.lerp(TREE_LIGHT, tint * 0.8)
	ci.draw_circle(c, s + 1.3, TREE_DARK)
	ci.draw_circle(c, s, leaf)
	ci.draw_circle(c + Vector2(-s * 0.3, -s * 0.32), s * 0.45, leaf.lightened(0.16))


func _draw_pine(ci: CanvasItem, p: Vector2, s: float, tint: float) -> void:
	_shadow(ci, p + Vector2(s * 0.35, 0.5), s * 0.9, s * 0.4)
	ci.draw_rect(Rect2(p.x - s * 0.12, p.y - s * 0.5, s * 0.24, s * 0.5), TRUNK)
	var col := PINE.lerp(TREE, tint * 0.6)
	for k in range(3):
		var y := p.y - s * 0.35 - k * s * 0.6
		var w := s * (0.95 - k * 0.2)
		var tri := PackedVector2Array([Vector2(p.x - w, y), Vector2(p.x, y - s * 1.05), Vector2(p.x + w, y)])
		ci.draw_colored_polygon(tri, col)
		ci.draw_polyline(_closed(tri), TREE_DARK, 1.1, true)


func _draw_palm(ci: CanvasItem, p: Vector2, s: float) -> void:
	_shadow(ci, p + Vector2(s * 0.5, 0.5), s * 0.9, s * 0.32)
	var top := p + Vector2(s * 0.35, -s * 1.9)
	ci.draw_polyline(PackedVector2Array([p, p + Vector2(-s * 0.05, -s * 1.0), top]), TRUNK, 2.4, true)
	for k in range(5):
		var a := -PI * 0.5 + (k - 2) * 0.72
		var tip := top + Vector2(cos(a) * s * 1.15, sin(a) * s * 0.55 + s * 0.45)
		var mid := top.lerp(tip, 0.5) + Vector2(0, -s * 0.25)
		ci.draw_polyline(PackedVector2Array([top, mid, tip]), Color("3f9a3f"), 3.0, true)
	ci.draw_circle(top, 2.0, Color("6b4a2a"))


func _draw_mountain(ci: CanvasItem, base: Vector2, w: float, h: float, snow: bool) -> void:
	var peak := base + Vector2(w * 0.04, -h)
	var left := base + Vector2(-w * 0.5, 0)
	var right := base + Vector2(w * 0.5, 0)
	var crease := base + Vector2(w * 0.1, 0)
	var l1 := left.lerp(peak, 0.55) + Vector2(-3, 1)
	var r1 := right.lerp(peak, 0.6) + Vector2(3, 2)
	_shadow(ci, base + Vector2(w * 0.1, 0), w * 0.55, 6.0)
	ci.draw_colored_polygon(PackedVector2Array([left, l1, peak, crease]), ROCK)
	ci.draw_colored_polygon(PackedVector2Array([crease, peak, r1, right]), ROCK_DARK)
	if snow:
		var sl := peak.lerp(l1, 0.42)
		var sr := peak.lerp(r1, 0.4)
		var sc := peak.lerp(crease, 0.3)
		ci.draw_colored_polygon(PackedVector2Array([peak, sc, sl.lerp(sc, 0.5) + Vector2(0, 3), sl]), SNOW)
		ci.draw_colored_polygon(PackedVector2Array([peak, sr, sr.lerp(sc, 0.5) + Vector2(0, 3), sc]), Color("d8dde6"))
	ci.draw_polyline(PackedVector2Array([left, l1, peak, r1, right]), INK, 1.6, true)
	ci.draw_line(peak, crease.lerp(peak, 0.35), Color(INK, 0.5), 1.0, true)


func _draw_volcano(ci: CanvasItem, base: Vector2) -> void:
	var w := 128.0
	var h := 84.0
	var left := base + Vector2(-w * 0.5, 0)
	var right := base + Vector2(w * 0.5, 0)
	var rim_l := base + Vector2(-w * 0.13, -h)
	var rim_r := base + Vector2(w * 0.13, -h)
	var crease := base + Vector2(w * 0.12, 0)
	_shadow(ci, base + Vector2(10, 0), w * 0.6, 8.0)
	ci.draw_colored_polygon(PackedVector2Array([left, rim_l, rim_l.lerp(rim_r, 0.6), crease]), Color("7d5a45"))
	ci.draw_colored_polygon(PackedVector2Array([crease, rim_l.lerp(rim_r, 0.6), rim_r, right]), Color("5a3e30"))
	for lava: Array in [[0.45, -0.3], [0.6, 0.25], [0.52, 0.05]]:
		var start := rim_l.lerp(rim_r, lava[0])
		var stop := start + Vector2(w * float(lava[1]), h * 0.62)
		ci.draw_polyline(_smooth_open([start, start.lerp(stop, 0.5) + Vector2(4, 0), stop], 4), LAVA, 2.4, true)
	ci.draw_set_transform(rim_l.lerp(rim_r, 0.5), 0.0, Vector2(1.0, 0.32))
	ci.draw_circle(Vector2.ZERO, w * 0.13, Color("3b2620"))
	ci.draw_circle(Vector2(0, 2), w * 0.09, LAVA)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_polyline(PackedVector2Array([left, rim_l, rim_r, right]), INK, 1.6, true)


func _draw_pyramid(ci: CanvasItem, base: Vector2, w: float, h: float) -> void:
	var apex := base + Vector2(w * 0.05, -h)
	var left := base + Vector2(-w * 0.5, 0)
	var right := base + Vector2(w * 0.5, 0)
	var mid := base + Vector2(w * 0.15, 0)
	_shadow(ci, base + Vector2(w * 0.25, 0), w * 0.55, 5.0)
	ci.draw_colored_polygon(PackedVector2Array([left, apex, mid]), Color("f1d58f"))
	ci.draw_colored_polygon(PackedVector2Array([mid, apex, right]), Color("c99d55"))
	for k in range(1, 4):
		var t := float(k) / 4.0
		ci.draw_line(left.lerp(apex, t), mid.lerp(apex, t), Color("c9a75a"), 1.0, true)
	ci.draw_polyline(PackedVector2Array([left, apex, right, left]), INK, 1.4, true)


func _draw_house(ci: CanvasItem, p: Vector2, s: float, roof: Color) -> void:
	_shadow(ci, p + Vector2(s * 0.5, 0), s * 0.95, s * 0.3)
	var w := s * 1.25
	var h := s * 0.8
	var body := Rect2(p.x - w * 0.5, p.y - h, w, h)
	ci.draw_rect(body, WALL)
	ci.draw_rect(body, INK, false, 1.2)
	var tri := PackedVector2Array([Vector2(p.x - w * 0.62, p.y - h), Vector2(p.x, p.y - h - s * 0.75),
			Vector2(p.x + w * 0.62, p.y - h)])
	ci.draw_colored_polygon(tri, roof)
	ci.draw_polyline(_closed(tri), INK, 1.2, true)
	ci.draw_rect(Rect2(p.x - s * 0.13, p.y - s * 0.42, s * 0.26, s * 0.42), Color("7a4a26"))


func _draw_lighthouse(ci: CanvasItem, p: Vector2) -> void:
	_shadow(ci, p + Vector2(10, 0), 14.0, 4.0)
	var tower := PackedVector2Array([p + Vector2(-6, 0), p + Vector2(-4, -30), p + Vector2(4, -30), p + Vector2(6, 0)])
	ci.draw_colored_polygon(tower, Color("f6f1e7"))
	for k in range(2):
		var y0 := -6.0 - k * 12.0
		var band := PackedVector2Array([p + Vector2(-5.6, y0), p + Vector2(-5.2, y0 - 5),
				p + Vector2(5.2, y0 - 5), p + Vector2(5.6, y0)])
		ci.draw_colored_polygon(band, Color("d0453a"))
	ci.draw_polyline(_closed(tower), INK, 1.3, true)
	ci.draw_rect(Rect2(p.x - 6, p.y - 33, 12, 3), INK)
	ci.draw_rect(Rect2(p.x - 3.5, p.y - 40, 7, 7), Color("ffe08a"))
	ci.draw_rect(Rect2(p.x - 3.5, p.y - 40, 7, 7), INK, false, 1.0)
	var cap := PackedVector2Array([p + Vector2(-5, -40), p + Vector2(0, -46), p + Vector2(5, -40)])
	ci.draw_colored_polygon(cap, Color("d0453a"))
	ci.draw_polyline(_closed(cap), INK, 1.0, true)


func _draw_rock(ci: CanvasItem, p: Vector2, s: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-s, 0), p + Vector2(-s * 0.7, -s * 0.7), p + Vector2(-s * 0.1, -s),
			p + Vector2(s * 0.6, -s * 0.6), p + Vector2(s, 0)])
	_shadow(ci, p + Vector2(s * 0.3, 0.5), s * 1.1, s * 0.3)
	ci.draw_colored_polygon(pts, ROCK)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.1, -s), p + Vector2(s * 0.6, -s * 0.6),
			p + Vector2(s, 0), p + Vector2(0, 0)]), ROCK_DARK)
	ci.draw_polyline(_closed(pts), INK, 1.2, true)


func _draw_reed(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_line(p, p + Vector2(-1.5, -s), Color("3c5a2a"), 1.2, true)
	ci.draw_line(p + Vector2(2, 0), p + Vector2(3, -s * 0.8), Color("3c5a2a"), 1.2, true)
	ci.draw_line(p + Vector2(-1.4, -s), p + Vector2(-1.6, -s + 3.5), Color("6b4a2a"), 2.4, true)

# ================================================================ DRAW: ANIMATED LAYER

func _draw_fx() -> void:
	var ci := _fx
	if AMBIENT_MOTION:
		for w in _waves:
			var p := Vector2(w.x + sin(_time * 0.6 + w.z) * 4.0, w.y)
			var alpha := 0.24 + 0.12 * sin(_time * 0.9 + w.z)
			var pts := PackedVector2Array()
			for k in range(9):
				var t := float(k) / 8.0
				pts.append(p + Vector2(t * 30.0, sin(t * TAU) * 2.5))
			ci.draw_polyline(pts, Color(1, 1, 1, alpha), 1.6, true)
		_draw_smoke(ci)

	_draw_ribbon_tails(ci)
	_draw_restored_reefs(ci)

	if _current >= 0:
		var spot := _spots[_current]
		var pulse := fmod(_time * 0.7, 1.0)
		ci.draw_arc(spot, 11.0 + pulse * 14.0, 0, TAU, 32, Color(PIN_NEXT, 0.8 * (1.0 - pulse)), 2.0, true)
		var bob := sin(_time * 2.0) * 2.0 if AMBIENT_MOTION else 0.0
		_draw_sub(ci, _sub_pos + Vector2(0, bob), signf(spot.x - _sub_pos.x))


## W8: an island whose coral actually came back gets a small living reef marker
## beside its dive pin — the map's record of the restoration component. Drawn in
## the animated layer so it can pulse, like every other living thing on the map.
func _draw_restored_reefs(ci: CanvasItem) -> void:
	for i in range(_spots.size()):
		if not GameProgress.is_reef_restored(String(ISLAND_BUTTONS.keys()[i])):
			continue
		var at := _spots[i] + Vector2(BANNER_SIZE.x * 0.5 + 18.0, 10.0)
		var beat := 0.5 + 0.5 * sin(_time * 2.0 + float(i))
		ci.draw_circle(at + Vector2(0, 4), 19.0, Color(0.05, 0.30, 0.24, 0.35))
		for k in range(5):
			var a := TAU * float(k) / 5.0 + 0.4
			var tip := at + Vector2(cos(a), sin(a)) * (11.0 + 1.6 * beat)
			ci.draw_line(at, tip, Color("ff7aa2"), 3.4, true)
			ci.draw_line(at, tip, Color("ffd7e2"), 1.8, true)
			ci.draw_circle(tip, 2.0 + beat, Color(1.0, 0.96, 0.80, 0.9))
		ci.draw_circle(at, 4.0, Color("ff9ab8"))


func _draw_smoke(ci: CanvasItem) -> void:
	var origin := VOLCANO + Vector2(0, -86)
	for k in range(5):
		var t := fmod(_time * 0.18 + float(k) / 5.0, 1.0)
		var p := origin + Vector2(t * 26.0 + sin(t * 6.0 + k) * 4.0, -t * 70.0)
		var a := (1.0 - t) * minf(t * 6.0, 1.0) * 0.55
		ci.draw_circle(p, 5.0 + t * 10.0, Color(0.85, 0.85, 0.85, a))


func _draw_ribbon_tails(ci: CanvasItem) -> void:
	for i in range(_banners.size()):
		var btn := _banners[i]
		var half := btn.size * 0.5
		var c := btn.position + half
		var sc := btn.scale.x
		var rot := btn.rotation
		var face := BANNER_LOCKED.darkened(0.25)
		if _states[i] != LOCKED:
			face = Color("c9893f") if _states[i] == CURRENT else Color("d9b98a")
		for side: float in [-1.0, 1.0]:
			var x0 := side * (half.x - 6.0)
			var x1 := side * (half.x + 16.0)
			var y0 := -half.y + 10.0
			var y1 := half.y + 6.0
			var notch := Vector2(x1 - side * 7.0, (y0 + y1) * 0.5)
			var local := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), notch, Vector2(x1, y1), Vector2(x0, y1)])
			var tail := Transform2D(rot, Vector2(sc, sc), 0.0, c) * local
			ci.draw_colored_polygon(tail, face)
			ci.draw_polyline(_closed(tail), Color(INK, 0.8), 1.4, true)


func _draw_sub(ci: CanvasItem, p: Vector2, dir: float) -> void:
	ci.draw_set_transform(p, 0.0, Vector2(dir, 1.0) * 1.2)
	var hull := PackedVector2Array()
	for k in range(24):
		var a := TAU * float(k) / 24.0
		hull.append(Vector2(cos(a) * 17.0, sin(a) * 7.0))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -6), Vector2(-3, -13), Vector2(6, -13), Vector2(7, -6)]),
			Color("f2b531"))
	ci.draw_polyline(PackedVector2Array([Vector2(-4, -6), Vector2(-3, -13), Vector2(6, -13), Vector2(7, -6)]), INK, 1.2, true)
	ci.draw_line(Vector2(2, -13), Vector2(2, -18), INK, 1.4, true)
	ci.draw_line(Vector2(2, -18), Vector2(6, -18), INK, 1.4, true)
	ci.draw_colored_polygon(hull, Color("ffcb3d"))
	ci.draw_polyline(_closed(hull), INK, 1.4, true)
	ci.draw_circle(Vector2(6, 0), 3.0, INK)
	ci.draw_circle(Vector2(6, 0), 2.0, Color("9fe3ff"))
	ci.draw_circle(Vector2(-3, 0), 2.0, Color("9fe3ff"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(-22, -5), Vector2(-22, 5)]), Color("e09a2a"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ================================================================ GEOMETRY HELPERS

func _fill(ci: CanvasItem, poly: PackedVector2Array, col: Color, soft_edge: bool = true) -> void:
	if poly.size() < 3:
		return
	ci.draw_colored_polygon(poly, col)
	if soft_edge:
		ci.draw_polyline(_closed(poly), col, 1.0, true)


func _outline(ci: CanvasItem, poly: PackedVector2Array, col: Color, width: float) -> void:
	if poly.size() >= 3:
		ci.draw_polyline(_closed(poly), col, width, true)


func _draw_dashed(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float, dash: float, gap: float) -> void:
	var drawing := true
	var remaining := dash
	var piece := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		var pos := 0.0
		while seg - pos > remaining:
			pos += remaining
			var q := a.lerp(b, pos / seg)
			if drawing:
				piece.append(q)
				ci.draw_polyline(piece, col, width, true)
				remaining = gap
			else:
				piece = PackedVector2Array([q])
				remaining = dash
			drawing = not drawing
		remaining -= seg - pos
		if drawing:
			piece.append(b)
	if drawing and piece.size() >= 2:
		ci.draw_polyline(piece, col, width, true)


func _route_between(a: Vector2, b: Vector2) -> PackedVector2Array:
	var n := _route_loop.size()
	var ia := _nearest_index(_route_loop, a)
	var ib := _nearest_index(_route_loop, b)
	var fwd := (ib - ia + n) % n
	var back := (ia - ib + n) % n
	var path := PackedVector2Array([a])
	if fwd <= back:
		for k in range(fwd + 1):
			path.append(_route_loop[(ia + k) % n])
	else:
		for k in range(back + 1):
			path.append(_route_loop[(ia - k + n) % n])
	path.append(b)
	return path


func _nearest_index(pts: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in range(pts.size()):
		var d := pts[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _smooth_loop(ctrl: Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in range(n):
		var p0: Vector2 = ctrl[(i - 1 + n) % n]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % n]
		var p3: Vector2 = ctrl[(i + 2) % n]
		for s in range(steps):
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(steps)))
	return out


func _smooth_open(ctrl: Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in range(n - 1):
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		for s in range(steps):
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(steps)))
	var last: Vector2 = ctrl[n - 1]
	out.append(last)
	return out


func _roughen(pts: PackedVector2Array, amount: float, phase: float) -> PackedVector2Array:
	# push each point in/out along its normal with looping noise (seamless)
	var n := pts.size()
	var total := 0.0
	for i in range(n):
		total += pts[i].distance_to(pts[(i + 1) % n])
	var radius := total / TAU
	var out := PackedVector2Array()
	var dist := 0.0
	for i in range(n):
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var a := dist / radius
		var t := (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized()
		var nrm := Vector2(t.y, -t.x)
		out.append(pts[i] + nrm * _noise.get_noise_3d(cos(a) * radius, sin(a) * radius, phase * 97.0) * amount)
	return out


func _inset(pts: PackedVector2Array, w_min: float, w_max: float, phase: float) -> PackedVector2Array:
	# move each point inward by a smoothly varying amount (variable-width beaches)
	var n := pts.size()
	var sgn := 1.0 if _area(pts) > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in range(n):
		var t := (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized()
		var outward := Vector2(t.y, -t.x) * sgn
		var k := clampf(0.5 + _noise.get_noise_3d(pts[i].x * 0.4, pts[i].y * 0.4, phase * 131.0) * 1.4, 0.0, 1.0)
		out.append(pts[i] - outward * lerpf(w_min, w_max, k))
	return out


func _blob(center: Vector2, radius: Vector2, seed_val: int, count: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var pts := PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var w := 1.0 + 0.12 * sin(a * 2.0 + p1) + 0.07 * sin(a * 3.0 + p2) + 0.04 * sin(a * 5.0 + p3)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * w)
	return pts


func _strip(path: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := path.size()
	for i in range(n):
		var t := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-t.y, t.x) * lerpf(w0, w1, float(i) / float(n - 1)) * 0.5
		left.append(path[i] + nrm)
		right.append(path[i] - nrm)
	right.reverse()
	return left + right


func _cut_at_coast(path: PackedVector2Array, land: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in path:
		if not Geometry2D.is_point_in_polygon(p, land):
			break
		out.append(p)
	return out


func _chaikin(pts: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var cur := pts
	for _it in range(iterations):
		var nxt := PackedVector2Array()
		var n := cur.size()
		for i in range(n):
			nxt.append(cur[i].lerp(cur[(i + 1) % n], 0.25))
			nxt.append(cur[i].lerp(cur[(i + 1) % n], 0.75))
		cur = nxt
	return cur


func _resample(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var n := pts.size()
	var acc := 0.0
	for i in range(n):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var seg := a.distance_to(b)
		var pos := spacing - acc
		while pos <= seg:
			out.append(a.lerp(b, pos / seg))
			pos += spacing
		acc = seg - (pos - spacing)
	return out


func _dist_to_path(p: Vector2, path: PackedVector2Array) -> float:
	var best := INF
	for i in range(path.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])))
	return best


func _grow(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	return _biggest(Geometry2D.offset_polygon(poly, delta, Geometry2D.JOIN_ROUND))


func _closing(poly: PackedVector2Array, delta: float, bridge: float) -> PackedVector2Array:
	# grow then shrink: bridges bays narrower than ~2 * bridge (smooth sailing line)
	return _grow(_grow(poly, delta + bridge), -bridge)


func _clean(poly: PackedVector2Array, fallback: PackedVector2Array) -> PackedVector2Array:
	# roughening can make a shape cross itself; merge it with itself to untangle,
	# and fall back to the smooth version if that still fails
	if not Geometry2D.triangulate_polygon(poly).is_empty():
		return poly
	var fixed := _biggest(Geometry2D.merge_polygons(poly, poly))
	if not Geometry2D.triangulate_polygon(fixed).is_empty():
		return fixed
	return fallback


func _clip(poly: PackedVector2Array, inside: PackedVector2Array) -> PackedVector2Array:
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
	var a := 0.0
	for i in range(pts.size()):
		a += pts[i].cross(pts[(i + 1) % pts.size()])
	return a * 0.5


func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(1.0, float(pts.size()))


func _moved(poly: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, off) * poly


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	if poly.size() > 0:
		out.append(poly[0])
	return out
