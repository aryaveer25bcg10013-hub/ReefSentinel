# Verification

Everything in this file was produced by running the harnesses in `tools/` on Windows 11 with
**Godot 4.7.2 stable** and an **RTX 4060 laptop GPU**. Re-run the commands to reproduce; the
numbers below are what the harnesses printed, not estimates.

The harnesses are scaffolding, not part of the game, so `tools/` is git-ignored — re-create
them if you need them (the intent of each one is described below). Nothing in the game depends
on them.

Legend: **verified** = a harness asserted it and the assertion passed. **Not verified** =
nothing checks it, so assume it can break.

---

## 1. Static and boot health — verified

```bash
GODOT="/c/Users/aryav/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
timeout 200 "$GODOT" --headless --path . --import
timeout 60  "$GODOT" --headless --path . --quit-after 90
```

**Result:** the import pass finishes with no `ERROR` or `WARNING` lines, and the boot check
prints exactly one line — the Godot version banner — then exits 0. Nothing loads a broken
resource, no autoload throws, and the world map sets itself up headless.

> Gotcha paid for already: `godot --headless --check-only --script <file>` reports bogus
> "identifier not declared" errors for scripts that touch `Telemetry` / `GameProgress`, because
> autoloads are not registered in that mode. Run the script properly instead.

> Always wrap Godot runs in `timeout`. A parse error can leave the process spinning forever.

> The game writes `user://progress.json` when it clears an island, so resetting between runs
> means deleting that file — otherwise the map opens with islands already unlocked and the
> bestiary already filled in.

## 2. Levels, spawns, zones and adaptation — verified

```bash
timeout 200 "$GODOT" --headless --path . --script res://tools/verify_levels.gd
```

The harness loads each real island scene, drives the real `WaveManager` with the real enemy, and
kills everything the way a competent player would. Final result line:
`PASS: levels cleared, spawns legal, zones weighted, adaptation intact`.

| Check | redwake | quiet_belt | harrow |
|---|---|---|---|
| `reef_cleared(<island_id>)` fired | yes | yes | yes |
| Waves cleared | 3 | 4 | 4 |
| Enemies killed | 15 | 28 | 38 |
| Every spawn inside the floor and clear of obstacles | yes | yes | yes |
| Every spawn ≥ 320 px from the player at spawn | yes | yes | yes |
| Species in the wave mix | 2 | 4 | 6 |
| Mean damage multiplier for a single spammed weapon, wave 1 → last wave | 1.166 → 1.066 (**−8.6 %**) | 1.002 → 0.756 (**−24.6 %**) | 0.882 → 0.477 (**−45.9 %**) |

That last row is the payoff: it is *how much damage the swarm would now take from the weapon
the player kept using*, measured on the populations the level actually bred. Spam one weapon and
the reef measurably hardens against it, and the effect grows with the island and the number of
generations. (Redwake is the tutorial — 3 waves means only two generations — so its drift is the
smallest.)

Species weakness declarations are machine-checked by `species_db.audit()`, which the harness
calls first: for all six species, `damage_multiplier_for(weak_to) > 1.0` and `< 1.0` for every
declared resistance. Result: `species table audit clean (6 species)`.

### Progression and bestiary persistence — verified

Driving the three islands for real leaves the save file (Windows:
`%APPDATA%\Godot\app_userdata\ReefSentinel\progress.json`) as:

```json
{"cleared":["redwake","quiet_belt","harrow"],"seen":["drifter_jelly","spine_urchin","ember_nautilus","kelp_snatcher","bone_ray"]}
```

So the map → dive → `reef_cleared` → `mark_island_cleared()` → unlock chain works, and the
bestiary records exactly the species that actually spawned (five of harrow's six were drawn
in that run — `steelhead_bloom` simply did not come up in the wave mix, which is the correct
behaviour, not a miss). An older save carrying only `"cleared"` still loads: both keys are read
defensively.

### Zone-weighted spawning — verified

200 simulated spawns per species, per island, through the real zone picker:

| | home zone | every non-home zone |
|---|---|---|
| redwake | 140/200 (70 %) | 20/200 each |
| quiet_belt | 140/200 (70 %) | 20/200 each |
| harrow | 127/200 (64 %) | 18–19/200 each |

Every species is *predominantly* where it belongs and *never* exclusive. The same run prints the
live spawn distribution from real waves (e.g. harrow: `bone_ray` 17/27 at home, and it also
appeared in all four other zones).

### Biome identity — verified

The audit caught a real pre-existing bug: **all three islands were rendering the same shallow-reef
biome.** `configure()` was being called *after* `add_child()`, so `_ready()` had already baked the
floor with the default settings. Fixed by configuring the level before it enters the tree, and the
harness now checks that each island reports its own biome, zone set and hazard mix.

## 3. Weapons and the genetic algorithm — verified

```bash
timeout 120 "$GODOT" --headless --path . --script res://tools/verify_weapons.gd
```

**18 assertions, all passing** (`PASS: two offensive weapons, one defensive dome, selection
pressure intact`). The interesting ones:

- **Sonic Pulse** does its contracted **10 damage** to a neutral genome, and **13.775** to a Spiny
  species — the counter is real, not cosmetic.
- **Thermal Beam** does exactly `30 × multiplier` too (29.925 on the same target).
- **Every landed hit adds at least 2 feedback nodes** (damage number + impact burst) — no silent
  hits.
- **Bubble Dome is defensive**: a genome with maximum `spiky_shell` takes **0 damage** from it,
  and a species that swims into it is rooted (`state == ROOTED`).
