# Antigravity paste-ready prompt

Copy everything between the `===== BEGIN PROMPT =====` and `===== END PROMPT =====` markers
into Google Antigravity as your first message (Agent mode, with repo access enabled).
The full technical brief it refers to is committed at
`docs/ANTIGRAVITY_REDESIGN_BRIEF.md`.

If Antigravity cannot read the repository, use the **standalone fallback** at the bottom of
this file instead.

===== BEGIN PROMPT =====

You are the lead gameplay engineer on **Reef Sentinel**, a top-down 2D marine shooter built
in **Godot 4.7 with GDScript only**.

Repository: https://github.com/aryaveer25bcg10013-hub/ReefSentinel.git
Work from branch `feature/C/levels-1-3` (commit `d26439d`) — this branch holds all three
roles' integrated work. `main` does not. Create a new branch for your work, e.g.
`feature/redesign-pass-1`.

## Step 0 — before you write any code

1. Read **`docs/ANTIGRAVITY_REDESIGN_BRIEF.md`** in full. It is your specification: project
   overview, full repo inventory, the frozen contract, a deep-dive on every system
   (genome, genetic algorithm, telemetry, wave manager, level controller, procedural reef
   floor, player, weapons, enemy, HUD, world map), the current placeholder-art status,
   GDScript gotchas specific to this codebase, and the complete redesign wish-list.
2. Read **`docs/INTEGRATION.md`** — the frozen contract. It overrides your defaults.
3. Confirm a green baseline **before editing anything**:
   ```bash
   cd /c/Users/aryav/ReefSentinel
   GODOT="/c/Users/aryav/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
   timeout 180 "$GODOT" --headless --path . --import
   timeout 60  "$GODOT" --headless --path . --quit-after 90
   ```
   The boot check must print only the Godot version line — no errors or warnings.
   (On a non-Windows machine, use that machine's Godot 4.7 binary; nothing else changes.)

## Non-negotiable rules

- **Never rename or respell anything frozen:** weapon ids `"sonic" | "bubble" | "thermal"`;
  node groups `"player"` and `"invasive"`; autoloads `Telemetry` and `GameProgress`;
  `class_name InvasiveGenome`; island ids `"redwake" → "quiet_belt" → "harrow" →
  "second_watch" → "mire"`; save path `user://progress.json`; the signal/function signatures
  listed in `docs/INTEGRATION.md` §5.
- **The damage formula stays in exactly one place** — `systems/genome.gd`'s
  `damage_multiplier_for()`. If you want a change to the contract, do not make it: write
  `// PROPOSED CHANGE:` with your reasoning and implement the additive alternative instead.
- Keep every change inside the owning role's paths where possible (levels/UI = `scenes/ui/`,
  `scenes/levels/`; enemies/systems = `scenes/enemies/`, `systems/`; player/weapons =
  `scenes/player/`, `scenes/weapons/`), and mark changes to another role's file with a
  `// PROPOSED CHANGE:` comment.
- 60 FPS with F5, no edits outside owned paths, no broken builds. TABS for indentation,
  `snake_case` files, `PascalCase` nodes, typed GDScript.
- Verify empirically, never on exit codes alone: drive all three levels headlessly to
  `reef_cleared`, audit spawns, and re-measure adaptation. The brief's §12 has the full
  verification plan — use it after every phase.

## The work — redesign and improve the game

