extends StaticBody2D

var hp := 100.0
var _taken := {}
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("invasive")
	z_index = 10
	print("DUMMY ready at ", global_position, "  groups: ", get_groups())


func _draw() -> void:
	var col := Color.WHITE if _flash > 0.0 else Color.RED
	draw_circle(Vector2.ZERO, 40.0, col)
	draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 32, Color.BLACK, 3.0)


func receive_damage(amount: float, weapon_id: String) -> void:
	if weapon_id != "thermal":
		print("HIT by ", weapon_id, " amount ", amount)
	_flash = 0.1
	hp -= amount
	_taken[weapon_id] = _taken.get(weapon_id, 0.0) + amount
	if hp <= 0.0:
		hp = 100.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	queue_redraw()
	if _taken.is_empty():
		_t = 0.0
		return
	_t += delta
	if _t >= 1.0:
		print("damage last second: ", _taken, "  hp=", snappedf(hp, 0.1))
		_taken.clear()
		_t = 0.0
