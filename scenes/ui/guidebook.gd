extends Control
## The Guidebook (W8) — the reef's field guide, opened from the world map.
##
## This replaces the hovering bestiary overlay. The old version never sized
## itself: it was added to a parent Control that had already finished its layout
## pass, so anchors alone left it 0x0 and its own _draw() bailed out — every
## label landed on top of the map with no book under it. The fix is that this
## node owns its rect outright (see _layout) and the first thing _draw() paints
## is a fully opaque backdrop, so nothing from the map can show through.
##
## Everything is drawn in code, exactly like world_map.gd and reef_floor.gd — the
## owner's reference image is a watermarked stock asset used for STYLE ONLY and
## is not copied or shipped here. The look it asks for: near-black backdrop, a
## green coral cover grown inward from the corners, cream parchment pages with
## faint blotches and a shaded centre gutter, a white diamond ornament above the
## book, and bookmark tabs at the bottom that double as the species selector.
##
## Content comes from systems/species_db.gd — the same single source of truth the
## enemy, the wave manager and the friendly creatures read — so the book can
## never disagree with the water. Every species has a named entry with its own
## art, stats and zones: discovery only badges an entry, it never hides one.
##
## Public API (used by world_map.gd and tools/verify_ui.gd):
##   open()  close()  is_open()  step(dir)  signal closed

const SpeciesDB := preload("res://systems/species_db.gd")
const ReefArt := preload("res://scenes/levels/reef_art.gd")

signal closed

const BG := Color("0b0d10")
const COVER := Color("3f7a2a")
const COVER_LIGHT := Color("8dc24a")
const COVER_DARK := Color("26521a")
const PAGE := Color("e9d6a9")
const PAGE_LIGHT := Color("f2e3bd")
const PAGE_SHADE := Color("d8c08a")
const PAGE_BAND := Color("b7905c")
const INK := Color("4a2f18")
const INK_SOFT := Color("6d4a24")
const HELPER_INK := Color("1d6039")
const ACCENT := Color("f6f7f2")
const THREAT_COLOUR := [Color("5c8f3a"), Color("c9a227"), Color("c0492c")]

const COVER_EDGE := 34.0
const SPINE := 26.0
const TAB_SIZE := Vector2(112, 26)
const FONT_SIZES := {"name": 34, "head": 17, "body": 15, "small": 13, "tiny": 12}

var _ids: Array[String] = []
var _index := 0
var _time := 0.0

var _book := Rect2()
var _pages := Rect2()
var _left_page := Rect2()
var _right_page := Rect2()
var _portrait := Rect2()

var _name_label: Label
var _meta_label: Label
var _blurb_label: Label
var _lore_label: Label
var _stats_label: Label
var _weak_label: Label
var _zone_label: Label
var _progress_label: Label
var _footer_label: Label
var _helper_caption: Label
var _tabs: Array[Button] = []
var _prev_button: Button
var _next_button: Button
var _close_button: Button
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Guidebook"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# Closed is the normal state on the map, so a closed book processes nothing:
	# open() turns the per-frame redraw back on.
	set_process(false)
	_ids = SpeciesDB.get_all_guidebook_ids()
	_build_children()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_children() -> void:
	_name_label = _make_label(FONT_SIZES["name"], INK)
	_meta_label = _make_label(FONT_SIZES["head"], INK_SOFT)
	_blurb_label = _make_label(FONT_SIZES["body"], INK_SOFT)
	_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_label = _make_label(FONT_SIZES["small"], INK_SOFT)
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label = _make_label(FONT_SIZES["body"], INK)
	_weak_label = _make_label(FONT_SIZES["body"], INK)
	_weak_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_label = _make_label(FONT_SIZES["body"], INK)
	_zone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label = _make_label(FONT_SIZES["small"], INK_SOFT)
	_footer_label = _make_label(FONT_SIZES["small"], INK_SOFT)
	_helper_caption = _make_label(FONT_SIZES["small"], HELPER_INK)
	_helper_caption.visible = false

	for i in _ids.size():
		var tab := Button.new()
		tab.custom_minimum_size = TAB_SIZE
		tab.size = TAB_SIZE
		tab.add_theme_font_size_override("font_size", 12)
		tab.pressed.connect(_select.bind(i))
		add_child(tab)
		_tabs.append(tab)

	_prev_button = _page_button("<", Vector2(30, 34))
	_prev_button.pressed.connect(func() -> void: step(-1))
	_next_button = _page_button(">", Vector2(30, 34))
	_next_button.pressed.connect(func() -> void: step(1))
	_close_button = _page_button("Close  (Esc)", Vector2(140, 34))
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.pressed.connect(close)


