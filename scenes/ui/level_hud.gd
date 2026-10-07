extends CanvasLayer
# C owns this file — the in-level HUD.
#
# Built entirely in code, like world_map.gd builds its art, so there are no extra
# scenes or font assets to keep in sync. It talks to gameplay only through the
# frozen contract:
#   player.health_changed(current, max_health)   -> hull bar + vignette
#   player.died
#   wave_started / wave_completed / reef_cleared (via level_base, not directly)
#
# Additive readouts fed by level_base (all optional, no frozen name involved):
#   set_effectiveness(weapon_id, multiplier, delta)   W3 adaptation readout
#   show_adaptation(lines)                            W3 between-wave banner
#   show_species_card(name, hint, tint, threat)       W3/W6 first-contact card
#   set_weapon_status(status)                         W1 cooldown/heat/recharge
#   set_reef(ratio, state, health, colour)            W8 live reef health readout
#   show_reef(title, advice, colour)                  W8 restored / bleached notice
#   show_seed_prompt(text, progress)                  W9 hold-to-plant prompt
#   show_seed_result(planted, gain)                   W9 planting confirmation
#
# HudRoot/AdaptationBanner and HudRoot/DangerVignette keep their exact names and
# paths: the verification harness reaches for them by path.


signal return_to_map_pressed
signal retry_pressed

const HullBar := preload("res://scenes/ui/hull_bar.gd")
const DamageVignette := preload("res://scenes/ui/damage_vignette.gd")
const ReefMeter := preload("res://scenes/ui/reef_meter.gd")

const PAD := 20.0
const PANEL_BG := Color(0.02, 0.10, 0.18, 0.82)
const BANNER_BG := Color(0.03, 0.12, 0.20, 0.94)
const ACCENT := Color("ffd45e")
const GOOD := Color("2fb67c")
const WARN := Color("ffb347")
const BAD := Color("e0553f")
const TEXT := Color("f2f7fb")
const MUTED := Color(0.75, 0.82, 0.88, 0.85)

const WEAPON_NAMES := {
	"sonic": "SONIC PULSE",
	"bubble": "BUBBLE DOME",
	"thermal": "THERMAL BEAM",
}
const BANNER_TIME := 3.0
const CARD_TIME := 3.4
const REEF_NOTICE_TIME := 4.0
const REEF_PANEL_SIZE := Vector2(316, 74)

