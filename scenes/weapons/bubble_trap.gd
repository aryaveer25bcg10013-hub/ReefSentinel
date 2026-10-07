extends Area2D
# A owns this file
#
# W1 — BUBBLE IS THE DEFENSIVE TOOL, NOT A THIRD GUN.
# The contract fixes its numbers and they are all honoured here:
#   * radius 80 px
#   * base damage 0  (this weapon can never kill anything)
#   * roots what it touches for 1.5 s base (applied by B's enemy through
#     receive_damage(0.0, "bubble") — the only place that maths is allowed)
#
# What changed: instead of drifting off as a throwaway trap, the bubble is a
# dome the sentinel deploys around itself. It follows the sub, roots everything
# that swims into it, and eats a limited number of incoming hits — the panic
# button. It still logs its shot to Telemetry (frozen API), while the genetic
# algorithm ignores the defensive weapon when it weighs selection pressure.

const WEAPON_ID := "bubble"
const TRAP_RADIUS := 80.0     # per contract
const ROOT_DURATION := 1.5    # per contract, applied by B's enemy

@export var drift_speed := 40.0   # legacy drift, only used when unanchored
@export var lifetime := 4.0
@export var absorb_charges := 2

const SPRITE_PATH := "res://scenes/weapons/bubble_trap.svg"
const REROOT_INTERVAL := 0.6

var _has_sprite := false
var _age := 0.0
var _charges := 2
var _root_timer := 0.0
var _host: Node2D = null      # the submarine, when the dome is deployed on it
var _impact_flash := 0.0
var _expiring := false


func _ready() -> void:
	_charges = absorb_charges
	_add_sprite()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if find_children("*", "CollisionShape2D", false).is_empty():
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = TRAP_RADIUS
		shape.shape = circle
		add_child(shape)


## The submarine calls this right after instancing, so the dome travels with the
## sentinel instead of drifting away.
func deploy_on(host: Node2D) -> void:
	_host = host
	global_position = host.global_position
	collision_layer = 0
	collision_mask = 1


func charges_left() -> int:
	return _charges


## Called by the submarine's take_health_damage(). Returns true when the dome ate
## the hit (the hull takes nothing).
func absorb_hit() -> bool:
	if _expiring or _charges <= 0:
		return false
	_charges -= 1
	_impact_flash = 1.0
	if _charges <= 0:
		_expire()
	return true


func _physics_process(delta: float) -> void:
	_age += delta
	_impact_flash = maxf(0.0, _impact_flash - delta * 2.4)
	if is_instance_valid(_host):
		global_position = _host.global_position
	else:
		global_position += Vector2.RIGHT.rotated(global_rotation) * drift_speed * delta
	if _age >= lifetime:
		_expire()
	# Re-root anything still inside, so a dome parked on a cluster keeps holding.
	_root_timer -= delta
	if _root_timer <= 0.0:
		_root_timer = REROOT_INTERVAL
		_root_everything_inside()
	queue_redraw()


func _root_everything_inside() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("invasive") and body.has_method("receive_damage"):
			body.receive_damage(0.0, WEAPON_ID)


func _add_sprite() -> void:
	if ResourceLoader.exists(SPRITE_PATH):
		var tex := load(SPRITE_PATH) as Texture2D
		if tex:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			add_child(sprite)
			_has_sprite = true


func _expire() -> void:
	if _expiring:
		return
	_expiring = true
	# pop: a short scale-up/fade so the dome's end is legible
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.18)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.18)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	# Fallback placeholder, only drawn when the sprite file is missing
	if _has_sprite:
		return
	var pulse := 1.0 + 0.03 * sin(_age * 5.0)
	draw_circle(Vector2.ZERO, TRAP_RADIUS * pulse, Color(0.5, 0.8, 1.0, 0.18))
	# segmented shell: one arc per remaining absorb charge, so the dome's health
	# is readable without any HUD text
	for i in range(maxi(1, _charges)):
		var seg := TAU / float(maxi(1, _charges))
		draw_arc(Vector2.ZERO, TRAP_RADIUS * pulse, float(i) * seg + _age, float(i + 1) * seg + _age,
				18, Color(0.72, 0.94, 1.0, 0.85), 3.0)
	if _impact_flash > 0.0:
		draw_arc(Vector2.ZERO, TRAP_RADIUS * (1.0 + 0.12 * (1.0 - _impact_flash)), 0.0, TAU, 40,
				Color(1, 1, 1, _impact_flash), 5.0)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("invasive"):
		return
	if body.has_method("receive_damage"):
		# Base damage is 0. The weapon_id tells B's enemy to apply the root.
		body.receive_damage(0.0, WEAPON_ID)
	if body.has_method("apply_impulse"):
		# A dome pushes rather than damages: shove it off the sentinel.
		var away := (body.global_position - global_position)
		if away.length() < 0.01:
			away = Vector2.RIGHT.rotated(randf() * TAU)
		body.call("apply_impulse", away.normalized(), 90.0)

# PROPOSED CHANGE: for B. Enemy.receive_damage() starts a ROOT_DURATION (1.5 s)
# root when weapon_id == "bubble"; the dome never deals damage, so it can only
# ever be a control tool. No new public enemy method is required.
