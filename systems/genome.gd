class_name InvasiveGenome
extends Resource
# B owns this file

@export var acoustic_armor := 0.0
@export var spiky_shell := 0.0
@export var heat_sink := 0.0
@export var speed_multiplier := 1.0
@export var max_health := 50.0

func damage_multiplier_for(weapon_id: String) -> float:
	match weapon_id:
		"sonic": return (1.0 - acoustic_armor) * (1.0 + spiky_shell)
		"bubble": return (1.0 - spiky_shell) * (1.0 + heat_sink)
		"thermal": return (1.0 - heat_sink) * (1.0 + acoustic_armor)
	return 1.0
