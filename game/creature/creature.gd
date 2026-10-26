class_name Creature
extends CharacterBody2D

signal hp_changed(hp: int, max_hp: int)
signal died(c: Creature)
signal form_changed(def: CreatureDef)
signal hit_landed(target: Node, damage: int)

const GRAVITY := 2600.0
const FALL_MULT := 1.55
const LOW_JUMP_MULT := 2.4
const COYOTE := 0.1
const BUFFER := 0.12
const ACCEL := 4200.0
const DECEL := 5200.0
const AIR_CONTROL := 0.75
const MAX_FALL := 1500.0

const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_ONEWAY := 64
const L_BREAK := 128

var def: CreatureDef
var input := CreatureInput.new()
var input_source = null
var team := 0
var facing := 1
var hp := 10
var max_hp := 10
var alive := true
var controls_enabled := true
var invulnerable_until := 0.0
var in_water := false
var on_wall := 0
var climbing := false
var flying := false
var extra_jumps := 0
var extra_jumps_used := 0
var damage_mult := 1.0
var speed_mult := 1.0
var stealth := false
var stunned_until := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := false
var _attack_cd := 0.0
var _attack_anim := 0.0
var _hurt_anim := 0.0
var _land_squash := 0.0
var _time := 0.0
var _knock := Vector2.ZERO
var _last_damage_from := Vector2.ZERO
var abilities: Array = []

var visual: Node2D
var sprite: Sprite2D
var shape: CollisionShape2D
var shadow: Sprite2D

func _ready() -> void:
	floor_snap_length = 10.0
	floor_max_angle = deg_to_rad(50.0)
	collision_layer = L_PLAYER if team == 0 else L_ENEMY
	collision_mask = L_WORLD | L_ONEWAY | L_BREAK
	add_to_group("creatures")
	if visual == null:
		_build()
	if def == null:
		set_form(Creatures.fallback())

func _build() -> void:
	shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	add_child(shape)
	shadow = Sprite2D.new()
	shadow.texture = Fx.soft_tex
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.z_index = -1
	add_child(shadow)
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	sprite = Sprite2D.new()
	sprite.centered = true
	var m := ShaderMaterial.new()
	m.shader = load("res://game/core/flash.gdshader")
	sprite.material = m
	visual.add_child(sprite)

func set_form(d: CreatureDef, keep_hp_ratio := false) -> void:
	if visual == null:
		_build()
	var ratio := float(hp) / float(max_hp) if keep_hp_ratio and max_hp > 0 else 1.0
	def = d
	max_hp = d.max_hp()
	hp = clampi(int(ceil(max_hp * ratio)), 1, max_hp)
	flying = d.flight
	extra_jumps = 1 if d.has("double_jump") else 0
	sprite.texture = d.texture
	var h := d.height_px()
	var tex_h := float(d.texture.get_height())
	var k := h / tex_h
	sprite.scale = Vector2(k, k)
	sprite.position = Vector2(0, -h * 0.5)
	var ch := h * 0.74
	var cw := minf(ch * 0.95, float(d.texture.get_width()) * k * 0.62)
	if d.flight:
		ch = h * 0.6
		cw = minf(ch * 1.1, float(d.texture.get_width()) * k * 0.6)
	(shape.shape as RectangleShape2D).size = Vector2(cw, ch)
	shape.position = Vector2(0, -ch * 0.5)
	shadow.scale = Vector2(cw / 160.0, 0.08)
	shadow.position = Vector2(0, 2)
	_rebuild_abilities()
	hp_changed.emit(hp, max_hp)
	form_changed.emit(d)

func _rebuild_abilities() -> void:
	for a in abilities:
		if is_instance_valid(a):
			a.on_removed()
			a.queue_free()
	abilities.clear()
	stealth = false
	damage_mult = 1.0
	speed_mult = 1.0
	for id in def.abilities:
		var a = Abilities.create(id)
		if a != null:
			a.creature = self
			a.name = "ab_" + id
			add_child(a)
			abilities.append(a)
			a.on_added()

