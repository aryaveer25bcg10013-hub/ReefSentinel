# Reef Sentinel — Master Session Briefing

Paste this entire file into every coding-model session that touches this project.
It combines the live integration contract with the repo context, current state,
known integration gaps, and the rules all AI sessions must follow.

Usage note: this file is meant to be the ONLY copy you paste. When you open a
new session, start from this file, then add only the branch, role, and current
goal for that session. Do not re-paste the separate contract file on top of it,
because this file already contains it.

If you believe something in this brief should change, do **not** change it.
Output your suggestion as a `// PROPOSED CHANGE:` comment and stop.

---

## 1. Project identity

- Repo: `https://github.com/aryaveer25bcg10013-hub/ReefSentinel.git`
- Name in project file: `ReefSentinel`
- Engine: Godot 4.7 (Godot 4.7.2 stable is the installed editor)
- Renderer/physics from `project.godot`:
  - render driver: `d3d12`
  - physics engine: `Jolt Physics`
  - stretch mode: `canvas_items`, stretch aspect: `expand`
- Language: GDScript only
- Game genre: top-down 2D marine shooter
- Core idea: player controls a submarine across a chain of reef islands.
  Enemies adapt between waves via a genetic algorithm that mutates traits based
  on player weapon-usage telemetry. This is an educational demo of resistance
  evolution.

---

## 2. Team ownership model

Keep work strictly inside owned paths. Do not edit outside your assigned area
unless the task explicitly covers a shared contract file or a frozen API file.

- Role A owns:
  - `scenes/player/`
  - `scenes/weapons/`
- Role B owns:
  - `scenes/enemies/`
  - `systems/`
  - `autoload/telemetry.gd`
- Role C owns:
  - `scenes/ui/`
  - `scenes/levels/`
  - `autoload/game_progress.gd`
- Shared read-only: `docs/INTEGRATION.md`

---

## 3. Godot and GDScript style

- Indentation: TABS (Godot default).
- Files and folders: `snake_case`, for example `wave_manager.gd`.
- Node names: `PascalCase`, for example `Submarine`.
- Signals, variables, and functions: `snake_case`.
- Constants: `SCREAMING_SNAKE_CASE`.
- Use typed GDScript where possible:
  - `func take_health_damage(amount: float) -> void:`
- Frozen API and frozen names override any style preference. Never rename things
  defined in the contract just because a style pass would look cleaner.

### GDScript gotcha that already bit this project

`Array.filter()` returns an **untyped** `Array`, even when called on a typed
array like `Array[Node]`. Assigning that straight back into an `Array[Node]`
variable is a runtime error, and the error silently aborted the wave loop so
levels could never be cleared. Prune typed arrays with an explicit loop:

```gdscript
var kept: Array[Node] = []
for node: Node in _alive:
	if is_instance_valid(node):
		kept.append(node)
_alive = kept
```

### Movement keys live in project.godot, not in code

Godot's built-in `ui_left` / `ui_right` / `ui_up` / `ui_down` actions ship bound
to the **arrow keys only**. On the earlier `main`-derived branches there was no
`[input]` section at all, so WASD did nothing while the HUD advertised it.
`project.godot` now binds arrows *and* WASD to those same four actions. If you
ever see movement break again, check `[input]` in `project.godot` first.

---

## 4. Fixed strings — never rename or respell

- Weapon IDs: `"sonic"`, `"bubble"`, `"thermal"`
- Node groups:
  - `"player"` for the submarine
  - `"invasive"` for all enemies
- Autoload singletons:
  - `Telemetry`
  - `GameProgress`
- class_name resource: `InvasiveGenome`, which extends `Resource`
- Island IDs in progression order:
  - `"redwake"`
  - `"quiet_belt"`
  - `"harrow"`
  - `"second_watch"`
  - `"mire"`
- Save path: `user://progress.json`

---

## 5. Frozen public API

These signatures are fixed. Other code may call them, but the signatures and
names themselves are not up for revision without a proposal comment.

### Player — Role A implements; Role B and C may call

```gdscript
signal health_changed(current: int, max_health: int)
signal died

func take_health_damage(amount: float) -> void
```

### Enemy — Role B implements; Role A may call

```gdscript
signal died(genome: Resource, position: Vector2)

func receive_damage(amount: float, weapon_id: String) -> void
func setup(genome: Resource) -> void
```

