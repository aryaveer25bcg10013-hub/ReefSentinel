# Reef Sentinel

A top-down 2D marine shooter built in **Godot 4.7 (GDScript only)**, where the enemies
evolve against the way you play.

You pilot a submarine ("the sentinel") through a chain of reef islands. Each island is a
walled dive arena where waves of invasive species swim at you. **Between waves the swarm
evolves**: a genetic algorithm reads the weapon-usage telemetry from the wave you just
fought and breeds a population that is more resistant to whatever you leaned on and less
resistant to whatever you neglected.

That is the whole point of the game — it is a playable demo of resistance evolution, the
same reason bacteria become resistant to an antibiotic that gets over-used. Clear a reef by
using the whole toolkit instead of spamming one button.

## Run it

```bash
# Godot 4.7.x
godot --path .                 # play the main scene (world map)
godot --path . -e              # open the editor, then press F5
godot --headless --path . --import          # after adding files
godot --headless --path . --quit-after 120  # boot check: expect only the version line
```

Progress is saved to `user://progress.json` (on Windows:
`%APPDATA%\Godot\app_userdata\ReefSentinel\progress.json`). Delete it to reset.

### Controls

| Input | Action |
|---|---|
| WASD / arrow keys | Move |
| Mouse | Aim |
| Left click / Space | Fire (hold for sonic and thermal) |
| 1 / 2 / 3 | Sonic Pulse / Bubble Dome / Thermal Beam |
| Esc | Return to the world map |

## The three weapons are not a menu of three guns

| Weapon | Role | Numbers |
|---|---|---|
| **Sonic Pulse** | rapid fire, the reliable gun | 10 damage, 0.25 s cooldown |
| **Thermal Beam** | sustained burst with a cost | 30 damage/sec while held, overheat lockout + VENTING |
| **Bubble Dome** | **defensive** — the panic button | **0 damage**, 80 px radius, roots 1.5 s, absorbs 2 hits, 6 s rearm |

Because the dome cannot hurt anything, the genetic algorithm **ignores it when weighing
selection pressure** (`DAMAGE_WEAPON_IDS` in `systems/genetic_algorithm.gd`): spamming your
shield does not teach the reef to resist your shield. Every `"bubble"` shot is still
recorded by Telemetry — that API is frozen — it simply carries no evolutionary weight.

## Species and the counter-loop

Every invasive belongs to a species with its own art, its own signature trait and its own
counter. The damage formula lives in exactly one place (`systems/genome.gd`), and a
multiplier above 1 means *that weapon hurts more*:

```
sonic   : (1 - acoustic_armor) * (1 + spiky_shell)     -> beats Spiky Shell
bubble  : (1 - spiky_shell)    * (1 + heat_sink)        -> beats Heat Sink  (rooting, not damage)
thermal : (1 - heat_sink)      * (1 + acoustic_armor)   -> beats Acoustic Armor
```

| Species | Look | Weak to | Resists | Debuts |
|---|---|---|---|---|
| Drifter Jelly | pale translucent bell, tendrils | sonic | — | Redwake |
| Spine Urchin | dark bulb, dense needles | **sonic** | bubble | Redwake |
| Ember Nautilus | ribbed shell, glowing vents | **bubble** | thermal | Quiet Belt |
| Kelp Snatcher | fast ribbon eel | **thermal** | sonic | Quiet Belt |
| Bone Ray | wide plated glider | **thermal** | sonic, bubble | Harrow |
| Steelhead Bloom | clustered plates and barbs | **thermal, sonic** | bubble | Harrow |

Species set a *starting bias* and the art; the GA evolves on top of that across waves. Species
identity, weaknesses, spawn weights and the bestiary text all come from one file —
`systems/species_db.gd` — so the book and the swarm can never disagree. `species_db.audit()`
machine-checks that every declared weakness really is above 1.0 and every declared resistance
really is below it.

