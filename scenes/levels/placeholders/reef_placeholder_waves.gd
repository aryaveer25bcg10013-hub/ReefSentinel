extends Node
# C-owned PLACEHOLDER wave director — scaffolding only, NOT Role B's WaveManager.
#
# Why this exists: the levels need a working wave loop before
# res://systems/wave_manager.tscn lands. It emits the frozen WaveManager signal
# triple, so level_base.gd connects to exactly the same three signals whether
# B's director exists or not — swapping it in requires no level edits.
#
# Frozen WaveManager signals implemented verbatim:
#   signal wave_started(wave_number: int)
#   signal wave_completed(wave_number: int)
#   signal reef_cleared(reef_id: String)
#
# Genome traits are NOT invented here. The level supplies a template genome
# (level difficulty data) and this director only jitters a copy per enemy, so
# systems/genome.gd stays the single source of truth for resistance.

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal reef_cleared(reef_id: String)

const GENOME_JITTER := 0.05   # per-enemy variation around the level baseline
const SPAWN_SPACING := 0.25   # seconds between enemies inside one wave

var _island_id := ""
var _wave_total := 3
var _first_wave := 3
var _wave_step := 2
var _enemy_scene: PackedScene = null
var _genome_template: InvasiveGenome = null
var _points: Array[Vector2] = []
var _arena := Vector2(1600, 900)
var _touch_damage := 8.0

var _wave := 0
var _alive: Array[Node] = []
var _queue_remaining := 0
var _spawn_timer := 0.0
var _running := false
var _point_cursor := 0


func configure(island_id: String, wave_total: int, first_wave: int, wave_step: int,
		enemy_scene: PackedScene, genome_template: InvasiveGenome, points: Array[Vector2],
		arena: Vector2, touch_damage: float) -> void:
	_island_id = island_id
	_wave_total = maxi(1, wave_total)
	_first_wave = maxi(1, first_wave)
	_wave_step = maxi(0, wave_step)
	_enemy_scene = enemy_scene
	_genome_template = genome_template
	_points = points
	_arena = arena
	_touch_damage = touch_damage


func start() -> void:
	if _running:
		return
	_running = true
	_wave = 0
	_begin_next_wave()


func current_wave() -> int:
	return _wave


func wave_total() -> int:
	return _wave_total


func alive_count() -> int:
	_prune()
	return _alive.size() + _queue_remaining


# NOTE: Array.filter() returns an UNTYPED Array in GDScript, so reassigning it
# straight back into an Array[Node] is a runtime error. Prune with a loop.
func _prune() -> void:
	var kept: Array[Node] = []
	for node: Node in _alive:
		if is_instance_valid(node):
			kept.append(node)
	_alive = kept


func is_running() -> bool:
	return _running


# ---------- wave loop ----------

func _begin_next_wave() -> void:
	_wave += 1
	_queue_remaining = _first_wave + (_wave - 1) * _wave_step
	_spawn_timer = 0.0
	wave_started.emit(_wave)


func _process(delta: float) -> void:
	if not _running:
		return
	if _queue_remaining > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_SPACING
			_queue_remaining -= 1
			_spawn_enemy()
		return

	_prune()
	if _alive.is_empty():
		_finish_wave()


func _finish_wave() -> void:
	wave_completed.emit(_wave)
	if _wave >= _wave_total:
		_running = false
		reef_cleared.emit(_island_id)
	else:
		_begin_next_wave()


func _spawn_enemy() -> void:
	if _enemy_scene == null or _points.is_empty():
		return
	var enemy := _enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	get_parent().add_child(enemy)
	var point: Vector2 = _points[_point_cursor % _points.size()]
	_point_cursor += 1
	enemy.global_position = point + Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0))
	if enemy.has_method("set_arena_limit"):
		enemy.call("set_arena_limit", _arena)
	if "touch_damage" in enemy:
		enemy.set("touch_damage", _touch_damage)
	if enemy.has_method("setup"):
		enemy.call("setup", _make_genome())
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died)
	_alive.append(enemy)


func _on_enemy_died(_genome: Resource, _position: Vector2) -> void:
	_prune()


# ---------- genome ----------

func _make_genome() -> InvasiveGenome:
	var genome := InvasiveGenome.new()
	if _genome_template != null:
		genome.acoustic_armor = _jitter(_genome_template.acoustic_armor)
		genome.spiky_shell = _jitter(_genome_template.spiky_shell)
		genome.heat_sink = _jitter(_genome_template.heat_sink)
		genome.speed_multiplier = _jitter(_genome_template.speed_multiplier)
		genome.max_health = _jitter(_genome_template.max_health)
	return genome


func _jitter(value: float) -> float:
	return maxf(0.0, value * (1.0 + randf_range(-GENOME_JITTER, GENOME_JITTER)))
