extends Area2D
# A owns this file
#
# W1 — the reliable always-there gun. Numbers are frozen: 10 damage, 0.25 s
# cooldown (the cooldown lives on the submarine). What is new here is impact:
# a wake trail behind the shot, a knockback impulse on the target, impact sparks
# from B's enemy, and a shake + hitstop when the hit actually kills.

const WEAPON_ID := "sonic"

@export var speed := 800.0
@export var damage := 10.0 # base damage, per contract
@export var lifetime := 2.0
@export var knockback := 130.0

const SPRITE_PATH := "res://scenes/weapons/sonic_pulse.svg"
const TRAIL_POINTS := 7

var _has_sprite := false
var _age := 0.0
var _spent := false
var _trail: Array[Vector2] = []


func _ready() -> void:
	_add_sprite()
	z_index = 20
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if find_children("*", "CollisionShape2D", false).is_empty():
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var step := Vector2.RIGHT.rotated(global_rotation) * speed * delta
	global_position += step
	_age += delta
	# wake: sample local positions so the trail renders in this node's space
	_trail.push_back(-step)
	if _trail.size() > TRAIL_POINTS:
		_trail.pop_front()
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _add_sprite() -> void:
	if ResourceLoader.exists(SPRITE_PATH):
		var tex := load(SPRITE_PATH) as Texture2D
		if tex:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			add_child(sprite)
			_has_sprite = true


func _draw() -> void:
	# trailing wake, drawn behind the sprite
	var count := _trail.size()
	for i in count:
		var t := float(i + 1) / float(TRAIL_POINTS)
		var p := Vector2.ZERO
		for j in range(i, count):
			p += _trail[j]
		var fade := t * 0.55
		draw_circle(p / float(count - i), 5.0 * t + 1.0, Color(0.55, 0.9, 1.0, fade))
	if not _has_sprite:
		# Fallback placeholder, only drawn when the sprite file is missing
		draw_circle(Vector2.ZERO, 6.0, Color.CYAN)


func _on_body_entered(body: Node2D) -> void:
	if _spent or body.is_in_group("player"):
		return
	if not body.is_in_group("invasive"):
		return
	_spent = true
	var dir := Vector2.RIGHT.rotated(global_rotation)
	if body.has_method("receive_damage"):
		body.receive_damage(damage, WEAPON_ID)
	var killed := body.has_method("is_dead") and bool(body.call("is_dead"))
	if body.has_method("apply_impulse"):
		body.call("apply_impulse", dir, knockback)
	var fx := get_tree().get_first_node_in_group("weapon_fx")
	if fx != null:
		if killed:
			fx.call("shake", 5.5)
			fx.call("hitstop", 0.35, 0.055)
		else:
			fx.call("shake", 1.6)
	queue_free()