func body_height() -> float:
	return (shape.shape as RectangleShape2D).size.y

func body_width() -> float:
	return (shape.shape as RectangleShape2D).size.x

func center() -> Vector2:
	return global_position + Vector2(0, -body_height() * 0.5)

func _physics_process(delta: float) -> void:
	_time += delta
	if input_source != null and controls_enabled and alive:
		input_source.poll(self, input)
	elif not controls_enabled or not alive:
		input.move = Vector2.ZERO
		input.jump_held = false
		input.ability_held = false
		input.clear_edges()
	if Time.get_ticks_msec() / 1000.0 < stunned_until:
		input.move = Vector2.ZERO
		input.clear_edges()
	_move(delta)
	_combat(delta)
	for a in abilities:
		if is_instance_valid(a):
			a.physics(delta)
	_animate(delta)
	input.clear_edges()

func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and velocity.y >= -1.0 and _time > 0.2:
		_land_squash = clampf(_last_fall_speed / 1400.0, 0.15, 0.6)
		if _last_fall_speed > 700.0:
			Fx.burst(global_position, "dust", Color(0.85, 0.8, 0.7, 0.9), 12)
			Audio.play("land", -8.0)
		extra_jumps_used = 0
	_was_on_floor = on_floor
	if on_floor:
		_coyote = COYOTE
		extra_jumps_used = 0
	else:
		_coyote -= delta
	if input.jump:
		_buffer = BUFFER
	else:
		_buffer -= delta
	var x := input.move.x
	if absf(x) > 0.2:
		facing = 1 if x > 0.0 else -1
	var target := x * def.run_speed() * speed_mult
	if in_water and def.has("underwater_speed_9"):
		target *= 1.6
	var rate := (ACCEL if absf(x) > 0.05 else DECEL) * (1.0 if on_floor else AIR_CONTROL)
	velocity.x = move_toward(velocity.x, target, rate * delta)
	climbing = false
	on_wall = 0
	if is_on_wall():
		on_wall = -1 if get_wall_normal().x > 0.0 else 1
	if flying:
		_fly(delta)
	elif in_water:
		_swim(delta)
	else:
		if def.has("wall_climb") and on_wall != 0 and signf(x) == on_wall:
			climbing = true
			velocity.y = -input.move.y * 260.0 if absf(input.move.y) > 0.2 else move_toward(velocity.y, -90.0 if x != 0.0 else 0.0, 3000.0 * delta)
			if input.move.y > 0.2:
				velocity.y = 260.0
			if _buffer > 0.0:
				_buffer = 0.0
				velocity.y = -def.jump_velocity(GRAVITY) * 0.85
				velocity.x = -on_wall * 420.0
		else:
			var g := GRAVITY
			if velocity.y > 0.0:
				g *= FALL_MULT
			elif not input.jump_held:
				g *= LOW_JUMP_MULT
			velocity.y = minf(velocity.y + g * delta, MAX_FALL)
			if _buffer > 0.0 and def.jump > 0:
				if _coyote > 0.0:
					_do_jump(1.0)
				elif extra_jumps_used < extra_jumps:
					extra_jumps_used += 1
					_do_jump(0.85)
					Fx.burst(global_position, "dust", Color(1, 1, 1, 0.7), 8)
	velocity += _knock
	_knock = _knock.move_toward(Vector2.ZERO, 3000.0 * delta)
	if velocity.y > 0.0:
		_last_fall_speed = velocity.y
	if input.move.y > 0.5 and input.jump and on_floor:
		position.y += 2.0
		set_collision_mask_value(7, false)
		var restore := func(): set_collision_mask_value(7, true)
		get_tree().create_timer(0.25).timeout.connect(restore)
	move_and_slide()

var _last_fall_speed := 0.0

func _do_jump(mult: float) -> void:
	_buffer = 0.0
	_coyote = 0.0
	velocity.y = -def.jump_velocity(GRAVITY) * mult
	_land_squash = -0.35
	Audio.play("whoosh", -14.0, 0.2)

