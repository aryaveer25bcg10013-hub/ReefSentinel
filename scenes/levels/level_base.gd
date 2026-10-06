extends Node2D
# C owns this file — the shared controller for one dive level (one reef island).
#
# Owns: the reef floor, arena walls, player spawn, camera, wave flow, HUD, and
# the hand-off back to the world map. Everything it touches from other roles
# goes through the frozen contract, so it keeps working as A and B land their
# real scenes:
#
#   Role A  scenes/player/submarine.tscn   (falls back to a placeholder rig)
#   Role B  scenes/enemies/invasive_enemy.tscn (falls back to a placeholder enemy)
#   Role B  systems/wave_manager.tscn       (falls back to a placeholder director)
#
# The fallbacks live in scenes/levels/placeholders/ and are deleted once the
# real scenes land. No level edits are needed when they do.
#
# // PROPOSED CHANGE: the contract freezes the WaveManager SIGNALS but not how a
# // level starts it. This file assumes either configure(...) then start(), or
# // bare start(), and connects only the three frozen signals. If Role B wants a
# // different entry point, agree it explicitly rather than letting each level
# // invent its own call.

const FLOOR_SCRIPT := "res://scenes/levels/reef_floor.gd"
const PLAYER_SCENE := "res://scenes/player/submarine.tscn"
const ENEMY_SCENE := "res://scenes/enemies/invasive_enemy.tscn"
const WAVE_DIRECTOR_SCENE := "res://systems/wave_manager.tscn"
const PLACEHOLDER_PLAYER_SCRIPT := "res://scenes/levels/placeholders/reef_placeholder_player.gd"
const PLACEHOLDER_ENEMY_SCRIPT := "res://scenes/levels/placeholders/reef_placeholder_enemy.gd"
const PLACEHOLDER_WAVES_SCRIPT := "res://scenes/levels/placeholders/reef_placeholder_waves.gd"
const HUD_SCRIPT := "res://scenes/ui/level_hud.gd"
const WORLD_MAP_SCENE := "res://scenes/ui/world_map.tscn"

const ARENA_SIZE := Vector2(1600, 900)
const WALL_THICKNESS := 40.0

# ================================================================ LEVEL DATA
# Set per-level in each .tscn. This is level design, not genome logic: the
# genome traits below are only the STARTING resistance of an island, and the
# multiplier maths stays in systems/genome.gd.

@export var island_id: String = "redwake"
@export var island_name: String = "Redwake"
@export_enum("Shallow Reef", "Kelp Belt", "Volcanic Vents") var biome: int = 0
@export var wave_count: int = 3
@export var enemies_first_wave: int = 3
@export var enemies_per_wave_step: int = 2
@export var level_seed: int = 0
@export var genome_acoustic_armor: float = 0.05
@export var genome_spiky_shell: float = 0.05
@export var genome_heat_sink: float = 0.05
@export var genome_speed_multiplier: float = 0.90
@export var genome_max_health: float = 40.0
@export var enemy_touch_damage: float = 8.0

var _seed := 4242
var _arena := ARENA_SIZE
var _floor: Node2D
var _player: Node2D
var _camera: Camera2D
var _director: Node
var _hud: CanvasLayer
var _completed := false


func _ready() -> void:
	_seed = level_seed if level_seed != 0 else absi(hash(island_id))
	_build_floor()
	_build_walls()
	_build_player()
	_build_waves()
	_build_hud()


# ================================================================ WORLD

func _build_floor() -> void:
	var floor_node := Node2D.new()
	floor_node.name = "ReefFloor"
	if not _apply_script(floor_node, FLOOR_SCRIPT):
		return
	add_child(floor_node)
	floor_node.call("configure", biome, _arena, _seed)
	_floor = floor_node


