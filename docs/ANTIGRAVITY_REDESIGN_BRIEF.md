# REEF SENTINEL — ANTIGRAVITY REDESIGN BRIEF

**Audience:** Google Antigravity (agentic coding model) working directly in the repo.
**Goal of this document:** give you *everything* about the project — what it is, how it is
built, what is frozen, what is placeholder — and then a precise, prioritised redesign
wish-list the owner wants implemented.

**Read order:** §1–§3 (what this is), §4 (the frozen contract — non-negotiable),
§5 (how the systems actually work), §6 (what is placeholder art today),
§9 (the wish-list — this is the work), §10 (concrete species design proposal),
§11 (data/API additions needed to support the wish-list), §12 (verification + DoD),
§14 (exact commands).

Everything in this file is verified against the repo as it stands on branch
`feature/C/levels-1-3` at commit `d26439d`.

---

## 1. What the game is

**Reef Sentinel** is a **top-down 2D marine shooter built in Godot 4.7 (GDScript only)**.

- The player pilots a **submarine** ("the sentinel") through a chain of **reef islands**.
- Each island is a **dive level**: a walled underwater arena where **waves of invasive
  species** spawn and swim at the player.
- Between waves the invasives **evolve** via a **genetic algorithm**. The GA reads
  **player weapon-usage telemetry** (which weapons the player actually fired) and mutates
  enemy traits so that the population becomes **more resistant to what the player spams**
  and less resistant to what the player neglects.
- This is an **educational demo of resistance evolution** — the same reason bacteria
  become resistant to an antibiotic that is over-used.

**Progression:** islands unlock in a fixed order; clearing one writes to the save file and
unlocks the next.

**Three screens exist today:**

| Screen | Scene | Purpose |
|---|---|---|
| World map / level select | `res://scenes/ui/world_map.tscn` (main scene) | Hand-drawn-in-code island map with 5 level banners + submarine, click to dive |
| Dive level (×3) | `res://scenes/levels/level_{redwake,quiet_belt,harrow}.tscn` | The arena, the waves, the HUD |
| (none) | — | No menu, no paused/settings screen exists yet |

**Gameplay flow (signals chain — memorise this):**

```
player fires
  -> submarine calls Telemetry.log_shot(weapon_id)
  -> projectile/hitbox touches a body in group "invasive"
  -> enemy.receive_damage(amount, weapon_id)
  -> enemy asks genome.damage_multiplier_for(weapon_id)   [ONLY place this maths exists]
  -> enemy health drops; on <= 0 enemy.died(genome, position) + Telemetry.log_kill(...)
  -> WaveManager counts down _alive; at 0 -> wave_completed(wave_number)
  -> GA.evolve(population, Telemetry.get_usage_fractions(true), next_size)
  -> next wave spawns tougher/more resistant genomes
  -> after last wave -> reef_cleared(reef_id)
  -> level_base calls GameProgress.mark_island_cleared(reef_id)
  -> progress.json updated -> next island unlocked on the map
```

---

## 2. Repository facts

