# REEF SENTINEL — MASTER AI BRIEFING (paste this ENTIRE file into every AI session)

You are assisting with "Reef Sentinel", a Godot 4 top-down 2D marine shooter.
This contract OVERRIDES your defaults. Never rename anything defined here.
If you believe the contract should change: DO NOT change it — output your
suggestion as a "// PROPOSED CHANGE:" comment and stop.

## 1. Project facts
- Engine: Godot 4.x (same version for all members). Language: GDScript only.
- Team: A = player/weapons, B = enemies/GA/telemetry, C = levels/UI/progression.
- Enemy adaptation: genetic algorithm mutates enemy traits between waves based
  on player weapon-usage telemetry. Educational demo of resistance evolution.

## 2. GDScript style (all code must match)
- Indentation: TABS (Godot default).
- Files/folders: snake_case (`wave_manager.gd`). Nodes: PascalCase (`Submarine`).
- Signals/vars/functions: snake_case. Constants: SCREAMING_SNAKE_CASE.
- Typed GDScript where possible: `func take_health_damage(amount: float) -> void:`
- No new autoloads, no new class_names outside this contract.

## 3. Fixed strings — NEVER rename or respell
- Weapon IDs: "sonic" | "bubble" | "thermal"
- Node groups: "player" (submarine) | "invasive" (all enemies)
- Autoload singletons: Telemetry | GameProgress
- class_name: InvasiveGenome (Resource)
- Island IDs, in progression order:
  "redwake" -> "quiet_belt" -> "harrow" -> "second_watch" -> "mire"
- Save path: user://progress.json

## 4. Directory ownership (never edit outside your paths)
- A owns: scenes/player/, scenes/weapons/
- B owns: scenes/enemies/, systems/, autoload/telemetry.gd
- C owns: scenes/ui/, scenes/levels/, autoload/game_progress.gd
- Shared read-only: docs/INTEGRATION.md

## 5. Public API — signatures are frozen

### Player (A implements, B and C may CALL)
signal health_changed(current: int, max_health: int)
signal died
func take_health_damage(amount: float) -> void

### Enemy (B implements, A may CALL)
signal died(genome: Resource, position: Vector2)
func receive_damage(amount: float, weapon_id: String) -> void
func setup(genome: Resource) -> void

### Telemetry autoload (B implements, A may CALL)
func log_shot(weapon_id: String) -> void
func log_kill(genome: Resource, weapon_id: String, distance: float) -> void
func export_json() -> String
func reset_run() -> void

### GameProgress autoload (C implements, everyone may CALL)
signal island_cleared(id: String)
signal island_unlocked(id: String)
const ISLANDS := ["redwake", "quiet_belt", "harrow", "second_watch", "mire"]
func is_unlocked(id: String) -> bool
func mark_island_cleared(id: String) -> void

### WaveManager (B implements, C may CONNECT to signals)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal reef_cleared(reef_id: String)

### Genome (B implements, A may READ)
class_name InvasiveGenome extends Resource
@export var acoustic_armor := 0.0
@export var spiky_shell := 0.0
@export var heat_sink := 0.0
@export var speed_multiplier := 1.0
@export var max_health := 50.0
func damage_multiplier_for(weapon_id: String) -> float

## 6. Damage formula — lives ONLY in systems/genome.gd
- "sonic":   (1 - acoustic_armor) * (1 + spiky_shell)
- "bubble":  (1 - spiky_shell) * (1 + heat_sink)
- "thermal": (1 - heat_sink) * (1 + acoustic_armor)
Counter-loop: Sonic beats Spiky, Bubble beats Heat Sink, Thermal beats
Acoustic Armor. No weapon damage numbers anywhere else.

## 7. Gameplay flow (signals chain)
Player fires -> A calls Telemetry.log_shot() -> projectile Area2D hits body in
"group invasive" -> enemy.receive_damage(amount, weapon_id) -> B applies
genome multiplier -> enemy dies -> enemy.died(genome, position) ->
WaveManager counts -> reef_cleared(reef_id) -> C marks island cleared ->
next island unlocks. Telemetry feeds the GA which mutates genomes between waves.

## 8. Weapon behavior specs (A)
- sonic: fast straight projectile, 0.25 s cooldown, base damage 10
- bubble: slow Area2D trap, roots enemies 1.5 s, base damage 0, radius 80 px
- thermal: continuous beam, 30 damage/sec while held, overheat meter
Weapon switching: keys 1/2/3. Submarine speed: 300 px/s, 100 max health.

## 9. Definition of done (every PR)
- Game runs at 60 FPS with F5 on the branch, even with placeholder art.
- No files edited outside owned paths; no contract names changed.
- Placeholders allowed; broken builds are not.
