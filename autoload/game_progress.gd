extends Node
# C owns this file

signal island_cleared(id: String)
signal island_unlocked(id: String)

const ISLANDS := ["redwake", "quiet_belt", "harrow", "second_watch", "mire"]

func is_unlocked(_id: String) -> bool:
	return false

func mark_island_cleared(_id: String) -> void:
	pass
