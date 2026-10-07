extends CharacterBody2D
## Invasive enemy: genome-driven chase AI with CHASE / ROOTED / DEAD states.
##
## Public API is frozen (docs/INTEGRATION.md §5):
##   signal died(genome: Resource, position: Vector2)
##   func receive_damage(amount: float, weapon_id: String) -> void
##   func setup(genome: Resource) -> void
##
## Additive on top of the contract (Roles A/C may call/read these):
##   func apply_impulse(direction: Vector2, strength: float) -> void   # knockback + sparks
##   func is_dead() -> bool
##   func health_ratio() -> float
##   func resistance_against(weapon_id: String) -> float
##   var species_id: String
##
## The damage maths still lives ONLY in systems/genome.gd::damage_multiplier_for().
## Everything visual here is driven by that one return value.

signal died(genome: Resource, position: Vector2)

const SpeciesDB := preload("res://systems/species_db.gd")
const DamageNumber := preload("res://scenes/enemies/damage_number.gd")
const HitBurst := preload("res://scenes/enemies/hit_burst.gd")

enum State { CHASE, ROOTED, DEAD }

const BASE_SPEED := 90.0
const ATTACK_RANGE := 32.0
const ATTACK_COOLDOWN := 1.0
const BASE_ROOT_DURATION := 1.5
const MAX_ROOT_DURATION := 3.0
const WOBBLE_STRENGTH := 0.35
const SEPARATION_RADIUS := 40.0
const SEPARATION_WEIGHT := 0.8
const SEPARATION_INTERVAL := 0.2
const BODY_RADIUS := 14.0

# W2 feedback tuning.
const ABSORBED_THRESHOLD := 0.5     # below this multiplier a hit reads as "absorbed"
const IMPACT_COOLDOWN := 0.14       # thins sparks for sustained weapons
const KNOCKBACK_DECAY := 9.0
# Animation redraws are throttled to 20 Hz: rebuilding ~60 canvas commands per
# enemy per frame is the single biggest CPU cost in a big wave, and a drifting
# jelly at 20 fps is indistinguishable from one at 60. Every *hit* still redraws
# immediately, so feedback stays instant.
const REDRAW_INTERVAL := 0.05
const SLOW_REFRESH := 0.25

# Weapon identity colours for the resistance shimmer and hit sparks.
const WEAPON_TINT := {
	"sonic": Color("62d8ff"),
	"bubble": Color("a8e8ff"),
	"thermal": Color("ff9a3c"),
}

# INTEGRATION NOTE (C): this was `const CONTACT_DAMAGE := 10.0`. Each level scene
# exports its own `enemy_touch_damage` (redwake 6 / quiet_belt 8 / harrow 10) and
# hands it to WaveManager.configure(), which sets this before the first hit, so
# per-island difficulty tuning is no longer silently discarded. 10.0 remains the
# standalone default. No frozen name is affected.
@export var touch_damage := 10.0

var species_id := "drifter_jelly"

var _genome: InvasiveGenome = InvasiveGenome.new()
var _health := 50.0
var _max_health := 50.0
var _speed := BASE_SPEED
var _state: State = State.CHASE
var _root_timer := 0.0
var _attack_timer := 0.0
var _separation_timer := 0.0
var _separation := Vector2.ZERO
var _age := 0.0
var _wobble_phase := randf() * TAU
var _last_weapon_id := ""
var _player: Node2D
var _flash_tween: Tween
var _impulse_cooldown := 0.0
var _knock := Vector2.ZERO
var _facing := 0.0
var _floor: Node = null
var _slow_factor := 1.0
var _last_multiplier := 1.0
var _death_burst_done := false
var _redraw_timer := 0.0
var _slow_timer := 0.0


func _ready() -> void:
	add_to_group("invasive")
	# Species data may arrive after _ready (setup()), so re-read lazily in _draw.
	queue_redraw()


