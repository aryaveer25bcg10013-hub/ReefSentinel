extends Node
## Spawns waves of invasives for one reef and evolves genomes between waves.
##
## Frozen surface (docs/INTEGRATION.md §5) is the signal triple below. How a
## *level* starts a reef is explicitly NOT frozen, so level_base.gd probes for
## configure() + start() and reads alive_count(). Those live at the bottom of this
## file and funnel into B's own start_reef() loop — there is exactly one code path.
##
## // PROPOSED CHANGE: B's original file exposed only start_reef()/stop() with
## // auto_start=false, so a level could never start a reef. The additions below
## // are strictly additive; no frozen name is renamed or respelled.

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal reef_cleared(reef_id: String)

const GeneticAlgorithm := preload("res://systems/genetic_algorithm.gd")

# Jitter applied around a level's starting genome (level difficulty data) when
# founding the population, so an island still starts as hard as its .tscn says.
const TEMPLATE_RESISTANCE_JITTER := 0.03
const TEMPLATE_SPEED_JITTER := 0.06
const TEMPLATE_HEALTH_JITTER := 0.10
# Keeps any fallback spawn clear of the arena walls.
const SPAWN_MARGIN := 80.0
const SPAWN_JITTER := 26.0

@export var reef_id := "redwake"
@export var enemy_scene: PackedScene
@export var waves_per_reef := 3
@export var base_enemy_count := 6
@export var enemy_count_growth := 2
@export var spawn_radius := 520.0
@export var spawn_interval := 0.4
@export var inter_wave_delay := 3.0
@export var auto_start := false
@export var debug_log := true

var wave_number := 0
var population: Array[InvasiveGenome] = []

var _alive := 0
var _running := false

# Set by the level through configure().
var _genome_template: InvasiveGenome = null
var _spawn_points: Array[Vector2] = []
var _arena := Vector2(1600, 900)
var _touch_damage := 0.0
var _point_cursor := 0


func _ready() -> void:
	if auto_start:
		start_reef()


# ============================================================ LEVEL ENTRY POINT

func configure(island_id: String, wave_total: int, first_wave: int, wave_step: int,
		scene: PackedScene, genome_template: InvasiveGenome, points: Array[Vector2],
		arena: Vector2, touch_damage: float) -> void:
	reef_id = island_id
	waves_per_reef = maxi(1, wave_total)
	base_enemy_count = maxi(1, first_wave)
	enemy_count_growth = maxi(0, wave_step)
	if scene != null:
		enemy_scene = scene
	_genome_template = genome_template
	_spawn_points = points
	_arena = arena
	_touch_damage = touch_damage


func start() -> void:
	if _running:
		return
	start_reef(reef_id)


func start_reef(id: String = "") -> void:
	if enemy_scene == null:
		push_error("WaveManager: enemy_scene is not set")
		return
	if id != "":
		reef_id = id
	wave_number = 0
	Telemetry.reset_run()
	population = _seed_population(_enemy_count_for(1))
	_running = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died") and not player.is_connected("died", stop):
		player.connect("died", stop)
	_start_next_wave()


func stop() -> void:
	_running = false


# ============================================================ READ-ONLY QUERIES

func current_wave() -> int:
	return wave_number


func wave_total() -> int:
	return waves_per_reef


func alive_count() -> int:
	return maxi(_alive, 0)


func is_running() -> bool:
	return _running


# ============================================================ WAVE LOOP

func _start_next_wave() -> void:
	wave_number += 1
	Telemetry.reset_wave()
	_alive = population.size()
	wave_started.emit(wave_number)
	var batch: Array[InvasiveGenome] = population.duplicate()
	_spawn_batch(batch, wave_number)


func _spawn_batch(genomes: Array[InvasiveGenome], wave: int) -> void:
	for genome in genomes:
		await get_tree().create_timer(spawn_interval).timeout
		if not _running or wave != wave_number:
			return
		_spawn_enemy(genome)


