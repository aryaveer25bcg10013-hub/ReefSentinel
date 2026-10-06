extends CharacterBody2D
# C-owned PLACEHOLDER — scaffolding only, NOT Role B's real enemy.
#
# Why this exists: the three level scenes must run (F5, 60 FPS) before
# res://scenes/enemies/invasive.tscn lands, and the levels must need no editing
# once it does. level_base.gd prefers B's scene whenever it exists, so this file
# is dead weight the moment B ships. Delete it then.
#
# Frozen enemy API implemented verbatim:
#   signal died(genome: Resource, position: Vector2)
#   func receive_damage(amount: float, weapon_id: String) -> void
#   func setup(genome: Resource) -> void
#
# Trait visuals are honest: spikes scale with spiky_shell, the shell plate with
# acoustic_armor, and the glow with heat_sink, so the GA's adaptation is visible
# on screen rather than only in the telemetry.

signal died(genome: Resource, position: Vector2)

const BASE_SPEED := 78.0
const ROOT_DURATION := 1.5     # contract: bubble roots for 1.5 s
const BODY_RADIUS := 16.0
const CONTACT_COOLDOWN := 0.7
const WALL_KEEP := 60.0
const BODY := Color("5b2c3f")
const BODY_EDGE := Color("33231a")
const SPIKE := Color("ffe08a")
const ARMOR := Color("8fa4b8")
const HEAT := Color("ff7a2e")
const EYE := Color("f6f1e7")

@export var touch_damage := 8.0

var _genome: InvasiveGenome = null
var _health := 50.0
var _max_health := 50.0
var _speed := BASE_SPEED
var _root_timer := 0.0
var _contact_timer := 0.0
var _flash := 0.0
var _dead := false
var _wobble := 0.0
var _arena_ref := Vector2(1600, 900)
var _last_weapon_id := "sonic"


func _ready() -> void:
	add_to_group("invasive")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_ensure_shape()
	_wobble = randf() * TAU


func _ensure_shape() -> void:
	if find_children("*", "CollisionShape2D", false).is_empty():
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = BODY_RADIUS
		shape.shape = circle
		add_child(shape)


# ---------- Frozen API ----------

func setup(genome: Resource) -> void:
	_genome = genome as InvasiveGenome
	if _genome != null:
		_max_health = _genome.max_health
		_speed = BASE_SPEED * _genome.speed_multiplier
	else:
		_max_health = 50.0
		_speed = BASE_SPEED
	_health = _max_health
	queue_redraw()


func receive_damage(amount: float, weapon_id: String) -> void:
	if _dead:
		return
	_last_weapon_id = weapon_id
	# Bubble is a trap, not a damage source: base damage 0, roots instead.
	if weapon_id == "bubble":
		_root_timer = ROOT_DURATION
		_flash = 0.12
		queue_redraw()
		return

	# The multiplier lives ONLY in systems/genome.gd — never inline it here.
	var multiplier := 1.0
	if _genome != null:
		multiplier = _genome.damage_multiplier_for(weapon_id)
	_health -= amount * multiplier
	_flash = 0.12
	queue_redraw()
	if _health <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	# Feed the kill back to telemetry so the GA has data to work with. The
	# autoload is looked up defensively, like Role A's submarine does.
	var telemetry := get_node_or_null("/root/Telemetry")
	if telemetry:
		var distance := 0.0
		var target := get_tree().get_first_node_in_group("player") as Node2D
		if target != null:
			distance = global_position.distance_to(target.global_position)
		telemetry.log_kill(_genome, _last_weapon_id, distance)
	died.emit(_genome, global_position)
	queue_free()


# ---------- Behaviour ----------

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_wobble += delta * 2.0
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	if _contact_timer > 0.0:
		_contact_timer -= delta

	if _root_timer > 0.0:
		_root_timer -= delta
		velocity = velocity.lerp(Vector2.ZERO, minf(1.0, 10.0 * delta))
	else:
		_chase(delta)
	move_and_slide()
	_touch_player()

	global_position.x = clampf(global_position.x, WALL_KEEP, _arena_ref.x - WALL_KEEP)
	global_position.y = clampf(global_position.y, WALL_KEEP, _arena_ref.y - WALL_KEEP)


func _chase(delta: float) -> void:
	var target := get_tree().get_first_node_in_group("player") as Node2D
	if target == null:
		velocity = velocity.lerp(Vector2.ZERO, minf(1.0, 4.0 * delta))
		return
	var to_target := (target.global_position - global_position).normalized()
	# slight weave so a pack does not stack into a single line
	var weave := Vector2(-to_target.y, to_target.x) * sin(_wobble) * 0.35
	velocity = (to_target + weave).normalized() * _speed


func _touch_player() -> void:
	if _contact_timer > 0.0:
		return
	var target := get_tree().get_first_node_in_group("player") as Node
	if target == null or not target.has_method("take_health_damage"):
		return
	var target_node := target as Node2D
	if target_node == null:
		return
	if global_position.distance_to(target_node.global_position) > BODY_RADIUS + 26.0:
		return
	_contact_timer = CONTACT_COOLDOWN
	target.take_health_damage(touch_damage)


## The level tells each enemy how far it may roam.
func set_arena_limit(size: Vector2) -> void:
	_arena_ref = size


# ---------- Placeholder art ----------

func _draw() -> void:
	var flash := _flash > 0.0
	var body := Color.WHITE if flash else BODY
	# spikes grow with spiky_shell
	var spikes := 0.0
	var armor := 0.0
	var heat := 0.0
	if _genome != null:
		spikes = clampf(_genome.spiky_shell, 0.0, 1.0)
		armor = clampf(_genome.acoustic_armor, 0.0, 1.0)
		heat = clampf(_genome.heat_sink, 0.0, 1.0)

	if spikes > 0.02:
		for k in range(12):
			var a := TAU * float(k) / 12.0
			var inner := Vector2(cos(a), sin(a)) * BODY_RADIUS * 0.9
			var outer := Vector2(cos(a), sin(a)) * (BODY_RADIUS + 4.0 + spikes * 13.0)
			draw_colored_polygon(PackedVector2Array([
				inner + Vector2(-sin(a), cos(a)) * 3.2,
				outer,
				inner + Vector2(sin(a), -cos(a)) * 3.2,
			]), Color(SPIKE, 0.9))
	draw_circle(Vector2.ZERO, BODY_RADIUS, body)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 28, BODY_EDGE, 2.4, true)
	if armor > 0.02:
		draw_arc(Vector2.ZERO, BODY_RADIUS - 3.0, PI, TAU, 20, Color(ARMOR, 0.35 + armor * 0.65),
				4.0 + armor * 5.0, true)
	if heat > 0.02:
		draw_circle(Vector2.ZERO, BODY_RADIUS * (0.35 + heat * 0.25), Color(HEAT, 0.25 + heat * 0.5))
	draw_circle(Vector2(-5.0, -3.0), 3.4, EYE)
	draw_circle(Vector2(-5.0, -3.0), 1.7, BODY_EDGE)
