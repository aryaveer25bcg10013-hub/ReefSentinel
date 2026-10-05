extends Area2D
# A owns this file

const WEAPON_ID := "sonic"

@export var speed := 800.0
@export var damage := 10.0 # base damage, per contract
@export var lifetime := 2.0

const SPRITE_PATH := "res://scenes/weapons/sonic_pulse.svg"

var _has_sprite := false
var _age := 0.0
var _spent := false


func _ready() -> void:
	_add_sprite()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if find_children("*", "CollisionShape2D", false).is_empty():
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)


func _physics_process(delta: float) -> void:
	global_position += Vector2.RIGHT.rotated(global_rotation) * speed * delta
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
	draw_circle(Vector2.ZERO, 6.0, Color.CYAN)


func _on_body_entered(body: Node2D) -> void:
	if _spent or body.is_in_group("player"):
		return
	if body.is_in_group("invasive") and body.has_method("receive_damage"):
		body.receive_damage(damage, WEAPON_ID)
	_spent = true
	queue_free()