func _page_button(text: String, size_v: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.size = size_v
	button.custom_minimum_size = size_v
	button.add_theme_font_size_override("font_size", 20)
	add_child(button)
	return button


# ================================================================ PUBLIC API

func open() -> void:
	visible = true
	set_process(true)
	_refresh()
	move_to_front()
	# The book has to be in front of the map's own buttons, not just its art.
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).z_index = 1


func close() -> void:
	visible = false
	set_process(false)
	closed.emit()


func is_open() -> bool:
	return visible


func step(direction: int) -> void:
	if _ids.is_empty():
		return
	_index = posmod(_index + direction, _ids.size())
	_refresh()


func _select(index: int) -> void:
	_index = clampi(index, 0, maxi(0, _ids.size() - 1))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		step(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		step(-1)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ================================================================ CONTENT

func _refresh() -> void:
	if _ids.is_empty():
		return
	var sid := _ids[_index]
	var friendly := SpeciesDB.is_friendly(sid)
	var data := SpeciesDB.get_species_any(sid)
	var recorded := GameProgress.has_seen_species(sid)
	var threat := int(data.get("threat", 1))

	_name_label.text = String(data.get("name", sid))
	_name_label.add_theme_color_override("font_color", HELPER_INK if friendly else INK)

	var standing := "REEF HELPER — HARMLESS" if friendly \
			else "THREAT %s" % _threat_pips(threat)
	_meta_label.text = "%s   •   %s   •   %s" % [sid, standing,
			"RECORDED" if recorded else "NOT YET RECORDED"]
	_meta_label.add_theme_color_override("font_color",
			HELPER_INK if friendly else INK_SOFT)

	_blurb_label.text = String(data.get("blurb", ""))
	_lore_label.text = String(data.get("lore", ""))
	_stats_label.text = _helper_stats_text(data) if friendly else _stats_text(data)
	if friendly:
		_weak_label.text = "REEF ROLE   %s — %s\nHARM TO YOU   None. It never attacks the sentinel." % [
			String(data.get("role", "HELPER")), String(data.get("help", ""))]
	else:
		_weak_label.text = "WEAKNESS   %s\nRESISTS    %s" % [
			SpeciesDB.weakness_text(sid), SpeciesDB.resists_text(sid)]
	_zone_label.text = _zones_text(sid, friendly)
	_helper_caption.visible = friendly
	_helper_caption.text = "REEF HELPER — works the coral, cannot be harmed"

	var seen := 0
	for id: String in _ids:
		if GameProgress.has_seen_species(id):
			seen += 1
	_progress_label.text = "FIELD LOG   %d / %d species recorded" % [seen, _ids.size()]
	_footer_label.text = "REEFS RESTORED   %d / %d islands   •   entry %d / %d" % [
		GameProgress.restored_reef_count(), 3, _index + 1, _ids.size()]

	for i in _tabs.size():
		_tab_label_text(i, _ids[i])
	_layout()


## Tabs are the species selector, and they are labelled even for species the
## player has not met: the book is a guide, so it names what is out there.
func _tab_label_text(i: int, sid: String) -> void:
	var tab := _tabs[i]
	var data := SpeciesDB.get_species_any(sid)
	var friendly := SpeciesDB.is_friendly(sid)
	var recorded := GameProgress.has_seen_species(sid)
	tab.text = String(data.get("name", sid)).to_upper()
	var box := StyleBoxFlat.new()
	var base := COVER if not friendly else Color("2f6d4a")
	# an entry the player has not met yet stays on the shelf, slightly dimmer, but
	# it keeps its name: this book names every species in the reef.
	if not recorded and i != _index:
		base = base.darkened(0.22)
	box.bg_color = COVER_LIGHT if i == _index else base
	box.border_color = COVER_DARK
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	tab.add_theme_stylebox_override("normal", box)
	tab.add_theme_color_override("font_color", Color("1c3a12") if i == _index else Color("eaf7dd"))
	tab.add_theme_color_override("font_hover_color", Color("102009"))


func _threat_pips(threat: int) -> String:
	var out := ""
	for i in 3:
		out += "*" if i < threat else "-"
	return out


func _bar(value: float, scale_max: float) -> String:
	var slots := 10
	var filled := int(round(clampf(value / maxf(0.001, scale_max), 0.0, 1.0) * float(slots)))
	var out := "["
	for i in slots:
		out += "#" if i < filled else "."
	out += "]"
	return out


func _stats_text(data: Dictionary) -> String:
	var base: Dictionary = data.get("baseline", {})
	var armor := float(base.get("acoustic_armor", 0.0))
	var spiky := float(base.get("spiky_shell", 0.0))
	var heat := float(base.get("heat_sink", 0.0))
	var speed := float(base.get("speed_multiplier", 1.0))
	var health := float(base.get("max_health", 50.0))
	return "BASE STRAIN\n  ARMOUR      %.2f  %s\n  SPIKES      %.2f  %s\n  HEAT SINK   %.2f  %s\n  SWIM SPEED  %.2f  %s\n  BODY MASS   %.0f  %s" % [
		armor, _bar(armor, 0.8),
		spiky, _bar(spiky, 0.8),
		heat, _bar(heat, 0.8),
		speed, _bar(speed, 1.8),
		health, _bar(health, 120.0)]


## Helpers have no combat stat block, so their entry shows reef work instead —
## the same shape of block, so both kinds of entry read the same way.
func _helper_stats_text(data: Dictionary) -> String:
	var rate := float(data.get("restore_rate", 0.0))
	return "REEF WORK\n  ROLE        %s\n  RESTORE     +%.2f / s  %s\n  DIET        invasive growth\n  HARM TO YOU none  %s\n  HABITAT     %s" % [
		String(data.get("role", "HELPER")),
		rate, _bar(rate, 1.5),
		_bar(0.0, 1.0),
		SpeciesDB.zone_label(String(data.get("home_zone", "open_water")))]


## Where a species can be met — one row per island — annotated with whether that
## island's reef has actually been restored, so the book doubles as a progress
## board for the restoration component.
func _zones_text(sid: String, friendly: bool) -> String:
	var rows := SpeciesDB.spawn_rows(sid)
	if rows.is_empty():
		return "SPAWN ZONES\n  not yet observed"
	var out := "REEF SITES — every dive" if friendly else "SPAWN ZONES"
	for row: Dictionary in rows:
		var island := String(row["island"])
		var others: Array = row.get("others", [])
		out += "\n  %s — home: %s %s" % [island.capitalize(), row["home"],
				"✓ RESTORED" if GameProgress.is_reef_restored(island) else ""]
		if not others.is_empty():
			out += "\n     also in: %s" % ", ".join(others)
	return out


# ================================================================ LAYOUT

## The book owns its rect. Anchors alone left this node 0x0 when it was added to
## a parent that had already laid itself out, which silently killed the whole
## _draw() path — so position and size are set here, every layout pass.
func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x < 200.0 or view.y < 160.0:
		return
	if absf(size.x - view.x) > 0.5 or absf(size.y - view.y) > 0.5:
		size = view
	if position != Vector2.ZERO:
		position = Vector2.ZERO

	var tabs_height := TAB_SIZE.y * 2.0 + 10.0
	var mx := view.x * 0.045
	var my := view.y * 0.055
	_book = Rect2(Vector2(mx, my), Vector2(view.x - mx * 2.0, view.y - my * 2.0 - tabs_height))
	_pages = _book.grow(-COVER_EDGE)
	_pages.size.y -= 8.0
	var half := (_pages.size.x - SPINE) * 0.5
	_left_page = Rect2(_pages.position, Vector2(half, _pages.size.y))
	_right_page = Rect2(_pages.position + Vector2(half + SPINE, 0.0), Vector2(half, _pages.size.y))

	var pad := 24.0
	# ---- left page: name, meta, portrait, blurb, and the long field note
	_name_label.position = _left_page.position + Vector2(pad, pad - 4.0)
	_name_label.size = Vector2(_left_page.size.x - pad * 2.0, 40.0)
	_meta_label.position = _left_page.position + Vector2(pad, pad + 38.0)
	_meta_label.size = Vector2(_left_page.size.x - pad * 2.0, 26.0)
	var plate_top := pad + 70.0
	var plate_h := clampf(_left_page.size.y * 0.40, 120.0, 230.0)
	_portrait = Rect2(_left_page.position + Vector2(pad, plate_top),
			Vector2(_left_page.size.x - pad * 2.0, plate_h))
	_blurb_label.position = _portrait.position + Vector2(0.0, _portrait.size.y + 8.0)
	_blurb_label.size = Vector2(_portrait.size.x, 52.0)
	_helper_caption.position = _blurb_label.position + Vector2(0.0, 54.0)
	_helper_caption.size = Vector2(_portrait.size.x, 20.0)
	_lore_label.position = _blurb_label.position + Vector2(0.0, 78.0)
	_lore_label.size = Vector2(_portrait.size.x,
			_left_page.end.y - _lore_label.position.y - pad)

	# ---- right page: log, stat block, weakness, zones, footer
	var rp := _right_page.position + Vector2(pad, pad - 4.0)
	var rw := _right_page.size.x - pad * 2.0
	_progress_label.position = rp
	_progress_label.size = Vector2(rw, 20.0)
	_stats_label.position = rp + Vector2(0.0, 26.0)
	_stats_label.size = Vector2(rw, 140.0)
	_weak_label.position = rp + Vector2(0.0, 172.0)
	_weak_label.size = Vector2(rw, 62.0)
	_zone_label.position = rp + Vector2(0.0, 238.0)
	_zone_label.size = Vector2(rw, 150.0)
	_footer_label.position = Vector2(_right_page.position.x + pad, _right_page.end.y - pad - 6.0)
	_footer_label.size = Vector2(rw, 20.0)

	# ---- bookmark tabs, hanging off the bottom edge of the cover in two rows:
	#      invaders first, reef helpers under them
	var invaders := SpeciesDB.ORDER.size()
	_place_tab_row(0, invaders, 0, view)
	_place_tab_row(invaders, _tabs.size() - invaders, 1, view)

	# Page turners sit inside the cover band, so a full-width book never pushes
	# them off the screen edge.
	var arrow_y := _pages.position.y + _pages.size.y * 0.5 - _prev_button.size.y * 0.5
	_prev_button.position = Vector2(_book.position.x + 3.0, arrow_y)
	_next_button.position = Vector2(_book.end.x - _next_button.size.x - 3.0, arrow_y)
	_close_button.position = Vector2(view.x - 158.0, 16.0)


func _place_tab_row(from: int, count: int, row: int, view: Vector2) -> void:
	if count <= 0:
		return
	var total := float(count) * TAB_SIZE.x
	var start := Vector2(view.x * 0.5 - total * 0.5,
			_book.end.y + 6.0 + float(row) * (TAB_SIZE.y + 4.0))
	for i in count:
		var tab := _tabs[from + i]
		tab.position = start + Vector2(float(i) * TAB_SIZE.x, 0.0)
		tab.size = TAB_SIZE


# ================================================================ DRAW

func _draw() -> void:
	var view := size
	if view.x < 200.0 or view.y < 160.0:
		return
	# Opaque, full-screen: the map behind the book must not read through it.
	draw_rect(Rect2(Vector2.ZERO, view), BG, true)
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.05, 0.16, 0.22, 0.35), true)
	_draw_ornament(Vector2(view.x * 0.5, _book.position.y - 18.0))
	_draw_cover()
	_draw_pages()
	_draw_portrait()