The game currently works end to end: three dive levels, a submarine with three weapons, and
invasives whose traits evolve between waves against the player's weapon-usage telemetry. It
looks and feels like a prototype. Implement these seven improvements (full detail, acceptance
criteria, and recommended approach for each are in the brief's §9 — follow them):

1. **Weapons — 2 offensive + 1 defensive.** Today all three weapons read as attacks. Make
   `sonic` and `thermal` the offensive pair and turn `bubble` into a genuine defensive tool
   (dome/barrier that roots and can absorb contact damage) — while keeping bubble at 0 base
   damage and its 80 px radius / 1.5 s root, sonic at 10 dmg / 0.25 s cooldown, and thermal at
   30 dps with overheat. Give all three real **impact and feel**: recoil, muzzle flash, hit
   sparks, screenshake, hitstop on kill, readable cooldown/heat/recharge state. Note the
   telemetry consequence in the brief: a defensive weapon must not distort what the swarm
   evolves to resist.

2. **Invasive species — better assets and visible damage.** Replace the placeholder circle
   art with real, distinct species art, and make damage unmistakable: hit flash, damage
   numbers that scale with the applied damage, impact particles, knockback, a persistent
   wounded state as health drops, and a death animation. A player must be able to tell from
   the screen alone that they hit, roughly how hard, when the hit was resisted, and when the
   target died.

3. **Make the adaptation visible.** The evolution works but the player cannot see it. Add a
   per-weapon effectiveness readout for the equipment in use, a between-wave "the swarm is
   adapting" banner that names the traits that shifted and what it means for the player's
   current weapon, a per-enemy resistance shimmer, and a first-contact toast. After two waves
   of spamming one weapon, the player should be able to see that the swarm got better against
   that specific weapon and by roughly how much. The data is already recorded — use it.

4. **Redesign all three level maps.** Add real obstacles per biome (coral bombies and arches;
   kelp forests and a wreck; vent geysers and lava-glass ridges) that collide for both the
   player and enemies, and much richer layered backgrounds (distant silhouettes, light
   shafts, denser caustics, drifting particulate, background shoals, biome ambience). Keep
   the bake-once performance convention, keep `wall_rects()`, and **keep every spawn point
   reachable** — an unreachable enemy soft-locks the wave, which is a bug this project has
   already paid for. Verify with a headless drive of all three levels.

5. **Improve the player health bar.** It is a plain progress bar today. Give it a hull-integrity
   look (segmented frame, tick marks, lagging damage ghost, hit flash), clear threshold states
   including a low-health pulse and screen-edge vignette, and a small state label. It must stay
   driven purely by the frozen `health_changed(current, max_health)` signal and survive window
   resizing.

6. **Species variety + an in-game bestiary book on the map screen.** Invasives must all look
   different and have different weaknesses drawn from the existing three-weapon counter-loop
   (a spiky species is weak to sonic, a heat-venting species is weak to bubble, an armoured
   species is weak to thermal — see the ready-to-build six-species table in the brief's §10).
   Add a **bestiary** opened from the world map, styled as an open book: dark background, an
   open book with a **green coral/seaweed cover border**, **cream parchment pages** with faint
   blotches and a shaded centre gutter, a **small white diamond ornament at the top centre**
   of the frame, and tab/bookmark shapes at the bottom centre. Entries show each species'
   name, art, stats, weaknesses and where it spawns, with undiscovered species shown as
   silhouettes. That reference image is a watermarked stock asset supplied as style reference
   only — **do not copy or ship it**; recreate the look as code-drawn art, matching the
   project's existing convention of drawing everything procedurally. Drive the whole bestiary
   from one shared species data file so the enemies and the book can never disagree.

7. **Majority-weighted spawn zones.** Different species should spawn predominantly at
   different points on each map, but **never exclusively** — every species must stay possible
   everywhere, just less likely. Implement named spawn zones per level with species × zone
   weights where the home zone dominates and every other zone keeps a small non-zero floor
   weight, verify the distribution over ~200 headless spawns (majority in the home zone, at
   least one appearance in each other zone), make it deterministic for a fixed level seed,
   and surface the zone data in the bestiary.

## How to sequence it

Follow the brief's §13 work order (foundation/species data first, then enemy art and
feedback, adaptation UI, spawn zones, bestiary UI, weapon redesign, then levels and health
bar). End every phase with a runnable build, the §12 verification pass, and a commit. Attach
the verification numbers and screenshots (bestiary, health bar, a hit in progress, all three
levels) to the pull request description.

Report back at the end of each phase with: what changed, which files, the verification
results, and anything you had to leave as a `PROPOSED CHANGE`.

===== END PROMPT =====

---

## Standalone fallback (only if Antigravity cannot read the repo)

If the agent has no repository access, paste the prompt above **and** attach:
- `docs/ANTIGRAVITY_REDESIGN_BRIEF.md` (the full specification),
- `docs/INTEGRATION.md` (the frozen contract),
- the source files listed in the brief's §2.1 inventory.

The brief is written so that it can be pasted alongside the code without any extra explanation.
