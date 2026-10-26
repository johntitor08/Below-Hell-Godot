class_name GameCamera
extends Camera2D

var target: Node2D
var look_ahead := 140.0
var _shake := 0.0
var _shake_t := 0.0
var _ahead := 0.0
var bounds := Rect2()

func _ready() -> void:
	add_to_group("game_camera")
	position_smoothing_enabled = false
	make_current()

func add_shake(a: float, d: float) -> void:
	_shake = maxf(_shake, a)
	_shake_t = maxf(_shake_t, d)

func snap() -> void:
	if target != null:
		global_position = _goal()

func _goal() -> Vector2:
	var p := target.global_position + Vector2(_ahead, -90.0)
	if bounds.size != Vector2.ZERO:
		var half := get_viewport_rect().size * 0.5 / zoom
		p.x = clampf(p.x, bounds.position.x + half.x, maxf(bounds.position.x + half.x, bounds.end.x - half.x))
		p.y = clampf(p.y, bounds.position.y + half.y, maxf(bounds.position.y + half.y, bounds.end.y - half.y))
	return p

func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var f := 0.0
		if target is Creature:
			f = target.facing
			if absf(target.velocity.x) < 30.0:
				f *= 0.4
		_ahead = lerpf(_ahead, f * look_ahead, minf(1.0, delta * 2.0))
		global_position = global_position.lerp(_goal(), minf(1.0, delta * 6.0))
	if _shake_t > 0.0:
		_shake_t -= delta
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, delta * _shake * 4.0)
	else:
		offset = Vector2.ZERO
