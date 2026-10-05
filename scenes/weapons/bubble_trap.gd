extends Area2D
# A owns this file

const WEAPON_ID := "bubble"
const TRAP_RADIUS := 80.0 # per contract
const ROOT_DURATION := 1.5 # per contract, applied by B's enemy

@export var drift_speed := 40.0
@export var lifetime := 8.0

const SPRITE_PATH := "res://scenes/weapons/bubble_trap.svg"

var _has_sprite := false
var _age := 0.0
var _triggered := false


func _ready() -> void:
	_add_sprite()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if find_children("*", "CollisionShape2D", false).is_empty():
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = TRAP_RADIUS
		shape.shape = circle
		add_child(shape)


func _physics_process(delta: float) -> void:
	global_position += Vector2.RIGHT.rotated(global_rotation) * drift_speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _add_sprite() -> void:
	if ResourceLoader.exists(SPRITE_PATH):
		var tex := load(SPRITE_PATH) as Texture2D
		if tex:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			add_child(sprite)
			_has_sprite = true


func _draw() -> void:
	# Fallback placeholder, only drawn when the sprite file is missing
	if _has_sprite:
		return
	draw_circle(Vector2.ZERO, TRAP_RADIUS, Color(0.5, 0.8, 1.0, 0.25))
	draw_arc(Vector2.ZERO, TRAP_RADIUS, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, 0.8), 2.0)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("invasive"):
		return
	_triggered = true
	var targets := get_overlapping_bodies()
	if not targets.has(body):
		targets.append(body)
	for target in targets:
		if target.is_in_group("invasive") and target.has_method("receive_damage"):
			# Base damage is 0. The weapon_id tells B's enemy to apply the root.
			target.receive_damage(0.0, WEAPON_ID)
	queue_free()

# PROPOSED CHANGE: for B. Enemy.receive_damage() should start a ROOT_DURATION
# (1.5 s) root when weapon_id == "bubble". No new public method is needed.