### Telemetry autoload — Role B implements; Role A may call

```gdscript
func log_shot(weapon_id: String) -> void
func log_kill(genome: Resource, weapon_id: String, distance: float) -> void
func export_json() -> String
func reset_run() -> void
```

### GameProgress autoload — Role C implements; everyone may call

```gdscript
signal island_cleared(id: String)
signal island_unlocked(id: String)

const ISLANDS := ["redwake", "quiet_belt", "harrow", "second_watch", "mire"]

func is_unlocked(id: String) -> bool
func mark_island_cleared(id: String) -> void
```

### WaveManager — Role B implements; Role C may connect to signals

```gdscript
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal reef_cleared(reef_id: String)
```

### Genome — Role B implements; Role A may read

```gdscript
class_name InvasiveGenome extends Resource

@export var acoustic_armor := 0.0
@export var spiky_shell := 0.0
@export var heat_sink := 0.0
@export var speed_multiplier := 1.0
@export var max_health := 50.0

func damage_multiplier_for(weapon_id: String) -> float
```

---

## 6. Damage formula — lives only in `systems/genome.gd`

Do not copy damage numbers into weapons, enemies, or anywhere else. The genome
is the only place that maps weapon IDs to multipliers.

- `"sonic"`: `(1 - acoustic_armor) * (1 + spiky_shell)`
- `"bubble"`: `(1 - spiky_shell) * (1 + heat_sink)`
- `"thermal"`: `(1 - heat_sink) * (1 + acoustic_armor)`

Counter-loop:
- Sonic beats Spiky Shell
- Bubble beats Heat Sink
- Thermal beats Acoustic Armor

---

## 7. Gameplay flow — signal chain

The expected chain is:

1. Player fires
2. Role A calls `Telemetry.log_shot(weapon_id)`
3. Projectile `Area2D` hits a body in group `"invasive"`
4. Enemy receives `receive_damage(amount, weapon_id)`
5. Role B applies genome multiplier from `InvasiveGenome.damage_multiplier_for()`
6. If enemy dies, it emits `died(genome, position)`
7. `WaveManager` counts the kill and eventually emits `reef_cleared(reef_id)`
8. Role C marks the island cleared
9. The next island unlocks

Telemetry feeds the GA, which mutates genomes between waves.

---

## 8. Weapon behavior specs — Role A

- **sonic**
  - fast straight projectile
  - cooldown: `0.25 s`
  - base damage: `10`
- **bubble**
  - slow `Area2D` trap
  - roots enemies for `1.5 s`
  - base damage: `0`
  - radius: `80 px`
- **thermal**
  - continuous beam
  - `30` damage per second while held
  - has an overheat meter

Weapon switching uses keys `1`, `2`, `3`.

Submarine constants:
- speed: `300 px/s`
- max health: `100`

---

## 9. Definition of done for every PR

- The game runs at 60 FPS with F5 on the branch, even with placeholder art.
- No files edited outside owned paths.
- No contract names changed.
- Placeholders are allowed; broken builds are not.

---

## 10. Branch map

| Branch | State |
| --- | --- |
| `main` | Contract + scaffolding. Only `systems/genome.gd` is a real implementation. |
| `feature/C/world-map` | Role C world map (procedural island art, locked/cleared pins, route). |
| `feature/C/levels-1-3` | **New.** Levels 1–3 plus the map → level loading path. Branched off `feature/C/world-map`. |
| `my-isolated-game-demo-branch` | Off-contract Role A smoke test (movement + three weapons + test dummy). Not a merge baseline, but its `scenes/player/` and `scenes/weapons/` files were copied into `feature/C/levels-1-3`. |
| `feature/A/submarine-movement` | Local only, no commits yet. |

---

## 11. Level architecture (the three built levels)

Levels live in `scenes/levels/` and are Role C territory.

```
scenes/levels/
  level_base.gd              shared controller (one script, three levels)
  reef_floor.gd              procedural floor, baked once into a SubViewport
  level_redwake.tscn         1. Redwake      — Shallow Reef    (3 waves)
  level_quiet_belt.tscn      2. Quiet Belt   — Kelp Belt        (4 waves)
  level_harrow.tscn          3. Harrow       — Volcanic Vents  (4 waves)
  placeholders/              TEMPORARY scaffolding, delete when A and B ship
    reef_placeholder_player.gd
    reef_placeholder_enemy.gd
    reef_placeholder_waves.gd
scenes/ui/level_hud.gd       in-level HUD, built entirely in code
```