func setup(genome: Resource) -> void:
	_genome = genome as InvasiveGenome
	if _genome == null:
		_genome = InvasiveGenome.new()
	species_id = _genome.species_id
	_health = _genome.max_health
	_max_health = maxf(1.0, _genome.max_health)
	_speed = BASE_SPEED * _genome.speed_multiplier
	queue_redraw()


func receive_damage(amount: float, weapon_id: String) -> void:
	if _state == State.DEAD:
		return
	var multiplier := _genome.damage_multiplier_for(weapon_id)
	_last_weapon_id = weapon_id
	_last_multiplier = multiplier
	var applied := amount * multiplier
	_health -= applied
	_flash()
	if amount > 0.0:
		_report_hit(applied, multiplier, weapon_id)
	if weapon_id == "bubble":
		_root(clampf(BASE_ROOT_DURATION * multiplier, 0.25, MAX_ROOT_DURATION))
	queue_redraw()
	if _health <= 0.0:
		_die()


## Additive knockback/spark hook. Projectiles pass their travel direction;
## sustained weapons pass a direction with a small or zero strength so they still
## get impact sparks at a throttled rate.
func apply_impulse(direction: Vector2, strength: float) -> void:
	if _state == State.DEAD:
		return
	if strength > 0.0:
		_knock += direction.normalized() * strength
	_impact_cue(direction)


func is_dead() -> bool:
	return _state == State.DEAD


func health_ratio() -> float:
	return clampf(_health / _max_health, 0.0, 1.0)


## How hard this organism currently is against one weapon. <1 means it tanks it.
func resistance_against(weapon_id: String) -> float:
	return _genome.damage_multiplier_for(weapon_id)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_age += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_impulse_cooldown = maxf(0.0, _impulse_cooldown - delta)
	_knock = _knock.lerp(Vector2.ZERO, minf(1.0, KNOCKBACK_DECAY * delta))
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_timer = SLOW_REFRESH
		_update_slow_factor()
	_redraw_timer += delta
	if _redraw_timer >= REDRAW_INTERVAL:
		_redraw_timer = 0.0
		queue_redraw()

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return

	match _state:
		State.ROOTED:
			_root_timer -= delta
			velocity = _knock
			move_and_slide()
			if _root_timer <= 0.0:
				_state = State.CHASE
				queue_redraw()
		State.CHASE:
			_chase(delta)


## Kelp hides and slows; the reef floor owns the fields so both sides agree.
func _update_slow_factor() -> void:
	if _floor == null or not is_instance_valid(_floor):
		_floor = get_tree().get_first_node_in_group("reef_floor") as Node
		if _floor == null:
			return
	if _floor.has_method("slow_factor_at"):
		_slow_factor = float(_floor.call("slow_factor_at", global_position))


func _chase(delta: float) -> void:
	_separation_timer -= delta
	if _separation_timer <= 0.0:
		_update_separation()
		_separation_timer = SEPARATION_INTERVAL + randf() * 0.1

	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)
	var wobble := dir.orthogonal() * sin(_age * 3.0 + _wobble_phase) * WOBBLE_STRENGTH
	var desired := (dir + wobble + _separation * SEPARATION_WEIGHT).normalized()

	if dist <= ATTACK_RANGE * 0.75:
		velocity = _knock
	else:
		velocity = desired * _speed * _slow_factor + _knock
	move_and_slide()
	if velocity.length() > 6.0:
		_facing = lerp_angle(_facing, velocity.angle(), minf(1.0, 8.0 * delta))

	if dist <= ATTACK_RANGE and _attack_timer <= 0.0:
		_attack_timer = ATTACK_COOLDOWN
		if _player.has_method("take_health_damage"):
			_player.take_health_damage(touch_damage)


func _update_separation() -> void:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("invasive"):
		if other == self or not other is Node2D:
			continue
		var offset: Vector2 = global_position - (other as Node2D).global_position
		var d := offset.length()
		if d > 0.01 and d < SEPARATION_RADIUS:
			push += offset / d * (1.0 - d / SEPARATION_RADIUS)
	_separation = push


