extends RefCounted
## Shared species database — the ONE source of truth for invasive species.
##
## Read by the enemy (spawning + art), the wave manager (species/zone weighting)
## and the in-game bestiary, so the book and the swarm can never disagree.
##
## const SpeciesDB := preload("res://systems/species_db.gd")
##
## Nothing here renames or removes anything in the frozen contract: species ids
## are new strings, and the damage maths still lives only in
## systems/genome.gd::damage_multiplier_for().
##
## Counter-loop reminder (>1 = that weapon HURTS MORE):
##   sonic   : (1 - acoustic_armor) * (1 + spiky_shell)   -> beats Spiky Shell
##   bubble  : (1 - spiky_shell)    * (1 + heat_sink)     -> beats Heat Sink
##   thermal : (1 - heat_sink)      * (1 + acoustic_armor) -> beats Acoustic Armor

const ORDER: Array[String] = [
	"drifter_jelly",
	"spine_urchin",
	"ember_nautilus",
	"kelp_snatcher",
	"bone_ray",
	"steelhead_bloom",
]

## Spawn-zone display names. Zone ids are shared across biomes where the
## terrain reads the same (open water and channels exist everywhere).
const ZONES := {
	"open_water": "Open Water",
	"coral_shelf": "Coral Shelf",
	"sand_bar": "Sand Bar",
	"channel": "Deep Channel",
	"kelp_trench": "Kelp Trench",
	"wreck_shallows": "Wreck Shallows",
	"vent_field": "Vent Field",
	"bone_flats": "Bone Flats",
	"ridge_ruins": "Ridge Ruins",
	"ash_drift": "Ash Drift",
}

## Majority, not ultimatum: a species' home zone dominates its spawn cycle but
## every other zone of the level keeps a guaranteed minority share.
const HOME_SLOTS := 7
const FLOOR_SLOTS := 1

## Canonical zone ids per island. The procedural floor builds these same zones
## (scenes/levels/reef_floor.gd, keyed by biome) and the spawn audit asserts the
## two agree, so the bestiary can list where a species shows up without loading
## a level.
const ISLAND_ZONES := {
	"redwake": ["open_water", "coral_shelf", "sand_bar", "channel"],
	"quiet_belt": ["open_water", "wreck_shallows", "kelp_trench", "channel"],
	"harrow": ["open_water", "vent_field", "bone_flats", "ridge_ruins", "ash_drift"],
	"second_watch": [],
	"mire": [],
}

