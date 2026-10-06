extends CanvasLayer
# C owns this file — the in-level HUD.
#
# Built entirely in code, like world_map.gd builds its art, so there are no
# extra scenes or font assets to keep in sync. It talks to gameplay only through
# the frozen contract:
#   player.health_changed(current, max_health)
#   player.died
#   wave_started / wave_completed / reef_cleared (via level_base, not directly)

signal return_to_map_pressed
signal retry_pressed

const BAR_SIZE := Vector2(240, 18)
const PAD := 20.0
const INK := Color("0c2338")
const PANEL_BG := Color(0.02, 0.10, 0.18, 0.82)
const BANNER_BG := Color(0.02, 0.10, 0.18, 0.92)
const ACCENT := Color("ffd45e")
const GOOD := Color("2fb67c")
const BAD := Color("e0553f")
const TEXT := Color("f2f7fb")
const MUTED := Color(0.75, 0.82, 0.88, 0.85)

var _root: Control
var _health_bar: ProgressBar
var _health_label: Label
var _island_label: Label
var _wave_label: Label
var _weapon_label: Label
var _enemy_label: Label
var _controls_label: Label
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: Label
var _panel_primary: Button
var _panel_secondary: Button
var _respawn_button: Button


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- health, top left
	var health_box := _make_panel(Vector2(PAD, PAD), Vector2(BAR_SIZE.x + 24.0, 62.0))
	_root.add_child(health_box)
	_health_label = _make_label(health_box, "100 / 100", Vector2(12, 6), 16, TEXT)
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.show_percentage = false
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.position = Vector2(12, 30)
	_health_bar.size = BAR_SIZE
	_health_bar.add_theme_stylebox_override("background", _bar_style(INK))
	_health_bar.add_theme_stylebox_override("fill", _bar_style(GOOD))
	health_box.add_child(_health_bar)

	# ---- island + wave, top centre
	_island_label = _make_label(_root, "", Vector2(0, PAD), 30, TEXT)
	_island_label.size = Vector2(600, 40)
	_island_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label = _make_label(_root, "", Vector2(0, PAD + 44.0), 20, ACCENT)
	_wave_label.size = Vector2(600, 28)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ---- enemies + weapon, top right
	_enemy_label = _make_label(_root, "", Vector2(0, PAD), 18, TEXT)
	_enemy_label.size = Vector2(220, 26)
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label = _make_label(_root, "", Vector2(0, PAD + 26.0), 16, MUTED)
	_weapon_label.size = Vector2(220, 24)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ---- respawn, bottom left
	_respawn_button = _make_button("Respawn Enemy (R)", Vector2(PAD, 0), Vector2(210, 34))
	_respawn_button.pressed.connect(func() -> void: retry_pressed.emit())
	_root.add_child(_respawn_button)

	# ---- controls hint, bottom
	_controls_label = _make_label(_root, "WASD move   •   Left click / Space fire   •   Esc world map", Vector2(0, 0), 15, MUTED)
	_controls_label.size = Vector2(720, 22)
	_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ---- centre panel (cleared / dead)
	_panel = PanelContainer.new()
	_panel.name = "LevelPanel"
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)

	var box := VBoxContainer.new()
	box.name = "PanelBox"
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	_panel_title = _make_label(box, "", Vector2.ZERO, 34, ACCENT)
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_title.custom_minimum_size = Vector2(440, 44)
	_panel_body = _make_label(box, "", Vector2.ZERO, 17, TEXT)
	_panel_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_body.custom_minimum_size = Vector2(440, 60)
	_panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_panel_primary = _make_button("Return to Map", Vector2.ZERO, Vector2(440, 40))
	_panel_primary.pressed.connect(func() -> void: return_to_map_pressed.emit())
	box.add_child(_panel_primary)

	_panel_secondary = _make_button("Dive Again", Vector2.ZERO, Vector2(440, 40))
	_panel_secondary.pressed.connect(func() -> void: retry_pressed.emit())
	box.add_child(_panel_secondary)

	get_viewport().size_changed.connect(_reposition)
	_reposition()


func _reposition() -> void:
	var view := get_viewport().get_visible_rect().size
	_island_label.position.x = (view.x - _island_label.size.x) * 0.5
	_wave_label.position.x = (view.x - _wave_label.size.x) * 0.5
	_enemy_label.position.x = view.x - PAD - _enemy_label.size.x
	_weapon_label.position.x = view.x - PAD - _weapon_label.size.x
	_respawn_button.position.y = view.y - PAD - _respawn_button.size.y
	_controls_label.position.x = (view.x - _controls_label.size.x) * 0.5
	_controls_label.position.y = view.y - PAD - _controls_label.size.y
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = Vector2((view.x - panel_size.x) * 0.5, (view.y - panel_size.y) * 0.5)


# ================================================================ PUBLIC API

func bind_player(player: Node) -> void:
	if player == null:
		return
	if player.has_signal("health_changed"):
		player.connect("health_changed", _on_health_changed)
		var cur: Variant = player.get("current_health")
		var mx: Variant = player.get("max_health")
		if cur != null and mx != null:
			_on_health_changed(int(cur), int(mx))
	if player.has_signal("died"):
		player.connect("died", _on_player_died)


func set_island_name(island_name: String, level_number: int) -> void:
	_island_label.text = "%d. %s" % [level_number, island_name]
	_panel_title.text = "REEF CLEARED"


func set_wave(wave: int, total: int) -> void:
	_wave_label.text = "Wave %d / %d" % [wave, total]


func set_enemies_left(count: int) -> void:
	_enemy_label.text = "Enemies: %d" % count


func set_weapon(weapon_id: String) -> void:
	_weapon_label.text = "Weapon: %s" % weapon_id


func show_cleared(island_name: String, next_name: String) -> void:
	var body := "%s is secure." % island_name
	if next_name != "":
		body += "\nNext reef unlocked: %s" % next_name
	_panel_body.text = body
	_panel_title.text = "REEF CLEARED"
	_panel_primary.text = "Return to Map"
	_panel_secondary.visible = true
	_panel.visible = true
	_reposition()


func show_failed(island_name: String) -> void:
	_panel_title.text = "SUBMARINE LOST"
	_panel_body.text = "The sentinel went down at %s.\nAdapt and try again." % island_name
	_panel_primary.text = "Return to Map"
	_panel_secondary.visible = true
	_panel.visible = true
	_reposition()


func hide_panel() -> void:
	_panel.visible = false


func set_controls_visible(shown: bool) -> void:
	_controls_label.visible = shown
	_respawn_button.visible = shown


# ================================================================ INTERNALS

func _on_health_changed(current: int, max_health: int) -> void:
	var mx := maxi(1, max_health)
	_health_bar.max_value = mx
	_health_bar.value = clampi(current, 0, mx)
	_health_label.text = "%d / %d" % [current, mx]
	var ratio := float(current) / float(mx)
	var fill := _bar_style(GOOD if ratio > 0.5 else (ACCENT if ratio > 0.25 else BAD))
	_health_bar.add_theme_stylebox_override("fill", fill)


func _on_player_died() -> void:
	# level_base decides the wording; this only hides the transient bits.
	pass


func _make_label(parent: Node, text: String, pos: Vector2, font_size: int, col: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 16)
	return button


func _make_panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = ACCENT
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box


func _bar_style(col: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = col
	box.set_corner_radius_all(4)
	box.set_border_width_all(1)
	box.border_color = Color(0, 0, 0, 0.35)
	return box