### How a level is put together

`level_base.gd` is the only level script. Each `.tscn` is just a `Node2D` with
that script and a different set of exported values:

- `island_id`, `island_name` — must match the frozen island IDs exactly
- `biome` — 0 Shallow Reef, 1 Kelp Belt, 2 Volcanic Vents
- `wave_count`, `enemies_first_wave`, `enemies_per_wave_step`
- `level_seed` — drives all procedural art placement
- `genome_*` — the STARTING resistance of that island (level difficulty data;
  the multiplier maths still lives only in `systems/genome.gd`)
- `enemy_touch_damage`

At runtime `level_base.gd` builds, in order: the reef floor, arena walls, the
player, the wave director, and the HUD.

### The fallback rule (important)

Every dependency on another role resolves in this order:

1. If `res://scenes/player/submarine.tscn` exists → use Role A's submarine.
2. Otherwise → use `placeholders/reef_placeholder_player.gd`.
3. If `res://scenes/enemies/invasive_enemy.tscn` exists → use Role B's enemy.
4. Otherwise → use `placeholders/reef_placeholder_enemy.gd`.
5. If `res://systems/wave_manager.tscn` exists → use Role B's WaveManager.
6. Otherwise → use `placeholders/reef_placeholder_waves.gd`.

**No level edits are needed when A and B land their real scenes.** They appear
automatically. All three real scenes have now landed, so every file under
`placeholders/` is unreachable and can be deleted at any time.

### Role B's WaveManager is now live — how a level starts it

`level_base.gd` probes for `configure(...)` and then `start()`, because the
contract freezes the WaveManager *signals* but never its entry point. B's file
shipped only `start_reef()` / `stop()` with `auto_start = false`, so a level could
never have started a reef at all. `systems/wave_manager.gd` therefore keeps B's
wave loop verbatim and adds a strictly additive, level-facing layer on top:

- `configure(island_id, wave_total, first_wave, wave_step, enemy_scene,
  genome_template, spawn_points, arena, touch_damage)` — accepts the level design
- `start()` → funnels into B's `start_reef()`, so there is still one code path
- `alive_count()`, `current_wave()`, `wave_total()`, `is_running()` — read-only
  queries the level and HUD poll

Three integration fixes were required, each commented in-line:

1. **Founding genomes.** `GeneticAlgorithm.seed_population()` rolls every
   resistance in 0.0–0.1, which silently discarded each island's exported
   `genome_*` starting resistances. The WaveManager now seeds around the level's
   template, jittered for variation, and falls back to B's seeding when no
   template was configured.
2. **Spawn placement.** B's original spawn was `player + angle * spawn_radius`
   (520). In a 1600x900 arena that puts enemies *outside* the walls (e.g. y = -70),
   where they can never reach the player, so the wave never clears — a hard
   soft-lock. Spawns now use the floor's designed `spawn_points()` and are clamped
   into the arena either way.
3. **Enemy parenting.** Enemies were added to `get_tree().current_scene`, making
   them siblings of the level. They are now added to the level itself.

### Perf convention

Both `reef_floor.gd` and `world_map.gd` draw their static art once into an
off-screen `SubViewport` and display it as a single quad, so a frame costs one
texture draw instead of thousands of canvas commands. Only a small FX layer
(caustics, bubbles, vent smoke) redraws per frame. Keep this pattern.

---

## 12. What is built vs what is missing

### Built and verified

- Contract, project scaffolding, genome resource with the real damage formula.
- World map with locked / cleared / current states and `GameProgress` save/load.
- **Levels 1–3**, each with a procedural floor, walls, player spawn, camera,
  wave flow, HUD, and a return-to-map hand-off.
- **The map → level loading path**: pressing an unlocked island calls
  `get_tree().change_scene_to_file(...)`. Levels 4 and 5 report that their dive
  scene does not exist yet instead of failing.
- **The map ↔ progression loop**: clearing a reef calls
  `GameProgress.mark_island_cleared()`, which writes `user://progress.json` and
  emits `island_unlocked`, so returning to the map shows the next reef unlocked.
