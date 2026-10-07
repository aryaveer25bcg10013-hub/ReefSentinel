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
| E (hold) | Plant coral at a bed — only once the wave is over |
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
identity, weaknesses, spawn weights, reef roles and the guidebook text all come from one file —
`systems/species_db.gd` — so the book, the swarm and the helpers can never disagree.
`species_db.audit()` machine-checks that every declared weakness really is above 1.0, that every
declared resistance really is below it, and that no reef helper has sneaked into the invasive
roster.

Each species is **predominantly** found in its home zone on each island, but never *only*
there: the spawn cycle gives the home zone **7 slots** plus **one slot for every other zone**
of the island, so a species can always surprise you somewhere else. That is verified over 200
simulated spawns per species (home share: 70 % on islands with 4 zones, 64 % on the island
with 5).

## Saving the reef is the other half of the game

Every dive has coral beds on it, and the coral is losing. Four numbers drive it, and all of them
live in `systems/reef_restoration.gd` (pure logic — no nodes, no drawing — so the whole loop is
simulatable in a headless test):

- **Invasives drain it.** Every living invasive smothers the reef at 0.6 points a second.
- **Your kills restore it.** Each confirmed kill hands back 4 points.
- **You can also plant coral by hand.** Hold E at a bed between waves for 14 points — more than
  three kills — once per bed per lull (the rules are in *Planting coral* below).
- **The helpers work for free — but only in clear water.** Three friendly species patrol the
  beds at a combined ~2.8 points a second, dropping to a trickle while invaders are in the
  water and to a third of that on a bleached reef.

So it is a race, not a meter. Clearing the water is what lets the helpers graze; killing fast
is what rebuilds the coral. Restore a reef to full health and the island is marked restored in
`user://progress.json` and in the guidebook, and the sentinel that did the work gets 25 hull
back.
Let it reach zero and it bleaches: bone-white skeleton, no polyps, and the helpers visibly
slow down until the water is clear again.

`tools/verify_levels.gd` simulates three players against those exact numbers — one who kills an
invader every 0.5 s, one every 3 s, and one who never kills anything — and requires three
different outcomes (restored / healing / bleached). Across a slow dive the helpers are worth
**+51 reef points**; without them the same dive barely holds on.

### The friendly species

Three species live in the same water and fight for the reef instead of the player:

| Helper | Reef role | Worth |
|---|---|---|
| Reef Parrotfish | rasps the invasive algae mat off coral heads | +1.35 / s |
| Cleaner Wrasse | picks parasites and dead tissue out of polyps | +1.00 / s |
| Gardener Crab | cements loose coral fragments back onto the rock | +1.15 / s |

They are safe **by construction**, and the harness proves it rather than trusting it: they are
drawn from their own table (never `SPECIES`), they are added to group `"friendly"` and never
`"invasive"`, they expose no `receive_damage()`, the wave manager never spawns them and the
GA never sees them. `tools/verify_weapons.gd` flies a live sonic pulse straight through one and
requires it to come out the other side, with all its reef value intact.

### Planting coral — the action you take after the swarm is dead

Kills are coral you rescue. Planting is coral you put back yourself. When a wave is finished,
est the sentinel over a coral bed and **hold E for 1.6 s**: the bed grows a real new head (visible
on the coral, not just in a number) and the reef gains **+14 health** — three and a half kills'
worth from one deliberate act.

Four rules keep it a decision rather than a free win, and the harness defends each of them:

- **The swarm has to be beaten, not merely off-screen.** The gate is the wave being over *and*
the water being empty. A live wave's spawner leaves the screen momentarily empty between two
arrivals, and holding E through that does nothing — `tools/verify_levels.gd` holds the key through
**~150 frames of empty-looking water inside a live wave** and requires no planting, then plants
normally once the wave dies.
- **You have to be at a bed** — within 130 px of its centre.
- **One planting per bed per wave.** The swarm scatters the fragments you are carrying, so they
come back with the next wave. Three beds is three plantings per lull, not an unlimited tap.
- **It costs the lull.** You are stationary for 1.6 s at a known spot while the next wave is
already on its way.

The HUD says where you stand: a prompt appears over the nearest plantable bed, the bar under it
fills as you hold, and the bed itself draws a dashed ready ring, a filling arc, then a burst as
the new head lands — all three are code-drawn in `scenes/levels/reef_site.gd`.

The planting action also dragged a real flaw into the light. Spawns were only pushed away from the
**arena centre**, on the assumption that the player was standing there. Parking at a bed broke that
assumption — the swarm could arrive on top of the sentinel while it planted — so
`systems/wave_manager.gd` now also keeps arrivals at least 340 px from the **player**
(`SPAWN_MIN_PLAYER_DIST`), re-rolling the species' home zone a few times and, in the worst case,
handing back the ring point the sentinel is furthest from.

## Project layout

```
autoload/      Telemetry (weapon usage, kills, generations) · GameProgress (unlocks, species, reefs)
systems/       genome.gd (damage formula) · genetic_algorithm.gd (fitness/evolve)
               wave_manager.gd (wave loop, zone-weighted spawning) · species_db.gd (shared data)
scenes/player/ submarine, weapon FX (recoil, shake, hitstop)
scenes/weapons/sonic pulse · bubble dome · thermal beam
scenes/enemies/invasive enemy (species art, damage numbers, sparks, wounds)
systems/       reef_restoration.gd (the coral, as pure logic)
scenes/levels/ level controller (waves, reef tick, the E-key planting channel)
               procedural biome floor (obstacles, hazards, zones)
               coral beds (baked art, live health, plant feedback) · friendly creatures
scenes/ui/     world map · in-level HUD (hull bar, reef meter, adaptation readout) · guidebook
docs/          INTEGRATION.md (the frozen contract) · VERIFICATION.md · shots/
```

No third-party addons, no binary art: the submarine and projectiles are SVG, and the map,
reef floors, enemies, coral beds, HUD and guidebook are all drawn in code and baked once into
an off-screen viewport, so a frame costs a handful of quads rather than thousands of draw
calls. The coral is the tricky one — it changes with reef health — so it re-bakes only when the
reef crosses a visible 4 % health bucket. Measured in-run, the whole reef component costs
**−0.30 to +0.70 ms/frame** across runs — inside this laptop's noise floor, and the harness fails
the run if it ever climbs above 2 ms (it was **+2.73 ms/frame** before the beds baked once).

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

The **Guidebook** is the reef's field book, opened from the button on the world map. It is nine
entries — six invaders with their stat blocks and counter-weapons, three reef helpers with their
reef work — every one named, illustrated and detailed, because it is a guide and not a puzzle
box. Species you have actually met get a `RECORDED` badge and fill the field-log counter; the
rest are still fully written down. Entries for the islands show whether that reef has been
brought back.

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
