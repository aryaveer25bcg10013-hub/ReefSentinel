extends Node
# C owns this file

signal island_cleared(id: String)
signal island_unlocked(id: String)

const ISLANDS := ["redwake", "quiet_belt", "harrow", "second_watch", "mire"]
var cleared: Array[String] = []
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

func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"cleared": cleared}))

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary and data.has("cleared"):
		cleared.assign(data["cleared"])
