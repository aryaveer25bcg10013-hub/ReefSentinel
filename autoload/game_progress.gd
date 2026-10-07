extends Node
# C owns this file

signal island_cleared(id: String)
signal island_unlocked(id: String)
## Additive (W6): emitted the first time a species is recorded, so the guidebook
## can badge it new. No frozen signal is touched.
signal species_discovered(id: String)
## Additive (W8): emitted when a reef is credited as restored, so the map and the
## guidebook can celebrate it without polling.
signal reef_restored(id: String)

const ISLANDS := ["redwake", "quiet_belt", "harrow", "second_watch", "mire"]
var cleared: Array[String] = []
## Additive (W6/W3): species the player has actually met in the water.
var species_seen: Array[String] = []
## Additive (W8): islands whose coral was actually brought back.
var reefs_restored: Array[String] = []
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

# ---------- Guidebook: species records (additive) ----------

func has_seen_species(id: String) -> bool:
	return species_seen.has(id)

## Records a species as discovered. Returns true when this call is what
## discovered it, so callers can fire a one-shot toast.
func mark_species_seen(id: String) -> bool:
	if id == "" or species_seen.has(id):
		return false
	species_seen.append(id)
	save_progress()
	species_discovered.emit(id)
	return true

func seen_species_count() -> int:
	return species_seen.size()

func reset_seen() -> void:
	species_seen.clear()
	save_progress()

# ---------- Reef restoration (additive, W8) ----------

func is_reef_restored(id: String) -> bool:
	return reefs_restored.has(id)


## Credits an island's reef as restored. Returns true only for the first time,
## so callers can fire a one-shot celebration.
func mark_reef_restored(id: String) -> bool:
	if id == "" or reefs_restored.has(id):
		return false
	reefs_restored.append(id)
	save_progress()
	reef_restored.emit(id)
	return true


func restored_reef_count() -> int:
	return reefs_restored.size()


func reset_reefs() -> void:
	reefs_restored.clear()
	save_progress()

func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"cleared": cleared,
		"seen": species_seen,
		"restored": reefs_restored,
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
	# before the guidebook or the reef component existed still loads. The JSON keys
	# are unchanged, so the same file keeps working.
	if data.has("cleared") and data["cleared"] is Array:
		cleared.assign(data["cleared"])
	if data.has("seen") and data["seen"] is Array:
		species_seen.assign(data["seen"])
	if data.has("restored") and data["restored"] is Array:
		reefs_restored.assign(data["restored"])