## Small white diamond above the book with a faint rule under it.
func _draw_ornament(centre: Vector2) -> void:
	var r := 9.0
	var diamond := PackedVector2Array([
		centre + Vector2(0, -r), centre + Vector2(r * 0.72, 0),
		centre + Vector2(0, r), centre + Vector2(-r * 0.72, 0)])
	draw_colored_polygon(diamond, ACCENT)
	draw_polyline(_ring(diamond), Color(ACCENT, 0.55), 1.0, true)
	draw_line(centre + Vector2(-70.0, r + 7.0), centre + Vector2(70.0, r + 7.0), Color(ACCENT, 0.28), 1.0)


## Green coral cover: a rounded slab plus leafy lobes grown inward from the
## corners, lighter sage highlights over a deeper green.
func _draw_cover() -> void:
	draw_rect(_book.grow(6.0), Color(0, 0, 0, 0.45), true)
	var cover := _rounded(_book, 14.0)
	draw_colored_polygon(cover, COVER)
	draw_polyline(_ring(cover), COVER_DARK, 3.0, true)
	var bevel := _rounded(_book.grow(-7.0), 12.0)
	draw_polyline(_ring(bevel), Color(COVER_LIGHT, 0.35), 2.0, true)

	_rng.seed = 20260407
	var corners := [
		_book.position,
		Vector2(_book.end.x, _book.position.y),
		Vector2(_book.position.x, _book.end.y),
		_book.end,
	]
	for corner: Vector2 in corners:
		for i in range(7):
			var t := float(i) / 6.0
			var along_x := 1.0 if corner.x < _book.get_center().x else -1.0
			var along_y := 1.0 if corner.y < _book.get_center().y else -1.0
			var base := corner + Vector2(along_x * t * 150.0, along_y * _rng.randf_range(4.0, 15.0))
			var r := _rng.randf_range(9.0, 21.0) * (1.0 - t * 0.35)
			var lobe := _blob(base, Vector2(r * 1.25, r), _rng.randi(), 14)
			draw_colored_polygon(lobe, COVER if i % 2 == 0 else COVER.darkened(0.12))
			draw_colored_polygon(_grow(lobe, -r * 0.34), Color(COVER_LIGHT, 0.85))
			draw_polyline(_ring(lobe), COVER_DARK, 1.6, true)
		for i in range(3):
			var tip := corner + Vector2(
				(1.0 if corner.x < _book.get_center().x else -1.0) * _rng.randf_range(40.0, 120.0),
				(1.0 if corner.y < _book.get_center().y else -1.0) * _rng.randf_range(60.0, 160.0))
			var mid := corner.lerp(tip, 0.5) + Vector2(_rng.randf_range(-18.0, 18.0), 0.0)
			draw_polyline(PackedVector2Array([corner, mid, tip]), Color(COVER_LIGHT, 0.45), 3.0, true)