Each species is **predominantly** found in its home zone on each island, but never *only*
there: the spawn cycle gives the home zone **7 slots** plus **one slot for every other zone**
of the island, so a species can always surprise you somewhere else. That is verified over 200
simulated spawns per species (home share: 70 % on islands with 4 zones, 64 % on the island
with 5).

## Project layout

```
autoload/      Telemetry (weapon usage, kills, generations) · GameProgress (unlocks, bestiary)
systems/       genome.gd (damage formula) · genetic_algorithm.gd (fitness/evolve)
               wave_manager.gd (wave loop, zone-weighted spawning) · species_db.gd (shared data)
scenes/player/ submarine, weapon FX (recoil, shake, hitstop)
scenes/weapons/sonic pulse · bubble dome · thermal beam
scenes/enemies/invasive enemy (species art, damage numbers, sparks, wounds)
scenes/levels/ level controller · procedural biome floor (obstacles, hazards, zones)
scenes/ui/     world map · in-level HUD (hull bar, adaptation readout) · bestiary book
docs/          INTEGRATION.md (the frozen contract) · VERIFICATION.md · shots/
```

No third-party addons, no binary art: the submarine and projectiles are SVG, and the map,
reef floors, enemies, HUD and bestiary are all drawn in code and baked once into an
off-screen viewport, so a frame costs a handful of quads rather than thousands of draw calls.

**Frozen contract** (do not rename): weapon ids `"sonic" | "bubble" | "thermal"`, node groups
`"player" | "invasive"`, autoloads `Telemetry | GameProgress`, `class_name InvasiveGenome`,
island ids `redwake → quiet_belt → harrow → second_watch → mire`, save path
`user://progress.json`. See [docs/INTEGRATION.md](docs/INTEGRATION.md).

## Verification

Every claim above is checked by a runnable harness under `tools/` (kept out of version
control on purpose — they are throwaway scaffolding, not part of the game). See
[docs/VERIFICATION.md](docs/VERIFICATION.md) for the measured numbers, the limits of what was
checked, and [the screenshots](docs/shots/index.html) for what the game actually looks like.

```bash
godot --headless --path . --script res://tools/verify_levels.gd   # clears all 3 levels, audits spawns/zones/adaptation
godot --headless --path . --script res://tools/verify_weapons.gd  # 2 offensive + 1 defensive, dome absorption, GA filter
godot --path . --script res://tools/verify_ui.gd                  # renders every draw path, saves docs/shots/*.png
godot --path . --script res://tools/verify_perf.gd                # frame time at 5 and 16 enemies (vsync off)
```

## Not built yet

Islands 4 (`second_watch`) and 5 (`mire`) have map markers and unlock logic but no dive
scenes. There is no audio anywhere in the project, and no menu beyond the world map and the
bestiary.

### Decisions left for the owner

Several changes touch another role's file and are flagged in-line with `// PROPOSED CHANGE:`
comments (`grep -rn "PROPOSED CHANGE"`). Each keeps every frozen name and number intact:

1. `systems/genetic_algorithm.gd` — the **defensive** weapon is excluded from selection
   pressure, so spamming the bubble dome does not teach the swarm to resist it.
2. `systems/wave_manager.gd` — spawning seeds each species from the **species table** blended
   with the island's difficulty template, and picks the spawn **zone** first.
3. `scenes/weapons/bubble_trap.gd` — what "deploying" a dome means for Role B's root
   behaviour (contact still goes through the frozen `receive_damage(0.0, "bubble")` path).
4. `scenes/levels/level_base.gd` — the level is configured *before* it enters the tree; doing
   it after meant every island silently baked the default biome.

A few more decisions are still the owner's to make, with the details in
[docs/INSTRUCTIONS.md](docs/INSTRUCTIONS.md) §13: whether resistance should persist across
dives, whether Redwake's two generations are enough to teach evolution, and how the `max_health`
term in the fitness function should be priced.