func _spawn_enemy(genome: InvasiveGenome) -> void:
	var enemy := enemy_scene.instantiate()
	enemy.setup(genome)
	enemy.connect("died", _on_enemy_died)
	# INTEGRATION NOTE: B added to get_tree().current_scene, which made every
	# enemy a sibling of the level. Spawning into the level itself keeps the
	# arena owning its enemies (and the level's floor/camera as their parent).
	var host: Node = get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(enemy)
	enemy.global_position = _spawn_position()
	if _touch_damage > 0.0 and "touch_damage" in enemy:
		enemy.set("touch_damage", _touch_damage)


## B's original spawn was player position + a random angle * spawn_radius (520).
## Around a 1600x900 arena that places enemies OUTSIDE the walls (e.g. y = -70),
## where they can never reach the player and the wave can never clear — a hard
## soft-lock. Use the floor's designed spawn points when the level supplied them,
## and clamp the fallback ring into the arena either way.
func _spawn_position() -> Vector2:
	if not _spawn_points.is_empty():
		var point: Vector2 = _spawn_points[_point_cursor % _spawn_points.size()]
		_point_cursor += 1
		return _clamp_to_arena(point + Vector2(
			randf_range(-SPAWN_JITTER, SPAWN_JITTER), randf_range(-SPAWN_JITTER, SPAWN_JITTER)))
	var origin := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		origin = player.global_position
	return _clamp_to_arena(origin + Vector2.from_angle(randf() * TAU) * spawn_radius)


func _clamp_to_arena(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, SPAWN_MARGIN, maxf(SPAWN_MARGIN, _arena.x - SPAWN_MARGIN)),
		clampf(p.y, SPAWN_MARGIN, maxf(SPAWN_MARGIN, _arena.y - SPAWN_MARGIN)))


func _on_enemy_died(_genome: Resource, _position: Vector2) -> void:
	if not _running:
		return
	_alive -= 1
	if _alive <= 0:
		_finish_wave()


func _finish_wave() -> void:
	wave_completed.emit(wave_number)
	if wave_number >= waves_per_reef:
		_running = false
		reef_cleared.emit(reef_id)
		return

	var usage := Telemetry.get_usage_fractions(true)
	population = GeneticAlgorithm.evolve(population, usage, _enemy_count_for(wave_number + 1))
	var traits := GeneticAlgorithm.mean_traits(population)
	Telemetry.log_generation(wave_number, traits)
	if debug_log:
		print("[WaveManager] wave %d usage=%s -> next mean traits=%s" % [wave_number, usage, traits])

	await get_tree().create_timer(inter_wave_delay).timeout
	if _running:
		_start_next_wave()


func _enemy_count_for(wave: int) -> int:
	return base_enemy_count + enemy_count_growth * (wave - 1)


# ============================================================ FOUNDING GENOMES

## GeneticAlgorithm.seed_population() rolls every resistance in 0.0-0.1, which
## would throw away the per-island starting genomes each level scene exports
## (level difficulty design: redwake ~0.05, quiet_belt ~0.18, harrow ~0.3). Use
## the level's template when one was configured, jittered for founding variation,
## and fall back to the GA's own seeding when WaveManager runs standalone.
func _seed_population(size: int) -> Array[InvasiveGenome]:
	if _genome_template == null:
		return GeneticAlgorithm.seed_population(size)
	var pop: Array[InvasiveGenome] = []
	for i in size:
		var g := InvasiveGenome.new()
		g.acoustic_armor = _jitter_resistance(_genome_template.acoustic_armor)
		g.spiky_shell = _jitter_resistance(_genome_template.spiky_shell)
		g.heat_sink = _jitter_resistance(_genome_template.heat_sink)
		g.speed_multiplier = _genome_template.speed_multiplier * (
			1.0 + randf_range(-TEMPLATE_SPEED_JITTER, TEMPLATE_SPEED_JITTER))
		g.max_health = _genome_template.max_health * (
			1.0 + randf_range(-TEMPLATE_HEALTH_JITTER, TEMPLATE_HEALTH_JITTER))
		g.clamp_traits()
		pop.append(g)
	return pop


func _jitter_resistance(value: float) -> float:
	return maxf(0.0, value + randf_range(-TEMPLATE_RESISTANCE_JITTER, TEMPLATE_RESISTANCE_JITTER))