const SPECIES := {
	"drifter_jelly": {
		"id": "drifter_jelly",
		"name": "Drifter Jelly",
		"blurb": "A translucent drifter trailing fine tendrils. The open-water baseline.",
		"lore": "The cheapest body in the reef: no shell worth the name, no vents, no plates. Drifter Jellies survive by numbers alone, so a sentinel that relies on one weapon quickly teaches the swarm to shrug it off.",
		"threat": 1,
		"baseline": {"acoustic_armor": 0.06, "spiky_shell": 0.12, "heat_sink": 0.06,
				"speed_multiplier": 0.88, "max_health": 40.0},
		"weak_to": ["sonic"],
		"weakness_reason": "A soft bell resonates apart under sonic pressure.",
		"resists": [],
		"home_zone": "open_water",
		"islands": ["redwake", "quiet_belt", "harrow"],
		"shape": "jelly",
		"tint": Color("4fb4e8"),
		"accent": Color("d8f4ff"),
		"size": 1.0,
	},
	"spine_urchin": {
		"id": "spine_urchin",
		"name": "Spine Urchin",
		"blurb": "A dark bulb of dense calcium needles growing on the coral shelf.",
		"lore": "Shotgunned coral rubble gave it that coat. Dense spines are brittle, so acoustic pressure cracks them and turns the urchin's own armour into shrapnel — but a bubble envelope simply cannot get a grip on the needles.",
		"threat": 2,
		"baseline": {"acoustic_armor": 0.05, "spiky_shell": 0.45, "heat_sink": 0.05,
				"speed_multiplier": 0.82, "max_health": 58.0},
		"weak_to": ["sonic"],
		"weakness_reason": "Sonic pulses shatter rigid spines and use them as shrapnel.",
		"resists": ["bubble"],
		"home_zone": "coral_shelf",
		"home_zone_by_island": {"quiet_belt": "wreck_shallows", "harrow": "ash_drift"},
		"islands": ["redwake", "quiet_belt", "harrow"],
		"shape": "urchin",
		"tint": Color("6b3f8f"),
		"accent": Color("c79bff"),
		"size": 1.0,
	},
	"ember_nautilus": {
		"id": "ember_nautilus",
		"name": "Ember Nautilus",
		"blurb": "A ribbed spiral shell venting geothermal heat through lateral slits.",
		"lore": "Born beside the vents, it breathes heat the way other species breathe water: a thermal beam only warms its chassis. Trap it in a bubble envelope, though, and its own cooling siphons suffocate it.",
		"threat": 2,
		"baseline": {"acoustic_armor": 0.16, "spiky_shell": 0.05, "heat_sink": 0.45,
				"speed_multiplier": 0.95, "max_health": 62.0},
		"weak_to": ["bubble"],
		"weakness_reason": "A bubble trap suffocates its cooling siphons; heat stress does the rest.",
		"resists": ["thermal"],
		"home_zone": "vent_field",
		"home_zone_by_island": {"quiet_belt": "channel"},
		"islands": ["quiet_belt", "harrow"],
		"shape": "nautilus",
		"tint": Color("e0662e"),
		"accent": Color("ffc46a"),
		"size": 1.05,
	},
	"kelp_snatcher": {
		"id": "kelp_snatcher",
		"name": "Kelp Snatcher",
		"blurb": "A ribbon eel that slithers between fronds and strikes in bursts.",
		"lore": "Built for the trench: almost no armour, but a body that turns on a coin. Its slippery hide shrugs off broad acoustic waves, while a sustained thermal beam cooks the uninsulated muscle underneath.",
		"threat": 2,
		"baseline": {"acoustic_armor": 0.14, "spiky_shell": 0.02, "heat_sink": 0.02,
				"speed_multiplier": 1.40, "max_health": 44.0},
		"weak_to": ["thermal"],
		"weakness_reason": "Unarmoured muscle cooks fast under sustained thermal focus.",
		"resists": ["sonic"],
		"home_zone": "kelp_trench",
		"home_zone_by_island": {"harrow": "ridge_ruins"},
		"islands": ["quiet_belt", "harrow"],
		"shape": "eel",
		"tint": Color("3f9a5a"),
		"accent": Color("9be07a"),
		"size": 1.0,
	},
	"bone_ray": {
		"id": "bone_ray",
		"name": "Bone Ray",
		"blurb": "A wide, flat glider plated in interlocking osteoderms.",
		"lore": "Ancient benthic rays whose dorsal scutes knit into a single acoustic mirror. Sonic pulses splash off the plates, but the same bone conducts heat straight into the body cavity — thermal is the answer.",
		"threat": 3,
		"baseline": {"acoustic_armor": 0.45, "spiky_shell": 0.10, "heat_sink": 0.02,
				"speed_multiplier": 1.05, "max_health": 78.0},
		"weak_to": ["thermal"],
		"weakness_reason": "Bone plates conduct heat straight into the body cavity.",
		"resists": ["sonic", "bubble"],
		"home_zone": "bone_flats",
		"islands": ["harrow"],
		"shape": "ray",
		"tint": Color("b9b2a0"),
		"accent": Color("f2ecdc"),
		"size": 1.15,
	},
	"steelhead_bloom": {
		"id": "steelhead_bloom",
		"name": "Steelhead Bloom",
		"blurb": "A clustered anemone head fused with pyrite plates and short barbs.",
		"lore": "It mines iron out of the ridge ruins and grows it. Nothing crushes it, nothing traps it — but heat melts the metallic binder that holds the cluster together, and a hard enough sonic hit cracks the seams.",
		"threat": 3,
		"baseline": {"acoustic_armor": 0.28, "spiky_shell": 0.52, "heat_sink": 0.05,
				"speed_multiplier": 0.70, "max_health": 92.0},
		"weak_to": ["thermal", "sonic"],
		"weakness_reason": "Heat melts the binder between plates; sonic cracks the seams.",
		"resists": ["bubble"],
		"home_zone": "ridge_ruins",
		"islands": ["harrow"],
		"shape": "bloom",
		"tint": Color("5c6b7d"),
		"accent": Color("cfe0f0"),
		"size": 1.2,
	},
}


