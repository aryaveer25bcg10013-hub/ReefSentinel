class_name InvasiveGenome
extends Resource
## Heritable traits of an invasive enemy. The damage formula lives ONLY here.

const MAX_RESISTANCE := 0.8
const MIN_SPEED := 0.6
const MAX_SPEED := 1.8
const MIN_HEALTH := 30.0
const MAX_HEALTH := 120.0

@export var acoustic_armor := 0.0
@export var spiky_shell := 0.0
@export var heat_sink := 0.0
@export var speed_multiplier := 1.0
@export var max_health := 50.0


## Counter-loop: Sonic beats Spiky, Bubble beats Heat Sink, Thermal beats Acoustic Armor.
func damage_multiplier_for(weapon_id: String) -> float:
	match weapon_id:
		"sonic":
			return (1.0 - acoustic_armor) * (1.0 + spiky_shell)
		"bubble":
			return (1.0 - spiky_shell) * (1.0 + heat_sink)
		"thermal":
			return (1.0 - heat_sink) * (1.0 + acoustic_armor)
	push_warning("InvasiveGenome: unknown weapon_id '%s'" % weapon_id)
	return 1.0


func clamp_traits() -> void:
	acoustic_armor = clampf(acoustic_armor, 0.0, MAX_RESISTANCE)
	spiky_shell = clampf(spiky_shell, 0.0, MAX_RESISTANCE)
	heat_sink = clampf(heat_sink, 0.0, MAX_RESISTANCE)
	speed_multiplier = clampf(speed_multiplier, MIN_SPEED, MAX_SPEED)
	max_health = clampf(max_health, MIN_HEALTH, MAX_HEALTH)


func to_dict() -> Dictionary:
	return {
		"acoustic_armor": snappedf(acoustic_armor, 0.001),
		"spiky_shell": snappedf(spiky_shell, 0.001),
		"heat_sink": snappedf(heat_sink, 0.001),
		"speed_multiplier": snappedf(speed_multiplier, 0.001),
		"max_health": snappedf(max_health, 0.1),
	}
