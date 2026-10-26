class_name Abilities

const TILE := 64.0

static func create(id: String) -> Ability:
	var a: Ability = null
	match id:
		"tongue_grapple": a = TongueGrapple.new()
		"super_jump": a = SuperJump.new()
		"dive_attack_height_scaled": a = DiveAttack.new()
		"echolocation_reveal": a = Echolocation.new()
		"idle_regen": a = IdleRegen.new()
		"camouflage_stealth": a = Camouflage.new()
		"tongue_pull_items": a = TonguePull.new()
		"thorn_armor_contact_damage": a = ThornArmor.new()
		"roll_form": a = RollForm.new()
		"split_clone": a = SplitClone.new()
		"clone_sacrifice": a = CloneSacrifice.new()
		"electric_field_aoe_water": a = ElectricField.new()
		"nine_lives_revive": a = NineLives.new()
		"antler_charge_break_walls": a = AntlerCharge.new()
		"knockback": a = Knockback.new()
		"squeeze_through_pipes": a = Squeeze.new()
		"ink_blind": a = InkBlind.new()
		"summon_pack_10s": a = SummonPack.new()
		"grab_carry_drop": a = GrabCarry.new()
		"roar_stun": a = RoarStun.new()
		"smash_heavy_obstacles": a = Smash.new()
		"fire_breath_aoe": a = FireBreath.new()
		"all_traversal": a = Smash.new()
		"web_bridge": a = WebBridge.new()
		"web_trap": a = WebTrap.new()
		"parry_reflect": a = Parry.new()
		"burrow": a = Burrow.new()
		"pit_trap": a = PitTrap.new()
		"poison_sting_dot": a = PoisonSting.new()
	if a != null:
		a.id = id
	return a

static func primary_of(c: Creature) -> Ability:
	for a in c.abilities:
		if a.slot == 1:
			return a
	return null

static func secondary_of(c: Creature) -> Ability:
	for a in c.abilities:
		if a.slot == 2:
			return a
	return null


class TongueGrapple extends Ability:
	var line: Line2D
	var target := Vector2.ZERO
	var pulling := 0.0

	func on_added() -> void:
		slot = 1
		cooldown = 0.45
		line = Line2D.new()
		line.width = 7.0
		line.default_color = Color(0.95, 0.45, 0.55)
		line.visible = false
		line.top_level = true
		line.z_index = 20
		creature.add_child(line)

	func on_removed() -> void:
		if is_instance_valid(line):
			line.queue_free()

	func activate() -> bool:
		var from := creature.center()
		var best = null
		for dir in [Vector2(creature.facing, -1.2), Vector2(creature.facing, -0.45), Vector2(0, -1), Vector2(creature.facing, 0)]:
			var q := PhysicsRayQueryParameters2D.create(from, from + dir.normalized() * TILE * 7.0, 1 | 128)
			q.exclude = [creature.get_rid()]
			var r := creature.get_world_2d().direct_space_state.intersect_ray(q)
			if not r.is_empty():
				best = r.position
				break
		for gp in creature.get_tree().get_nodes_in_group("grapple_points"):
			if gp.global_position.distance_to(from) < TILE * 7.5:
				best = gp.global_position
				break
		if best == null:
			return false
		target = best
		pulling = 0.35
		Audio.play("whoosh", -6.0)
		return true

	func tick(delta: float) -> void:
		if pulling > 0.0:
			pulling -= delta
			var d := target - creature.center()
			creature.velocity = d.normalized() * minf(1400.0, d.length() * 9.0)
			if d.length() < 40.0:
				pulling = 0.0
				creature.velocity *= 0.35
			line.visible = true
			line.points = [creature.center() + Vector2(creature.facing * 12, -6), target]
		else:
			line.visible = false


class SuperJump extends Ability:
	func on_added() -> void:
		slot = 0

	func tick(_delta: float) -> void:
		var c := creature
		if c.is_on_floor() and c.input.move.y > 0.5 and c.input.jump:
			c.velocity.y = -c.def.jump_velocity(Creature.GRAVITY) * 1.45
			Fx.burst(c.global_position, "dust", Color(0.7, 1, 0.7), 14)
			Audio.play("whoosh", -6.0)


