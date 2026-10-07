extends Node
# C owns this file

signal island_cleared(id: String)
signal island_unlocked(id: String)
## Additive (W6): emitted the first time a species is recorded, so the bestiary
## can badge it new. No frozen signal is touched.
signal species_discovered(id: String)

const ISLANDS := ["redwake", "quiet_belt", "harrow", "second_watch", "mire"]
var cleared: Array[String] = []
## Additive (W6/W3): species the player has actually met in the water.
var bestiary_seen: Array[String] = []
const SAVE_PATH := "user://progress.json"

func _ready() -> void:
	load_progress()

func is_unlocked(id: String) -> bool:
	var idx := ISLANDS.find(id)
	if idx <= 0:
		return true
	return cleared.has(ISLANDS[idx - 1])

func mark_island_cleared(id: String) -> void:
	if not cleared.has(id):
		cleared.append(id)
		save_progress()
		island_cleared.emit(id)
		var next_idx := ISLANDS.find(id) + 1
		if next_idx < ISLANDS.size():
			island_unlocked.emit(ISLANDS[next_idx])

# ---------- Bestiary (additive) ----------

func has_seen_species(id: String) -> bool:
	return bestiary_seen.has(id)

## Records a species as discovered. Returns true when this call is what
## discovered it, so callers can fire a one-shot toast.
func mark_species_seen(id: String) -> bool:
	if id == "" or bestiary_seen.has(id):
		return false
	bestiary_seen.append(id)
	save_progress()
	species_discovered.emit(id)
	return true

func seen_species_count() -> int:
	return bestiary_seen.size()

func reset_bestiary() -> void:
	bestiary_seen.clear()
	save_progress()

func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"cleared": cleared,
		"seen": bestiary_seen,
	}))

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return
	# Old saves only carry "cleared": read each key defensively so a save written
	# before the bestiary existed still loads.
	if data.has("cleared") and data["cleared"] is Array:
		cleared.assign(data["cleared"])
	if data.has("seen") and data["seen"] is Array:
		bestiary_seen.assign(data["seen"])