- **Remote:** `https://github.com/aryaveer25bcg10013-hub/ReefSentinel.git`
- **Working branch:** `feature/C/levels-1-3` (integration branch: all three roles merged here)
- **`main` is untouched** at `f5475e8` and does **not** contain roles A/B's work.
- **Base commit:** `d26439d` — *"feat: integrate Role B genetic-evolution enemies + levels 1-3 + Role A sub/weapons"* (55 files, +3736/−29)
- **Engine version used to author/test everything:** **Godot 4.7.2 stable**
- **`project.godot` key settings:**
  - `config/name = "ReefSentinel"`
  - `run/main_scene = "res://scenes/ui/world_map.tscn"`
  - `config/features = PackedStringArray("4.7", "Forward Plus")`
  - `rendering_device/driver.windows = "d3d12"`
  - `physics/3d/physics_engine = "Jolt Physics"` (only 3D physics; 2D is Godot's built-in)
  - `window/stretch/mode = "canvas_items"`, `aspect = "expand"`
  - **Autoloads:** `Telemetry` (`*uid://bwoqnltiklh63`), `GameProgress` (`*uid://bfa8ik1emqxlq`)
  - **`[input]`** defines `ui_left/right/up/down` bound to **both arrow keys and WASD**
    (`physical_keycode`). Godot's built-ins only cover arrows, which is why WASD used to
    do nothing. Do not remove the WASD bindings.
- **No addons, no plugins, no third-party dependencies.** No `.glb`/`.png` gameplay art —
  graphics are **SVG for the player/weapons** and **code-drawn (`_draw()`) for the
  map, the level floors, and the enemies.**

### 2.1 File inventory (line counts are exact at `d26439d`)

```
project.godot                                  engine config (see above)
icon.svg                                       app icon
docs/INTEGRATION.md                   98       the frozen contract (READ-ONLY)
docs/INSTRUCTIONS.md                 506       master session briefing (human-facing)
docs/ANTIGRAVITY_REDESIGN_BRIEF.md            this file
docs/ANTIGRAVITY_PROMPT.md                    the paste-ready prompt companion

autoload/telemetry.gd                 91       B — weapon usage + kill/generation logs
autoload/game_progress.gd             39       C — unlock order + user://progress.json

systems/genome.gd                     46       B — InvasiveGenome + THE damage formula
systems/genetic_algorithm.gd         116       B — fitness / evolve / mutate (RefCounted)
systems/wave_manager.gd              235       B — wave loop + level-facing configure/start
systems/wave_manager.tscn                      B — trivial Node wrapper (script-only)
systems/ga_manager.gd                  2       obsolete placeholder ("do not implement until week 9+") — DELETE CANDIDATE

scenes/enemies/invasive_enemy.gd     163       B — CharacterBody2D chase AI, placeholder _draw() art
scenes/enemies/invasive_enemy.tscn             B — body + CircleShape2D(14)

scenes/levels/level_base.gd          359       C — shared level controller (ONE per level scene)
scenes/levels/reef_floor.gd          597       C — procedural biome floor + wall_rects() + spawn_points()
scenes/levels/level_redwake.tscn               C — island 1 data (exports only)
scenes/levels/level_quiet_belt.tscn            C — island 2 data
scenes/levels/level_harrow.tscn                C — island 3 data
scenes/levels/placeholders/reef_placeholder_{player,enemy,waves}.gd   UNREACHABLE leftovers; delete candidates

scenes/player/submarine.gd           208       A — movement, 3 weapons, health, aim
scenes/player/submarine.tscn / .svg            A — 112x64 sub sprite
scenes/player/test_arena.tscn                  A — sandbox scene (dev only)
scenes/player/test_dummy.gd           42       A — target dummy used by the sandbox

scenes/weapons/sonic_pulse.gd         59       A — fast projectile (10 dmg, 0.25 s cd)
scenes/weapons/bubble_trap.gd         69       A — drifting trap (radius 80, 0 dmg, roots 1.5 s)
scenes/weapons/thermal_beam.gd        84       A — continuous beam (30 dps + overheat)
scenes/weapons/{sonic_pulse,bubble_trap}.svg   A — projectile art
scenes/weapons/thermal_nozzle.svg              A — beam nozzle art

scenes/ui/world_map.gd              1282       C — the entire world map, drawn in code
scenes/ui/world_map.tscn                       C — CanvasLayer/Control skeleton with Islands/* buttons
scenes/ui/level_hud.gd               271       C — code-built in-level HUD
scenes/ui/.gitkeep                             tracked leftover (delete candidate)
```

### 2.2 Ownership (respect it; the human owner will review per-role)

| Role | Owns | Notes |
|---|---|---|
| **A** | `scenes/player/`, `scenes/weapons/` | player rig + weapons |
| **B** | `scenes/enemies/`, `systems/`, `autoload/telemetry.gd` | enemies, GA, telemetry |
| **C** | `scenes/ui/`, `scenes/levels/`, `autoload/game_progress.gd` | levels, HUD, map, progression |

`docs/INTEGRATION.md` and any shared data file are **read-only shared**.
New shared data (e.g. a species database) belongs in `systems/` so both the enemy
(B) and the bestiary UI (C) can read it without cross-owning files.

---

## 3. How to build / run

Godot is installed at:

```
C:\Users\aryav\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
```

Set a shell variable once so the commands below are copy-pasteable (Git Bash syntax):

```bash
cd /c/Users/aryav/ReefSentinel
GODOT="/c/Users/aryav/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
```

**Import / reimport assets and rebuild the script class cache (run after adding files):**

```bash
timeout 180 "$GODOT" --headless --path . --import
```

**Headless boot check — the main scene must start with zero errors/warnings:**

```bash
timeout 60 "$GODOT" --headless --path . --quit-after 90
```

Expected output is exactly:

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
```

…and nothing else. Any `SCRIPT ERROR`, `ERROR`, or `WARNING` line is a failure.

**Play it windowed:** open the editor (`"$GODOT" --path . -e`) and press **F5**, or launch
the main scene directly (`timeout 300 "$GODOT" --path .`). Controls: **WASD/arrows** move,
**mouse aims**, **left click / Space** fires, **1 / 2 / 3** switch weapon, **Esc** returns
to the world map.

**Save file (delete it to reset progression):**

```
C:\Users\aryav\AppData\Roaming\Godot\app_userdata\ReefSentinel\progress.json
```

Current content format: `{"cleared":["redwake","quiet_belt","harrow"]}`
(`user://` resolves to that folder on Windows.)

> **Always wrap Godot runs in `timeout`.** A GDScript parse error can leave the process
> spinning forever and a plain run will hang the terminal.

---

## 4. THE FROZEN CONTRACT (from `docs/INTEGRATION.md`) — DO NOT BREAK

This contract **overrides your defaults**. If you believe something here must change,
do **not** change it — write your reasoning as a `// PROPOSED CHANGE:` comment and keep
the existing name/behaviour working.

### 4.1 Names that can never be renamed or respelled

- **Weapon IDs:** `"sonic"` | `"bubble"` | `"thermal"`
- **Node groups:** `"player"` (the submarine) | `"invasive"` (every enemy)
- **Autoload singletons:** `Telemetry` | `GameProgress`
- **`class_name InvasiveGenome extends Resource`**
- **Island IDs, in progression order:**
  `"redwake"` → `"quiet_belt"` → `"harrow"` → `"second_watch"` → `"mire"`
- **Save path:** `user://progress.json`

### 4.2 Frozen public API — signatures and signal shapes are frozen

```gdscript
# Player (A implements, everyone may CALL)
signal health_changed(current: int, max_health: int)
signal died
func take_health_damage(amount: float) -> void

# Enemy (B implements, A may CALL)
signal died(genome: Resource, position: Vector2)
func receive_damage(amount: float, weapon_id: String) -> void
func setup(genome: Resource) -> void

# Telemetry autoload (B implements, A may CALL)
func log_shot(weapon_id: String) -> void
func log_kill(genome: Resource, weapon_id: String, distance: float) -> void
func export_json() -> String
func reset_run() -> void

# GameProgress autoload (C implements, everyone may CALL)
signal island_cleared(id: String)
signal island_unlocked(id: String)
const ISLANDS := ["redwake", "quiet_belt", "harrow", "second_watch", "mire"]
func is_unlocked(id: String) -> bool
func mark_island_cleared(id: String) -> void

# WaveManager (B implements, C may CONNECT to signals)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal reef_cleared(reef_id: String)

# Genome (B implements, A may READ)
class_name InvasiveGenome extends Resource
@export var acoustic_armor := 0.0
@export var spiky_shell := 0.0
@export var heat_sink := 0.0
@export var speed_multiplier := 1.0
@export var max_health := 50.0
func damage_multiplier_for(weapon_id: String) -> float
```

### 4.3 The damage formula lives in EXACTLY ONE place

`systems/genome.gd` → `damage_multiplier_for()` — and nowhere else:

| Weapon | Multiplier applied to incoming damage | Counter-loop meaning |
|---|---|---|
| `"sonic"` | `(1 - acoustic_armor) * (1 + spiky_shell)` | **Sonic beats Spiky Shell** |
| `"bubble"` | `(1 - spiky_shell) * (1 + heat_sink)` | **Bubble beats Heat Sink** |
| `"thermal"` | `(1 - heat_sink) * (1 + acoustic_armor)` | **Thermal beats Acoustic Armor** |

A multiplier **> 1 means that weapon hurts more** (the trait it "beats" is high), **< 1
means the organism is tanking it**. Any new visual, damage number, or sound must be driven
by **this** return value — never hard-code a second effectiveness table.

### 4.4 Weapon behaviour specs (from the contract)

- `sonic` — fast straight projectile, **0.25 s cooldown**, **base damage 10**
- `bubble` — slow drifting Area2D trap, **roots enemies 1.5 s**, **base damage 0**, **radius 80 px**
- `thermal` — continuous beam, **30 damage/sec while held**, with an **overheat meter**
- Weapon switching: **keys 1/2/3**. Submarine: **300 px/s**, **100 max health**.

### 4.5 Definition of Done (applies to every change)

- The game runs at **60 FPS with F5**, even with placeholder art.
- No files edited outside owned paths; no contract name renamed.
- Placeholders are allowed; **broken builds are not**.

---

## 5. How the systems actually work (read before touching anything)

### 5.1 `systems/genome.gd` — the heritable traits

Clamps (`clamp_traits()`): resistance traits `0.0 … 0.8` (`MAX_RESISTANCE`),
`speed_multiplier` `0.6 … 1.8`, `max_health` `30.0 … 120.0`. Defaults `0/0/0/1.0/50`.
`to_dict()` rounds traits for telemetry (`0.001`, health `0.1`).

### 5.2 `systems/genetic_algorithm.gd` — the evolution engine

`extends RefCounted`, **deliberately has no `class_name`** — load it with
`const GeneticAlgorithm := preload("res://systems/genetic_algorithm.gd")`.

Constants: `ELITE_COUNT 2`, `TOURNAMENT_SIZE 3`, `MUTATION_RATE 0.35`,
`RESISTANCE_SIGMA 0.08`, `SPEED_SIGMA 0.08`, `HEALTH_SIGMA 5.0`, `METABOLIC_COST 0.5`,
`MIN_EXPECTED_DAMAGE 0.05`.

Static API: `seed_population(size)`, `fitness(genome, usage)`,
`evolve(population, usage, next_size)`, `mean_traits(population)`, private
`_tournament` / `_crossover` / `_mutate`.

**Fitness — understand this before you rebalance anything:**

```
expected_damage = Σ_w ( usage[w] * genome.damage_multiplier_for(w) )   # usage is {weapon_id: fraction}
resistance      = 1 / max(expected_damage, MIN_EXPECTED_DAMAGE)
health_factor   = sqrt(max_health / 50)
investment      = acoustic_armor + spiky_shell + heat_sink
                + max(0, speed_multiplier - 1) + max(0, (max_health - 50) / 100)
fitness         = resistance * health_factor / (1 + METABOLIC_COST * investment)
```

So: **traits cost fitness (metabolic cost), resistances you don't need are wasted, and
`max_health` is under-priced** (it drifts upward no matter which weapon you use). That is
a known, documented behaviour, not a bug — an educational talking point.

`evolve()` keeps the top `ELITE_COUNT` genomes as duplicative elites, fills the rest by
tournament selection → uniform crossover per trait → mutation → `clamp_traits()`.

### 5.3 `autoload/telemetry.gd` — what the player did

Frozen API plus additive helpers used by the GA layer:
`reset_wave()`, `get_usage_fractions(wave_only := true)` (returns
`{"sonic": f, "bubble": f, "thermal": f}` summing to 1.0), `log_generation(wave, mean_traits)`.
`_wave_shots` is reset at the start of every wave, so `usage_fractions(true)` describes
**only the wave just finished** — that is the adaptation pressure.
Storage: `MAX_KILL_LOG 500` (ring buffer), `export_json()` returns shots/kills/usage/
generations/kill_log.

### 5.4 `systems/wave_manager.gd` — the director

`extends Node`, script-only scene. B's original surface is `start_reef(id)` / `stop()` with
`auto_start=false` — which a level could not use, so an **additive** level-facing layer was
added at the bottom of the file:

```gdscript
func configure(island_id, wave_total, first_wave, wave_step, scene: PackedScene,
               genome_template: InvasiveGenome, points: Array[Vector2],
               arena: Vector2, touch_damage: float) -> void
func start() -> void          # calls start_reef(reef_id) exactly once
func alive_count() -> int
func current_wave() -> int
func wave_total() -> int
func is_running() -> bool
```

There is **exactly one spawn code path** (`start_reef` → `_start_next_wave` →
`_spawn_batch` → `_spawn_enemy`). Extra constants:
`TEMPLATE_RESISTANCE_JITTER 0.03`, `TEMPLATE_SPEED_JITTER 0.06`,
`TEMPLATE_HEALTH_JITTER 0.10`, `SPAWN_MARGIN 80.0`, `SPAWN_JITTER 26.0`,
`spawn_interval 0.4`, `inter_wave_delay 3.0`.

Two integration fixes are baked in and must be preserved:

1. **Spawn positions** come from the level's `reef_floor.spawn_points()` (cursor advances
   per enemy, jittered, then clamped into the arena). B's original
   `player + angle*520` ring put enemies **outside the 1600×900 walls** → unreachable →
   the wave could never clear → hard soft-lock.