var _root: Control
var _hull: Control
var _vignette: Control
var _hull_numbers: Label
var _hull_state: Label
var _island_label: Label
var _wave_label: Label
var _weapon_label: Label
var _effect_label: Label
var _status_label: Label
var _enemy_label: Label
var _controls_label: Label
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: Label
var _panel_primary: Button
var _panel_secondary: Button
var _respawn_button: Button
var _banner: PanelContainer
var _banner_title: Label
var _banner_lines: VBoxContainer
var _card: PanelContainer
var _card_title: Label
var _card_body: Label
var _banner_timer := 0.0
var _card_timer := 0.0
# W8: the coral.
var _reef_panel: PanelContainer
var _reef_meter: Control
var _reef_label: Label
var _reef_notice: PanelContainer
var _reef_notice_title: Label
var _reef_notice_body: Label
var _reef_notice_timer := 0.0
var _reef_state := ""
# W9: the planting action.
var _seed_panel: PanelContainer
var _seed_label: Label
var _seed_bar: Control
var _seed_hint := ""
var _reef_start_ratio := 0.45
var _effect_colour := MUTED
var _status_colour := MUTED
var _effect_tooltip := ""


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- danger vignette sits behind every readout
	_vignette = Control.new()
	_vignette.name = "DangerVignette"
	_vignette.set_script(DamageVignette)
	_root.add_child(_vignette)

	# ---- hull integrity, top left
	var hull_box := _make_panel(Vector2(PAD, PAD), Vector2(316, 76))
	_root.add_child(hull_box)
	var hull_title := _make_label(hull_box, "HULL INTEGRITY", Vector2(14, 6), 13, MUTED)
	hull_title.name = "HullTitle"
	_hull = Control.new()
	_hull.name = "HullBar"
	_hull.set_script(HullBar)
	_hull.position = Vector2(14, 24)
	_hull.size = Vector2(268, 30)
	hull_box.add_child(_hull)
	_hull_numbers = _make_label(_root, "100 / 100", Vector2(PAD + 292, PAD + 26), 17, TEXT)
	_hull_numbers.name = "HullNumbers"
	_hull_numbers.size = Vector2(90, 24)
	_hull_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hull_state = _make_label(_root, "HULL", Vector2(PAD + 14, PAD + 56), 14, GOOD)

	# ---- first-contact species card, under the hull box
	_card = PanelContainer.new()
	_card.name = "SpeciesCard"
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _panel_style(Color("63e0ff")))
	_root.add_child(_card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 2)
	_card.add_child(card_box)
	_card_title = _make_label(card_box, "", Vector2.ZERO, 19, ACCENT)
	_card_title.custom_minimum_size = Vector2(300, 24)
	_card_body = _make_label(card_box, "", Vector2.ZERO, 14, TEXT)
	_card_body.custom_minimum_size = Vector2(300, 20)
	_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ---- the coral: live reef health, bottom left above the restart button
	_reef_panel = _make_panel(Vector2(PAD, 0), REEF_PANEL_SIZE)
	_reef_panel.name = "ReefPanel"
	_root.add_child(_reef_panel)
	var reef_box := VBoxContainer.new()
	reef_box.add_theme_constant_override("separation", 3)
	_reef_panel.add_child(reef_box)
	_reef_label = _make_label(reef_box, "REEF HEALTH", Vector2.ZERO, 14, WARN)
	_reef_label.custom_minimum_size = Vector2(REEF_PANEL_SIZE.x - 36.0, 18)
	_reef_meter = Control.new()
	_reef_meter.name = "ReefMeter"
	_reef_meter.set_script(ReefMeter)
	_reef_meter.custom_minimum_size = Vector2(REEF_PANEL_SIZE.x - 36.0, 18)
	reef_box.add_child(_reef_meter)

	# ---- reef state notice (restored / bleached), stacked above the meter
	_reef_notice = PanelContainer.new()
	_reef_notice.name = "ReefNotice"
	_reef_notice.visible = false
	_reef_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reef_notice.add_theme_stylebox_override("panel", _panel_style(GOOD))
	_root.add_child(_reef_notice)
	var notice_box := VBoxContainer.new()
	notice_box.add_theme_constant_override("separation", 2)
	_reef_notice.add_child(notice_box)
	_reef_notice_title = _make_label(notice_box, "", Vector2.ZERO, 19, GOOD)
	_reef_notice_title.custom_minimum_size = Vector2(300, 24)
	_reef_notice_body = _make_label(notice_box, "", Vector2.ZERO, 14, TEXT)
	_reef_notice_body.custom_minimum_size = Vector2(300, 20)
	_reef_notice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ---- W9 planting prompt, above the controls hint where the eyes already are
	_seed_panel = _make_panel(Vector2(0, 0), Vector2(340, 54))
	_seed_panel.name = "SeedPrompt"
	_seed_panel.visible = false
	_root.add_child(_seed_panel)
	var seed_box := VBoxContainer.new()
	seed_box.add_theme_constant_override("separation", 3)
	_seed_panel.add_child(seed_box)
	_seed_label = _make_label(seed_box, "", Vector2.ZERO, 15, GOOD)
	_seed_label.custom_minimum_size = Vector2(304, 20)
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_bar = Control.new()
	_seed_bar.name = "SeedBar"
	_seed_bar.set_script(ReefMeter)
	_seed_bar.custom_minimum_size = Vector2(304, 12)
	seed_box.add_child(_seed_bar)

	# ---- island + wave, top centre
	_island_label = _make_label(_root, "", Vector2(0, PAD), 30, TEXT)
	_island_label.size = Vector2(600, 40)
	_island_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label = _make_label(_root, "", Vector2(0, PAD + 44.0), 20, ACCENT)
	_wave_label.size = Vector2(600, 28)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ---- enemies + weapon + how the swarm is holding up, top right
	_enemy_label = _make_label(_root, "", Vector2(0, PAD), 18, TEXT)
	_enemy_label.size = Vector2(250, 26)
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label = _make_label(_root, "", Vector2(0, PAD + 26.0), 16, MUTED)
	_weapon_label.size = Vector2(250, 24)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_effect_label = _make_label(_root, "", Vector2(0, PAD + 50.0), 17, GOOD)
	_effect_label.size = Vector2(250, 24)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label = _make_label(_root, "", Vector2(0, PAD + 74.0), 15, MUTED)
	_status_label.size = Vector2(250, 22)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ---- between-wave adaptation banner, above the controls
	_banner = PanelContainer.new()
	_banner.name = "AdaptationBanner"
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", _panel_style(BAD))
	_root.add_child(_banner)
	var banner_box := VBoxContainer.new()
	banner_box.add_theme_constant_override("separation", 4)
	_banner.add_child(banner_box)
	_banner_title = _make_label(banner_box, "THE SWARM IS ADAPTING", Vector2.ZERO, 21, BAD)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.custom_minimum_size = Vector2(520, 26)
	_banner_lines = VBoxContainer.new()
	_banner_lines.add_theme_constant_override("separation", 2)
	banner_box.add_child(_banner_lines)

	# ---- restart, bottom left
	_respawn_button = _make_button("Restart Dive", Vector2(PAD, 0), Vector2(190, 34))
	_respawn_button.pressed.connect(func() -> void: retry_pressed.emit())
	_root.add_child(_respawn_button)

	# ---- controls hint, bottom
	_controls_label = _make_label(_root, "WASD move   •   1 / 2 / 3 switch weapon   •   Left click / Space fire   •   E plant coral at a bed   •   Esc world map",
			Vector2(0, 0), 15, MUTED)
	_controls_label.size = Vector2(820, 22)
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


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer = maxf(0.0, _banner_timer - delta)
		if _banner_timer <= 0.0:
			_banner.visible = false
		else:
			_banner.modulate.a = clampf(_banner_timer / 0.6, 0.0, 1.0)
	if _card_timer > 0.0:
		_card_timer = maxf(0.0, _card_timer - delta)
		if _card_timer <= 0.0:
			_card.visible = false
		else:
			_card.modulate.a = clampf(_card_timer / 0.6, 0.0, 1.0)
	if _reef_notice_timer > 0.0:
		_reef_notice_timer = maxf(0.0, _reef_notice_timer - delta)
		if _reef_notice_timer <= 0.0:
			_reef_notice.visible = false
		else:
			_reef_notice.modulate.a = clampf(_reef_notice_timer / 0.6, 0.0, 1.0)


