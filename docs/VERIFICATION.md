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

> The game writes `user://progress.json` when it clears an island or restores a reef, so
> resetting between runs means deleting that file — otherwise the map opens with islands
> already unlocked and the guidebook already filled in. `verify_levels.gd` clears the file's
> three lists at start-up instead, so its reef verdicts are always measured against a state
> that run created.

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
| Mean damage multiplier for a single spammed weapon, wave 1 → last wave | 1.147 → 0.986 (**−14.0 %**) | 0.995 → 0.774 (**−22.2 %**) | 0.891 → 0.515 (**−42.2 %**) |

That last row is the payoff: it is *how much damage the swarm would now take from the weapon
the player kept using*, measured on the populations the level actually bred. Spam one weapon and
the reef measurably hardens against it, and the effect grows with the island and the number of
generations. (Redwake is the tutorial — 3 waves means only two generations — so its drift is the
smallest.)

Species weakness declarations are machine-checked by `species_db.audit()`, which the harness
calls first: for all six species, `damage_multiplier_for(weak_to) > 1.0` and `< 1.0` for every
declared resistance — and, since W8, that no reef helper has drifted into the invasive roster,
declares a threat level or claims combat resistances. Result:
`species table audit clean (6 species, 3 helpers)`.

### Reef restoration — verified, and shown to discriminate

The coral component is pure logic (`systems/reef_restoration.gd`), so the harness ticks the real
object at the real frame rate over the real wave sizes of a three-wave island for three
different players:

| Simulated player | Reef at the end | Verdict |
|---|---|---|
| kills an invader every **0.5 s** | **100.0 %** | RESTORED — the island is credited |
| kills an invader every **3.0 s** | **66.8 %** | HEALING — complete, but never tops out, so no credit |
| **never kills anything** | **3.0 %** | BLEACHED — the swarm wins |

The same dive without the friendly species ends at **15.8 %** instead of 66.8 %, so the helpers
are worth **+51 reef points over a slow dive** — measured, not asserted. The harness fails if the
fast and slow dives converge, if the never-clearing dive survives, or if the helpers move the
number by less than 10 points, so re-tuning the economy cannot silently flatten it.

On the live levels, after each island is cleared:

| | coral beds | helpers | reef start → end | kills credited |
|---|---|---|---|---|
| redwake | 3 | 3 | 45.0 % → **99.6 %** (RESTORED) | 8 |
| quiet_belt | 3 | 3 | 38.0 % → **99.9 %** (RESTORED) | 27 |
| harrow | 4 | 3 | 30.0 % → **99.9 %** (RESTORED) | 31 |

The end-of-dive number moves a little between runs (redwake has measured 77.5 % and 99.6 % on the
same build): the reef's kill credit is read from the live invasive population, and the harness's
last few kills land on the same frame it reads the verdict. Both are honest readings of the same
run, not a range being cherry-picked. The lull between waves is stretched to 2.5 s in this harness
(production is 3.0 s) so the planting test has a window to work in, which gives the helpers a
little more quiet time than the old 0.25 s pacing did.

and the harness also checks, per level, that no helper is in group `"invasive"`, that none
exposes `receive_damage()`, that each one is actually working a coral bed, that the wave manager
never spawned a helper as an invader, and that the credit written to the save file matches the
reef's own verdict when the last wave died.

### The planting action — verified through real input

`_plant_test()` drives the action the way a player does — `Input.action_press("reef_seed")` and a
real hold — and the only number the test shortens is the channel itself (`seed_time` 0.06 s
instead of 1.6 s), exactly as the run shortens `spawn_interval`. Everything else is production.

| What is checked | Evidence from the run |
|---|---|
| Planting actually pays | **+14.2 reef health**, worth 14.0, against 0 kills in the window |
| Planting grows coral, not just a number | **+1 coral head** on the bed (`fragment_count()` before/after) |
| Reef health is measured honestly | 90 settle frames with the kill counter flat before the hold, and the harness fails if any kill lands inside the window |
| The ceiling is respected | the gain is required to equal `min(SEED_RESTORE, headroom)`, so a bed planted near full health is not read as a short change |
| Out of range does nothing | key held mid-arena for 90 frames, `plantings` stays 0 |
| One planting per bed per wave | a second 120-frame hold on the same bed leaves `plantings` at 1 |
| **A live wave is not a lull** | key held through **148–150 frames** of empty-looking water *inside* a running wave (`alive == 0`, `_wave_done == false`) and the bed at rest grew **0** heads |
| A live swarm refuses the action outright | after the next wave is up, `plantings` is still 1 when the reef is audited |
| The action is worth more than a kill | `SEED_RESTORE > 3 × KILL_RESTORE`, asserted before the first hold |
| The number was tested unclamped | the harness fails unless at least one level planted with ≥ 14.6 headroom |