class DiveAttack extends Ability:
	var diving := false
	var start_y := 0.0

	func on_added() -> void:
		slot = 1
		cooldown = 0.6

	func activate() -> bool:
		if creature.is_on_floor() or diving:
			return false
		diving = true
		start_y = creature.global_position.y
		creature.flying = false
		creature.velocity = Vector2(creature.facing * 380.0, 1500.0)
		Audio.play("whoosh", -4.0)
		return true

	func tick(_delta: float) -> void:
		if not diving:
			return
		creature.velocity.y = 1500.0
		if creature.is_on_floor() or creature.in_water:
			diving = false
			creature.flying = creature.def.flight
			var h := maxf(0.0, creature.global_position.y - start_y)
			var dmg := int(creature.def.hit_damage() * (1.0 + h / (TILE * 3.0)))
			for f in foes_in_radius(creature.global_position, TILE * 1.8):
				hit(f, dmg, Vector2(500, -500))
			Fx.burst(creature.global_position, "dust", Color(0.9, 0.9, 1), 24)
			Fx.shake(clampf(h / 40.0, 4.0, 16.0), 0.25)
			Audio.play("land", 0.0)


class Echolocation extends Ability:
	func on_added() -> void:
		slot = 1
		cooldown = 2.5
		creature.add_to_group("sees_dark")

	func on_removed() -> void:
		creature.remove_from_group("sees_dark")

	func activate() -> bool:
		var ring := Sprite2D.new()
		ring.texture = Fx.soft_tex
		ring.modulate = Color(0.75, 0.55, 1, 0.7)
		ring.global_position = creature.center()
		ring.z_index = 60
		world().add_child(ring)
		ring.scale = Vector2(0.1, 0.1)
		var tw := ring.create_tween().set_parallel(true)
		tw.tween_property(ring, "scale", Vector2(14, 14), 0.7)
		tw.tween_property(ring, "modulate:a", 0.0, 0.7)
		tw.chain().tween_callback(ring.queue_free)
		for s in creature.get_tree().get_nodes_in_group("secret"):
			if s.global_position.distance_to(creature.global_position) < TILE * 12.0 and s.has_method("reveal"):
				s.reveal(8.0)
		Audio.play("spawn", -6.0, 0.3)
		return true


class IdleRegen extends Ability:
	var t := 0.0

	func tick(delta: float) -> void:
		if creature.velocity.length() < 15.0 and creature.hp < creature.max_hp:
			t += delta
			if t >= 0.7:
				t = 0.0
				creature.heal(2)
				Fx.burst(creature.center(), "pickup", Color(1, 0.6, 0.85), 4)
		else:
			t = 0.0


class Camouflage extends Ability:
	func on_added() -> void:
		slot = 1
		cooldown = 0.4

	func activate() -> bool:
		creature.stealth = not creature.stealth
		Fx.burst(creature.center(), "pickup", Color(0.6, 1, 0.85), 10)
		return true

	func tick(_delta: float) -> void:
		if creature.stealth and creature.input.attack:
			creature.stealth = false

	func on_removed() -> void:
		creature.stealth = false


class TonguePull extends Ability:
	func on_added() -> void:
		slot = 2
		cooldown = 0.8

	func activate() -> bool:
		var best = null
		var bd := TILE * 7.0
		for n in creature.get_tree().get_nodes_in_group("pickups") + creature.get_tree().get_nodes_in_group("carryable"):
			var d: float = n.global_position.distance_to(creature.center())
			if d < bd:
				bd = d
				best = n
		if best == null:
			return false
		var tw: Tween = best.create_tween()
		tw.tween_property(best, "global_position", creature.center(), 0.25)
		Audio.play("whoosh", -6.0)
		return true


class ThornArmor extends Ability:
	var t := 0.0

	func on_hurt(dmg: int, source) -> void:
		if source != null and is_instance_valid(source) and source.has_method("take_hit"):
			hit(source, maxi(2, dmg / 2), Vector2(380, -220))

	func tick(delta: float) -> void:
		t -= delta
		if t > 0.0:
			return
		for f in foes_in_radius(creature.center(), creature.body_width() * 0.8 + 20.0):
			hit(f, 3, Vector2(300, -200))
			t = 0.5