2. **Enemies are parented to the level** (`get_parent()`), not
   `get_tree().current_scene`, so the arena owns its enemies.
3. `_seed_population()` seeds from the **level's genome template** (jittered) instead of
   the GA's hardcoded `0.0–0.1`, so `genome_*` values in each level `.tscn` are respected.
4. `touch_damage` is pushed onto each spawned enemy via `enemy.set("touch_damage", _touch_damage)`
   when the property exists.

### 5.5 `scenes/levels/level_base.gd` — the level controller

One script, three data-only scenes. `_ready()` builds, in order:
`_build_floor()` → `_build_walls()` → `_build_player()` → `_build_waves()` → `_build_hud()`.

Per-level exports (these ARE the level design; edit them in the `.tscn`):

| Export | Meaning |
|---|---|
| `island_id`, `island_name` | contract IDs + display name |
| `biome` (0 Shallow Reef, 1 Kelp Belt, 2 Volcanic Vents) | floor generator variant |
| `wave_count`, `enemies_first_wave`, `enemies_per_wave_step` | wave pacing |
| `level_seed` | floor + spawn-point seed |
| `genome_*` (acoustic/spiky/heat/speed/health) | the island's **starting** genome template |
| `enemy_touch_damage` | contact damage per hit |

Arena is `ARENA_SIZE := Vector2(1600, 900)` with `WALL_THICKNESS := 40.0`. The controller
prefers real scenes and falls back to placeholders
(`PLAYER_SCENE`, `ENEMY_SCENE`, `WAVE_DIRECTOR_SCENE`), attaches a `Camera2D` with
`position_smoothing` limited to the arena, wires the three frozen WaveManager signals,
and `_process()` polls `alive_count()` / `current_weapon_id` into the HUD.
`Esc` (`ui_cancel`) returns to the world map; `_return_to_map()` and `_retry()`
(`reload_current_scene`) are used by the HUD panel buttons.

**Current level data:**

| Level | island_id | biome | waves | enemies (first → step) | seed | genome a/s/h / speed / hp | touch |
|---|---|---|---|---|---|---|---|
| 1 | `redwake` | 0 Shallow Reef | 3 | 3 → +2 | 101 | 0.05 / 0.05 / 0.05 / 0.90 / 40 | 6 |
| 2 | `quiet_belt` | 1 Kelp Belt | 4 | 4 → +2 | 202 | 0.18 / 0.12 / 0.20 / 1.00 / 55 | 8 |
| 3 | `harrow` | 2 Volcanic Vents | 4 | 5 → +3 | 303 | 0.30 / 0.25 / 0.35 / 1.12 / 70 | 10 |

### 5.6 `scenes/levels/reef_floor.gd` — the procedural arena art

**Performance convention, same as `world_map.gd`: all static art is drawn once with
`_draw()` into an off-screen `SubViewport` and baked, so a frame costs one textured quad
instead of thousands of draw calls.** Only the `_fx` layer (caustics, rising bubbles,
vent lights) redraws per frame.

- `enum Biome { SHALLOW_REEF, KELP_BELT, VOLCANIC_VENTS }`, palettes per biome
  (`FLOOR_SAND`, `FLOOR_SHADE`, `FLOOR_ACCENT` arrays — one entry per biome).
- `BAKE_SCALE 1.5` for crisp outlines, `RIM 78.0` (dark open-water band inside the arena
  edge), `FLOOR_INSET 26.0`.
- Geometry is roughened rounded rects built through a `FastNoiseLite` simplex wobble
  (`_roughen`, seeded by `level_seed`), plus polygon helpers (`_blob`, `_grow`, `_clip`,
  `_biggest`, `_area`, `_fill`, `_outline`).
- Props drawn per biome: **coral** (`_draw_coral`), **kelp** (`_draw_kelp`), **rock**
  (`_draw_rock`), **anemone** (`_draw_anemone`), **volcanic vent** (`_draw_vent`).
- `wall_rects() -> Array[Rect2]` returns **the only 4 solid rectangles** (N/S/E/W) —
  this is what `level_base` turns into `StaticBody2D` collision.
- `spawn_points(count, rng_seed) -> Array[Vector2]` scatters points inside the floor
  polygon shrunk by 70 px, **at least 340 px from the arena centre** (so they never spawn
  on the player) and **120 px apart**, rejecting anything outside the shrunk floor.

### 5.7 Role A — `scenes/player/submarine.gd` and the weapons

- `CharacterBody2D` in group `"player"`, `MOTION_MODE_FLOATING`, `speed 300.0`,
  `max_health 100`, movement on `Input.get_vector("ui_left","ui_right","ui_up","ui_down")`.
- Sprite (`Sprite2D`, `res://scenes/player/submarine.svg`) rotates toward the mouse via
  `lerp_angle` at `18.0 * delta`, with `flip_v` when swimming left. Aim =
  `(get_global_mouse_position() - global_position).angle()`.
- Fire inputs: `Space` (physical) **or** left mouse button. Muzzle position =
  `global_position + Vector2.RIGHT.rotated(aim) * muzzle_distance`.
- Firing behaviour is **per weapon**: `sonic` fires continuously while held on a **0.25 s**
  cooldown; `bubble` fires **once per press** on a **placeholder 0.8 s** cooldown (the
  contract does not define a cooldown for it); `thermal` calls `beam.set_firing(held)` and
  logs a `"thermal"` shot once per `0.25 s` while the beam is on (a continuous beam has no
  discrete shots).
