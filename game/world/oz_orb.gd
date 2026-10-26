class_name OzOrb
extends Area2D

var value := 1
var launch := Vector2.ZERO
var _v := Vector2.ZERO
var _t := 0.0
var _base := Vector2.ZERO
var _sprite: Sprite2D
var _glow: Sprite2D
var _taken := false
var _settled := false

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 8
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 26.0 if value == 1 else 36.0
	cs.shape = c
	add_child(cs)
	_glow = Sprite2D.new()
	_glow.texture = Fx.soft_tex
	_glow.modulate = Color(0.55, 0.35, 1.0, 0.55)
	_glow.scale = Vector2(0.9, 0.9) * (1.0 if value == 1 else 1.5)
	add_child(_glow)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/props/oz_orb.png")
	var k := (46.0 if value == 1 else 70.0) / _sprite.texture.get_height()
	_sprite.scale = Vector2(k, k)
	add_child(_sprite)
	_v = launch
	_settled = launch == Vector2.ZERO
	_base = global_position
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	_t += delta
	if not _settled:
		_v.y += 2000.0 * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + _v * delta + Vector2(0, 20), 1 | 64)
		var r := get_world_2d().direct_space_state.intersect_ray(q)
		if not r.is_empty() and _v.y > 0.0:
			global_position = r.position - Vector2(0, 30)
			_settled = true
			_base = global_position
		else:
			global_position += _v * delta
	else:
		_sprite.position.y = sin(_t * 3.0) * 6.0
	_glow.scale = Vector2.ONE * (0.85 + sin(_t * 5.0) * 0.08) * (1.0 if value == 1 else 1.5)
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Creature and c.team == 0 and c.alive:
			var d: Vector2 = c.center() - global_position
			if d.length() < 150.0 and _settled:
				global_position += d.normalized() * minf(d.length(), 520.0 * delta)

func _on_body(b: Node) -> void:
	if _taken or not (b is Creature) or b.team != 0:
		return
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl != null and lvl.has_method("collect_oz") and not lvl.collect_oz(value, global_position):
		return
	_taken = true
	Fx.burst(global_position, "pickup", Color(0.7, 0.5, 1.0), 16)
	Audio.play("bonus", -6.0, 0.15)
	queue_free()