class RollForm extends Ability:
	var rolling := false

	func on_added() -> void:
		slot = 1

	func physics(delta: float) -> void:
		rolling = creature.input.ability_held and creature.alive
		creature.speed_mult = 1.7 if rolling else 1.0
		if rolling:
			creature.visual.rotation += creature.facing * delta * 14.0
			for f in foes_in_radius(creature.center(), creature.body_width()):
				hit(f, creature.def.hit_damage(), Vector2(500, -260))

	func modify_incoming(dmg: int, _s) -> int:
		return dmg / 2 if rolling else dmg

	func on_removed() -> void:
		creature.speed_mult = 1.0


class SplitClone extends Ability:
	var clone: Node2D

	func on_added() -> void:
		slot = 1
		cooldown = 1.0

	func activate() -> bool:
		if clone != null and is_instance_valid(clone):
			clone.queue_free()
		var body := RigidBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 1 | 64 | 128
		body.lock_rotation = true
		body.add_to_group("clones")
		body.add_to_group("plate_pressers")
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(creature.body_width(), creature.body_height())
		cs.shape = r
		cs.position = Vector2(0, -r.size.y * 0.5)
		body.add_child(cs)
		var sp := Sprite2D.new()
		sp.texture = creature.def.texture
		sp.scale = creature.sprite.scale * 0.85
		sp.position = creature.sprite.position
		sp.modulate = Color(0.6, 1, 0.7, 0.75)
		sp.flip_h = creature.facing < 0
		body.add_child(sp)
		body.global_position = creature.global_position + Vector2(creature.facing * TILE, -8)
		world().add_child(body)
		body.linear_velocity = Vector2(creature.facing * 320.0, -380.0)
		clone = body
		Fx.burst(body.global_position, "transform", Color(0.6, 1, 0.7), 20)
		Audio.play("spawn", -6.0)
		return true

	func on_removed() -> void:
		if clone != null and is_instance_valid(clone):
			clone.queue_free()


class CloneSacrifice extends Ability:
	func on_added() -> void:
		slot = 2
		cooldown = 1.0

	func activate() -> bool:
		var sc: SplitClone = null
		for a in creature.abilities:
			if a is SplitClone:
				sc = a
		if sc == null or sc.clone == null or not is_instance_valid(sc.clone):
			return false
		var p: Vector2 = sc.clone.global_position
		for f in foes_in_radius(p, TILE * 2.5):
			hit(f, 18, Vector2(600, -500))
		for b in breakables_in_radius(p, TILE * 1.5):
			b.break_by(1)
		Fx.burst(p, "death", Color(0.5, 1, 0.6), 40)
		Fx.shake(10.0, 0.3)
		Audio.play("explosion", -4.0)
		sc.clone.queue_free()
		return true


class ElectricField extends Ability:
	func on_added() -> void:
		slot = 1
		cooldown = 2.2

	func activate() -> bool:
		var r := TILE * (5.0 if creature.in_water else 2.4)
		for f in foes_in_radius(creature.center(), r):
			hit(f, 10 if creature.in_water else 6, Vector2(200, -150))
			if f.has_method("stun"):
				f.stun(0.8)
		Fx.burst(creature.center(), "hit", Color(1, 0.95, 0.4), 40)
		Fx.shake(6.0, 0.2)
		Audio.play("shot", -4.0, 0.3)
		return true


class NineLives extends Ability:
	var charges := 1

	func prevent_death() -> bool:
		if charges <= 0:
			return false
		charges -= 1
		Fx.popup(creature.center() + Vector2(0, -60), "♥", Color(1, 0.8, 0.4), 52)
		Fx.burst(creature.center(), "transform", Color(1, 0.85, 0.4), 30)
		creature.invulnerable_until = Time.get_ticks_msec() / 1000.0 + 1.5
		return true


class AntlerCharge extends Ability:
	var t := 0.0

	func on_added() -> void:
		slot = 1
		cooldown = 1.1

	func activate() -> bool:
		t = 0.42
		Audio.play("whoosh", -2.0)
		return true

	func tick(delta: float) -> void:
		if t <= 0.0:
			return
		t -= delta
		creature.velocity.x = creature.facing * 980.0
		var front := creature.center() + Vector2(creature.facing * creature.body_width() * 0.7, 0)
		for f in foes_in_radius(front, TILE * 1.1):
			hit(f, creature.def.hit_damage() + 4, Vector2(900, -520))
		for b in breakables_in_radius(front, TILE * 0.9):
			b.break_by(2)
			Fx.shake(8.0, 0.2)
		if creature.is_on_wall() and t < 0.38:
			t = 0.0
			Fx.shake(6.0, 0.15)


