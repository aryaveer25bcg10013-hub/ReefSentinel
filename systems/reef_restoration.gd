extends RefCounted
## Reef restoration — the per-level "help the coral" component.
##
## One of these lives in every dive. It is deliberately pure logic: no nodes, no
## drawing, no signals. level_base ticks it each frame with two numbers it
## already has (how many invasives are alive, how many reef helpers are working)
## and reads the result back for the HUD, the coral art and the save file. That
## is what makes the whole loop testable in a headless harness
## (tools/verify_levels.gd) rather than only observable by eye.
##
## The loop the player feels:
##   * invaders smother the reef — every living invasive drains it
##   * your kills pull it back — every confirmed kill is a lump of health
##   * the helpers work for free, but only at a trickle while invaders are
##     actually in the water, so clearing a wave is what lets them graze
##   * and, once you have defeated the swarm, YOU plant coral at a bed by hand —
##     the biggest single gain in the system, and the only one the player
##     chooses to make rather than earns by surviving
##   * clear a dive with the reef above RESTORED_AT and the island is marked
##     restored in the guidebook; finish with the reef at zero and it bleached.
##
## Restoring is deliberately a race, not a formality: a wave left swimming
## out-drains the helpers, so the fastest way to save the reef is to shoot.
## tools/verify_levels.gd simulates three players (fast / slow / never clears)
## and asserts they end in three different states, so this tuning is under test.

const SpeciesDB := preload("res://systems/species_db.gd")

const HEALTH_MAX := 100.0
## Tuned so the three levers stay distinct (tools/verify_levels.gd simulates three
## players to prove it): a swarm left swimming out-drains everything and bleaches
## the reef, a slow but complete clear lands short of restored, and a fast clear
## tops it out only because the helpers keep working the whole time.
const DRAIN_PER_INVASIVE := 0.60   # per living invasive, per second
const KILL_RESTORE := 4.0          # one dead invasive hands back this much
## What the player's own hands are worth: one coral planting (the seeded action
## after a wave is cleared) hands back more than a kill does, because it is the
## only way the reef grows *new* heads instead of just fending off the swarm.
const SEED_RESTORE := 14.0
## Multiplied by the species' own restore_rate from systems/species_db.gd, so
## the roster stays the single source of truth for how much each helper is worth.
const RESTORE_SCALE := 0.8
## A crowded reef is not a place to graze: with invaders in the water the helpers
## drop to a trickle, so the way to let them work is to clear the water. The two
## penalties are what stop a patient player from simply out-waiting the swarm.
const CROWDED_EFFORT := 0.2
const BLEACHED_EFFORT := 0.35
const RESTORED_AT := 99.5          # "restored" fires once the reef tops out
const STRUGGLING_BELOW := 45.0     # HUD wording thresholds
const THRIVING_ABOVE := 80.0
const HIDDEN_BELOW := 22.0         # helpers give up working under this
## The bar a dive is judged on when the last wave dies (see earned_restoration).
const EARNED_ABOVE := 80.0

var health := 45.0
var kills := 0
var plantings := 0
var restored := false
var bleached := false
var peak_health := 0.0
var start_health := 45.0


func configure(start: float) -> void:
	start_health = clampf(start, 5.0, HEALTH_MAX - 5.0)
	health = start_health
	peak_health = health
	kills = 0
	plantings = 0
	restored = false
	bleached = false


## One frame of reef life. `friendly_power` is the summed restore_rate of every
## helper currently working the reef (0 when they have all retreated).
## Returns "" most frames, or a one-shot event:
##   "restored"  — the reef reached full health for the first time this dive
##   "bleached"  — the reef hit zero
func tick(delta: float, invasives: int, friendly_power: float) -> String:
	var before := health
	var alive := maxi(0, invasives)
	var drain := DRAIN_PER_INVASIVE * float(alive)
	var restore := RESTORE_SCALE * maxf(0.0, friendly_power) * helper_effort(alive)
	health = clampf(health + (restore - drain) * delta, 0.0, HEALTH_MAX)
	peak_health = maxf(peak_health, health)
	if health <= 0.0 and before > 0.0 and not bleached:
		bleached = true
		return "bleached"
	if health >= RESTORED_AT and not restored:
		restored = true
		return "restored"
	return ""


## A confirmed kill hands a lump of health straight back to the reef.
func add_kill() -> String:
	kills += 1
	health = clampf(health + KILL_RESTORE, 0.0, HEALTH_MAX)
	peak_health = maxf(peak_health, health)
	if health >= RESTORED_AT and not restored:
		restored = true
		return "restored"
	return ""


## The player planted coral — the one reef gain that comes from doing something
## on purpose rather than from surviving. level_base drives it (it owns the key
## and the proximity check); this only owns the number. Returns the same one-shot
## event strings as tick() so the caller has a single place to react.
func seed_planted() -> String:
	plantings += 1
	health = clampf(health + SEED_RESTORE, 0.0, HEALTH_MAX)
	peak_health = maxf(peak_health, health)
	if health >= RESTORED_AT and not restored:
		restored = true
		return "restored"
	return ""


## How hard the helpers can work right now, 0..1. Two things hold them back:
## invaders in the water (they will not graze under a swarm) and a bleached reef
## (there is almost no living tissue left to work on). Both recover on their own
## as soon as the water is clear and the coral is coming back.
func helper_effort(invasives: int = 0) -> float:
	var bleeding := 1.0 if health >= HIDDEN_BELOW else BLEACHED_EFFORT
	var crowded := 1.0 if invasives <= 0 else CROWDED_EFFORT
	return bleeding * crowded


func ratio() -> float:
	return clampf(health / HEALTH_MAX, 0.0, 1.0)


## Where this dive started, as a fraction — the HUD draws a mark there.
func configured_start_ratio() -> float:
	return clampf(start_health / HEALTH_MAX, 0.0, 1.0)


func health_text() -> String:
	return "%d%%" % int(round(health))


## Short state word for the HUD and the guidebook.
func state_label() -> String:
	if restored:
		return "RESTORED"
	if bleached:
		return "BLEACHED"
	if health >= THRIVING_ABOVE:
		return "THRIVING"
	if health >= STRUGGLING_BELOW:
		return "HEALING"
	return "FAILING"


## One-line explanation of what the player should do about the state.
func advice_text() -> String:
	if restored:
		return "The coral is open again. Every polyp is feeding."
	if bleached:
		return "The coral has bleached. Clear the water and the helpers will rebuild it."
	if health >= THRIVING_ABOVE:
		return "Polyps are opening. Keep the swarm off the heads."
	if health >= STRUGGLING_BELOW:
		return "The helpers are gaining. Keep shooting."
	return "The invaders are smothering the reef faster than it can recover."


func state_colour() -> Color:
	if restored:
		return Color("56d6a0")
	if bleached:
		return Color("eef2f5")
	if health >= THRIVING_ABOVE:
		return Color("7de08a")
	if health >= STRUGGLING_BELOW:
		return Color("ffd45e")
	return Color("e0553f")


## Did this dive actually help the reef? This is the bar the level is judged on:
## the island is recorded as restored only if the coral was topped out (or left
## in good shape) when the last wave died.
func earned_restoration() -> bool:
	return restored or health >= EARNED_ABOVE
