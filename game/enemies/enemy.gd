class_name Enemy
extends CharacterBody2D

signal defeated(e: Enemy)

const GRAVITY := 2600.0
const KINDS := {
	"imp": {"tex": "res://assets/props/imp.png", "h": 70.0, "hp": 22, "speed": 170.0, "chase": 300.0, "dmg": 8, "drop": 1, "armor": 1.0, "fly": false, "sight": 520.0},
	"skeleton": {"tex": "res://assets/props/skeleton.png", "h": 110.0, "hp": 46, "speed": 110.0, "chase": 210.0, "dmg": 14, "drop": 2, "armor": 0.5, "fly": false, "sight": 460.0},
	"wraith": {"tex": "res://assets/props/wraith.png", "h": 96.0, "hp": 28, "speed": 120.0, "chase": 250.0, "dmg": 10, "drop": 2, "armor": 1.0, "fly": true, "sight": 600.0},
	"boss": {"tex": "res://assets/props/imp.png", "h": 240.0, "hp": 340, "speed": 160.0, "chase": 260.0, "dmg": 18, "drop": 0, "armor": 1.0, "fly": false, "sight": 2000.0},
}

var kind := "imp"
var cfg: Dictionary
var hp := 10
var max_hp := 10
var dir := -1
var alive := true
var stunned_until := 0.0
var carried := false
var home := Vector2.ZERO
var _knock := Vector2.ZERO
var _contact_cd := 0.0
var _attack_t := 0.0
var _time := 0.0
var _hurt := 0.0
var _phase := 0
var _boss_t := 2.0
var target: Creature
var visual: Node2D
var sprite: Sprite2D
var bar: ProgressBar

func setup(k: String) -> Enemy:
	kind = k
	return self

func _ready() -> void:
	cfg = KINDS.get(kind, KINDS["imp"])
	max_hp = int(cfg.hp)
	hp = max_hp
	home = global_position
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 0 if cfg.fly else (1 | 64 | 128)
	var h: float = cfg.h
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(h * 0.6, h * 0.8)
	cs.shape = r
	cs.position = Vector2(0, -r.size.y * 0.5)
	add_child(cs)
	visual = Node2D.new()
	add_child(visual)
	sprite = Sprite2D.new()
	sprite.texture = load(cfg.tex)
	var k: float = h / sprite.texture.get_height()
	sprite.scale = Vector2(k, k)
	sprite.position = Vector2(0, -h * 0.5)
	var m := ShaderMaterial.new()
	m.shader = load("res://game/core/flash.gdshader")
	if kind == "boss":
		m.set_shader_parameter("tint", Color(1.0, 0.55, 0.5))
	sprite.material = m
	visual.add_child(sprite)
	if kind == "boss":
		dir = -1

func center() -> Vector2:
	return global_position + Vector2(0, -float(cfg.h) * 0.45)

func _find_target() -> void:
	target = null
	var best: float = cfg.sight
	for c in get_tree().get_nodes_in_group("creatures"):
		if not (c is Creature) or not c.alive or c.team != 0 or c.stealth:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d < best and (cfg.fly or _visible(c)):
			best = d
			target = c

func _visible(c: Creature) -> bool:
	var q := PhysicsRayQueryParameters2D.create(center(), c.center(), 1 | 128)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(delta: float) -> void:
	_time += delta
	_contact_cd -= delta
	_hurt = maxf(0.0, _hurt - delta * 4.0)
	if not alive or carried:
		_animate(delta)
		return
	var stunned := Time.get_ticks_msec() / 1000.0 < stunned_until
	if int(_time * 4.0) % 2 == 0:
		_find_target()
	if stunned:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	elif kind == "boss":
		_boss(delta)
	elif cfg.fly:
		_fly(delta)
	else:
		_walk(delta)
	if not cfg.fly:
		velocity.y = minf(velocity.y + GRAVITY * delta, 1500.0)
	velocity += _knock
	_knock = _knock.move_toward(Vector2.ZERO, 2600.0 * delta)
	move_and_slide()
	if not stunned:
		_contact()
	_animate(delta)

func _walk(delta: float) -> void:
	var sp: float = cfg.speed
	if target != null:
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 20.0:
			dir = 1 if dx > 0.0 else -1
		sp = cfg.chase
		if kind == "skeleton" and absf(dx) < 110.0 and absf(target.global_position.y - global_position.y) < 90.0:
			_attack_t += delta
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			if _attack_t > 0.55:
				_attack_t = -0.6
				_lunge()
			return
	else:
		_attack_t = 0.0
		if is_on_floor() and (is_on_wall() or not _ground_ahead()):
			dir = -dir
	if is_on_floor() and target != null and is_on_wall() and kind == "imp":
		velocity.y = -820.0
	velocity.x = move_toward(velocity.x, dir * sp, 1600.0 * delta)

func _ground_ahead() -> bool:
	var p := global_position + Vector2(dir * float(cfg.h) * 0.45, -6)
	var q := PhysicsRayQueryParameters2D.create(p, p + Vector2(0, 50), 1 | 64 | 128)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _lunge() -> void:
	velocity.x = dir * 520.0
	velocity.y = -260.0
	if target != null and target.center().distance_to(center()) < 150.0:
		target.take_hit(int(cfg.dmg), global_position, Vector2(dir * 620.0, -380.0), self)
	Audio.play("whoosh", -6.0)