func _build_walls() -> void:
	var rects: Array = []
	if _floor != null and _floor.has_method("wall_rects"):
		rects = _floor.call("wall_rects")

	var body := StaticBody2D.new()
	body.name = "ArenaWalls"
	add_child(body)
	if rects.is_empty():
		rects = [
			Rect2(0, 0, _arena.x, WALL_THICKNESS),
			Rect2(0, _arena.y - WALL_THICKNESS, _arena.x, WALL_THICKNESS),
			Rect2(0, 0, WALL_THICKNESS, _arena.y),
			Rect2(_arena.x - WALL_THICKNESS, 0, WALL_THICKNESS, _arena.y),
		]
	for rect: Rect2 in rects:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		body.add_child(shape)


# ================================================================ PLAYER

func _build_player() -> void:
	var node: Node2D = null
	# Prefer Role A's real submarine the moment it exists.
	if ResourceLoader.exists(PLAYER_SCENE):
		var scene := load(PLAYER_SCENE) as PackedScene
		if scene != null:
			node = scene.instantiate() as Node2D
	if node == null:
		var body := CharacterBody2D.new()
		if not _apply_script(body, PLACEHOLDER_PLAYER_SCRIPT):
			return
		node = body
	node.name = "Submarine"
	add_child(node)
	node.global_position = _arena * 0.5
	_player = node
	if not node.is_in_group("player"):
		node.add_to_group("player")
	_attach_camera(node)


func _attach_camera(target: Node2D) -> void:
	var existing := target.get_node_or_null("Camera2D") as Camera2D
	if existing == null:
		for child in target.get_children():
			if child is Camera2D:
				existing = child
				break
	if existing == null:
		existing = Camera2D.new()
		existing.name = "Camera2D"
		target.add_child(existing)
	existing.limit_left = 0
	existing.limit_top = 0
	existing.limit_right = int(_arena.x)
	existing.limit_bottom = int(_arena.y)
	existing.position_smoothing_enabled = true
	existing.position_smoothing_speed = 8.0
	existing.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	existing.make_current()
	_camera = existing


# ================================================================ WAVES

func _build_waves() -> void:
	var director := _make_wave_director()
	if director == null:
		push_warning("Level %s: no wave director available" % island_id)
		return
	add_child(director)
	_director = director

	if director.has_signal("wave_started"):
		director.connect("wave_started", _on_wave_started)
	if director.has_signal("wave_completed"):
		director.connect("wave_completed", _on_wave_completed)
	if director.has_signal("reef_cleared"):
		director.connect("reef_cleared", _on_reef_cleared)

	var points := _spawn_points()
	var genome := _genome_template()
	if director.has_method("configure"):
		director.call("configure", island_id, wave_count, enemies_first_wave,
				enemies_per_wave_step, _enemy_scene(), genome, points, _arena, enemy_touch_damage)
	if director.has_method("start"):
		director.call("start")


func _make_wave_director() -> Node:
	# Prefer Role B's real WaveManager the moment it exists.
	if ResourceLoader.exists(WAVE_DIRECTOR_SCENE):
		var scene := load(WAVE_DIRECTOR_SCENE) as PackedScene
		if scene != null:
			var node := scene.instantiate() as Node
			if node != null:
				node.name = "WaveManager"
				return node
	var fallback := Node.new()
	if not _apply_script(fallback, PLACEHOLDER_WAVES_SCRIPT):
		return null
	fallback.name = "WaveDirectorPlaceholder"
	return fallback


func _enemy_scene() -> PackedScene:
	if ResourceLoader.exists(ENEMY_SCENE):
		var scene := load(ENEMY_SCENE) as PackedScene
		if scene != null:
			return scene
	return _placeholder_enemy_scene()


func _placeholder_enemy_scene() -> PackedScene:
	var script := load(PLACEHOLDER_ENEMY_SCRIPT)
	if not (script is Script):
		return null
	var proto := CharacterBody2D.new()
	proto.name = "ReefPlaceholderEnemy"
	proto.set_script(script)
	var packed := PackedScene.new()
	var err := packed.pack(proto)
	proto.free()
	if err != OK:
		push_warning("Could not pack placeholder enemy scene")
		return null
	return packed


