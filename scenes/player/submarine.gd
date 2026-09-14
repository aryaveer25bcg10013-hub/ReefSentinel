extends CharacterBody2D
# A owns this file

signal health_changed(current: int, max_health: int)
signal died

@export var max_health := 100
@export var speed := 300.0

func take_health_damage(_amount: float) -> void:
	pass
