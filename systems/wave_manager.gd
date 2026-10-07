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
const SpeciesDB := preload("res://systems/species_db.gd")

# Jitter applied around a level's starting genome (level difficulty data) when
# founding the population, so an island still starts as hard as its .tscn says.
const TEMPLATE_RESISTANCE_JITTER := 0.03
const TEMPLATE_SPEED_JITTER := 0.06
const TEMPLATE_HEALTH_JITTER := 0.10
# Keeps any fallback spawn clear of the arena walls.
const SPAWN_MARGIN := 80.0
const SPAWN_JITTER := 26.0
# Keeps a jittered spawn at least as far from the arena centre as the floor's
# own spawn rule (reef_floor.SPAWN_MIN_CENTRE_DIST).
const SPAWN_MIN_CENTRE_DIST := 340.0
# The centre band above only means "away from the player" while the player is in
# the middle. The sentinel is free to leave — it parks over a coral bed to plant
# coral after a wave — so distance from the *player* gets its own rule, the same
# 340 px band measured from them instead of from the arena centre.
const SPAWN_MIN_PLAYER_DIST := 340.0
# How many times a spawn point is re-rolled before giving up and taking the far
# side of the ring. Cheap: a zone pool holds ZONE_POOL_SIZE validated points.
const SPAWN_PLAYER_RETRIES := 6

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
var _spawned_total := 0

# Set by the level through configure().
var _genome_template: InvasiveGenome = null
var _spawn_points: Array[Vector2] = []
var _arena := Vector2(1600, 900)
var _touch_damage := 0.0
var _point_cursor := 0

# W7 majority-weighted spawning (additive).
var _spawn_zones: Array[Dictionary] = []      # {id, label, centre, radius, points}
var _zone_ids: Array[String] = []
var _zone_cycles: Dictionary = {}             # species id -> Array[String]
var _zone_cursors: Dictionary = {}            # "species|zone" -> int
var _spawn_zone_report: Dictionary = {}       # zone id -> {species id -> count}
var _floor: Object = null                     # reef floor, for validated points
var _prev_profile: Dictionary = {}
var _profile_delta: Dictionary = {}
var _prev_mean_traits: Dictionary = {}
var _mean_traits: Dictionary = {}


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


## Additive: hand the wave manager the level's named spawn zones (from
## reef_floor.spawn_zones()) so species can arrive predominantly at home.
func set_spawn_zones(zones: Array) -> void:
	_spawn_zones.clear()
	_zone_ids.clear()
	for z: Dictionary in zones:
		var entry := z.duplicate()
		_spawn_zones.append(entry)
		_zone_ids.append(String(entry["id"]))
	_zone_cycles.clear()
	_zone_cursors.clear()


## Additive: the floor node, used to validate jittered spawn points.
func set_floor_source(floor_node: Object) -> void:
	_floor = floor_node


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
	_spawned_total = 0
	_spawn_zone_report.clear()
	Telemetry.reset_run()
	population = _seed_population(_enemy_count_for(1))
	# Baseline the adaptation readout against the founding population, so the
	# first generation's delta describes wave 1 -> wave 2 honestly.
	_prev_profile = resistance_profile()
	_profile_delta.clear()
	_prev_mean_traits = GeneticAlgorithm.mean_traits(population)
	_mean_traits = _prev_mean_traits.duplicate()
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


## Mean damage multiplier the live population applies to each weapon (>1 means
## that weapon is still effective, <1 means the swarm is tanking it).
func resistance_profile() -> Dictionary:
	var profile := {"sonic": 0.0, "bubble": 0.0, "thermal": 0.0}
	if population.is_empty():
		return profile
	for g in population:
		for w: String in ["sonic", "bubble", "thermal"]:
			profile[w] += g.damage_multiplier_for(w)
	for w: String in profile.keys():
		profile[w] = snappedf(float(profile[w]) / float(population.size()), 0.001)
	return profile


## Additive: mean evolved traits of the live population (same maths the GA logs).
func mean_traits() -> Dictionary:
	if population.is_empty():
		return {}
	return GeneticAlgorithm.mean_traits(population)


## Additive: how the current population's resistance to each weapon compares
## with the previous generation. Negative = the swarm got better against it.
func generation_delta() -> Dictionary:
	return _profile_delta.duplicate()


## Additive: mean traits before and after the last evolution step, for the
## between-wave "the swarm is adapting" panel ({before, after} dictionaries).
func last_generation_traits() -> Dictionary:
	return {"before": _prev_mean_traits.duplicate(), "after": _mean_traits.duplicate()}


## Additive: which species are currently in the population, with counts.
func species_roster() -> Dictionary:
	var roster := {}
	for g in population:
		roster[g.species_id] = int(roster.get(g.species_id, 0)) + 1
	return roster