class Knockback extends Ability:
	func on_added() -> void:
		creature.hit_landed.connect(_on_hit)

	func _on_hit(target, _d) -> void:
		if is_instance_valid(target) and target.has_method("knockback"):
			target.knockback(Vector2(creature.facing * 700.0, -300.0))


class Squeeze extends Ability:
	var squeezed := false
	var normal_size := Vector2.ZERO

	func on_added() -> void:
		normal_size = (creature.shape.shape as RectangleShape2D).size

	func tick(_delta: float) -> void:
		var want := creature.input.move.y > 0.5
		if want == squeezed:
			return
		var r := creature.shape.shape as RectangleShape2D
		if want:
			r.size = Vector2(normal_size.x * 0.9, TILE * 0.55)
		else:
			var q := PhysicsShapeQueryParameters2D.new()
			var rr := RectangleShape2D.new()
			rr.size = normal_size
			q.shape = rr
			q.transform = Transform2D(0, creature.global_position + Vector2(0, -normal_size.y * 0.5 - 1))
			q.collision_mask = 1 | 128
			q.exclude = [creature.get_rid()]
			if not creature.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
				return
			r.size = normal_size
		creature.shape.position = Vector2(0, -r.size.y * 0.5)
		creature.visual.scale.y = 0.6 if want else 1.0
		squeezed = want

	func on_removed() -> void:
		if creature.shape != null:
			(creature.shape.shape as RectangleShape2D).size = normal_size


class InkBlind extends Ability:
	func on_added() -> void:
		slot = 2
		cooldown = 4.0

	func activate() -> bool:
		Fx.burst(creature.center(), "death", Color(0.08, 0.05, 0.12), 46)
		for f in foes_in_radius(creature.center(), TILE * 3.5):
			if f.has_method("stun"):
				f.stun(2.5)
		creature.invulnerable_until = Time.get_ticks_msec() / 1000.0 + 0.6
		Audio.play("whoosh", -2.0)
		return true


class SummonPack extends Ability:
	func on_added() -> void:
		slot = 1
		cooldown = 14.0

	func activate() -> bool:
		for i in 2:
			var w := GhostWolf.new()
			w.owner_creature = creature
			w.global_position = creature.global_position + Vector2((i * 2 - 1) * TILE, -10)
			world().add_child(w)
		Fx.burst(creature.center(), "transform", Color(0.7, 0.8, 1), 30)
		Audio.play("spawn", -2.0)
		return true


class GhostWolf extends CharacterBody2D:
	var owner_creature: Creature
	var life := 10.0
	var spr: Sprite2D
	var cd := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1 | 64
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(70, 50)
		cs.shape = r
		cs.position = Vector2(0, -25)
		add_child(cs)
		spr = Sprite2D.new()
		spr.texture = Creatures.get_def("kurt").texture
		var k := 70.0 / spr.texture.get_height()
		spr.scale = Vector2(k, k)
		spr.position = Vector2(0, -35)
		spr.modulate = Color(0.6, 0.75, 1, 0.65)
		add_child(spr)

	func _physics_process(delta: float) -> void:
		life -= delta
		cd -= delta
		if life <= 0.0 or owner_creature == null or not is_instance_valid(owner_creature):
			Fx.burst(global_position, "pickup", Color(0.6, 0.75, 1), 12)
			queue_free()
			return
		var target = null
		var bd := 900.0
		for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("creatures"):
			if e == owner_creature or not is_instance_valid(e):
				continue
			if e is Creature and (e.team == owner_creature.team or not e.alive):
				continue
			var d: float = e.global_position.distance_to(global_position)
			if d < bd:
				bd = d
				target = e
		var goal: Vector2 = target.global_position if target != null else owner_creature.global_position + Vector2(-owner_creature.facing * 80, 0)
		var dx := goal.x - global_position.x
		velocity.x = move_toward(velocity.x, signf(dx) * 520.0 if absf(dx) > 30.0 else 0.0, 3000.0 * delta)
		velocity.y += 2600.0 * delta
		if is_on_floor() and goal.y < global_position.y - 80.0:
			velocity.y = -900.0
		spr.flip_h = velocity.x < 0
		move_and_slide()
		if target != null and bd < 70.0 and cd <= 0.0 and target.has_method("take_hit"):
			cd = 0.6
			target.take_hit(6, global_position, Vector2(signf(dx) * 350.0, -220.0), owner_creature)


