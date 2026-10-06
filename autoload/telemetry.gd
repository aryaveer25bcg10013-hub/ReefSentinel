extends Node
## Autoload "Telemetry": records player weapon usage and kills for the GA.

const WEAPON_IDS := ["sonic", "bubble", "thermal"]
const MAX_KILL_LOG := 500

var _run_shots := {}
var _wave_shots := {}
var _run_kills := {}
var _kill_log: Array[Dictionary] = []
var _generation_log: Array[Dictionary] = []


func _ready() -> void:
	reset_run()


func log_shot(weapon_id: String) -> void:
	if not WEAPON_IDS.has(weapon_id):
		push_warning("Telemetry.log_shot: unknown weapon_id '%s'" % weapon_id)
		return
	_run_shots[weapon_id] += 1
	_wave_shots[weapon_id] += 1


func log_kill(genome: Resource, weapon_id: String, distance: float) -> void:
	if WEAPON_IDS.has(weapon_id):
		_run_kills[weapon_id] += 1
	var traits := {}
	var g := genome as InvasiveGenome
	if g != null:
		traits = g.to_dict()
	if _kill_log.size() >= MAX_KILL_LOG:
		_kill_log.pop_front()
	_kill_log.append({
		"t": snappedf(Time.get_ticks_msec() / 1000.0, 0.01),
		"weapon_id": weapon_id,
		"distance": snappedf(distance, 0.1),
		"genome": traits,
	})


func export_json() -> String:
	return JSON.stringify({
		"shots": _run_shots,
		"kills": _run_kills,
		"usage_fractions": get_usage_fractions(false),
		"generations": _generation_log,
		"kill_log": _kill_log,
	}, "\t")


func reset_run() -> void:
	_run_shots = _zeroed_counters()
	_wave_shots = _zeroed_counters()
	_run_kills = _zeroed_counters()
	_kill_log.clear()
	_generation_log.clear()


# --- Additions used by WaveManager / GA (do not change frozen API above) ---

func reset_wave() -> void:
	_wave_shots = _zeroed_counters()


## Share of shots per weapon, summing to 1.0 (all zeros if nothing was fired).
func get_usage_fractions(wave_only: bool = true) -> Dictionary:
	var source: Dictionary = _wave_shots if wave_only else _run_shots
	var total := 0
	for w in WEAPON_IDS:
		total += int(source[w])
	var result := {}
	for w in WEAPON_IDS:
		result[w] = (float(source[w]) / float(total)) if total > 0 else 0.0
	return result


func log_generation(wave_number: int, mean_traits: Dictionary) -> void:
	_generation_log.append({
		"wave": wave_number,
		"usage": get_usage_fractions(true),
		"mean_traits": mean_traits,
	})


func _zeroed_counters() -> Dictionary:
	var d := {}
	for w in WEAPON_IDS:
		d[w] = 0
	return d