- Role A's real submarine (`scenes/player/submarine.tscn` + `submarine.svg`) and all three weapons (`scenes/weapons/`), copied across from the demo branch.
- WASD movement, via an `[input]` section added to `project.godot`.
- **Role B's whole delivery, integrated and running:**
  - `autoload/telemetry.gd` — real shot/kill counters, per-wave usage fractions,
    generation log, JSON export (replaces the stub).
  - `systems/genome.gd` — B's version, with `clamp_traits()` and `to_dict()`.
  - `systems/genetic_algorithm.gd` — tournament selection, crossover, mutation,
    elitism, metabolic cost.
  - `scenes/enemies/invasive_enemy.gd` + `.tscn` — genome-driven chase AI with
    CHASE / ROOTED / DEAD states, trait visualisation, and per-island touch damage.
  - `systems/wave_manager.gd` + `.tscn` — the wave loop and the level-facing layer.
- Enemy adaptation is now demonstrable end to end (see the numbers below).
- `docs/INSTRUCTIONS.md` (this file) exists in the repo.

### Verified how

Run headless with Godot 4.7.2 via a throwaway harness (since deleted), plus one
windowed run. Every level was driven to a genuine `reef_cleared` with the real
WaveManager and the real enemy in the loop.

- **All three islands clear.** redwake 738 frames (12.3 s), quiet_belt 1244
  frames (20.7 s), harrow 1494 frames (24.9 s) of game time; 15 / 28 / 38 enemies
  killed; `reef_cleared` fired with the right island ID; `progress.json` holds
  `{"cleared":["redwake","quiet_belt","harrow"]}`. Zero errors, zero warnings.
- **Spawn audit.** All 15 / 28 / 38 spawns landed inside the arena walls
  (x 184–1441, y 177–723) and at least 321 px from the player. This is the check
  that fails on B's original player-relative spawn.
- **GA direction (isolated, 12 generations, population 12).** The weapon the
  player uses selects for its own counter, and the population's damage multiplier
  falls: sonic `acoustic_armor` 0.037→0.352 (damage x1.01→x0.66), bubble
  `spiky_shell` 0.045→0.594 (x1.00→x0.42), thermal `heat_sink` 0.048→0.529
  (x0.99→x0.49). In each case the trait the weapon *punishes* collapses.
- **Starting from the real island templates (10 generations).** redwake+sonic
  `acoustic_armor` 0.047→0.361 (x0.99→x0.66); quiet_belt+bubble `spiky_shell`
  0.126→0.402 (x1.06→x0.64); harrow+thermal `heat_sink` 0.359→0.796, at the 0.8
  cap, with `acoustic_armor` collapsing to 0.067 (x0.83→x0.22).
- **In-game adaptation (real levels, real loop).** Under single-weapon fire the
  mean damage multiplier falls on every island: quiet_belt+bubble -13.5%,
  harrow+thermal -7.6%, redwake+sonic ~-3% mean across 6 dives (5 of 6 fell; see
  open question 4).
- **Per-island tuning reaches the enemies.** Spawned enemies report
  `touch_damage` 6 / 8 / 10 on redwake / quiet_belt / harrow, i.e. exactly the
  levels' `enemy_touch_damage` exports.
- **Teardown is safe.** Freeing a level mid-spawn (the ESC-to-map path, while
  `_spawn_batch()` is awaiting a timer) leaves no freed-node errors and no stray
  enemies after 5 further seconds.
- **Performance.** Windowed on harrow with the full first wave alive and chasing:
  a steady 165 FPS at the 165 Hz vsync cap (process ~8 ms, physics ~4.5 ms), so
  comfortably inside the 16.67 ms / 60 FPS budget. The enemy draws plain
  `draw_circle` / `draw_line`, which is cheaper than the placeholder it replaced.

### Still missing or not wired

- Levels 4 and 5 (`second_watch`, `mire`).
- Nothing carries an evolved population back through the world map: every dive
  calls `Telemetry.reset_run()` and re-seeds from the island template.
- `scenes/levels/placeholders/` (all three scripts) — unreachable, safe to delete.
- `systems/ga_manager.gd` — the old "do not implement until week 9+" stub, now
  superseded by `systems/genetic_algorithm.gd`.
- No in-game way to *see* the adaptation other than enemy colour/spike count;
  the data is already in `Telemetry.export_json()`.