func _draw_pages() -> void:
	for page: Rect2 in [_left_page, _right_page]:
		var sheet := _rounded(page.grow(6.0), 6.0)
		draw_colored_polygon(sheet, PAGE_BAND)
		var inner := _rounded(page, 5.0)
		draw_colored_polygon(inner, PAGE)
		for i in range(4):
			var t := float(i) / 3.0
			var wash := _rounded(page.grow(-6.0 - t * 10.0), 4.0)
			draw_colored_polygon(wash, Color(PAGE_LIGHT, 0.16 * (1.0 - t)))
		_rng.seed = int(page.position.x) * 31 + 7
		for _b in range(16):
			var p := Vector2(
				_rng.randf_range(page.position.x + 10.0, page.end.x - 10.0),
				_rng.randf_range(page.position.y + 10.0, page.end.y - 10.0))
			var rad := _rng.randf_range(8.0, 34.0)
			draw_colored_polygon(_blob(p, Vector2(rad * 1.4, rad), _rng.randi(), 16),
					Color(PAGE_SHADE, _rng.randf_range(0.10, 0.24)))
		draw_polyline(_ring(inner), PAGE_BAND, 2.4, true)
		draw_polyline(_ring(_rounded(page.grow(-9.0), 3.0)), Color(PAGE_BAND, 0.5), 1.2, true)

	# shaded centre gutter where the two pages meet
	var gutter_x := _left_page.end.x
	var top := _left_page.position.y
	var height := _left_page.size.y
	for i in range(14):
		var t := float(i) / 13.0
		var w := 3.0 + t * 30.0
		var alpha := 0.30 * (1.0 - t)
		draw_rect(Rect2(gutter_x + w * 0.5, top, w, height), Color(0.35, 0.26, 0.14, alpha), true)
		draw_rect(Rect2(gutter_x - w * 1.5, top, w, height), Color(0.35, 0.26, 0.14, alpha), true)
	draw_line(Vector2(gutter_x, top - 6.0), Vector2(gutter_x, top + height + 6.0),
			Color(0.30, 0.21, 0.11, 0.55), 2.0)