func _root(duration: float) -> void:
	_state = State.ROOTED
	_root_timer = maxf(_root_timer, duration)
	velocity = Vector2.ZERO
	queue_redraw()


func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color(2.2, 2.2, 2.2)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.09)


# ================================================================ FEEDBACK

## One hit = a damage number plus sparks, and a distinct "absorbed" read when the
## swarm is tanking this weapon.
func _report_hit(applied: float, multiplier: float, weapon_id: String) -> void:
	var absorbed := multiplier < ABSORBED_THRESHOLD
	var host := get_parent()
	if host == null:
		return
	var number := DamageNumber.new() as Node2D
	host.add_child(number)
	number.global_position = global_position + Vector2(randf_range(-6.0, 6.0), -BODY_RADIUS - 8.0)
	number.call("show_hit", applied, multiplier, absorbed)
	if applied >= 0.01 or absorbed:
		_spawn_burst(Vector2.RIGHT.rotated(randf() * TAU), absorbed, 1.0)


func _impact_cue(direction: Vector2) -> void:
	if _impulse_cooldown > 0.0:
		return
	_impulse_cooldown = IMPACT_COOLDOWN
	_spawn_burst(direction, _last_multiplier < ABSORBED_THRESHOLD, 0.8)


func _spawn_burst(direction: Vector2, absorbed: bool, strength: float) -> void:
	var host := get_parent()
	if host == null:
		return
	var burst := HitBurst.new() as Node2D
	host.add_child(burst)
	burst.global_position = global_position + direction.normalized() * BODY_RADIUS * 0.7
	var tint: Color = WEAPON_TINT.get(_last_weapon_id, Color.WHITE)
	if absorbed:
		burst.call("configure", direction, Color(0.82, 0.92, 1.0), 3, 0.25)
	else:
		burst.call("configure", direction, tint, int(6.0 * strength) + 3, 0.7)


func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	var dist := 0.0
	if is_instance_valid(_player):
		dist = global_position.distance_to(_player.global_position)
	Telemetry.log_kill(_genome, _last_weapon_id, dist)
	GameProgress.mark_species_seen(species_id)
	# Death animation before the body disappears, but the signal fires now so the
	# wave loop never waits on cosmetics.
	died.emit(_genome, global_position)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var host := get_parent()
	if host != null and not _death_burst_done:
		_death_burst_done = true
		var poof := HitBurst.new() as Node2D
		host.add_child(poof)
		poof.global_position = global_position
		poof.call("configure", Vector2.RIGHT.rotated(randf() * TAU),
				SpeciesDB.get_species(species_id).get("accent", Color.WHITE), 10, 3.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.22)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.22)
	tween.chain().tween_callback(queue_free)


# ================================================================ DRAW
# Species identity lives here: every invasive reads as its own creature, and the
# evolved traits are visible on the body (spine count/length, plate thickness,
# vent glow, wounded state, resistance shimmer).