func _reposition() -> void:
	var view := get_viewport().get_visible_rect().size
	# the vignette uses FULL_RECT anchors, so its size follows the viewport on its
	# own — assigning size here would fight the anchors (and warn)
	_island_label.position.x = (view.x - _island_label.size.x) * 0.5
	_wave_label.position.x = (view.x - _wave_label.size.x) * 0.5
	# both are anchored to the hull box in the top-left corner
	_hull_numbers.position = Vector2(PAD + 292, PAD + 26)
	_hull_state.position = Vector2(PAD + 14, PAD + 56)
	for label: Label in [_enemy_label, _weapon_label, _effect_label, _status_label]:
		label.position.x = view.x - PAD - label.size.x
	_card.position = Vector2(PAD, PAD + 86.0)
	var card_size := _card.get_combined_minimum_size()
	_card.size = card_size
	var reef_size := _reef_panel.size
	_reef_panel.size = REEF_PANEL_SIZE
	_reef_panel.position = Vector2(PAD, view.y - PAD - _respawn_button.size.y - 10.0 - reef_size.y)
	var notice_size := _reef_notice.get_combined_minimum_size()
	_reef_notice.size = notice_size
	_reef_notice.position = Vector2(PAD, _reef_panel.position.y - notice_size.y - 8.0)
	var seed_size := Vector2(340, 54)
	_seed_panel.size = seed_size
	_seed_panel.position = Vector2((view.x - seed_size.x) * 0.5, view.y - 150.0 - seed_size.y)
	_respawn_button.position.y = view.y - PAD - _respawn_button.size.y
	_controls_label.position.x = (view.x - _controls_label.size.x) * 0.5
	_controls_label.position.y = view.y - PAD - _controls_label.size.y
	var banner_size := _banner.get_combined_minimum_size()
	_banner.size = banner_size
	_banner.position = Vector2((view.x - banner_size.x) * 0.5, view.y - 116.0 - banner_size.y)
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
	_set_text(_wave_label, "Wave %d / %d" % [wave, total])


