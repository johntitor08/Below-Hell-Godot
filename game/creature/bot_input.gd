class_name BotInput
extends RefCounted

var target: Creature
var level := 1.0
var _think := 0.0
var _move := 0.0
var _jump_t := 0.0
var _rng := RandomNumberGenerator.new()

func poll(c: Creature, i: CreatureInput) -> void:
	var dt := c.get_physics_process_delta_time()
	_think -= dt
	if target == null or not is_instance_valid(target) or not target.alive:
		i.move = Vector2.ZERO
		return
	var d := target.global_position - c.global_position
	if _think <= 0.0:
		_think = _rng.randf_range(0.12, 0.3) / level
		var keep := 70.0 + c.body_width()
		_move = signf(d.x) if absf(d.x) > keep else (-signf(d.x) * 0.5 if absf(d.x) < keep * 0.5 else 0.0)
		if _rng.randf() < 0.12:
			_move = -_move
	i.move = Vector2(_move, 0.0)
	if c.flying:
		i.move.y = clampf(d.y / 120.0, -1.0, 1.0)
	_jump_t -= dt
	if (d.y < -90.0 or c.is_on_wall()) and _jump_t <= 0.0 and not c.flying:
		i.jump = true
		i.jump_held = true
		_jump_t = 0.6
	else:
		i.jump_held = _jump_t > 0.3
	if absf(d.x) < c.body_width() + 80.0 and absf(d.y) < 110.0:
		c.facing = 1 if d.x > 0.0 else -1
		if _rng.randf() < 0.18 * level:
			i.attack = true
	if _rng.randf() < 0.015 * level:
		i.ability = true
		i.ability_held = true
	elif _rng.randf() < 0.3:
		i.ability_held = false