func _fly(delta: float) -> void:
	var goal := home + Vector2(sin(_time * 0.8) * 120.0, sin(_time * 1.6) * 30.0)
	var sp: float = cfg.speed
	if target != null:
		goal = target.center() + Vector2(0, -20)
		sp = cfg.chase
	var d := goal - center()
	velocity = velocity.move_toward(d.normalized() * minf(sp, d.length() * 3.0), 900.0 * delta)
	if absf(d.x) > 10.0:
		dir = 1 if d.x > 0.0 else -1

func _contact() -> void:
	if _contact_cd > 0.0:
		return
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Creature and c.alive and c.team == 0 and not c.stealth:
			var d: Vector2 = c.center() - center()
			var reach: float = float(cfg.h) * 0.42 + c.body_width() * 0.45
			if absf(d.x) < reach and absf(d.y) < float(cfg.h) * 0.45 + c.body_height() * 0.45:
				c.take_hit(int(cfg.dmg), global_position, Vector2(560.0, -420.0), self)
				_contact_cd = 0.8

func _boss(delta: float) -> void:
	var ratio := float(hp) / float(max_hp)
	_phase = 0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)
	_boss_t -= delta
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		return
	var dx := target.global_position.x - global_position.x
	if _boss_t > 0.0:
		dir = 1 if dx > 0.0 else -1
		velocity.x = move_toward(velocity.x, dir * float(cfg.speed) * (1.0 + _phase * 0.3), 1200.0 * delta)
		return
	var roll := randi() % (2 + _phase)
	match roll:
		0:
			velocity = Vector2(dir * 900.0, -500.0)
			Fx.shake(6.0, 0.2)
			Audio.play("grunt1", 0.0)
			_boss_t = 1.6 - _phase * 0.3
		1:
			for i in 3 + _phase * 2:
				var a := -PI * 0.5 + (i - (1 + _phase)) * 0.28
				_shoot(Vector2(cos(a), sin(a)) * 520.0 + Vector2(dir * 140.0, 0))
			Audio.play("shot", -2.0)
			_boss_t = 1.8 - _phase * 0.3
		_:
			for i in 2:
				var e := Enemy.new().setup("imp")
				e.global_position = global_position + Vector2((i * 2 - 1) * 140.0, -40)
				get_parent().add_child(e)
			Fx.burst(center(), "transform", Color(1, 0.4, 0.3), 30)
			Audio.play("spawn", 0.0)
			_boss_t = 2.6

func _shoot(v: Vector2) -> void:
	var p := Projectile.new()
	p.velocity = v
	p.damage = 12
	p.grav = 900.0
	p.global_position = center()
	get_parent().add_child(p)

func take_hit(dmg: int, from: Vector2, knock: Vector2, _source = null) -> void:
	if not alive:
		return
	dmg = maxi(1, int(round(dmg * float(cfg.armor))))
	hp -= dmg
	_hurt = 1.0
	if kind != "boss":
		_knock = Vector2(signf(global_position.x - from.x) * absf(knock.x), knock.y) * 0.7
	Fx.flash(sprite)
	Fx.popup(center() + Vector2(0, -float(cfg.h) * 0.5), str(dmg), Color(1, 0.95, 0.6))
	Fx.burst(center(), "hit", Color(1, 0.85, 0.5), 10)
	Audio.play("hit", -6.0)
	if hp <= 0:
		_die()

func poison(dmg: int, ticks: int) -> void:
	for i in ticks:
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(self) or not alive:
			return
		hp -= dmg
		Fx.popup(center() + Vector2(0, -float(cfg.h) * 0.5), str(dmg), Color(0.6, 1, 0.4), 26)
		Fx.flash(sprite, Color(0.5, 1, 0.4))
		if hp <= 0:
			_die()
			return

func stun(sec: float) -> void:
	stunned_until = Time.get_ticks_msec() / 1000.0 + sec

func knockback(v: Vector2) -> void:
	if kind != "boss":
		_knock = v

func set_carried(v: bool) -> void:
	carried = v
	collision_mask = 0 if v else (0 if cfg.fly else (1 | 64 | 128))

func _die() -> void:
	alive = false
	Fx.burst(center(), "death", Color(0.9, 0.3, 0.25), 30)
	Fx.shake(5.0 if kind != "boss" else 20.0, 0.3)
	Audio.play("explosion" if kind == "boss" else "grunt1", -4.0)
	for i in int(cfg.drop):
		var o := OzOrb.new()
		o.global_position = center() + Vector2(randf_range(-20, 20), -10)
		o.launch = Vector2(randf_range(-260, 260), randf_range(-620, -420))
		get_parent().call_deferred("add_child", o)
	defeated.emit(self)
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)

func _animate(delta: float) -> void:
	var sx := 1.0
	var sy := 1.0
	var off := Vector2.ZERO
	var rot := 0.0
	if cfg.fly:
		off.y = sin(_time * 4.0) * 6.0
		rot = velocity.x / 2000.0
	elif absf(velocity.x) > 10.0 and is_on_floor():
		off.y = -absf(sin(_time * 12.0)) * 5.0
		rot = sin(_time * 12.0) * 0.05
	else:
		var b := sin(_time * 2.6)
		sy += b * 0.03
		sx -= b * 0.02
	if _attack_t > 0.0:
		sy -= _attack_t * 0.18
		sx += _attack_t * 0.12
	if _hurt > 0.0:
		off.x += sin(_time * 60.0) * 4.0 * _hurt
	if Time.get_ticks_msec() / 1000.0 < stunned_until:
		rot = sin(_time * 20.0) * 0.1
	visual.position = off
	visual.rotation = lerp_angle(visual.rotation, rot, minf(1.0, delta * 10.0))
	visual.scale = Vector2(sx * (1.0 if dir > 0 else -1.0), sy)