- **The dome absorbs 2 hits** (hull 90 → 90 → 90, charges 2 → 0) and the third reaches the hull
  (90 → 80). Deploying it creates a real dome with a recharge state the HUD can read.
- **The GA ignores the defensive weapon**: usage `{"bubble": 1.0}` falls back to an even
  offensive split `{sonic 0.5, thermal 0.5}`, and `{sonic 3, bubble 1}` normalises to
  `{sonic 1.0, thermal 0.0}` — dome shots neither dilute nor distort sonic pressure.
- **Selection direction flips with the weapon.** Three genomes with identical metabolic
  investment, one raised resistance each:
  - under pure **sonic** pressure: armour **1.270** > heat sink 0.802 > spines 0.602
  - under pure **thermal** pressure: heat sink **1.270** > spines 0.802 > armour 0.602

  Same three numbers, opposite winner — the swarm evolves toward whatever counters the weapon you
  actually use. That is the educational loop, asserted instead of described.

## 4. Every drawing path renders — verified

```bash
timeout 280 "$GODOT" --path . --script res://tools/verify_ui.gd
```

Headless Godot cannot rasterize, so this one runs windowed, screenshots the viewport and counts
pixels of known colours. Result: `PASS: every draw path ran without errors`, 13 screenshots in
[docs/shots/](docs/shots/index.html) (1152×648, all ~100 % non-black), peak **12** simultaneous
enemies on screen.

| What was measured | Result |
|---|---|
| Bestiary cover-green palette | 2469 samples |
| Bestiary parchment | 3127 samples |
| Adaptation banner visible between waves | `true`, 2 text labels rendered |
| Hull "critical" red on the bar | 2541 samples |
| Damage vignette covered the viewport | size (1152, 648), intensity 0.379 |
| Screen-edge redness, hurt vs healthy | **0.177 vs 0.052** |
| The three arenas render different biomes | mean play-area colour delta **0.349 / 0.470 / 0.264** |

The last row is the W4 acceptance check: the harness loads each island in turn, waits for its
wave, and compares the average colour of the play area. Identical biomes would score ~0.00, so
this is also the regression test for the configure-before-`add_child()` bug described in §2.
The 13 screenshots are `01`–`09` for the map, bestiary, HUD, banner, dome, beam and a 12-enemy
load frame, plus `10`/`11`/`12` for Redwake, Quiet Belt and Harrow respectively.

Three real bugs were found and fixed by this harness: the damage vignette's `Control` was
resolving to a **0×0 rect** (invisible in-game), the bestiary's page wash was drawn with a
negative-size rect that clipped the illustrations, and the "wait for the wave" logic in the
harness itself was clamped so tests ran before enemies existed.

Also verified here: pressing the **real** world-map button (not the node) opens the bestiary, and
the bestiary masks species the player has not met as silhouettes with `???`.

## 5. Performance — verified

```bash
timeout 280 "$GODOT" --path . --script res://tools/verify_perf.gd
```

Wall-clock frame time over 150-frame windows, windowed, 1152×648. Vsync is disabled for the
capability rows because `Engine.get_frames_per_second()` lags badly and reported a fake "17 FPS"
in an earlier version of this harness; the wall clock is the honest metric.

Three consecutive runs of the same build (a laptop, so the spread is real):

| Scenario | Run A | Run B | Run C |
|---|---|---|---|
| Opening wave (2–4 enemies) | 1041 fps / 0.96 ms | 833 fps / 1.20 ms | 609 fps / 1.64 ms |
| **16 enemies of mixed species** | **370 fps / 2.70 ms** | **240 fps / 4.17 ms** | **198 fps / 5.05 ms** |
| Same 16, art hidden | 1055 fps / 0.95 ms | 724 fps / 1.38 ms | 839 fps / 1.19 ms |
| Floor + HUD only | 744 fps / 1.34 ms | 513 fps / 1.95 ms | 612 fps / 1.63 ms |
| **vsync ON (the F5 case)** | — | 118 fps | 108 fps |

Draw calls: ~800 with 16 enemies on screen, ~210 with the same swarm hidden.

Read it like this: the worst measured 16-enemy frame is **5.05 ms against a 16.67 ms budget**, so
even the slowest run has 3× headroom; with vsync on the game sits at the panel's refresh cap
(108–118 Hz here), which is above the contract's 60 FPS. Enemy art costs roughly 0.18 ms per enemy
per frame.

Three optimizations came out of this measurement and are in the build: enemies no longer redraw
every frame when nothing changed, the HUD no longer reshapes text per frame, and the floor's
animated layer bakes once instead of compositing every frame.

## 6. Not verified

None of these are known-broken; they are simply unchecked. Treat them as the risk list.

- **Audio.** There is no audio anywhere in the project. Nothing to verify.
- **Islands 4 and 5** (`second_watch`, `mire`) have world-map markers and unlock logic but no dive
  scenes, so the level harness only covers the three that exist. The bestiary likewise only lists
  what is built.
- **Long sessions.** The harnesses drive minutes, not hours. Memory growth over dozens of waves is
  unmeasured.
- **Non-Windows rendering.** All numbers come from one Windows/D3D12 laptop. Expect different
  absolute frame times on other GPUs, drivers and renderers, and measure again before claiming
  60 FPS on other hardware.
- **Human play.** A scripted player drives the harnesses; nobody has verified how the swarm *feels*
  to fight after ten generations, only that the damage numbers move the right way.
- **The bestiary is checked for palette, layout and masking, not for prose.** Typos are yours to
  catch by reading [docs/shots/02_bestiary_book.png](docs/shots/02_bestiary_book.png).
