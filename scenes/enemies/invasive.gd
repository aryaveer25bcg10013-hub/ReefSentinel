extends CharacterBody2D
# B owns this file

signal died(genome: Resource, position: Vector2)

func receive_damage(_amount: float, _weapon_id: String) -> void:
	pass

func setup(_genome: Resource) -> void:
	pass
