# Reef Sentinel — Locked Integration Contract
No changes without all 3 members agreeing.

## Godot version
Godot 4.x — everyone on the SAME version.

## Fixed strings (never rename)
- Weapon IDs: "sonic" | "bubble" | "thermal"
- Groups: "player" | "invasive"
- Autoloads: Telemetry | GameProgress

## Ownership
- A: scenes/player/, scenes/weapons/
- B: scenes/enemies/, systems/, autoload/telemetry.gd
- C: scenes/ui/, scenes/levels/, autoload/game_progress.gd

## Public API (copy signatures exactly)
- player.take_health_damage(amount: float)
- player.health_changed(current, max_health) [signal]
- player.died [signal]
- enemy.receive_damage(amount: float, weapon_id: String)
- enemy.died(genome, position) [signal]
- WaveManager.wave_started/wave_completed/reef_cleared [signals]
- Telemetry.log_shot(weapon_id: String)
- Telemetry.log_kill(genome, weapon_id, distance: float)
- GameProgress.is_unlocked(id: String) -> bool
- GameProgress.mark_island_cleared(id: String)

## Damage formula (lives ONLY in genome.gd)
- sonic:   (1 - acoustic_armor) * (1 + spiky_shell)
- bubble:  (1 - spiky_shell) * (1 + heat_sink)
- thermal: (1 - heat_sink) * (1 + acoustic_armor)