## ---- lookups -------------------------------------------------------------

static func get_species(id: String) -> Dictionary:
	return SPECIES.get(id, SPECIES["drifter_jelly"])


static func has_species(id: String) -> bool:
	return SPECIES.has(id)


static func get_all_species_ids() -> Array[String]:
	return ORDER.duplicate()


static func get_species_for_island(island_id: String) -> Array[String]:
	var result: Array[String] = []
	for sid in ORDER:
		var islands: Array = (SPECIES[sid] as Dictionary).get("islands", [])
		if islands.has(island_id):
			result.append(sid)
	if result.is_empty():
		result.append("drifter_jelly")
	return result


static func zone_label(zone_id: String) -> String:
	return String(ZONES.get(zone_id, zone_id.capitalize()))


static func zone_ids_for_island(island_id: String) -> Array[String]:
	var out: Array[String] = []
	for z: String in (ISLAND_ZONES.get(island_id, []) as Array):
		out.append(z)
	return out


static func home_zone_for_island(species_id: String, island_id: String) -> String:
	return resolve_home_zone(species_id, island_id, zone_ids_for_island(island_id))


## Where a species can be met, for the bestiary: one row per island it is part
## of, naming its home zone and every other zone it still turns up in.
static func spawn_rows(species_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var data := get_species(species_id)
	for island: String in (data.get("islands", []) as Array):
		var zones := zone_ids_for_island(island)
		if zones.is_empty():
			continue
		var home := resolve_home_zone(species_id, island, zones)
		var others: Array[String] = []
		for z: String in zones:
			if z != home:
				others.append(zone_label(z))
		rows.append({"island": island, "home": zone_label(home), "others": others})
	return rows


static func weakness_text(species_id: String) -> String:
	var data := get_species(species_id)
	var weak: Array = data.get("weak_to", [])
	if weak.is_empty():
		return "No strong counter"
	var names: Array[String] = []
	for w: String in weak:
		names.append(w.to_upper())
	return "%s — %s" % [", ".join(names), String(data.get("weakness_reason", ""))]


static func resists_text(species_id: String) -> String:
	var data := get_species(species_id)
	var resists: Array = data.get("resists", [])
	if resists.is_empty():
		return "Nothing"
	var names: Array[String] = []
	for w: String in resists:
		names.append(w.to_upper())
	return ", ".join(names)


## The zone a species calls home on a given island: an island-specific override
## when the natural zone does not exist there, else its declared home, else the
## level's first zone. Always one of `zone_ids`.
static func resolve_home_zone(species_id: String, island_id: String, zone_ids: Array) -> String:
	var data := get_species(species_id)
	var by_island: Dictionary = data.get("home_zone_by_island", {})
	var preferred: String = String(by_island.get(island_id, data.get("home_zone", "")))
	if zone_ids.has(preferred):
		return preferred
	for z: String in zone_ids:
		if z == preferred:
			return z
	if zone_ids.is_empty():
		return "open_water"
	return String(zone_ids[0])


## Deterministic spawn cycle for one species over one level's zones: the home
## zone fills HOME_SLOTS of every (HOME_SLOTS + others) slots, and every other
## zone gets FLOOR_SLOTS, so a species is *predominantly* at home but never
## exclusive. Same species + same zone list = same cycle, every run.
static func zone_cycle(species_id: String, island_id: String, zone_ids: Array) -> Array[String]:
	var home := resolve_home_zone(species_id, island_id, zone_ids)
	var others: Array[String] = []
	for z: String in zone_ids:
		if z != home:
			others.append(z)
	var cycle: Array[String] = []
	var remaining_home := HOME_SLOTS
	var oi := 0
	var guard := 0
	while (remaining_home > 0 or oi < others.size()) and guard < 256:
		guard += 1
		if oi < others.size() and cycle.size() % 3 == 0:
			cycle.append(others[oi])
			oi += 1
		elif remaining_home > 0:
			cycle.append(home)
			remaining_home -= 1
		elif oi < others.size():
			cycle.append(others[oi])
			oi += 1
	if cycle.is_empty():
		cycle.append(home)
	return cycle


# ---- genomes -------------------------------------------------------------

static func create_baseline_genome(species_id: String) -> InvasiveGenome:
	var data := get_species(species_id)
	var base: Dictionary = data.get("baseline", {})
	var g := InvasiveGenome.new()
	g.species_id = species_id
	g.acoustic_armor = float(base.get("acoustic_armor", 0.0))
	g.spiky_shell = float(base.get("spiky_shell", 0.0))
	g.heat_sink = float(base.get("heat_sink", 0.0))
	g.speed_multiplier = float(base.get("speed_multiplier", 1.0))
	g.max_health = float(base.get("max_health", 50.0))
	g.clamp_traits()
	return g


## Species identity blended with an island's difficulty template. The island
## raises the whole roster (later islands are harder for every species) but
## never overwrites a species' signature trait, so a late-game Spine Urchin is
## still recognisably spiky. Falls back to the pure baseline with no template.
static func create_island_genome(species_id: String, template: InvasiveGenome) -> InvasiveGenome:
	var g := create_baseline_genome(species_id)
	if template == null:
		return g
	# The island templates sit around 0.05/0.05/0.05, 0.90 speed, 40 hp; treat
	# that as the baseline island and add half of anything above it.
	g.acoustic_armor += maxf(0.0, (template.acoustic_armor - 0.05) * 0.5)
	g.spiky_shell += maxf(0.0, (template.spiky_shell - 0.05) * 0.5)
	g.heat_sink += maxf(0.0, (template.heat_sink - 0.05) * 0.5)
	g.speed_multiplier *= template.speed_multiplier / 0.90
	g.max_health *= template.max_health / 40.0
	g.clamp_traits()
	return g


## Species whose signature trait makes them weak to `weapon_id` (multiplier > 1).
static func is_weak_to(species_id: String, weapon_id: String) -> bool:
	var weak: Array = get_species(species_id).get("weak_to", [])
	return weak.has(weapon_id)


# ---- validation ----------------------------------------------------------

## Machine-checkable audit of the species table: every species must really be
## hurt more by its declared weakness and really resist what it claims. Returns
## a list of human-readable problems; empty means the table is honest.
static func audit() -> Array[String]:
	var problems: Array[String] = []
	for sid in ORDER:
		var data: Dictionary = SPECIES[sid]
		var genome := create_baseline_genome(sid)
		var weak: Array = data.get("weak_to", [])
		if weak.is_empty():
			problems.append("%s declares no weakness" % sid)
		for w: String in weak:
			var m := genome.damage_multiplier_for(w)
			if m <= 1.0:
				problems.append("%s claims weak to %s but multiplier is %.4f" % [sid, w, m])
		for r: String in data.get("resists", []):
			var m := genome.damage_multiplier_for(r)
			if m >= 1.0:
				problems.append("%s claims to resist %s but multiplier is %.4f" % [sid, r, m])
		if weak.has("bubble") and data.get("resists", []).has("bubble"):
			problems.append("%s both weak to and resisting bubble" % sid)
		var home: String = data.get("home_zone", "")
		if not ZONES.has(home):
			problems.append("%s has unknown home zone '%s'" % [sid, home])
		if (data.get("islands", []) as Array).is_empty():
			problems.append("%s declares no islands" % sid)
	return problems