func _genome_template() -> InvasiveGenome:
	var genome := InvasiveGenome.new()
	genome.acoustic_armor = genome_acoustic_armor
	genome.spiky_shell = genome_spiky_shell
	genome.heat_sink = genome_heat_sink
	genome.speed_multiplier = genome_speed_multiplier
	genome.max_health = genome_max_health
	return genome


func _spawn_points() -> Array[Vector2]:
	if _floor != null and _floor.has_method("spawn_points"):
		var result: Array = _floor.call("spawn_points", 10, _seed + 5)
		if result.size() >= 4:
			var typed: Array[Vector2] = []
			for p: Vector2 in result:
				typed.append(p)
			return typed
	# Ring fallback so a level can never soft-lock on a missing floor.
	var ring: Array[Vector2] = []
	var centre := _arena * 0.5
	for i in range(10):
		var a := TAU * float(i) / 10.0
		ring.append(centre + Vector2(cos(a), sin(a)) * minf(_arena.x, _arena.y) * 0.34)
	return ring


# ================================================================ HUD

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	if not _apply_script(hud, HUD_SCRIPT):
		return
	hud.name = "LevelHud"
	add_child(hud)
	_hud = hud
	if hud.has_signal("return_to_map_pressed"):
		hud.connect("return_to_map_pressed", _return_to_map)
	if hud.has_signal("retry_pressed"):
		hud.connect("retry_pressed", _retry)
	if hud.has_method("set_island_name"):
		hud.call("set_island_name", island_name, _level_number())
	if hud.has_method("set_wave"):
		hud.call("set_wave", 1, wave_count)
	if hud.has_method("bind_player"):
		hud.call("bind_player", _player)
	if _player != null and _player.has_signal("died"):
		_player.connect("died", _on_player_died)


func _on_player_died() -> void:
	if _completed or _hud == null:
		return
	if _hud.has_method("show_failed"):
		_hud.call("show_failed", island_name)


# ================================================================ FLOW

func _on_wave_started(wave_number: int) -> void:
	if _hud != null and _hud.has_method("set_wave"):
		_hud.call("set_wave", wave_number, wave_count)


func _on_wave_completed(_wave_number: int) -> void:
	pass


func _on_reef_cleared(reef_id: String) -> void:
	if _completed:
		return
	_completed = true
	if reef_id == "":
		reef_id = island_id
	GameProgress.mark_island_cleared(reef_id)
	if _hud != null and _hud.has_method("show_cleared"):
		_hud.call("show_cleared", island_name, _next_island_name(reef_id))


func _next_island_name(reef_id: String) -> String:
	var index := GameProgress.ISLANDS.find(reef_id)
	if index < 0 or index + 1 >= GameProgress.ISLANDS.size():
		return ""
	var next_id: String = GameProgress.ISLANDS[index + 1]
	return _pretty(next_id)


func _level_number() -> int:
	var index := GameProgress.ISLANDS.find(island_id)
	return (index + 1) if index >= 0 else 1


func _pretty(id: String) -> String:
	var parts := id.split("_")
	var out := ""
	for part: String in parts:
		if out != "":
			out += " "
		out += part.capitalize()
	return out


func _return_to_map() -> void:
	get_tree().change_scene_to_file(WORLD_MAP_SCENE)


func _retry() -> void:
	get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if _hud == null:
		return
	if _hud.has_method("set_enemies_left"):
		var left := 0
		if _director != null and _director.has_method("alive_count"):
			left = int(_director.call("alive_count"))
		elif not _completed:
			left = get_tree().get_nodes_in_group("invasive").size()
		_hud.call("set_enemies_left", left)
	if _hud.has_method("set_weapon") and _player != null:
		var weapon: Variant = _player.get("current_weapon_id")
		if weapon != null:
			_hud.call("set_weapon", String(weapon))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_map()


# ================================================================ HELPERS

func _apply_script(node: Object, path: String) -> bool:
	var script := load(path)
	if not (script is Script):
		push_warning("Missing script: %s" % path)
		return false
	node.set_script(script)
	return true