- `switch_weapon(id)` is an **additive** public helper used by keys `1/2/3`.
- `take_health_damage(amount)` is frozen: integer HP, clamps, emits `health_changed`,
  sets `_is_dead` and emits `died` at 0.
- Every projectile/beam is instantiated into `get_tree().current_scene`.

Weapons (all in `scenes/weapons/`, all `Area2D` except the beam which is a `Node2D`):

| Weapon | Scene script | Body | Key facts |
|---|---|---|---|
| Sonic | `sonic_pulse.gd` | `Area2D` | `speed 800`, `damage 10`, `lifetime 2.0`, 8 px circle, frees itself on first non-player body, calls `body.receive_damage(10.0, "sonic")` |
| Bubble | `bubble_trap.gd` | `Area2D` | `drift_speed 40`, `TRAP_RADIUS 80`, `lifetime 8.0`, no damage; on first invasive it calls `receive_damage(0.0, "bubble")` on **everything inside the radius** (B's enemy applies the root) then frees itself |
| Thermal | `thermal_beam.gd` | `Node2D` | `RayCast2D` length 500, `damage_per_second 30` applied **per physics frame × delta**, `max_heat 100`, buildup 30/s, cooling 50/s, overheats at max and unlocks only at 0 heat; beam colour lerps to red with heat; the sub drives it via `set_firing(bool)` |

### 5.8 Role B — `scenes/enemies/invasive_enemy.gd`

`CharacterBody2D` in group `"invasive"`, `motion_mode = 1` (floating). States
`enum State { CHASE, ROOTED, DEAD }`.

Constants: `BASE_SPEED 90.0`, `ATTACK_RANGE 32.0`, `ATTACK_COOLDOWN 1.0`,
`BASE_ROOT_DURATION 1.5`, `MAX_ROOT_DURATION 3.0`, `WOBBLE_STRENGTH 0.35`,
`SEPARATION_RADIUS 40.0`, `SEPARATION_WEIGHT 0.8`, `SEPARATION_INTERVAL 0.2`,
`BODY_RADIUS 14.0`. `@export var touch_damage := 10.0` (per-island via WaveManager).

- `setup(genome)` stores the genome, sets `_health = max_health` and
  `_speed = BASE_SPEED * speed_multiplier`.
- `receive_damage(amount, weapon_id)`: `_health -= amount * genome.damage_multiplier_for(weapon_id)`,
  calls `_flash()` (modulate 2× → white over 0.12 s), and for `"bubble"` roots for
  `clamp(1.5 * multiplier, 0.25, 3.0)`. At ≤ 0 → `_die()`: logs the kill with the **last
  weapon id** and the distance to the player, emits `died(genome, global_position)`,
  `queue_free()`.
- AI: chase the first node in group `"player"`, wobble sinusoidally off-axis, add a
  separation push from nearby invasives recomputed every ~0.2 s, stop inside
  `ATTACK_RANGE * 0.75`, and hit the player for `touch_damage` every `ATTACK_COOLDOWN`.
- **`_draw()` is placeholder art** (see §6).

### 5.9 Role C — HUD (`scenes/ui/level_hud.gd`) and world map (`scenes/ui/world_map.gd`)

**HUD** — a `CanvasLayer` (`layer = 10`), **built entirely in code** (no scene, no fonts,
no textures). Public API: `bind_player`, `set_island_name`, `set_wave`, `set_enemies_left`,
`set_weapon`, `show_cleared`, `show_failed`, `hide_panel`, `set_controls_visible`; signals
`return_to_map_pressed`, `retry_pressed`.

What exists today:
- a **plain `ProgressBar` health bar** — `BAR_SIZE := Vector2(240, 18)`, dark `#0c2338`
  background, fill recoloured green `#2fb67c` > 50 %, amber `#ffd45e` > 25 %, red `#e0553f`
  below that, with a `"100 / 100"` label above it;
- island name + `Wave n / m` top centre; `Enemies: n` + `Weapon: id` top right;
- a "Respawn Enemy (R)" button bottom left (actually wired to `retry_pressed` → reload scene);
- a controls hint line; a centre `PanelContainer` used for REEF CLEARED / SUBMARINE LOST
  with a "Return to Map" button and a "Dive Again" button.
- `_reposition()` re-lays out on viewport resize.

**World map** — `extends Control`, the main scene. Every pixel is drawn in code and baked
into a `SubViewport` exactly like the reef floor; a small `_fx` layer animates waves,
volcano smoke, and a bobbing submarine along a dashed route.

Key data:

```gdscript
const ISLAND_BUTTONS := { "redwake": "Redwake", "quiet_belt": "QuietBelt", "harrow": "Harrow",
                          "second_watch": "SecondWatch", "mire": "Mire" }
const LEVEL_SCENES := { "redwake": ".../level_redwake.tscn", "quiet_belt": ".../level_quiet_belt.tscn",
                        "harrow": ".../level_harrow.tscn" }          # 4 and 5 are not built yet
const LEVEL_SPOTS := { "redwake": Vector2(140,374), "quiet_belt": Vector2(598,216),
                       "harrow": Vector2(1004,362), "second_watch": Vector2(858,606),
                       "mire": Vector2(288,610) }
const BANNER_SIZE := Vector2(126, 38);  const BANNER_LIFT := 44.0
const BANNER_TILT := [-2.0, 1.5, -1.5, 2.0, -1.0]
const MAP_SEED := 42; const CLIFF_HEIGHT := 13.0; const ROUTE_GAP := 34.0; const AMBIENT_MOTION := true
```

Plus hand-authored coast polygon `COAST`, `ISLETS`, `MOUNTAINS`, `VOLCANO`, `LAKE`, `RIVER`,
`VILLAGE`, `LIGHTHOUSE`, `PYRAMIDS`, `FORESTS`, a large palette block, and drawing helpers
(`_draw_tree`, `_draw_pine`, `_draw_palm`, `_draw_mountain`, `_draw_volcano`, `_draw_pyramid`,
`_draw_house`, `_draw_lighthouse`, `_draw_sea`, `_draw_route`, `_draw_pin`, `_draw_compass`,
`_draw_sub`, `_draw_smoke`, …).

Level banners are `Button`s named `Islands/Redwake`, `Islands/QuietBelt`, `Islands/Harrow`,
`Islands/SecondWatch`, `Islands/Mire` inside the `.tscn`, positioned from `LEVEL_SPOTS`.
`_on_island_pressed(id)` gates on `GameProgress.is_unlocked(id)`, then
`change_scene_to_file(path)`; for levels 4/5 it prints `No dive scene yet for <id>.`

**Progression** (`autoload/game_progress.gd`): `ISLANDS` order, `cleared: Array[String]`
(public), `is_unlocked(id)` (index ≤ 0 ⇒ true, else the previous island must be cleared),
`mark_island_cleared(id)` (dedupes, saves, emits, unlocks next), `save_progress()` /
`load_progress()` against `user://progress.json`.

---

## 6. Current art status — what is real and what is placeholder

| Asset | State |
|---|---|
| Submarine | **Real art** — `scenes/player/submarine.svg`, 112×64, rotates/flips in code |
| Sonic projectile | **Real art** — `sonic_pulse.svg` |
| Thermal nozzle | **Real art** — `thermal_nozzle.svg`; the beam itself is `_draw()` lines |
| Bubble trap | **Real art** — `bubble_trap.svg` (soft translucent bubble) |
| Reef floors (×3) | **Procedurally drawn in code** — decent, biome-specific, baked |
| World map | **Procedurally drawn in code** — a lot of detail, hand-tuned constants |
| HUD | **Drawn in code**, functional but visually basic |
| **Invasives** | **PLACEHOLDER** — `invasive_enemy.gd::_draw()` draws a circle whose colour is a mix of the three resistances, plus `spiky_shell * 12` white spike lines, plus a blue arc while rooted. **No species identity, no sprite, no animation, no damage state.** |
| Hit feedback today | a 0.12 s white modulate flash (`_flash()`) only |
| Sounds / music | **none anywhere in the project** |
| Particles | only the floor's baked caustics/bubbles; no hit/death particles on enemies |

---

## 7. Known issues and technical debt

1. `scenes/levels/placeholders/reef_placeholder_{player,enemy,waves}.gd` are dead code —
   the real sub/enemy/WaveManager all exist, so the fallbacks never run. Safe to delete
   (keep `level_base.gd`'s `ResourceLoader.exists()` probes so deleting cannot break it).
2. `systems/ga_manager.gd` is a 2-line obsolete placeholder ("do not implement until
   week 9+"), superseded by `genetic_algorithm.gd`. Delete candidate.
3. `scenes/ui/.gitkeep` is a tracked leftover.
4. `bubble_trap` has a contract-undefined placeholder **0.8 s cooldown** in the sub.
5. `max_health` is under-priced in the fitness function, so health drifts upward under every
   weapon. Documented, intentional-looking, but worth rebalancing if the demo should show
   *different* adaptations per weapon.
6. The kill log records the **last weapon to touch** an enemy, which is right for a beam but
   slightly lossy for multi-source kills.
7. Enemy placeholder art means the player currently cannot tell species apart at all, and
   cannot see that an enemy is tanking a weapon — this is exactly what the wish-list fixes.
8. `README.md` does not exist at the repo root.

---

## 8. Godot 4.7 / GDScript specifics you must respect

**Performance convention of this codebase:** static procedural art is drawn once into a
`SubViewport` and displayed through a `Sprite2D`/`TextureRect`; only a small `_fx` layer
redraws per frame. `_draw()` on a node that calls `queue_redraw()` every frame is
acceptable only for a handful of nodes (the enemy count is ≤ ~40).

**Gotchas already paid for in this project:**

1. `Array.filter()` returns an **untyped** `Array` even when you call it on `Array[Node]`.
   Assigning the result back into a typed `Array[Node]` is a **runtime error that silently
   killed the wave loop**. Prune typed arrays with an explicit `for` loop instead.
2. Godot's built-in `ui_left/right/up/down` cover **arrow keys only**. WASD had to be added
   explicitly to `project.godot` with `physical_keycode`. Don't rely on WASD "just working"
   in a fresh project.
3. A single untyped `Array` element can cause a **parse error that prevents `quit()` from
   running**, leaving a headless process alive forever — always use `timeout`.
4. Underscore-private members are readable across scripts via `node.get("_sprite")`;
   this is how placeholders were kept invisible. Prefer real public getters in new code.
5. Indentation is **TABS**. Files/folders `snake_case`, nodes `PascalCase`, constants
   `SCREAMING_SNAKE_CASE`, typed GDScript wherever possible.
6. `class_name` additions are contract-sensitive: `InvasiveGenome` is the only gameplay
   `class_name` allowed by the contract. New scripts should use `preload()` constants
   (like `genetic_algorithm.gd`) unless the owner approves a new name.

---

## 9. THE REDESIGN WISH-LIST (this is the actual work)

The owner wants the following seven improvements. They are ordered as written by the owner;
**W1, W2 and W6 are the big ones.** Each item lists the goal, why, acceptance criteria, and
the files you are expected to touch. Everything must keep §4 intact and land on a **new
branch**, e.g. `feature/redesign-pass-1`.

---

### W1 — Weapons: 2 offensive + 1 defensive, with real impact

**Goal.** The player currently has **three offensive weapons** (sonic projectile, thermal
beam, and bubble — even though bubble deals 0 damage, its identity is "another attack").
Re-shape the loadout into **two offensive weapons and one genuinely defensive tool**, and
make all three *feel* like they hit something: recoil, muzzle flash, screenshake, impact
sparks, telegraphs, readable cooldowns/heat.

**Recommended shape (keeps every frozen ID and number):**

| Slot | ID (frozen) | New role | Feeling to add |
|---|---|---|---|
| Offensive 1 | `"sonic"` | rapid-fire straight shot, 10 dmg @ 0.25 s — the reliable, always-there gun | muzzle flash + recoil nudge on the sub, projectile trail/wake, ring shockwave on hit, hitstop on kill |
| Offensive 2 | `"thermal"` | sustained beam, 30 dps — the burst-damage tool with a hard overheat cost | audible/visual charge ramp, nozzle glow, heat dial that reads at a glance, overheat lockout with a "VENTING" state, beam sparks at the contact point |
| **Defensive** | `"bubble"` | **the panic button**: a bubble dome/shield the sub can deploy | dome flare on deploy, enemies bounce/root on contact, **the dome eats one hit or blocks contact damage for a short window**, expiry pop with a recharging meter |

**Hard constraints.** `bubble` must stay `damage 0` and keep rooting on contact
(`receive_damage(0.0, "bubble")` → B's enemy roots). Radius 80 px, root 1.5 s base.
Sonic stays 0.25 s / 10 dmg. Thermal stays 30 dps + overheat. Submarine stays 300 px/s,
100 HP. Weapon switching stays on `1/2/3` and `switch_weapon(id)` must keep working.

**Two consequences you must handle (this is the interesting part):**

1. **Telemetry pressure:** `Telemetry.log_shot("bubble")` still feeds
   `get_usage_fractions()`, which feeds `GeneticAlgorithm.fitness()`. If the defensive tool
   counts as an offensive weapon, spamming the shield will *teach the swarm to resist the
   shield* — evolutionarily nonsense and confusing for an educational demo. **Recommendation:**
   keep logging the shot (frozen API), but exclude the defensive weapon from the fitness
   weighting by adding a `DAMAGE_WEAPON_IDS := ["sonic","thermal"]` filter inside the GA's
   `fitness()`/usage normalisation, with a `// PROPOSED CHANGE:` comment explaining exactly
   why. Verify adaptation still happens for both offensive weapons afterwards.
2. **Feedback plumbing:** add a small, additive feedback layer used by all three weapons —
   e.g. `scenes/player/weapon_fx.gd` (screenshake via `Camera2D`, hitstop via
   `Engine.time_scale` for ~0.05 s, flash/spark helpers) plus a `_draw()`/`GPUParticles2D`
   pass. Keep it inside `scenes/player/` and `scenes/weapons/` (Role A's paths).

**Acceptance criteria.**
- Exactly two weapons deal damage; the third is defensive and deals none.
- Every hit the player sees produces at least two simultaneous cues (e.g. flash **and**
  spark, or recoil **and** shake) — no silent hits.
- Cooldown / heat / recharge state is readable without looking at a debug print.
- 60 FPS on F5 with a full harrow wave on screen.

**Files:** `scenes/player/*`, `scenes/weapons/*`, optionally a `Telemetry`-safe change in
`systems/genetic_algorithm.gd` (with a `PROPOSED CHANGE` comment) — nothing else.

---

### W2 — Invasive species: real assets + visible damage feedback

**Goal.** Replace the `_draw()` circle placeholder with proper species art **and make damage
unmistakable**. Today a hit produces one 0.12 s white flash; the player cannot tell if a
shot landed, or how much of the health is left.

**Required:**
- **Distinct art per species** (see §10) — SVG or procedural, consistent with the project's
  art direction (bold outlines, saturated reef palette, soft shading), drawn so the evolved
  traits are *visible*: spines, plate thickness, heat vents/glow, size, speed posture.
- **Damage feedback on every hit, layered:**
  - hit flash (white → species tint) — keep it, make it snappier;
  - **damage numbers** that scale with the applied damage (so a resisted hit reads as a
    small grey number, an effective hit reads as a big bright number);
  - **hit spark / ink-cloud particles** at the impact point;
  - **knockback** impulse along the projectile direction (projectiles only);
  - **hurt-state body change** — a "wounded" sprite frame or desaturation/tint that
    persists as health drops (green → yellow → red, or cracked shell);
  - **death**: poof/death animation, brief hitstop, then `queue_free()`.
- **A resist-vs-damage cue:** if `damage_multiplier_for(weapon_id) < ~0.5`, the hit should
  look *absorbed* (dull "clang", tiny number, armour shimmer) instead of effective
  (see W3, which owns the "they're tanking it" story).

**Acceptance criteria.** A player watching a 3-second fight can tell, without any HUD text,
(i) that they hit, (ii) roughly how much damage each hit did, (iii) when hits are being
resisted, (iv) when an enemy dies. No frame rate regression at 11+ enemies.

**Files:** `scenes/enemies/*` (art + feedback), `scenes/weapons/*` (spark/knockback call
sites if needed), `systems/genome.gd` **only** if you need to expose a read-only helper.

---

### W3 — Make adaptation VISIBLE: show that the swarm is withstanding attacks

**Goal.** The genetic adaptation works (verified: sustained single-weapon fire measurably
lowers the mean damage multiplier of that weapon over waves — quiet_belt ≈ −13.5 %,
harrow ≈ −7.6 %) but **the player has no way to see it**. The educational point of the game
is invisible. Fix that.

**Required (pick and implement at least three, they compose well):**

1. **Per-weapon effectiveness readout in the HUD** — take the current wave population's
   mean damage multiplier for the *equipped* weapon (compute from `WaveManager.population`
   via `GeneticAlgorithm.mean_traits()` / `damage_multiplier_for`, or expose an additive
   `WaveManager.resistance_profile()` helper) and show it as a dial/meter:
   "SONIC vs swarm: **72 %**" with a trend arrow since last wave. Green = effective,
   amber = diminishing, red = heavily resisted.
2. **Between-wave adaptation banner** — during `wave_completed` → `inter_wave_delay`
   (3 s, already in WaveManager) show a short "THE SWARM IS ADAPTING" panel listing the
   traits that moved this generation (the data already exists:
   `Telemetry.log_generation(wave, mean_traits)` / `GeneticAlgorithm.mean_traits`).
   Example line: `Heat Sink ▲ 0.42 → 0.61 — bubble damage now 34 % higher` (the game's
   own educational punchline).
3. **Per-enemy resistance shimmer** — the visual language of W2's "absorbed hit" plus a
   persistent trait-driven look (thicker plates, more spines, glowing vents, a faint
   shield outline whose intensity ≈ that weapon's `(1 - multiplier)`).
4. **First-contact hint** — the first time a species or a resistance crosses a threshold,
   a one-line toast ("These urchins are shrugging off your sonic pulse — try thermal"),
   and record the species as discovered for the bestiary (W6).

**Acceptance criteria.** After two waves of spamming one weapon, a player who looks at the
screen (not the console) can tell that the swarm has gotten better against that specific
weapon, and by roughly how much.

**Files:** `scenes/ui/level_hud.gd` (readout + banner), `scenes/enemies/*` (shimmer),
`systems/wave_manager.gd` (an additive read-only helper is acceptable — do not rename or
remove the frozen signals), `autoload/telemetry.gd` **read-only** (the data is already there).

---

### W4 — Redesign all 3 level maps: more obstacles, richer background

**Goal.** The three arenas today are an open rounded rectangle of sand with a rock rim and
decorative props that do **nothing**. The owner wants real level design: obstacles that
shape movement and cover, and a much richer background, per biome.

**Required:**
- **Obstacles per biome** that are actually solid (or meaningfully interactive):
  - Shallow Reef: coral bombies/reef heads, rock arches, sandbars.
  - Kelp Belt: dense kelp forests that **slow or hide** enemies, sunken wreck sections.
  - Volcanic Vents: **vent geysers** that damage or push the player/enemies on a timed
    cycle, lava-glass ridges.
  - Every solid must collide for BOTH the player and enemies (enemies use `move_and_slide()`,
    so give obstacles matching `StaticBody2D` collision so they path around them).
- **Background depth**, layered: distant reef silhouettes / parallax band, light shafts
  (god rays), denser caustics, drifting particulate, background fish shoals that scatter
  when the sub passes, biome-specific ambience (kelp sway, ember/ash drift, vent haze).
  Follow the bake-once convention (§8) — background layers can be `ParallaxBackground`/
  `ParallaxLayer` or a baked layer at a different scale, but they must not redraw the whole
  scene per frame.
- **Keep the guarantees:** `wall_rects()` must still return the arena boundary, and
  **spawn points must stay reachable** — that is the soft-lock bug class that already cost
  this project a day. Extend `spawn_points()` so it rejects points inside/near new
  obstacles (with a clearance radius ≈ enemy radius + margin) and, for zones (W7), returns
  points grouped by zone.

**Acceptance criteria.** Each of the 3 levels visibly and structurally differs; every
spawned enemy can reach the player in a headless test drive; no enemy or the player can get
permanently wedged (no concave traps narrower than the 14 px body + margin); 60 FPS on F5.

**Files:** `scenes/levels/reef_floor.gd` (+ new helper scripts under `scenes/levels/`),
`scenes/levels/level_*.tscn` (new exports are fine — additive), `scenes/levels/level_base.gd`
(only where it builds walls/collision).

---

### W5 — Improve the player health bar (currently too simple)

**Goal.** The health display is a plain 240×18 `ProgressBar` that only changes colour. Make
it an actual piece of UI that communicates state and danger.

**Required:**
- A **hull-integrity** styled bar: chamfered/segmented frame, tick marks every 10 HP, a
  lagging "damage ghost" that drains behind the real value, and a subtle scanline/glow.
- **Threshold states**: colour ramp already exists — add a **pulsing red border + vignette
  or screen edge flash at low health**, and a **one-shot hit flash** on the bar itself.
- Show **numeric current/max** plus a state label (`HULL`, `CRITICAL`) — keep the existing
  `health_changed(current, max_health)` signal as the only data source (contract).
- Must survive the existing `_reposition()` layout logic and viewport resizes.

**Acceptance criteria.** Losing 30 HP is visible from the bar alone (ghost trail + numbers +
colour + flash); at < 25 % the player feels it (vignette/pulse); no layout breakage at any
window size; still driven purely by the frozen `health_changed` signal.

**Files:** `scenes/ui/level_hud.gd` (the bar is built in `_build()` /
`_on_health_changed()`), plus optional new art scripts under `scenes/ui/`.

---

### W6 — Species variety + in-map BESTIARY BOOK

**Goal (two parts).**

**(a) Species identity.** The invasives must not all look/behave the same. Each species
gets its **own look** and its **own weapon weakness** (drawn from the existing
three-weapon counter-loop — a species is "weak to sonic" if it evolves high `spiky_shell`,
etc.). See §10 for a ready-to-build species table.

**(b) A bestiary, styled as a book, on the MAP screen.** Opened from the world map, it lists
every species with its data, weaknesses, and where it spawns.

**Visual spec — match this look (owner-provided reference image, style only):**

- Dark, near-black background; a single centred **open book** filling most of the frame.
- **Cover/border:** stylised **green coral and seaweed** growth framing the book — irregular
  leafy/coral lobes along the top and bottom edges, symmetrically grown inward from the
  corners; lighter sage-green highlights on the lobes over a deeper green base.
- **Pages:** pale **cream/parchment** (`#e8d5a8`-ish) with a soft **radial gradient** and
  faint irregular **blotches/stains** scattered across them, plus a drop shadow at the
  centre gutter where the two pages meet.
- **Page structure:** a darker cream/brown **border band** follows the page edges; the book
  has a visible **spine/gutter** down the centre; small tab/bookmark shapes hang off the
  bottom centre.
- **Ornament:** a small **white diamond** at the **top centre** of the frame, on the dark
  background just above the book, with a faint horizontal rule under it; matching small
  diamond/notch details at the left and right edges of the cover band.
- Colours: dark background `#0b0d10`-ish; green cover `#3f7a2a` base / `#8dc24a` highlights;
  cream page `#e9d6a9` / `#d8c08a` shading; ink text dark brown `#4a2f18`; accent (diamond)
  `#f6f7f2`.
- **Licensing note:** the reference is a watermarked stock image supplied as *style
  reference only*. **Do not copy or ship it.** Recreate the look as code-drawn art
  (`_draw()` + `SubViewport` bake, exactly like `world_map.gd`), which also matches the
  project's no-external-assets convention.

**Content per species entry:** name, portrait/silhouette, one-line description, threat tier,
stat block (armor / spiky / heat / speed / HP at the current island), **weakness (which
weapon is effective + short reason)**, resistances, **spawn zones per island** (from W7),
and a "discovered" gate — undiscovered species show as a silhouette with `???`.

**Interaction:** a book button on the world map (add it as a child of the existing
`Islands`/map root so `_reposition`-style layout keeps working); open/close with a page-turn
tween; `Esc` closes; left/right page or list navigation; entries grouped by island.

**Acceptance criteria.** Every species listed with correct data derived from the *same*
source of truth the enemy uses (no duplicated hardcoded tables); the book reads clearly at
1280×720 and at fullscreen; it opens and closes without disturbing `GameProgress` state; the
art matches the reference's palette and silhouette described above.

**Files:** new `scenes/ui/bestiary_*.gd(.tscn)` (C's path), `scenes/ui/world_map.gd`
(open button + wiring), shared species data in `systems/` (see §11), and
`scenes/enemies/*` to consume the same data.

---

### W7 — Majority-weighted spawn distribution per species

**Goal.** Different species should **predominantly** spawn at different points on each map,
but **never exclusively** — every species must remain *possible* everywhere, just less likely.

**Recommended implementation:**

1. Extend `reef_floor.gd` with `spawn_zones() -> Array[Dictionary]` naming 3–4 zones per
   biome, e.g. `{"id": "coral_shelf", "centre": Vector2(...), "radius": 240.0, "label": "Coral Shelf"}`,
   and make `spawn_points()` (or a new `spawn_points_in_zone(zone, count, seed)`) return
   points inside a given zone while keeping the existing guarantees (inside the floor,
   ≥ 340 px from the arena centre, ≥ 120 px apart, outside obstacles).
2. Give each level a **weight table**: species × zone → weight, where the species' home zone
   has the highest weight and every other zone keeps a **non-zero floor weight**
   (e.g. home `1.0`, other zones `0.10–0.20`). That is the "majority, not ultimatum" rule.
3. `WaveManager` picks zone → species by weighted random per spawn
   (`RandomNumberGenerator.randf()` cumulative weights, seeded from `level_seed` so runs are
   reproducible), then spawns that species' genome in that zone.
4. **Show it on the map**: the bestiary (W6) lists each species' zones, and ideally the
   level's opening frame / HUD hints at zone names.

**Acceptance criteria.** Over a headless test of ~200 spawns in one level, each species
appears in its home zone the majority of the time and appears **at least once** in every
other zone (**verify the floor weight empirically, don't assume**); zone assignment is
deterministic for a fixed seed; no spawn lands inside a wall or obstacle.

**Files:** `scenes/levels/reef_floor.gd`, `systems/wave_manager.gd` (additive spawn
selection), `scenes/levels/level_*.tscn` (new additive exports for the weight table),
bestiary data for display.

---

## 10. Concrete species design proposal (build this, or improve it and say why)

The three-weapon counter-loop already defines three natural archetypes. Use it:

| Archetype | Signature trait | Weak to | Tanks |
|---|---|---|---|
| Spiny | high `spiky_shell` | **Sonic** (`×(1+spiky)`) | Bubble (`×(1−spiky)`) |
| Thermal-venting | high `heat_sink` | **Bubble** (`×(1+heat)`) | Thermal (`×(1−heat)`) |
| Armoured | high `acoustic_armor` | **Thermal** (`×(1+armor)`) | Sonic (`×(1−armor)`) |

Proposed six species (two per built island; ids are new strings, deliberately *not* in the
frozen list, so they are safe to add):

| # | Species id | Display name | Look | Signature | Weak to | Resists | Debuts | Home zone (W7) |
|---|---|---|---|---|---|---|---|---|
| 1 | `drifter_jelly` | Drifter Jelly | small pale translucent bell, trailing tendrils, gentle bob | all traits low, cheap, slow drift → the baseline swarm | any (no resistance) | nothing | Redwake | `open_water` (spawns anywhere) |
| 2 | `spine_urchin` | Spine Urchin | dark violet-black bulb, long dense spines, slow roll | `spiky_shell` ↑ | **Sonic** | Bubble | Redwake | `coral_shelf` |
| 3 | `ember_nautilus` | Ember Nautilus | ribbed shell with glowing orange vent slits, leaves an ash trail | `heat_sink` ↑ (+ moderate armor) | **Bubble** | Thermal | Quiet Belt | `vent_field` |
| 4 | `kelp_snatcher` | Kelp Snatcher | ribbon-like eel, segmented, sways with kelp, fast and erratic | `speed_multiplier` ↑, low resistance | any (fragile) | — | Quiet Belt | `kelp_trench` |
| 5 | `bone_ray` | Bone Ray | flat, wide manta silhouette, pale bone plating, glides | `acoustic_armor` ↑ | **Thermal** | Sonic | Harrow | `bone_flats` |
| 6 | `steelhead_bloom` | Steelhead Bloom | clustered anemone head with fused metal plates and short spines | `spiky_shell` + `acoustic_armor` ↑ | **Sonic** and **Thermal** (dual) | Bubble | Harrow | `ridge_ruins` |

**Design rule that keeps the GA honest:** species sets the *starting bias* and the art; the
GA still evolves the population on top of it (see §11.1). So a late-wave Spine Urchin is
recognisably a Spine Urchin but noticeably tougher — the educational story ("this species
got resistant to what I kept using") stays intact while species stay distinguishable.

**Suggested visual delta for adaptation (feeds W2/W3):** scale the spike count/length and
the plate thickness with the evolved trait values, and add a faint outline glow whose
intensity tracks how much the species currently resists the **equipped** weapon.

---

## 11. Data / API additions required to support the wish-list

None of the following renames or removes anything frozen. Treat them as **additive**, and
mark any change to a B-owned system file with a `// PROPOSED CHANGE:` comment explaining the
reason, exactly like the existing integration notes in `wave_manager.gd`.

### 11.1 Species + genome

Add one field to the genome (a new `@export` is additive; the class name and existing traits
are untouched):

```gdscript
# systems/genome.gd
@export var species_id := "drifter_jelly"   # NEW, additive — identifies the species
```

Then:
- `GeneticAlgorithm._crossover()` should inherit `species_id` from one parent
  (so speciation survives evolution) — one line, additive.
- `WaveManager._seed_population()` seeds each genome from the **species template**
  (species baseline traits) blended with the **island template** (island difficulty),
  then jitters — so island 3 is harder than island 1 for the same species.
- Enemy art/animation is selected from `species_id`.

### 11.2 Shared species database (read-only, one source of truth)

Create **one** data file both the enemy (B) and the bestiary UI (C) read, so no table is
duplicated. It lives in `systems/` (B's path) purely to respect ownership:

```gdscript
# systems/species_db.gd  (new)
# const SpeciesDB := preload("res://systems/species_db.gd")
# Data per species: display_name, description, threat, baseline traits,
#   weakness_weapon_id + reason, resist_weapon_ids, visuals (sprite path / draw params),
#   per-island spawn zone weights, bestiary lore.
```

Suggested shape:

```gdscript
const SPECIES := {
    "spine_urchin": {
        "name": "Spine Urchin",
        "blurb": "A drifting ball of needles. Shotgun-blasted coral gave it that coat.",
        "threat": 2,
        "baseline": {"acoustic_armor": 0.05, "spiky_shell": 0.45, "heat_sink": 0.05,
                     "speed_multiplier": 0.85, "max_health": 60.0},
        "weak_to": "sonic",          # damage_multiplier_for("sonic") > 1 by construction
        "resists": ["bubble"],
        "home_zone": "coral_shelf",
        "zone_weights": {"coral_shelf": 1.0, "open_water": 0.15, "vent_field": 0.10},
        "islands": ["redwake", "quiet_belt", "harrow"],
    },
    # ...
}
```

**Validation requirement:** a small headless script/test should assert, for every species,
that `InvasiveGenome` built from `baseline` really produces
`damage_multiplier_for(weak_to) > 1.0` and `< 1.0` for each entry in `resists`. That is the
"different weaknesses" requirement made machine-checkable instead of a claim in a table.

### 11.3 Bestiary persistence

`GameProgress` gains an additive `var bestiary_seen: Array[String] = []` +
`func mark_species_seen(id)` persisted in the same `user://progress.json` under a new
`"seen"` key (old saves must still load — `load_progress()` currently tolerates a missing
`"cleared"` key, so extend it the same defensive way). Enemy `_die()` (or first hit) records
the species as seen.

### 11.4 Additive read-only helpers (optional but useful)

```gdscript
# systems/wave_manager.gd  (additive; nothing frozen is touched)
func resistance_profile() -> Dictionary   # {weapon_id: mean damage multiplier for the live population}
func spawn_zone_report() -> Dictionary    # {zone_id: {species_id: count}} for tests + bestiary hints
```

---

## 12. Verification plan and Definition of Done

Do this after **every** phase — this project has already been burned by "looks fine, actually
soft-locked":

1. `timeout 180 "$GODOT" --headless --path . --import` → no errors.
2. `timeout 60 "$GODOT" --headless --path . --quit-after 90` → exactly one version line, no
   `ERROR`/`WARNING`/`SCRIPT ERROR`.
3. **Drive all three levels headlessly to `reef_cleared`** with a throwaway script (temporary
   `.gd` + scene, deleted afterwards, or `--script`): assert the run reaches
   `reef_cleared(<island_id>)`, that every spawned enemy is inside the walls and ≥ 320 px from
   the player at spawn, that `_alive` reaches 0 for every wave, and that
   `progress.json` gains the island. Do not commit the harness.
4. **Spawn/zone audit:** ≥ 200 spawns per level; every spawn inside the floor, outside
   obstacles, in its selected zone; each species appears in its home zone in the majority of
   its spawns **and** at least once in every other zone.
5. **Adaptation still works:** fire a single weapon only; assert the mean damage multiplier
   for that weapon falls across waves (it does today: quiet_belt ≈ −13.5 %, harrow ≈ −7.6 %).
   Re-run this specifically after any change to `fitness()` (W1's defensive-weapon filter).
6. **Species weakness audit:** the §11.2 assertion script passes for all species.
7. **Perf:** windowed run on `harrow` with a full wave; must hold the vsync cap (60 FPS with
   F5 as the contract demands; the current build measures ~165 FPS uncapped in this arena,
   so there is headroom — but the new obstacles/particles are exactly what could eat it).
8. **Visual proof:** screenshot the bestiary, the improved health bar, a hit in progress, and
   all three redesigned levels, and attach them to the PR description.

**DoD (unchanged from the contract):** 60 FPS with F5, no edits outside owned paths, no
frozen name renamed, no broken build. Every deviation from the contract goes in as a
`// PROPOSED CHANGE:` comment with the reason, in the file where it applies.

---

## 13. Suggested work order (dependency-aware)

1. **Phase 0 — foundation:** delete the dead placeholders (§7 items 1–3, confirm the level
   still boots), create `systems/species_db.gd`, add `species_id` to the genome, wire species
   selection into spawning. Verify §12.1–12.4.
2. **Phase 1 — W2 + W6a:** species art + damage feedback, then the species table becomes
   visible in-game. Verify §12.6 + the feedback acceptance criteria.
3. **Phase 2 — W3:** adaptation readout + between-wave banner + resistance shimmer. Verify
   §12.5.
4. **Phase 3 — W7:** zones and majority weighting, surfaced in the bestiary data. Verify
   §12.4.
5. **Phase 4 — W6b:** the bestiary book UI on the map screen (needs Phase 3's zone data).
6. **Phase 5 — W1:** the two-offensive/one-defensive weapon redesign + impact feel. Re-run
   §12.5 because of the fitness change.
7. **Phase 6 — W4 + W5:** level redesigns and the health bar (both are self-contained
   polish with the most visual payoff).
8. Final: full §12 pass, screenshots, PR description with the numbers.

Every phase should end with a **runnable build** and a commit. Do not land a phase that
breaks the previous phase's verification.

---

## 14. Appendix — quick reference

**Exact commands**

```bash
cd /c/Users/aryav/ReefSentinel
GODOT="/c/Users/aryav/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

timeout 180 "$GODOT" --headless --path . --import      # reimport + class cache
timeout 60  "$GODOT" --headless --path . --quit-after 90   # boot check (expect 1 version line)
timeout 300 "$GODOT" --path .                          # play the main scene (world map)
timeout 60  "$GODOT" --path . -e                        # open the editor
```

**Frozen strings (one-line reminder):** weapon ids `sonic|bubble|thermal`; groups
`player|invasive`; autoloads `Telemetry|GameProgress`; class `InvasiveGenome`; islands
`redwake → quiet_belt → harrow → second_watch → mire`; save `user://progress.json`.

**Damage formula (the only copy):**

```
sonic   : (1 - acoustic_armor) * (1 + spiky_shell)
bubble  : (1 - spiky_shell)    * (1 + heat_sink)
thermal : (1 - heat_sink)      * (1 + acoustic_armor)
```

**Trait clamps:** resistances 0.0–0.8 · speed 0.6–1.8 · health 30–120.

**GA constants:** elites 2 · tournament 3 · mutation 0.35 · σ 0.08/0.08/5.0 · metabolic 0.5 ·
`MIN_EXPECTED_DAMAGE` 0.05.

**Arena:** 1600×900, 40 px walls, spawn points ≥ 340 px from centre and ≥ 120 px apart.

**Run order for a new session:** read this file → read `docs/INTEGRATION.md` → read the
systems you are about to change → run §12.1–12.2 to confirm a green baseline **before**
editing anything → then start at Phase 0.