func _draw() -> void:
	var data := SpeciesDB.get_species(species_id)
	var g := _genome
	var art_r := _art_radius(data)
	var hp := health_ratio()
	var tint: Color = data.get("tint", Color("4fb4e8"))
	var accent: Color = data.get("accent", Color.WHITE)
	var body := tint.darkened((1.0 - hp) * 0.35)
	# shadow keeps the swarm readable against bright sand
	draw_set_transform(Vector2(2.0, art_r * 0.55), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, art_r * 1.02, Color(0.02, 0.08, 0.06, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	match String(data.get("shape", "jelly")):
		"urchin":
			_draw_urchin(art_r, body, accent, g)
		"nautilus":
			_draw_nautilus(art_r, body, accent, g)
		"eel":
			_draw_eel(art_r, body, accent, g)
		"ray":
			_draw_ray(art_r, body, accent, g)
		"bloom":
			_draw_bloom(art_r, body, accent, g)
		_:
			_draw_jelly(art_r, body, accent, g)

	_draw_wounds(art_r, hp)
	_draw_resistance_shimmer(art_r)
	if _state == State.ROOTED:
		draw_arc(Vector2.ZERO, art_r + 9.0, 0.0, TAU, 26, Color(0.55, 0.85, 1.0, 0.9), 2.0)
		draw_arc(Vector2.ZERO, art_r + 13.0, 0.0, TAU, 26, Color(0.80, 0.95, 1.0, 0.35), 1.5)
	if _slow_factor < 1.0:
		# kelp drag: little fronds catching on the body
		for i in range(3):
			var a := _age * 0.8 + float(i) * 2.1
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (art_r + 7.0),
					Color(0.35, 0.62, 0.36, 0.55), 2.0, true)


func _art_radius(data: Dictionary) -> float:
	var size_scale := float(data.get("size", 1.0))
	var bulk := 0.82 + 0.42 * clampf((_max_health - 30.0) / 90.0, 0.0, 1.0)
	return BODY_RADIUS * size_scale * bulk * 0.96


## Drifter Jelly: soft bell with trailing tendrils that pulse with its speed.
func _draw_jelly(r: float, body: Color, accent: Color, g: InvasiveGenome) -> void:
	var pulse := 1.0 + 0.06 * sin(_age * 2.4 + _wobble_phase)
	var bell := PackedVector2Array()
	var n := 22
	for i in range(n + 1):
		var a := PI + PI * float(i) / float(n)
		bell.append(Vector2(cos(a) * r * pulse, sin(a) * r * 0.86 * pulse))
	for i in range(13):
		var a := float(i) / 12.0
		bell.append(Vector2(lerpf(r, -r, a), r * 0.34 * (1.0 - 0.3 * sin(a * PI))))
	draw_colored_polygon(bell, Color(body, 0.88))
	draw_polyline(_ring(bell), accent.darkened(0.1), 2.0, true)
	# inner organs: hotter core when it is heat-adapted
	draw_circle(Vector2(0, -r * 0.18), r * 0.36, Color(accent, 0.35 + g.heat_sink * 0.5))
	for i in range(5):
		var a := -PI * 0.5 + (float(i) - 2.0) * 0.42
		var sway := sin(_age * 3.0 + float(i)) * 3.0
		var tip := Vector2(cos(a) * r * 0.7 + sway, r * 0.34 + r * 1.25)
		draw_polyline(PackedVector2Array([Vector2(cos(a) * r * 0.5, r * 0.3), tip]),
				Color(accent, 0.72), 2.0, true)


## Spine Urchin: dense brittle needles; the evolved shell literally grows spikes.
func _draw_urchin(r: float, body: Color, accent: Color, g: InvasiveGenome) -> void:
	var spikes := int(clampf(9.0 + g.spiky_shell * 17.0, 8.0, 26.0))
	var spine_len := 5.0 + g.spiky_shell * 15.0
	for i in spikes:
		var a := TAU * float(i) / float(spikes) + _age * 0.35
		var wob := 1.0 + 0.05 * sin(_age * 2.0 + float(i))
		draw_line(Vector2.from_angle(a) * r * 0.82, Vector2.from_angle(a) * (r + spine_len) * wob,
				Color(accent, 0.9), 2.4, true)
		draw_circle(Vector2.from_angle(a) * (r + spine_len) * wob, 1.8, Color(1, 1, 1, 0.85))
	draw_circle(Vector2.ZERO, r * 0.92, body)
	draw_circle(Vector2.ZERO, r * 0.62, body.lightened(0.18))
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.4
		draw_circle(Vector2.from_angle(a) * r * 0.4, r * 0.16, Color(accent, 0.75))
	draw_arc(Vector2.ZERO, r * 0.92, 0.0, TAU, 22, Color(body.darkened(0.4), 0.9), 2.2, true)


## Ember Nautilus: ribbed spiral with glowing vent slits.
func _draw_nautilus(r: float, body: Color, accent: Color, g: InvasiveGenome) -> void:
	var glow := 0.35 + g.heat_sink * 0.65
	draw_circle(Vector2.ZERO, r, body.darkened(0.15))
	for i in range(3):
		var rr := r * (1.0 - float(i) * 0.26)
		draw_arc(Vector2(-r * 0.06 * float(i), r * 0.05 * float(i)), rr, PI * 0.15 + float(i) * 0.5,
				PI * 1.85 + float(i) * 0.4, 20, Color(accent, 0.85 - float(i) * 0.18), 2.6, true)
	# vent slits along the flank, driving the heat-sink fantasy
	for i in range(4):
		var t := -0.35 + float(i) * 0.26
		var p := Vector2(r * 0.55, r * t * 1.5)
		draw_circle(p, 2.6 + g.heat_sink * 3.4, Color(1.0, 0.55 + glow * 0.3, 0.2, 0.55 + glow * 0.4))
	for i in range(3):
		var a := _age * 1.6 + float(i) * 2.0
		draw_circle(Vector2(cos(a), sin(a)) * r * 0.5, 2.0, Color(1.0, 0.78, 0.45, 0.4 * glow))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(accent.darkened(0.25), 1.0), 2.4, true)