func set_enemies_left(count: int) -> void:
	_set_text(_enemy_label, "Enemies: %d" % count)


func set_weapon(weapon_id: String) -> void:
	_set_text(_weapon_label, "Weapon: %s" % String(WEAPON_NAMES.get(weapon_id, weapon_id)))


## level_base polls the HUD every frame; re-shaping identical text every frame is
## pure waste, so only touch the label when the string actually changed.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


## W3: "is my weapon still working against this swarm?" — mean damage multiplier
## of the live population for the equipped weapon, plus the change since the
## previous generation.
func set_effectiveness(weapon_id: String, multiplier: float, delta: float) -> void:
	var arrow := "—"
	var arrow_col := MUTED
	if delta < -0.005:
		arrow = "▼"
		arrow_col = BAD
	elif delta > 0.005:
		arrow = "▲"
		arrow_col = GOOD
	var col := GOOD
	if multiplier < 0.7:
		col = BAD
	elif multiplier < 0.95:
		col = WARN
	_set_text(_effect_label, "%s %.0f%%  %s" % [String(WEAPON_NAMES.get(weapon_id, weapon_id)), multiplier * 100.0, arrow])
	if arrow_col != _effect_colour:
		_effect_colour = arrow_col
		_effect_label.add_theme_color_override("font_color", col)
		if arrow_col != MUTED:
			_effect_label.add_theme_color_override("font_shadow_color", arrow_col)
	if absf(delta) >= 0.005:
		_effect_tooltip = "Swarm resistance to this weapon changed %.0f%%" % (delta * 100.0)
		_effect_label.tooltip_text = _effect_tooltip


## W1: weapon readiness (cooldown, heat lockout, dome recharge).
func set_weapon_status(status: Dictionary) -> void:
	if status.is_empty():
		_set_text(_status_label, "")
		return
	var state := String(status.get("state", "ready"))
	var detail := String(status.get("detail", ""))
	_set_text(_status_label, detail if detail != "" else state.to_upper())
	var col := MUTED
	match state:
		"ready":
			col = MUTED
		"cooling", "charging":
			col = WARN
		"venting", "recharging", "empty":
			col = BAD
	if col != _status_colour:
		_status_colour = col
		_status_label.add_theme_color_override("font_color", col)