func _fly(delta: float) -> void:
	var y := input.move.y
	if input.jump_held:
		y = -1.0
	var target_y := y * def.run_speed() * 0.85 * speed_mult
	if absf(y) < 0.1:
		target_y = sin(_time * 3.0) * 30.0
	velocity.y = move_toward(velocity.y, target_y, 3200.0 * delta)

func _swim(delta: float) -> void:
	var breathe := def.has("water_breathing") or def.has("underwater_speed_9") or def.has("squeeze_through_pipes")
	var y := input.move.y
	if input.jump_held:
		y = -1.0
	var sp := 260.0 if breathe else 170.0
	if def.has("underwater_speed_9"):
		sp = 480.0
	velocity.y = move_toward(velocity.y, y * sp + 60.0, 1400.0 * delta)
	if _buffer > 0.0 and not breathe and y < 0.0:
		_buffer = 0.0
		velocity.y = -def.jump_velocity(GRAVITY) * 0.6

func _combat(delta: float) -> void:
	_attack_cd -= delta
	_attack_anim = maxf(0.0, _attack_anim - delta * 4.0)
	_hurt_anim = maxf(0.0, _hurt_anim - delta * 4.0)
	if input.attack and _attack_cd <= 0.0 and alive:
		attack()

func attack() -> void:
	_attack_cd = 0.38
	_attack_anim = 1.0
	var reach := maxf(body_width() * 0.9, 56.0)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = (L_ENEMY if team == 0 else L_PLAYER) | L_BREAK | L_PLAYER | L_ENEMY
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(reach, body_height() * 0.9)
	cs.shape = r
	cs.position = Vector2(facing * (body_width() * 0.5 + reach * 0.4), -body_height() * 0.5)
	area.add_child(cs)
	add_child(area)
	Audio.play("whoosh", -10.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(area):
		return
	var hit_any := false
	for b in area.get_overlapping_bodies():
		if b == self:
			continue
		if b.has_method("take_hit") and _is_foe(b):
			var dmg := int(round(def.hit_damage() * damage_mult))
			b.take_hit(dmg, global_position, Vector2(facing * 520.0, -320.0), self)
			hit_landed.emit(b, dmg)
			hit_any = true
	if hit_any:
		Fx.hitstop(0.05)
		Fx.shake(5.0, 0.15)
	area.queue_free()

func _is_foe(b) -> bool:
	if b is Creature:
		return b.team != team
	return team == 0 or b.is_in_group("breakable")

func take_hit(dmg: int, from: Vector2, knock: Vector2, source = null) -> void:
	if not alive:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < invulnerable_until:
		return
	for a in abilities:
		if is_instance_valid(a):
			dmg = a.modify_incoming(dmg, source)
	if dmg <= 0:
		return
	hp -= dmg
	_last_damage_from = from
	invulnerable_until = now + 0.55
	_hurt_anim = 1.0
	var dir := signf(global_position.x - from.x)
	if dir == 0.0:
		dir = -facing
	_knock = Vector2(dir * absf(knock.x), knock.y) * 0.6
	velocity.y = minf(velocity.y, knock.y)
	Fx.flash(sprite, Color(1, 0.3, 0.3))
	Fx.popup(center() + Vector2(0, -body_height() * 0.6), str(dmg), Color(1, 0.45, 0.4))
	Fx.burst(center(), "hit", Color(1, 0.4, 0.35), 10)
	Audio.play("hit", -4.0)
	if hp <= 0:
		for a in abilities:
			if is_instance_valid(a) and a.prevent_death():
				hp = 1
				hp_changed.emit(hp, max_hp)
				return
		hp = 0
		hp_changed.emit(hp, max_hp)
		die()
		return
	hp_changed.emit(hp, max_hp)
	if source != null and is_instance_valid(source):
		for a in abilities:
			if is_instance_valid(a):
				a.on_hurt(dmg, source)

func heal(n: int) -> void:
	if not alive:
		return
	hp = mini(max_hp, hp + n)
	hp_changed.emit(hp, max_hp)

func die() -> void:
	if not alive:
		return
	alive = false
	Fx.burst(center(), "death", def.accent, 36)
	Fx.shake(10.0, 0.3)
	Audio.play("death", -4.0)
	died.emit(self)

func revive_at(p: Vector2, d: CreatureDef = null) -> void:
	global_position = p
	velocity = Vector2.ZERO
	_knock = Vector2.ZERO
	alive = true
	if d != null:
		set_form(d)
	else:
		hp = max_hp
		hp_changed.emit(hp, max_hp)
	invulnerable_until = Time.get_ticks_msec() / 1000.0 + 1.2
	visual.modulate.a = 1.0

func poison(dmg: int, ticks: int) -> void:
	for i in ticks:
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(self) or not alive:
			return
		hp = maxi(1, hp - dmg)
		hp_changed.emit(hp, max_hp)
		Fx.popup(center() + Vector2(0, -body_height() * 0.6), str(dmg), Color(0.6, 1, 0.4), 26)

func stun(sec: float) -> void:
	stunned_until = Time.get_ticks_msec() / 1000.0 + sec

func knockback(v: Vector2) -> void:
	_knock = v

func _animate(delta: float) -> void:
	if visual == null:
		return
	var on_floor := is_on_floor()
	var speed_ratio := clampf(absf(velocity.x) / maxf(def.run_speed(), 1.0), 0.0, 1.2)
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0
	var off := Vector2.ZERO
	if flying or in_water:
		var flap := sin(_time * (14.0 if flying else 5.0))
		sy += flap * 0.06
		sx -= flap * 0.04
		rot = velocity.x / 1800.0 + velocity.y / 4000.0 * facing
		off.y = sin(_time * 3.0) * 3.0
	elif on_floor:
		if speed_ratio > 0.1:
			var b := absf(sin(_time * 14.0 * (0.6 + speed_ratio * 0.5)))
			off.y = -b * 7.0 * speed_ratio
			rot = facing * 0.06 * speed_ratio + sin(_time * 14.0) * 0.03
		else:
			var br := sin(_time * 2.4)
			sy += br * 0.025
			sx -= br * 0.015
	else:
		var st := clampf(-velocity.y / 1400.0, -0.35, 0.35)
		sy += st * 0.5
		sx -= st * 0.3
		rot = clampf(velocity.x / 2400.0, -0.2, 0.2)
	if climbing:
		rot = -on_wall * 0.25 if on_wall != 0 else 0.0
	if _land_squash > 0.0:
		sy -= _land_squash * 0.6
		sx += _land_squash * 0.5
	elif _land_squash < 0.0:
		sy -= _land_squash * 0.5
		sx += _land_squash * 0.35
	_land_squash = move_toward(_land_squash, 0.0, delta * 3.2)
	if _attack_anim > 0.0:
		off.x += facing * sin(_attack_anim * PI) * 18.0
		rot += facing * sin(_attack_anim * PI) * 0.15
		sx += sin(_attack_anim * PI) * 0.08
	if _hurt_anim > 0.0:
		off.x += sin(_time * 60.0) * 5.0 * _hurt_anim
	visual.position = off
	visual.rotation = lerp_angle(visual.rotation, rot, minf(1.0, delta * 14.0))
	visual.scale = Vector2(sx * facing, sy)
	var now := Time.get_ticks_msec() / 1000.0
	var blink := now < invulnerable_until and alive and int(now * 16.0) % 2 == 0
	var a := 0.35 if stealth else 1.0
	if blink:
		a *= 0.45
	(sprite.material as ShaderMaterial).set_shader_parameter("alpha_mul", a)
	shadow.visible = on_floor and not flying
	if not alive:
		visual.modulate.a = move_toward(visual.modulate.a, 0.0, delta * 3.0)
