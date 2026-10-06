extends CharacterBody2D
## Invasive enemy: genome-driven chase AI with CHASE / ROOTED / DEAD states.
##
## Public API is frozen (docs/INTEGRATION.md §5):
##   signal died(genome: Resource, position: Vector2)
##   func receive_damage(amount: float, weapon_id: String) -> void
##   func setup(genome: Resource) -> void

signal died(genome: Resource, position: Vector2)

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

# INTEGRATION NOTE (C): this was `const CONTACT_DAMAGE := 10.0`. Each level scene
# exports its own `enemy_touch_damage` (redwake 6 / quiet_belt 8 / harrow 10) and
# hands it to WaveManager.configure(), which sets this before the first hit, so
# per-island difficulty tuning is no longer silently discarded. 10.0 remains the
# standalone default. No frozen name is affected.
@export var touch_damage := 10.0

var _genome: InvasiveGenome = InvasiveGenome.new()
var _health := 50.0
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


func _ready() -> void:
	add_to_group("invasive")
	queue_redraw()


func setup(genome: Resource) -> void:
	_genome = genome as InvasiveGenome
	if _genome == null:
		_genome = InvasiveGenome.new()
	_health = _genome.max_health
	_speed = BASE_SPEED * _genome.speed_multiplier
	queue_redraw()


func receive_damage(amount: float, weapon_id: String) -> void:
	if _state == State.DEAD:
		return
	var multiplier := _genome.damage_multiplier_for(weapon_id)
	_last_weapon_id = weapon_id
	_health -= amount * multiplier
	_flash()
	if weapon_id == "bubble":
		_root(clampf(BASE_ROOT_DURATION * multiplier, 0.25, MAX_ROOT_DURATION))
	if _health <= 0.0:
		_die()


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_age += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return

	match _state:
		State.ROOTED:
			_root_timer -= delta
			velocity = Vector2.ZERO
			if _root_timer <= 0.0:
				_state = State.CHASE
				queue_redraw()
		State.CHASE:
			_chase(delta)


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

	velocity = Vector2.ZERO if dist <= ATTACK_RANGE * 0.75 else desired * _speed
	move_and_slide()

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
	modulate = Color(2.0, 2.0, 2.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func _die() -> void:
	_state = State.DEAD
	var dist := 0.0
	if is_instance_valid(_player):
		dist = global_position.distance_to(_player.global_position)
	Telemetry.log_kill(_genome, _last_weapon_id, dist)
	died.emit(_genome, global_position)
	queue_free()


## Placeholder art: colour and spikes visualise the evolved traits.
func _draw() -> void:
	var g := _genome
	var body := Color(0.3 + g.heat_sink * 0.7, 0.3 + g.spiky_shell * 0.5, 0.3 + g.acoustic_armor * 0.7)
	draw_circle(Vector2.ZERO, BODY_RADIUS, body)
	var spikes := int(round(g.spiky_shell * 12.0))
	for i in spikes:
		var dir := Vector2.from_angle(TAU * float(i) / float(spikes))
		draw_line(dir * BODY_RADIUS, dir * (BODY_RADIUS + 6.0), Color.WHITE, 2.0)
	if _state == State.ROOTED:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 8.0, 0.0, TAU, 24, Color(0.5, 0.8, 1.0), 2.0)