## Portrait plate on the left page. Invaders keep the six silhouettes the enemy
## draws; reef helpers reuse the very art the creature swims with
## (scenes/levels/reef_art.gd), so the book shows the animal, not an impression.
func _draw_portrait() -> void:
	if _portrait.size.x < 40.0 or _portrait.size.y < 40.0 or _ids.is_empty():
		return
	var sid := _ids[_index]
	var friendly := SpeciesDB.is_friendly(sid)
	var data := SpeciesDB.get_species_any(sid)
	var frame := _rounded(_portrait, 8.0)
	draw_colored_polygon(frame, Color(PAGE_SHADE, 0.55))
	draw_polyline(_ring(frame), PAGE_BAND, 2.0, true)
	var centre := _portrait.get_center()
	var radius := minf(_portrait.size.x * 0.30, _portrait.size.y * 0.34)
	var tint: Color = data.get("tint", Color("4fb4e8"))
	var accent: Color = data.get("accent", Color.WHITE)
	# habitat disc so the portrait reads as a plate, not a floating blob
	var disc := Color(0.26, 0.42, 0.40, 0.30) if friendly else Color(PAGE_SHADE, 0.35)
	draw_circle(centre, radius * 1.7, disc)
	if friendly:
		for i in range(3):
			var a := _time * 0.25 + TAU * float(i) / 3.0
			draw_circle(centre + Vector2(cos(a), sin(a)) * radius * 1.5,
					maxf(2.0, radius * 0.06), Color(tint, 0.55))
		ReefArt.draw_creature(self, String(data.get("shape", "parrotfish")), centre, radius,
				tint, accent, _time * 0.6, 0.0)
	else:
		_draw_shape(String(data.get("shape", "jelly")), centre, radius, tint, accent)
	_draw_trait_marks(data, centre + Vector2(0.0, radius * 1.7), friendly)