## Additive: per-zone spawn tallies ({zone_id: {species_id: count}}), used by the
## spawn audit and the guidebook's "where it shows up" hints.
func spawn_zone_report() -> Dictionary:
	return _spawn_zone_report.duplicate(true)


func total_spawned() -> int:
	return _spawned_total


## Additive: the zone a species favours on this island (its "home" here).
func home_zone_for(species_id: String) -> String:
	return SpeciesDB.resolve_home_zone(species_id, reef_id, _zone_ids)


func zone_label(zone_id: String) -> String:
	return SpeciesDB.zone_label(zone_id)


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
	enemy.global_position = _spawn_position_for(genome.species_id)
	if _touch_damage > 0.0 and "touch_damage" in enemy:
		enemy.set("touch_damage", _touch_damage)
	_spawned_total += 1


# ============================================================ ZONE SPAWNING
# W7: every species has a home zone per island, but never exclusively — each
# species' cycle always contains every zone of the level. SpeciesDB.zone_cycle()
# builds the deterministic pattern (home = HOME_SLOTS, others = FLOOR_SLOTS).

func _zone_cycle_for(species_id: String) -> Array[String]:
	if _zone_ids.is_empty():
		var empty: Array[String] = []
		return empty
	if not _zone_cycles.has(species_id):
		_zone_cycles[species_id] = SpeciesDB.zone_cycle(species_id, reef_id, _zone_ids)
	return _zone_cycles[species_id]


func _next_zone_for(species_id: String) -> String:
	var cycle := _zone_cycle_for(species_id)
	if cycle.is_empty():
		return ""
	var key := "%s|cycle" % species_id
	var cursor := int(_zone_cursors.get(key, 0))
	_zone_cursors[key] = cursor + 1
	return cycle[cursor % cycle.size()]


func _point_in_zone(zone_id: String) -> Vector2:
	if _floor != null and _floor.has_method("zone_spawn_point"):
		var point: Variant = _floor.call("zone_spawn_point", zone_id, SPAWN_JITTER)
		if point is Vector2:
			return _clamp_to_arena(point)
	for z: Dictionary in _spawn_zones:
		if String(z["id"]) != zone_id:
			continue
		var pool: Array = z.get("points", [])
		if pool.is_empty():
			break
		var key := "%s|point" % zone_id
		var cursor := int(_zone_cursors.get(key, 0)) % pool.size()
		_zone_cursors[key] = cursor + 1
		return _clamp_to_arena(pool[cursor] + Vector2(
			randf_range(-SPAWN_JITTER, SPAWN_JITTER), randf_range(-SPAWN_JITTER, SPAWN_JITTER)))
	return _spawn_position()


## Wave spawn position: zone first (weighted by species), point second. Both
## routes pass the player rule, so a wave cannot arrive on top of the sentinel.
func _spawn_position_for(species_id: String) -> Vector2:
	var zone_id := _next_zone_for(species_id)
	if zone_id == "":
		return _spawn_position()
	var entry: Dictionary = _spawn_zone_report.get(zone_id, {})
	entry[species_id] = int(entry.get(species_id, 0)) + 1
	_spawn_zone_report[zone_id] = entry
	return _fair_zone_point(zone_id)


## B's original spawn was player position + a random angle * spawn_radius (520).
## Around a 1600x900 arena that places enemies OUTSIDE the walls (e.g. y = -70),
## where they can never reach the player and the wave can never clear — a hard
## soft-lock. Use the floor's designed spawn points when the level supplied them,
## and clamp the fallback ring into the arena either way.
func _spawn_position() -> Vector2:
	for _attempt in range(SPAWN_PLAYER_RETRIES):
		var candidate := _candidate_spawn_position()
		if _clear_of_player(candidate):
			return candidate
	# Every candidate came up short: give the wave the far side of the ring.
	return _farthest_ring_point()


## One unfiltered attempt: the level's designed points when it supplied them,
## else B's original player-relative ring (clamped inside the walls).
func _candidate_spawn_position() -> Vector2:
	if not _spawn_points.is_empty():
		var point: Vector2 = _spawn_points[_point_cursor % _spawn_points.size()]
		_point_cursor += 1
		return _safe_jitter(point)
	var origin := Vector2.ZERO
	var player := _player_node()
	if player != null:
		origin = player.global_position
	return _clamp_to_arena(origin + Vector2.from_angle(randf() * TAU) * spawn_radius)


## The sentinel, or null when there is none (headless tools, unit tests).
func _player_node() -> Node2D:
	var node := get_tree().get_first_node_in_group("player")
	return node as Node2D if node is Node2D else null


## The player rule: at least SPAWN_MIN_PLAYER_DIST from the sentinel. A level
## with no player is not a level with a player in the way, so that passes.
func _clear_of_player(p: Vector2) -> bool:
	var player := _player_node()
	if player == null:
		return true
	return p.distance_to(player.global_position) >= SPAWN_MIN_PLAYER_DIST


