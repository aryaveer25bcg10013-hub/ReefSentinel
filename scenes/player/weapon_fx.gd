extends Node
## Shared weapon feedback layer (W1), owned by the submarine.
##
## Any weapon can ask for feedback without knowing about the camera or the sub:
##   var fx := get_tree().get_first_node_in_group("weapon_fx")
##   if fx != null:
##       fx.call("shake", 4.0)
##       fx.call("hitstop")
##
## Hitstop uses Engine.time_scale, which is process-global — so the restore timer
## is parented to the tree ROOT, ignores the time scale and runs even if this
## node (or the whole level) is freed mid-freeze. A stuck slow-motion game is a
## far worse bug than a missed hitstop.

# Shake decays exponentially plus a constant tail, so a small tap settles fast
# and a kill punch still reads as one hit rather than a permanent wobble.
const SHAKE_EXP_DECAY := 7.0
const SHAKE_LINEAR_DECAY := 14.0

var _camera: Camera2D = null
var _shake := 0.0
var _freeze_active := false


func _ready() -> void:
	add_to_group("weapon_fx")


func bind_camera(camera: Camera2D) -> void:
	_camera = camera


## Radial camera shake. `amount` is in pixels at full strength.
func shake(amount: float, _duration: float = 0.18) -> void:
	_shake = maxf(_shake, amount)


## Brief freeze-frame on a kill. Nested calls are ignored while one is running.
func hitstop(scale: float = 0.35, duration: float = 0.055) -> void:
	if _freeze_active or Engine.time_scale != 1.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	_freeze_active = true
	Engine.time_scale = scale
	var timer := Timer.new()
	timer.name = "HitstopRestore"
	timer.one_shot = true
	timer.wait_time = duration
	timer.ignore_time_scale = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(timer)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_freeze_active = false
		timer.queue_free())
	timer.start()


func screen_flash(_strength: float = 1.0) -> void:
	# Screen-level flash is owned by the HUD's vignette; kept as a hook so weapons
	# have one place to ask for impact feedback.
	pass


func _process(delta: float) -> void:
	# The level attaches the camera after the submarine is built, so bind lazily.
	if _camera == null:
		var parent := get_parent()
		if parent != null:
			_camera = parent.get_node_or_null("Camera2D") as Camera2D
	if _shake <= 0.0005:
		if _camera != null:
			_camera.offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - (_shake * SHAKE_EXP_DECAY + SHAKE_LINEAR_DECAY) * delta)
	if _camera != null:
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