## One silhouette per invasive species shape — the same shapes the enemy draws,
## so the book is recognisably showing the creature the player actually met.
func _draw_shape(shape: String, c: Vector2, r: float, tint: Color, accent: Color) -> void:
	match shape:
		"urchin":
			for i in 18:
				var a := TAU * float(i) / 18.0
				draw_line(c + Vector2.from_angle(a) * r * 0.8, c + Vector2.from_angle(a) * r * 1.5,
						accent, 3.0, true)
			draw_circle(c, r * 0.9, tint)
			draw_circle(c, r * 0.55, tint.lightened(0.18))
		"nautilus":
			draw_circle(c, r * 0.95, tint)
			for i in range(3):
				draw_arc(c - Vector2(r * 0.1 * float(i), -r * 0.06 * float(i)), r * (0.95 - float(i) * 0.26),
						0.3, PI * 1.9, 22, Color(accent, 0.9), 3.0, true)
			draw_circle(c + Vector2(r * 0.5, -r * 0.1), r * 0.16, accent)
		"eel":
			for i in range(6):
				var t := float(i) / 5.0
				draw_circle(c + Vector2(-t * r * 2.1 + r * 0.6, sin(t * 3.4) * r * 0.42),
						r * (0.9 - t * 0.5), Color(tint, 1.0 - t * 0.25))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * 1.5, -r * 0.05), c + Vector2(r * 0.6, -r * 0.7),
				c + Vector2(r * 0.6, r * 0.55)]), accent)
		"ray":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * 1.25, 0), c + Vector2(r * 0.2, -r * 0.5),
				c + Vector2(-r * 0.6, -r * 1.05), c + Vector2(-r * 1.55, -r * 0.7),
				c + Vector2(-r * 1.0, 0), c + Vector2(-r * 1.55, r * 0.7),
				c + Vector2(-r * 0.6, r * 1.05), c + Vector2(r * 0.2, r * 0.5)]), tint)
			for i in range(5):
				var x := c.x + lerpf(r * 0.6, -r * 1.0, float(i) / 4.0)
				draw_line(Vector2(x, c.y - r * 0.5), Vector2(x, c.y + r * 0.5), Color(accent, 0.75), 2.0)
		"bloom":
			for i in range(6):
				var a := TAU * float(i) / 6.0
				draw_circle(c + Vector2.from_angle(a) * r * 0.55, r * 0.42, tint.lightened(0.05 * float(i)))
				draw_line(c + Vector2.from_angle(a) * r * 0.75, c + Vector2.from_angle(a) * r * 1.25,
						accent, 3.0, true)
			draw_circle(c, r * 0.4, tint.darkened(0.3))
		_:
			var bell := PackedVector2Array()
			for i in range(21):
				var a := PI + PI * float(i) / 20.0
				bell.append(c + Vector2(cos(a) * r * 0.95, sin(a) * r * 0.85))
			bell.append(c + Vector2(r * 0.9, r * 0.3))
			bell.append(c + Vector2(-r * 0.9, r * 0.3))
			draw_colored_polygon(bell, Color(tint, 0.9))
			draw_polyline(_ring(bell), accent, 2.5, true)
			draw_circle(c + Vector2(0.0, -r * 0.18), r * 0.34, Color(accent, 0.4))
			for i in range(5):
				var a := -PI * 0.5 + (float(i) - 2.0) * 0.42
				draw_line(c + Vector2(cos(a) * r * 0.5, r * 0.3),
						c + Vector2(cos(a) * r * 0.7, r * 1.5), Color(accent, 0.7), 2.0, true)