class GrabCarry extends Ability:
	var held: Node2D

	func on_added() -> void:
		slot = 1
		cooldown = 0.3

	func activate() -> bool:
		if held != null and is_instance_valid(held):
			if held is RigidBody2D:
				held.freeze = false
				held.linear_velocity = creature.velocity
			elif held.has_method("set_carried"):
				held.set_carried(false)
			held = null
			return true
		var best = null
		var bd := TILE * 2.0
		for n in creature.get_tree().get_nodes_in_group("carryable") + creature.get_tree().get_nodes_in_group("enemies"):
			var d: float = n.global_position.distance_to(creature.global_position + Vector2(0, TILE * 0.6))
			if d < bd:
				bd = d
				best = n
		if best == null:
			return false
		held = best
		if held is RigidBody2D:
			held.freeze = true
		elif held.has_method("set_carried"):
			held.set_carried(true)
		Audio.play("whoosh", -6.0)
		return true

	func tick(_delta: float) -> void:
		if held != null and is_instance_valid(held):
			held.global_position = creature.global_position + Vector2(0, TILE * 0.55)

	func on_removed() -> void:
		if held != null and is_instance_valid(held):
			if held is RigidBody2D:
				held.freeze = false
			elif held.has_method("set_carried"):
				held.set_carried(false)


class RoarStun extends Ability:
	func on_added() -> void:
		slot = 1
		cooldown = 4.0

	func activate() -> bool:
		for f in foes_in_radius(creature.center(), TILE * 5.0):
			if f.has_method("stun"):
				f.stun(2.2)
			hit(f, 4, Vector2(600, -300))
		Fx.shake(14.0, 0.45)
		Fx.burst(creature.center(), "transform", Color(1, 0.8, 0.6), 30)
		Audio.play("grunt2", 0.0, 0.0)
		return true


class Smash extends Ability:
	func on_added() -> void:
		creature.add_to_group("smashers")
		creature.hit_landed.connect(_on_hit)

	func on_removed() -> void:
		creature.remove_from_group("smashers")

	func _on_hit(target, _d) -> void:
		if is_instance_valid(target) and target.has_method("break_by"):
			target.break_by(3)


class FireBreath extends Ability:
	var tick_t := 0.0
	var fx: CPUParticles2D

	func on_added() -> void:
		slot = 1

	func physics(delta: float) -> void:
		var on := creature.input.ability_held and creature.alive and creature.controls_enabled
		if on:
			tick_t -= delta
			if fx == null or not is_instance_valid(fx):
				fx = Fx.burst(creature.center(), "fire", Color(1, 0.55, 0.15))
				if fx != null:
					fx.one_shot = false
			if fx != null:
				fx.global_position = creature.center() + Vector2(creature.facing * creature.body_width() * 0.6, -10)
				fx.direction = Vector2(creature.facing, 0.15)
			if tick_t <= 0.0:
				tick_t = 0.18
				var p := creature.center() + Vector2(creature.facing * TILE * 2.2, 0)
				for f in foes_in_radius(p, TILE * 2.0):
					hit(f, 5, Vector2(220, -120))
				for b in breakables_in_radius(p, TILE * 1.8):
					b.break_by(3)
				Fx.shake(2.0, 0.08)
		elif fx != null and is_instance_valid(fx):
			fx.emitting = false
			fx = null

	func on_removed() -> void:
		if fx != null and is_instance_valid(fx):
			fx.queue_free()


class WebBridge extends Ability:
	func on_added() -> void:
		slot = 1
		cooldown = 1.5

	func activate() -> bool:
		var b := StaticBody2D.new()
		b.collision_layer = 64
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE * 4.0, 14)
		cs.shape = r
		cs.one_way_collision = true
		b.add_child(cs)
		var vis := Line2D.new()
		vis.width = 10.0
		vis.default_color = Color(0.95, 0.95, 1, 0.85)
		vis.points = [Vector2(-TILE * 2, 0), Vector2(-TILE, 6), Vector2(0, 8), Vector2(TILE, 6), Vector2(TILE * 2, 0)]
		b.add_child(vis)
		b.global_position = creature.global_position + Vector2(creature.facing * TILE * 2.5, 6)
		world().add_child(b)
		var tw := b.create_tween()
		tw.tween_interval(7.0)
		tw.tween_property(vis, "modulate:a", 0.0, 0.6)
		tw.tween_callback(b.queue_free)
		Audio.play("whoosh", -8.0)
		return true