## W3: the between-wave "here is what just evolved" panel.
func show_adaptation(lines: Array) -> void:
	for child in _banner_lines.get_children():
		child.queue_free()
	for line: String in lines:
		var label := _make_label(_banner_lines, line, Vector2.ZERO, 15, TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(520, 20)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_timer = BANNER_TIME
	_reposition()


## W8: live reef health. `state` is the word from ReefRestoration.state_label()
## (RESTORED / THRIVING / HEALING / FAILING / BLEACHED) and `health` the number.
func set_reef(ratio: float, state: String, health: String, colour: Color) -> void:
	_set_text(_reef_label, "REEF HEALTH   %s   %s" % [health, state])
	if state != _reef_state:
		_reef_state = state
		_reef_label.add_theme_color_override("font_color", colour)
	_reef_meter.call("set_reef", ratio, _reef_start_ratio, colour, state == "BLEACHED")


## W8: a one-shot reef milestone — the coral came back, or it bleached out.
func show_reef(title: String, advice: String, colour: Color) -> void:
	_reef_notice_title.text = title
	_reef_notice_title.add_theme_color_override("font_color", colour)
	_reef_notice_body.text = advice
	_reef_notice.add_theme_stylebox_override("panel", _panel_style(colour))
	_reef_notice.visible = true
	_reef_notice.modulate.a = 1.0
	_reef_notice_timer = REEF_NOTICE_TIME
	if _reef_meter.has_method("pulse"):
		_reef_meter.call("pulse")
	_reposition()


## The reef starts where the island says it starts; the meter draws that mark so
## "how far have we come?" is answerable at a glance.
func set_reef_start(ratio: float) -> void:
	_reef_start_ratio = clampf(ratio, 0.0, 1.0)
	if _reef_meter != null:
		_reef_meter.call("set_reef", _reef_start_ratio, _reef_start_ratio,
				_reef_meter.get("_colour"), false)


## W9: the planting prompt. Empty text hides it; `progress` fills the bar under
## the words, so one node carries both "hold E" and "you are halfway there".
func show_seed_prompt(text: String, progress: float) -> void:
	if text == "":
		if _seed_panel.visible:
			_seed_panel.visible = false
		return
	_set_text(_seed_label, text)
	_seed_panel.visible = true
	var planting := progress > 0.0
	if text != _seed_hint:
		_seed_hint = text
		_seed_label.add_theme_color_override("font_color", ACCENT if planting else GOOD)
	# the bar reads as "planting done" when idle, so it never looks stuck at zero
	_seed_bar.call("set_reef", progress if planting else 1.0, 0.0,
			ACCENT if planting else GOOD, false)


## W9: one-shot confirmation that coral actually landed on the bed.
func show_seed_result(planted: int, gain: float) -> void:
	_reef_notice_title.text = "CORAL PLANTED"
	_reef_notice_title.add_theme_color_override("font_color", GOOD)
	_reef_notice_body.text = "Head %d is growing on this bed.  +%d reef health." % [planted, int(round(gain))]
	_reef_notice.add_theme_stylebox_override("panel", _panel_style(GOOD))
	_reef_notice.visible = true
	_reef_notice.modulate.a = 1.0
	_reef_notice_timer = 2.4
	if _reef_meter.has_method("pulse"):
		_reef_meter.call("pulse")
	_reposition()


## W3/W6: first-contact card for a species the player has not met before.
func show_species_card(display_name: String, hint: String, tint: Color, threat: int) -> void:
	var pips := ""
	for i in 3:
		pips += "●" if i < threat else "○"
	_card_title.text = "NEW CONTACT  %s  %s" % [display_name, pips]
	_card_title.add_theme_color_override("font_color", tint.lightened(0.35))
	_card_body.text = hint
	_card.visible = true
	_card.modulate.a = 1.0
	_card_timer = CARD_TIME
	_reposition()


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
	_panel_body.text = "The sentinel went down at %s.\nWatch which weapon the swarm stopped fearing." % island_name
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
	if _hull != null:
		_hull.call("set_health", current, max_health)
		_hull_numbers.text = "%d / %d" % [current, max_health]
		var state := String(_hull.call("state_label"))
		_hull_state.text = state
		_hull_state.add_theme_color_override("font_color", _hull.call("state_colour"))
	if _vignette != null:
		var ratio := float(current) / float(maxi(1, max_health))
		_vignette.call("set_health_ratio", ratio)
		if _last_health >= 0 and current < _last_health:
			_vignette.call("flash", clampf(float(_last_health - current) / 25.0, 0.25, 1.0))
	_last_health = current


func _on_player_died() -> void:
	# level_base decides the wording; this only hides the transient bits.
	if _vignette != null:
		_vignette.call("set_health_ratio", 0.0)
		_vignette.call("flash", 1.0)


var _last_health := -1


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


func _make_button(text: String, pos: Vector2, size_v: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size_v
	button.custom_minimum_size = size_v
	button.add_theme_font_size_override("font_size", 16)
	return button


func _make_panel(pos: Vector2, size_v: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = size_v
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel


func _panel_style(border: Color = ACCENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box