## Threat pips (or a green "helper" rosette) plus the counter-weapon tag stamped
## under the portrait.
func _draw_trait_marks(data: Dictionary, at: Vector2, friendly: bool) -> void:
	var font := ThemeDB.fallback_font
	if friendly:
		for i in range(6):
			var a := TAU * float(i) / 6.0 + _time * 0.2
			draw_circle(at + Vector2(cos(a), sin(a) * 0.7) * 7.0, 3.4, Color(HELPER_INK, 0.85))
		var text := "REEF HELPER — %s" % String(data.get("role", "HELPER"))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, at + Vector2(-w * 0.5, 30.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				HELPER_INK)
		return
	var threat := int(data.get("threat", 1))
	var col: Color = THREAT_COLOUR[clampi(threat - 1, 0, THREAT_COLOUR.size() - 1)]
	for i in 3:
		var centre := at + Vector2(float(i) * 22.0 - 22.0, 0.0)
		if i < threat:
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(0, -8), centre + Vector2(8, 0),
				centre + Vector2(0, 8), centre + Vector2(-8, 0)]), col)
		else:
			draw_arc(centre, 6.0, 0.0, TAU, 12, Color(0.35, 0.30, 0.22, 0.5), 1.5, true)
	var tag := "WEAK TO %s" % ", ".join(_upper_all(data.get("weak_to", [])))
	var width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, at + Vector2(-width * 0.5, 30.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)


func _upper_all(list: Array) -> Array[String]:
	var out: Array[String] = []
	for item: String in list:
		out.append(item.to_upper())
	return out


# ================================================================ SHAPE HELPERS

func _make_label(font_size: int, col: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", col)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(r, r), PI, PI * 1.5],
		[rect.position + Vector2(rect.size.x - r, r), PI * 1.5, TAU],
		[rect.position + rect.size - Vector2(r, r), 0.0, PI * 0.5],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5, PI],
	]
	for c: Array in corners:
		var centre: Vector2 = c[0]
		for i in range(5):
			var a: float = lerpf(float(c[1]), float(c[2]), float(i) / 5.0)
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


func _blob(centre: Vector2, radius: Vector2, seed_value: int, count: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var pts := PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var w := 1.0 + 0.16 * sin(a * 2.0 + p1) + 0.09 * sin(a * 3.0 + p2)
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y) * w)
	return pts


func _grow(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	var out := Geometry2D.offset_polygon(poly, delta, Geometry2D.JOIN_ROUND)
	var best := PackedVector2Array()
	var best_area := 0.0
	for p in out:
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


func _ring(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out