class WebTrap extends Ability:
	func on_added() -> void:
		slot = 2
		cooldown = 3.0

	func activate() -> bool:
		var a := Area2D.new()
		a.collision_layer = 0
		a.collision_mask = 4 | 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = TILE * 1.2
		cs.shape = c
		a.add_child(cs)
		var s := Sprite2D.new()
		s.texture = Fx.soft_tex
		s.modulate = Color(1, 1, 1, 0.3)
		s.scale = Vector2(1.6, 0.5)
		a.add_child(s)
		a.global_position = creature.global_position + Vector2(creature.facing * TILE, -10)
		world().add_child(a)
		var me := creature
		var on_enter := func(b):
			if b != me and b.has_method("stun") and not (b is Creature and b.team == me.team):
				b.stun(2.0)
		a.body_entered.connect(on_enter)
		var tw := a.create_tween()
		tw.tween_interval(6.0)
		tw.tween_callback(a.queue_free)
		return true


class Parry extends Ability:
	var window := 0.0

	func on_added() -> void:
		slot = 1
		cooldown = 0.7

	func activate() -> bool:
		window = 0.28
		Fx.burst(creature.center() + Vector2(creature.facing * 30, 0), "hit", Color(0.7, 1, 0.5), 8)
		return true

	func tick(delta: float) -> void:
		window = maxf(0.0, window - delta)
		if window > 0.0:
			creature.sprite.material.set_shader_parameter("flash", 0.35)
			creature.sprite.material.set_shader_parameter("flash_color", Color(0.7, 1, 0.5))

	func modify_incoming(dmg: int, source) -> int:
		if window <= 0.0:
			return dmg
		window = 0.0
		if source != null and is_instance_valid(source):
			hit(source, dmg * 2, Vector2(700, -400))
		Fx.hitstop(0.12)
		Fx.popup(creature.center() + Vector2(0, -60), "PARRY", Color(0.7, 1, 0.5), 30)
		Audio.play("shot", -2.0)
		return 0


class Burrow extends Ability:
	var under := false

	func on_added() -> void:
		slot = 1
		cooldown = 0.5

	func activate() -> bool:
		if not under and not creature.is_on_floor():
			return false
		under = not under
		creature.stealth = under
		creature.speed_mult = 0.45 if under else 1.0
		creature.visual.position.y = 0.0
		Fx.burst(creature.global_position, "dust", Color(0.85, 0.7, 0.5), 18)
		return true

	func tick(_delta: float) -> void:
		if under:
			creature.visual.scale.y *= 0.35
			creature.invulnerable_until = maxf(creature.invulnerable_until, Time.get_ticks_msec() / 1000.0 + 0.05)

	func on_removed() -> void:
		creature.stealth = false
		creature.speed_mult = 1.0


class PitTrap extends Ability:
	func on_added() -> void:
		slot = 2
		cooldown = 3.0

	func activate() -> bool:
		if not creature.is_on_floor():
			return false
		var a := Area2D.new()
		a.collision_layer = 0
		a.collision_mask = 4 | 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE * 1.4, 20)
		cs.shape = r
		a.add_child(cs)
		var s := Sprite2D.new()
		s.texture = Fx.soft_tex
		s.modulate = Color(0.2, 0.12, 0.05, 0.85)
		s.scale = Vector2(0.9, 0.18)
		a.add_child(s)
		a.global_position = creature.global_position + Vector2(creature.facing * TILE * 1.2, -4)
		world().add_child(a)
		var me := creature
		var on_enter := func(b):
			if b != me and b.has_method("take_hit") and not (b is Creature and b.team == me.team):
				b.take_hit(14, a.global_position, Vector2(0, -600), me)
				if b.has_method("stun"):
					b.stun(1.5)
				a.queue_free()
		a.body_entered.connect(on_enter)
		var tw := a.create_tween()
		tw.tween_interval(10.0)
		tw.tween_callback(a.queue_free)
		return true


class PoisonSting extends Ability:
	func on_added() -> void:
		creature.hit_landed.connect(_on_hit)

	func _on_hit(target, _d) -> void:
		if is_instance_valid(target) and target.has_method("poison"):
			target.poison(3, 4)