Writing this test found a **real, pre-existing spawn bug**: spawn positions were only kept away
from the **arena centre** (`reef_floor.SPAWN_MIN_CENTRE_DIST`, with the comment "so nothing lands on
the player"), which is only the same thing while the player stands in the middle. Parking the
sentinel over a coral bed — which is at least 200 px off-centre by construction — put the swarm's
arrival points back on top of the ship. `systems/wave_manager.gd` now enforces
`SPAWN_MIN_PLAYER_DIST` (340 px, measured from the player) on both spawn routes, re-rolling the
species' home zone up to six times and falling back to the ring point the player is furthest from.
The level harness's own 320 px spawn rule then went from 3–11 failures a run to zero.

### Progression, guidebook and reef persistence — verified

Driving the three islands for real leaves the save file (Windows:
`%APPDATA%\Godot\app_userdata\ReefSentinel\progress.json`) as:

```json
{"cleared":["redwake","quiet_belt","harrow"],"restored":["redwake","quiet_belt","harrow"],
 "seen":["reef_parrotfish","cleaner_wrasse","gardener_crab","drifter_jelly","spine_urchin","ember_nautilus","kelp_snatcher","bone_ray"]}
```

So the map → dive → `reef_cleared` → `mark_island_cleared()` → unlock chain works, the guidebook
records exactly the species that actually spawned (five of harrow's six were drawn in that run —
`steelhead_bloom` simply did not come up in the wave mix, which is the correct behaviour, not a
miss), and the three reef helpers were recorded by being met in the water rather than by looking
them up. An older save carrying only `"cleared"` still loads: all three keys are read
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

**26 assertions, all passing** (`PASS: two offensive weapons, one defensive dome, selection
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
- **Reef helpers cannot be hurt, and this is measured on a live projectile** (W8). A helper is
  placed in the water with a sonic pulse, a bubble dome and a thermal beam all aimed at it, and
the pulse is *real*: it flies from x = 120 past the helper and is checked at x = 427 with
  `_spent == false`. The helper comes out the other side in group `"friendly"`, still not in
  `"invasive"`, with no `receive_damage()`, its reef value unchanged at **1.35 /s**, and the dome
  has not spent a charge or shoved it.

## 4. Every drawing path renders — verified

```bash
timeout 280 "$GODOT" --path . --script res://tools/verify_ui.gd
```

Headless Godot cannot rasterize, so this one runs windowed, screenshots the viewport and counts
pixels of known colours. Result: `PASS: every draw path ran without errors`, 19 screenshots in
[docs/shots/](docs/shots/index.html) (1152×648, all ~100 % non-black), peak **12** simultaneous
enemies on screen.

| What was measured | Result |
|---|---|
| Guidebook cover-green palette | 11764 samples |
| Guidebook parchment | 47394 samples |
| Guidebook covers the whole viewport | size (1152, 648) == viewport (1152, 648) |
| Map does **not** show through the book | backdrop blue-red **0.071** at both corners (map water is ~0.28) |
| Every entry is written | 9/9 with a name, a stat block and spawn zones |
| The portrait shows the species' own art | 646 samples of the Drifter Jelly's tint inside its plate |
| Coral responds to reef health | mean red-green warmth **0.034 bleached → 0.093 restored** |
| HUD reef readout | `REEF HEALTH   66%   HEALING` on a live dive |
| The planting prompt is real HUD text | `HOLD  E  TO PLANT CORAL`, read off the `SeedPrompt` node |
| The prompt is actually painted in the shot | **363 / 6804** bright pixels inside the panel's own rect (a panel that never drew reads as flat water); the state colour lands on the panel's edge (95 samples while planting) |
| The channel is visible while it runs | the prompt switches to `PLANTING CORAL` and the hold is read at **0.36 s** of the 1.6 s channel |
| The planting action completes on a rendered frame | `1 planting(s), bed 0 → 1 coral head(s)`, plus `CORAL PLANTED` on the HUD |
| Adaptation banner visible between waves | `true`, 2 text labels rendered |
| Hull "critical" red on the bar | 2750 samples |
| Damage vignette covered the viewport | size (1152, 648), intensity 0.421 |
| Screen-edge redness, hurt vs healthy | **0.164 vs 0.052** |
| The three arenas render different biomes | mean play-area colour delta **0.343 / 0.470 / 0.261** |

The biome row is the W4 acceptance check: the harness loads each island in turn, waits for its
wave, and compares the average colour of the play area. Identical biomes would score ~0.00, so
this is also the regression test for the configure-before-`add_child()` bug described in §2.
The 19 screenshots are `01`–`09` for the map, guidebook, HUD, banner, dome, beam and a 12-enemy
load frame, `10`–`12` for Redwake, Quiet Belt and Harrow, `13`–`15` for the reef component
healthy, bleached and restored, and `16`–`18` for the planting action: the ready ring and prompt,
the arc filling as the channel runs, and the landing with the coral head and the HUD confirmation.

Four real bugs were found and fixed by this harness:

1. The damage vignette's `Control` resolved to a **0×0 rect** (invisible in-game).
2. The bestiary's page wash was drawn with a negative-size rect that clipped the illustrations.
3. The "wait for the wave" logic in the harness itself was clamped, so tests ran before enemies
   existed.
4. **The book never drew at all.** The bestiary `Control` was added to a parent that had already
   run its layout pass, so anchors alone left it at **0×0** — and because its `_draw()` starts by
   measuring itself, every page, cover and backdrop silently bailed out while the child labels
   happily rendered at the right coordinates. That is exactly what the owner saw: stat text
   floating over the ocean with no book under it. The guidebook now owns its rect (`_layout()`
   sets position and size every pass) and the harness asserts `size == viewport`, refuses to pass
   if the map's blue water reads through the backdrop at the screen corners, and walks all nine
   entries checking each one has a name, a stat block and zones.

Also verified here: pressing the **real** world-map button (not the node) opens the guidebook, and
the reef comparison is made honest by forcing the reef to 0 and then to full health and measuring
the coral's colour across all three beds in both shots — the component's visual response is a
number, not an impression.

The planting shots cost this harness several rounds of its own bugs, most of them the same
mistake: a check that reads game state in the frame it changes, or measures pixels against
geometry taken from the wrong frame. In order — the prompt was inspected on the frame the wave
died (the level's `_tick_seeding()` had not run yet, so the panel was still hidden); the planting
attempt began before the gate had opened and then depended on a synthetic key press surviving
75 frames of a windowed run; and the pixel check measured the **label's** rect, which a Label
inside a container reports as its pre-layout size until the container's next pass, so it sampled
water. It now waits for the **level's own** `_seed_target`, lets the prompt stand for 8 rendered
frames before the shot, shortens `seed_time` for the landing shot the way the run shortens
`spawn_interval` elsewhere, re-asserts the press every frame, and measures the panel rather than
the label. No game-side bug came out of these three shots, and the words are asserted from the
node — a screenshot is not OCR'd here, so what the prompt *looks like* is still for a human.

## 5. Performance — verified

```bash
timeout 280 "$GODOT" --path . --script res://tools/verify_perf.gd
```

Wall-clock frame time over 150-frame windows, windowed, 1152×648. Vsync is disabled for the
capability rows because `Engine.get_frames_per_second()` lags badly and reported a fake "17 FPS"
in an earlier version of this harness; the wall clock is the honest metric.

Three consecutive runs of the same build (a laptop, so the spread is real — the same build measured
401 fps and 208 fps on the first row in two runs minutes apart, which is why nothing here is
compared across sessions):

| Scenario | Run A | Run B | Run C |
|---|---|---|---|
| Opening wave (2–5 enemies) | 1041 fps / 0.96 ms | 401 fps / 2.49 ms | 208 fps / 4.79 ms |
| **16 enemies of mixed species** | **370 fps / 2.70 ms** | **195 fps / 5.12 ms** | **125 fps / 7.92 ms** |
| 16 enemies, 3 coral beds also on screen | — | — | 140 fps / 7.14 ms |
| Same 16, art hidden | 1055 fps / 0.95 ms | 510 fps / 1.96 ms | 318 fps / 3.15 ms |
| Floor + HUD only | 744 fps / 1.34 ms | 389 fps / 2.57 ms | 256 fps / 3.90 ms |
| **vsync ON (the F5 case)** | — | 147 fps | 139 fps |

Draw calls: ~900 with 16 enemies on screen, ~290 with the same swarm hidden.

Read it like this: the worst measured 16-enemy frame is **7.92 ms against a 16.67 ms budget**, so
even the slowest run has 2× headroom; with vsync on the game sits above the panel's refresh rate,
which clears the contract's 60 FPS. Enemy art costs roughly 0.2 ms per enemy per frame.

### The coral component's cost, measured inside one run

Cross-session numbers are too noisy to attribute anything to a new feature, so the last two rows
load the **same level twice in one run** — once with the coral component switched off
(`reef_site_count = 0`, `friendly_count = 0`) and once with it on:

| | frame time | draw calls |
|---|---|---|
| same level, reef component **off** | 1.93 ms/frame | 345 |
| same level, reef component **on** | 1.63 ms/frame | 370 |
| **difference** | **−0.30 ms/frame** | +25 |

The first version of the coral cost **+2.73 ms/frame**, because it redrew ~300 primitives every
frame. It now follows the project's bake-once convention: the colony is drawn by
`scenes/levels/reef_coral.gd` into a SubViewport and rendered as one sprite per bed, re-baked only
when the reef crosses a 4 % health bucket, and only a six-primitive sparkle layer redraws per
frame. The harness fails the run if the component costs more than 2 ms/frame.

The same A/B was measured again once the planting action landed (the ready ring, the progress arc
and the landing burst are new per-frame primitives on a bed the sentinel is standing at):

| | frame time | draw calls |
|---|---|---|
| same level, reef component **off** | 8.50 ms/frame | 435 |
| same level, reef component **on** | 9.20 ms/frame | 512 |
| **difference** | **+0.70 ms/frame** | +77 |

Three runs of this A/B after the planting work read **−0.30**, **−0.05** and **+0.70 ms/frame**, which
is the honest way to quote it: the component's cost sits inside this laptop's noise floor, the
sign flips between runs, and the harness fails the run above 2 ms/frame. What is *not* noise is
that the same component cost **+2.73 ms/frame** before the bake-once rewrite, which is the
regression the threshold exists to catch.

The absolute times in this pass are higher than the runs above (the same 5-enemy opening wave read
286 fps here against 401 fps in Run B) because they were taken minutes apart on a laptop; that is
exactly why the component's cost is only ever quoted as an in-run difference. The planting
feedback itself is drawn on a single bed and only while the sentinel is in range, so it is a
handful of arcs, not a per-frame redraw of the colony.

Five optimizations have come out of these measurements and are in the build: enemies no longer
redraw every frame when nothing changed, the HUD no longer reshapes text per frame, the floor's
animated layer bakes once instead of compositing every frame, coral beds bake per health bucket
instead of per frame, and the guidebook only redraws its pages while it is open.

## 6. Not verified

None of these are known-broken; they are simply unchecked. Treat them as the risk list.

- **Audio.** There is no audio anywhere in the project. Nothing to verify.
- **Islands 4 and 5** (`second_watch`, `mire`) have world-map markers and unlock logic but no dive
  scenes, so the level harness only covers the three that exist. The guidebook likewise only
  lists what is built.
- **Long sessions.** The harnesses drive minutes, not hours. Memory growth over dozens of waves is
  unmeasured.
- **Non-Windows rendering.** All numbers come from one Windows/D3D12 laptop. Expect different
  absolute frame times on other GPUs, drivers and renderers, and measure again before claiming
  60 FPS on other hardware.
- **Human play.** A scripted player drives the harnesses; nobody has verified how the swarm *feels*
  to fight after ten generations, only that the damage numbers move the right way.
- **The guidebook is checked for coverage, palette, backdrops and content, not for prose.** Every
  entry is asserted to have a name, stats and zones, but nobody has proof-read the blurbs — read
  [docs/shots/02_guidebook_invader_entry.png](docs/shots/02_guidebook_invader_entry.png) and
  [03](docs/shots/03_guidebook_helper_entry.png).
- **The reef balance is simulated, not play-tested.** The three-player dive model matches the real
  constants and the real tick rate, but it is a model: nobody has yet confirmed by hand that
  restoring a reef *feels* achievable on Harrow with its 4 beds and the full six-species roster,
  or that the speed at which the coral drains reads clearly during a busy wave.
- **The look of the planting feedback is judged by eye only.** The prompt's words, the bed's
  ready ring, the channel arc and the landing burst are all exercised and measured to exist, but
  whether the arc reads as a channel or the burst reads as coral *landing* is a question for the
  owner and the three screenshots (`16`–`18`), not for a harness.
- **The planting action's feel is unmeasured.** Its numbers are all in one place — `SEED_RESTORE`
  (14), `seed_time` (1.6 s), `seed_range` (130 px) and `seed_per_bed_per_wave` (1) — and the
  harness checks that they do what they say, but whether a 1.6 s stationary channel *feels* like
  the right cost for 14 points is a play-testing question nobody has answered. Each one is an
  `@export` on the level, so it can be tuned without touching the logic.
- **The reef component's numbers are the owner's to change.** Drain, kill value and helper value
  all live in `systems/reef_restoration.gd`; re-run `verify_levels.gd` after touching them, because
  it is the harness that proves the three outcomes stay distinct.
