extends RefCounted
## Genetic algorithm for invasive genomes. No class_name (contract) - use:
## const GeneticAlgorithm := preload("res://systems/genetic_algorithm.gd")

const WEAPON_IDS := ["sonic", "bubble", "thermal"]
const ELITE_COUNT := 2
const TOURNAMENT_SIZE := 3
const MUTATION_RATE := 0.35
const RESISTANCE_SIGMA := 0.08
const SPEED_SIGMA := 0.08
const HEALTH_SIGMA := 5.0
const METABOLIC_COST := 0.5
const MIN_EXPECTED_DAMAGE := 0.05


static func seed_population(size: int) -> Array[InvasiveGenome]:
	var pop: Array[InvasiveGenome] = []
	for i in size:
		var g := InvasiveGenome.new()
		g.acoustic_armor = randf_range(0.0, 0.1)
		g.spiky_shell = randf_range(0.0, 0.1)
		g.heat_sink = randf_range(0.0, 0.1)
		g.clamp_traits()
		pop.append(g)
	return pop


## Fitness = how well a genome resists the weapon mix the player actually used.
## usage: {weapon_id: fraction}. Higher is fitter.
static func fitness(genome: InvasiveGenome, usage: Dictionary) -> float:
	var total := 0.0
	var expected_damage := 0.0
	for w in WEAPON_IDS:
		var u: float = usage.get(w, 0.0)
		total += u
		expected_damage += u * genome.damage_multiplier_for(w)
	expected_damage = (expected_damage / total) if total > 0.0 else 1.0
	var resistance := 1.0 / maxf(expected_damage, MIN_EXPECTED_DAMAGE)
	var health_factor := sqrt(genome.max_health / 50.0)
	var investment := genome.acoustic_armor + genome.spiky_shell + genome.heat_sink
	investment += maxf(0.0, genome.speed_multiplier - 1.0)
	investment += maxf(0.0, (genome.max_health - 50.0) / 100.0)
	return resistance * health_factor / (1.0 + METABOLIC_COST * investment)


static func evolve(population: Array[InvasiveGenome], usage: Dictionary, next_size: int) -> Array[InvasiveGenome]:
	if population.is_empty():
		return seed_population(next_size)

	var scored: Array[Dictionary] = []
	for g in population:
		scored.append({"genome": g, "fitness": fitness(g, usage)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.fitness > b.fitness)

	var next: Array[InvasiveGenome] = []
	for i in mini(ELITE_COUNT, mini(scored.size(), next_size)):
		next.append(scored[i].genome.duplicate() as InvasiveGenome)

	while next.size() < next_size:
		var parent_a := _tournament(scored)
		var parent_b := _tournament(scored)
		var child := _crossover(parent_a, parent_b)
		_mutate(child)
		child.clamp_traits()
		next.append(child)
	return next


static func mean_traits(population: Array[InvasiveGenome]) -> Dictionary:
	var sums := {
		"acoustic_armor": 0.0, "spiky_shell": 0.0, "heat_sink": 0.0,
		"speed_multiplier": 0.0, "max_health": 0.0,
	}
	if population.is_empty():
		return sums
	for g in population:
		sums.acoustic_armor += g.acoustic_armor
		sums.spiky_shell += g.spiky_shell
		sums.heat_sink += g.heat_sink
		sums.speed_multiplier += g.speed_multiplier
		sums.max_health += g.max_health
	for key in sums:
		sums[key] = snappedf(sums[key] / population.size(), 0.001)
	return sums


static func _tournament(scored: Array[Dictionary]) -> InvasiveGenome:
	var best: Dictionary = scored[randi() % scored.size()]
	for i in TOURNAMENT_SIZE - 1:
		var challenger: Dictionary = scored[randi() % scored.size()]
		if challenger.fitness > best.fitness:
			best = challenger
	return best.genome


static func _crossover(a: InvasiveGenome, b: InvasiveGenome) -> InvasiveGenome:
	var child := InvasiveGenome.new()
	child.species_id = a.species_id if randf() < 0.5 else b.species_id
	child.acoustic_armor = a.acoustic_armor if randf() < 0.5 else b.acoustic_armor
	child.spiky_shell = a.spiky_shell if randf() < 0.5 else b.spiky_shell
	child.heat_sink = a.heat_sink if randf() < 0.5 else b.heat_sink
	child.speed_multiplier = a.speed_multiplier if randf() < 0.5 else b.speed_multiplier
	child.max_health = a.max_health if randf() < 0.5 else b.max_health
	return child


static func _mutate(g: InvasiveGenome) -> void:
	if randf() < MUTATION_RATE:
		g.acoustic_armor += randfn(0.0, RESISTANCE_SIGMA)
	if randf() < MUTATION_RATE:
		g.spiky_shell += randfn(0.0, RESISTANCE_SIGMA)
	if randf() < MUTATION_RATE:
		g.heat_sink += randfn(0.0, RESISTANCE_SIGMA)
	if randf() < MUTATION_RATE:
		g.speed_multiplier += randfn(0.0, SPEED_SIGMA)
	if randf() < MUTATION_RATE:
		g.max_health += randfn(0.0, HEALTH_SIGMA)