## A zone's own point, but fair to the player. _point_in_zone() walks the zone's
## validated pool one point per call, so re-rolling really does try somewhere
## else. If the whole zone is out (the sentinel is standing in it), any safe
## point will do — the species arrives from the wrong neighbourhood, not late.
func _fair_zone_point(zone_id: String) -> Vector2:
	for _attempt in range(SPAWN_PLAYER_RETRIES):
		var point := _point_in_zone(zone_id)
		if _clear_of_player(point):
			return point
	return _spawn_position()


## Last resort, when even the level's own points were all too close (a cramped
## arena, or the sentinel mid-arena): the ring point they are farthest from.
func _farthest_ring_point() -> Vector2:
	var player := _player_node()
	var best := _clamp_to_arena(_arena * 0.5 - Vector2(0.0, SPAWN_MIN_CENTRE_DIST))
	if player == null:
		return best
	var best_dist := -1.0
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var p := _clamp_to_arena(_arena * 0.5
				+ Vector2(cos(a), sin(a)) * minf(_arena.x, _arena.y) * 0.44)
		var d := p.distance_to(player.global_position)
		if d > best_dist:
			best_dist = d
			best = p
	return best


## Jitter must never break the spawn guarantees: a jittered point is only kept
## when it is still inside the floor, clear of obstacles and >= 340 px from the
## arena centre (the band the audit checks). Otherwise the clean point is used.
func _safe_jitter(base: Vector2) -> Vector2:
	var jittered := _clamp_to_arena(base + Vector2(
		randf_range(-SPAWN_JITTER, SPAWN_JITTER), randf_range(-SPAWN_JITTER, SPAWN_JITTER)))
	if _floor != null and is_instance_valid(_floor) and _floor.has_method("is_spawn_clear"):
		if bool(_floor.call("is_spawn_clear", jittered)):
			return jittered
		return _clamp_to_arena(base)
	if jittered.distance_to(_arena * 0.5) >= SPAWN_MIN_CENTRE_DIST:
		return jittered
	return _clamp_to_arena(base)


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
	_prev_mean_traits = GeneticAlgorithm.mean_traits(population)
	population = GeneticAlgorithm.evolve(population, usage, _enemy_count_for(wave_number + 1))
	_mean_traits = GeneticAlgorithm.mean_traits(population)
	var profile := resistance_profile()
	_profile_delta.clear()
	for w in profile:
		_profile_delta[w] = snappedf(profile[w] - float(_prev_profile.get(w, profile[w])), 0.001)
	_prev_profile = profile
	var traits := _mean_traits
	Telemetry.log_generation(wave_number, traits)
	if debug_log:
		print("[WaveManager] wave %d usage=%s -> next mean traits=%s" % [wave_number, usage, traits])

	await get_tree().create_timer(inter_wave_delay).timeout
	if _running:
		_start_next_wave()


func _enemy_count_for(wave: int) -> int:
	return base_enemy_count + enemy_count_growth * (wave - 1)


# ============================================================ FOUNDING GENOMES

# // PROPOSED CHANGE: founding genomes are seeded from SpeciesDB's per-species
# // baselines blended with the island difficulty template, so an island is still
# // as hard as its .tscn says while each invasive keeps its species identity and
# // signature trait. Fallback to the GA's own roll when no template was set.
func _seed_population(size: int) -> Array[InvasiveGenome]:
	var pop: Array[InvasiveGenome] = []
	var available := SpeciesDB.get_species_for_island(reef_id)
	if available.is_empty():
		return GeneticAlgorithm.seed_population(size)
	for i in size:
		# Round-robin so every island roster is represented in every wave, with
		# a gentle drift towards the hardier species as the waves progress.
		var offset := (maxi(wave_number, 1) - 1) * 2
		var species_id: String = available[(i + offset) % available.size()]
		var g := SpeciesDB.create_island_genome(species_id, _genome_template)
		g.acoustic_armor = _jitter_resistance(g.acoustic_armor)
		g.spiky_shell = _jitter_resistance(g.spiky_shell)
		g.heat_sink = _jitter_resistance(g.heat_sink)
		g.speed_multiplier *= 1.0 + randf_range(-TEMPLATE_SPEED_JITTER, TEMPLATE_SPEED_JITTER)
		g.max_health *= 1.0 + randf_range(-TEMPLATE_HEALTH_JITTER, TEMPLATE_HEALTH_JITTER)
		g.clamp_traits()
		pop.append(g)
	return pop


func _jitter_resistance(value: float) -> float:
	return maxf(0.0, value + randf_range(-TEMPLATE_RESISTANCE_JITTER, TEMPLATE_RESISTANCE_JITTER))