---

## 13. Open integration questions

1. **WaveManager entry point — RESOLVED, needs B's sign-off.**
   `systems/wave_manager.gd` now implements `configure()` / `start()` /
   `alive_count()` / `current_wave()` on top of B's `start_reef()`, so
   `level_base.gd` no longer needs a placeholder director and no level edits were
   required. B should fold that additive layer into his own file, otherwise the
   WaveManager is maintained in two places.

2. **Bubble semantics — RESOLVED.**
   B's enemy roots on `receive_damage(0.0, "bubble")`, scaled by the genome's
   bubble multiplier and clamped to 0.25–3.0 s around the contract's 1.5 s.
   Bubble is not a no-op.

3. **Which trait adapts is not always the obvious one (new).**
   The damage formula couples traits, so selection does not simply raise "the"
   resistance. Under bubble fire the population reliably became bubble-proof by
   *dropping* `heat_sink` (which bubble punishes) rather than by raising
   `spiky_shell`, even though both reduce bubble damage. Judge adaptation by the
   mean damage multiplier for the weapon actually used, not by one named trait.

4. **Adaptation is barely visible on Redwake (new).**
   Redwake has 3 waves and 3 founding enemies, so the GA gets exactly two
   generations and `ELITE_COUNT = 2`. Across 6 identical dives the mean damage
   multiplier fell in 5 of 6 runs, by roughly 1–7% — directionally right but
   within run-to-run noise. The 4-wave islands move clearly and consistently. If
   the tutorial island is meant to demonstrate evolution, give it more waves or
   more founding enemies; the GA is not the limiting factor.

5. **`max_health` drifts up under every weapon (new).**
   `fitness()` multiplies by `sqrt(max_health / 50)` but only charges
   `0.5 * (health - 50) / 100` in metabolic cost, so health is under-priced and
   rises regardless of weapon. Harmless for the demo; worth revisiting if the team
   wants trait investment to be a real trade-off.

6. **Enemy scene name diverges from the old stub (new).**
   The repo stub was `scenes/enemies/invasive.gd`, which was never attached to a
   scene. B delivered `invasive_enemy.gd` / `invasive_enemy.tscn`; the stub was
   deleted and `level_base.gd` now points at B's file. Confirm B wants to keep
   that name.

7. **Enemy touch damage became an exported value (new).**
   B's enemy hardcoded `CONTACT_DAMAGE := 10.0`, while each level exports
   `enemy_touch_damage` (6 / 8 / 10) and passes it through `configure()`. The
   constant became `@export var touch_damage := 10.0` so per-island difficulty is
   not silently discarded. No frozen name changed.

8. **Fire input is still not in the contract.**
   The contract defines movement and `1`/`2`/`3` weapon switching but no fire
   action. Role A's real submarine hardcodes `KEY_SPACE` / left mouse button, and
   there is no `"fire"` action in `project.godot`. It works today, but it is still
   undocumented, so write it into the contract before anyone adds a second input
   path.

---

## 14. Recommended next moves

1. Have B review the additive layer in `systems/wave_manager.gd` — the
   `configure()`/`start()`/`alive_count()` front-end plus the three integration
   fixes (template seeding, spawn placement, enemy parenting) — and fold it into
   his branch so the WaveManager is not maintained in two places.
2. Settle the two balance questions above: should Redwake show adaptation, and
   should resistance persist across dives.
3. Delete `scenes/levels/placeholders/` (all unreachable) and `systems/ga_manager.gd`
   (superseded by `systems/genetic_algorithm.gd`).
4. Add levels 4 and 5 by copying an existing level script instance and changing
   the exported values, then adding the two entries to `LEVEL_SCENES` in
   `scenes/ui/world_map.gd`.
5. Show the player what the reef learned. `Telemetry.export_json()` already holds
   per-wave `mean_traits`, so an end-of-dive "the reef adapted to your sonic"
   panel is nearly free and is the whole point of the educational demo.

---

## 15. How to use this file in a session

- Paste the whole file at the start of the session.
- Tell the model which branch it is working on and which role it is acting as.
- If the model wants to change a frozen name or formula, ask for a
  `// PROPOSED CHANGE:` comment, not a silent rewrite.
- Before finishing, confirm the result still runs at 60 FPS with F5 on the
  branch and does not edit outside owned paths.