## Kelp Snatcher: segmented ribbon that trails behind its heading.
func _draw_eel(r: float, body: Color, accent: Color, g: InvasiveGenome) -> void:
	draw_set_transform(Vector2.ZERO, _facing, Vector2.ONE)
	var segs := 6
	var wave := 1.0 + 0.5 * (1.0 - clampf(g.speed_multiplier / 1.8, 0.0, 1.0))
	for i in range(segs):
		var t := float(i) / float(segs - 1)
		var x := -t * r * 2.5
		var y := sin(_age * 6.5 - t * 3.4) * r * 0.42 * wave * (0.3 + t)
		var rr := r * (0.95 - t * 0.55)
		draw_circle(Vector2(x, y), rr, Color(body, 0.95 - t * 0.25))
		if i > 0:
			var pt := float(i - 1) / float(segs - 1)
			var px := -pt * r * 2.5
			var py := sin(_age * 6.5 - pt * 3.4) * r * 0.42 * wave * (0.3 + pt)
			draw_line(Vector2(px, py), Vector2(x, y), Color(body, 0.95 - t * 0.2), r * 1.5, true)
	# head crest and eye
	draw_colored_polygon(PackedVector2Array([Vector2(r * 0.9, 0), Vector2(r * 0.1, -r * 0.65),
			Vector2(r * 0.1, r * 0.55)]), Color(accent, 0.9))
	draw_circle(Vector2(r * 0.35, -r * 0.2), 2.2, Color(0.1, 0.1, 0.12))
	# dorsal fins scale with how fast the strain has evolved
	var fins := 3 + int(round(g.speed_multiplier * 2.0))
	for i in range(fins):
		var t := float(i) / float(fins)
		var x := r * 0.3 - t * r * 2.0
		draw_line(Vector2(x, 0), Vector2(x - r * 0.3, -r * 0.75), Color(accent, 0.5), 1.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Bone Ray: wide glider whose plating thickens with acoustic armour.
func _draw_ray(r: float, body: Color, accent: Color, g: InvasiveGenome) -> void:
	draw_set_transform(Vector2.ZERO, _facing, Vector2.ONE)
	var flap := sin(_age * 3.4) * 0.16
	var wing := PackedVector2Array([
		Vector2(r * 1.15, 0), Vector2(r * 0.2, -r * 0.5),
		Vector2(-r * 0.55, -r * 1.05 * (1.0 + flap)), Vector2(-r * 1.5, -r * 0.72 * (1.0 + flap)),
		Vector2(-r * 0.95, 0),
		Vector2(-r * 1.5, r * 0.72 * (1.0 - flap)), Vector2(-r * 0.55, r * 1.05 * (1.0 - flap)),
		Vector2(r * 0.2, r * 0.5)])
	draw_colored_polygon(wing, body)
	draw_polyline(_ring(wing), Color(accent, 0.85), 2.2, true)
	# osteoderm plates: how much acoustic damage it shrugs off, made visible
	var plates := 3 + int(round(g.acoustic_armor * 8.0))
	for i in range(plates):
		var t := float(i) / float(maxf(1.0, float(plates - 1)))
		var x := lerpf(r * 0.6, -r * 1.0, t)
		var h := r * (0.55 - t * 0.25)
		draw_line(Vector2(x, -h), Vector2(x, h), Color(accent, 0.55), 2.0 + g.acoustic_armor * 3.0, true)
	draw_line(Vector2(r * 1.15, 0), Vector2(-r * 1.2, sin(_age * 3.0) * r * 0.5),
			Color(body.darkened(0.4), 0.9), 2.4, true)
	draw_circle(Vector2(r * 0.72, -r * 0.1), 2.0, Color(0.08, 0.08, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Steelhead Bloom: clustered lobes fused with metal plates and short barbs.
func _draw_bloom(r: float, body: Color, accent: Color, g: InvasiveGenome) -> void:
	var lobes := 6
	for i in lobes:
		var a := TAU * float(i) / float(lobes) + _age * 0.3
		var lobe_r := r * (0.42 + 0.10 * sin(_age * 2.0 + float(i)))
		draw_circle(Vector2.from_angle(a) * r * 0.52, lobe_r, body.lightened(0.06 * float(i % 3)))
	for i in lobes:
		var a := TAU * float(i) / float(lobes) + _age * 0.3 + 0.5
		draw_line(Vector2.from_angle(a) * r * 0.7, Vector2.from_angle(a) * (r * 0.7 + 5.0 + g.spiky_shell * 9.0),
				Color(accent, 0.85), 2.6, true)
	# pyrite plating reads as a hard rim whose weight tracks acoustic armour
	draw_arc(Vector2.ZERO, r * 0.98, 0.0, TAU, 26, Color(accent, 0.9), 2.0 + g.acoustic_armor * 6.0, true)
	draw_circle(Vector2.ZERO, r * 0.42, Color(body.darkened(0.3), 1.0))
	draw_circle(Vector2.ZERO, r * 0.24, Color(1.0, 0.85, 0.55, 0.5 + g.heat_sink * 0.4))


## Wounded state: cracks and a drained tint persist as health drops, so a player
## can see which target is nearly dead without any HUD.
func _draw_wounds(r: float, hp: float) -> void:
	if hp > 0.72:
		return
	var severity := 1.0 - hp
	var count := int(clampf(severity * 6.0, 1.0, 6.0))
	for i in range(count):
		var a := float(i) * 2.399 + _wobble_phase
		var inner := Vector2.from_angle(a) * r * 0.25
		var outer := Vector2.from_angle(a + 0.35) * r * 0.95
		draw_line(inner, outer, Color(0.06, 0.05, 0.07, 0.35 + severity * 0.45), 2.0, true)
	if hp < 0.35:
		# critical: the body leaks a warning glow
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color(1.0, 0.35, 0.3, 0.5 + 0.3 * sin(_age * 8.0)), 2.0, true)


## The adaptation made visible: a faint ring whose intensity is exactly how much
## this organism resists the weapon the player is holding right now.
func _draw_resistance_shimmer(r: float) -> void:
	var weapon := "sonic"
	if is_instance_valid(_player):
		var current: Variant = _player.get("current_weapon_id")
		if current != null:
			weapon = String(current)
	var mult := _genome.damage_multiplier_for(weapon)
	if mult >= 0.95:
		return
	var strength := clampf((0.95 - mult) / 0.95, 0.0, 1.0)
	var tint: Color = WEAPON_TINT.get(weapon, Color.WHITE)
	var rr := r + 5.0
	var segs := 22
	for i in range(segs):
		if i % 2 == 0:
			continue
		var a0 := TAU * float(i) / float(segs) + _age * 0.9
		var a1 := TAU * float(i + 1) / float(segs) + _age * 0.9
		draw_arc(Vector2.ZERO, rr, a0, a1, 4, Color(tint, 0.30 + strength * 0.6), 2.4, true)


func _ring(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out
