class_name Entities

const TILE := 64.0

static func box_area(size: Vector2, mask: int) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = mask
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	a.add_child(cs)
	return a


class Spikes extends Area2D:
	var width := 1

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE * width - 8, TILE * 0.45)
		cs.shape = r
		cs.position = Vector2(TILE * width * 0.5, TILE * 0.78)
		add_child(cs)
		var tex: Texture2D = load("res://assets/props/spike_hazard.png")
		for i in width:
			var s := Sprite2D.new()
			s.texture = tex
			var k := TILE / tex.get_width()
			s.scale = Vector2(k, k)
			s.centered = false
			s.position = Vector2(i * TILE, TILE - tex.get_height() * k)
			add_child(s)

	func _physics_process(_d: float) -> void:
		for b in get_overlapping_bodies():
			if b is Creature and b.alive:
				b.take_hit(12, global_position + Vector2(b.global_position.x - global_position.x, TILE), Vector2(0, -900), self)


class Water extends Area2D:
	var size := Vector2(TILE, TILE)
	var _rect: ColorRect
	var _surf: Line2D
	var _t := 0.0

	func _ready() -> void:
		add_to_group("water")
		collision_layer = 32
		collision_mask = 2 | 4
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = size
		cs.shape = r
		cs.position = size * 0.5
		add_child(cs)
		_rect = ColorRect.new()
		_rect.color = Color(0.22, 0.42, 0.85, 0.42)
		_rect.size = size
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.z_index = 30
		add_child(_rect)
		_surf = Line2D.new()
		_surf.width = 5.0
		_surf.default_color = Color(0.7, 0.85, 1, 0.7)
		_surf.z_index = 31
		add_child(_surf)
		body_entered.connect(_on_enter)
		body_exited.connect(_on_exit)

	func _process(delta: float) -> void:
		_t += delta
		var pts := PackedVector2Array()
		var n := int(size.x / 16.0) + 1
		for i in n:
			var x := i * 16.0
			pts.append(Vector2(x, sin(_t * 2.5 + x * 0.05) * 3.0))
		_surf.points = pts

	func _on_enter(b: Node) -> void:
		if b is Creature:
			b.in_water = true
			Fx.burst(Vector2(b.global_position.x, global_position.y), "dust", Color(0.7, 0.85, 1, 0.9), 14)
			Audio.play("whoosh", -10.0)

	func _on_exit(b: Node) -> void:
		if b is Creature:
			for w in b.get_tree().get_nodes_in_group("water"):
				if w != self and w.overlaps_body(b):
					return
			b.in_water = false


class ExitPortal extends Area2D:
	var _t := 0.0
	var _s: Sprite2D
	var _glow: Sprite2D

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE * 1.2, TILE * 1.8)
		cs.shape = r
		cs.position = Vector2(TILE * 0.5, TILE * 0.1)
		add_child(cs)
		_glow = Sprite2D.new()
		_glow.texture = Fx.soft_tex
		_glow.modulate = Color(0.6, 0.4, 1, 0.6)
		_glow.scale = Vector2(2.4, 3.2)
		_glow.position = Vector2(TILE * 0.5, 0)
		add_child(_glow)
		_s = Sprite2D.new()
		_s.texture = load("res://assets/props/exit_portal.png")
		var k := TILE * 2.4 / _s.texture.get_height()
		_s.scale = Vector2(k, k)
		_s.position = Vector2(TILE * 0.5, -TILE * 0.2)
		add_child(_s)
		body_entered.connect(_on_body)

	func _process(delta: float) -> void:
		_t += delta
		_s.rotation = sin(_t * 1.5) * 0.04
		_glow.modulate.a = 0.45 + sin(_t * 3.0) * 0.15

	func _on_body(b: Node) -> void:
		if b is Creature and b.team == 0 and b.alive:
			var lvl := get_tree().get_first_node_in_group("level")
			if lvl != null:
				lvl.complete()


class Checkpoint extends Area2D:
	var active := false
	var _flame: Sprite2D
	var _pole: ColorRect

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE, TILE * 2)
		cs.shape = r
		cs.position = Vector2(TILE * 0.5, 0)
		add_child(cs)
		_pole = ColorRect.new()
		_pole.color = Color(0.25, 0.2, 0.2)
		_pole.size = Vector2(8, TILE * 1.3)
		_pole.position = Vector2(TILE * 0.5 - 4, -TILE * 0.3)
		add_child(_pole)
		_flame = Sprite2D.new()
		_flame.texture = Fx.soft_tex
		_flame.modulate = Color(0.5, 0.5, 0.6, 0.6)
		_flame.scale = Vector2(0.45, 0.6)
		_flame.position = Vector2(TILE * 0.5, -TILE * 0.4)
		add_child(_flame)
		body_entered.connect(_on_body)

	func _process(_d: float) -> void:
		if active:
			_flame.scale = Vector2(0.5, 0.7) * (1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.08)

	func _on_body(b: Node) -> void:
		if active or not (b is Creature) or b.team != 0:
			return
		active = true
		_flame.modulate = Color(0.75, 0.5, 1.0, 0.95)
		var lvl := get_tree().get_first_node_in_group("level")
		if lvl != null:
			lvl.set_checkpoint(global_position + Vector2(TILE * 0.5, TILE))
		Fx.burst(_flame.global_position, "pickup", Color(0.75, 0.5, 1), 20)
		Audio.play("bonus", -4.0, 0.0)


class Breakable extends StaticBody2D:
	var strength := 2
	var _s: Sprite2D

	func _ready() -> void:
		add_to_group("breakable")
		collision_layer = 128
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE, TILE)
		cs.shape = r
		cs.position = Vector2(TILE * 0.5, TILE * 0.5)
		add_child(cs)
		_s = Sprite2D.new()
		_s.texture = load("res://assets/props/stone_ledge.png")
		_s.centered = false
		var k := TILE / maxf(_s.texture.get_width(), _s.texture.get_height())
		_s.scale = Vector2(TILE / _s.texture.get_width(), TILE / _s.texture.get_height())
		_s.modulate = Color(1, 0.85, 0.75) if strength == 2 else Color(0.75, 0.7, 0.8)
		add_child(_s)
		var crack := Line2D.new()
		crack.width = 3.0
		crack.default_color = Color(0.1, 0.05, 0.05, 0.8)
		crack.points = [Vector2(20, 6), Vector2(30, 26), Vector2(24, 40), Vector2(38, 58)] if strength == 2 else [Vector2(10, 10), Vector2(54, 54), Vector2(32, 32), Vector2(54, 12)]
		add_child(crack)

	func take_hit(_dmg: int, _from: Vector2, _k: Vector2, source = null) -> void:
		if source is Creature and source.is_in_group("smashers"):
			break_by(3)
		else:
			Fx.burst(global_position + Vector2(TILE * 0.5, TILE * 0.5), "dust", Color(0.7, 0.65, 0.6), 4)

	func break_by(power: int) -> void:
		if power < strength:
			return
		Fx.burst(global_position + Vector2(TILE * 0.5, TILE * 0.5), "death", Color(0.65, 0.6, 0.55), 20)
		Fx.shake(5.0, 0.15)
		Audio.play("explosion", -8.0)
		queue_free()


class DarkZone extends Node2D:
	var size := Vector2(TILE, TILE)
	var _rect: ColorRect
	var _revealed := 0.0

	func _ready() -> void:
		add_to_group("secret")
		_rect = ColorRect.new()
		_rect.color = Color(0.01, 0.0, 0.02, 0.96)
		_rect.size = size
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.z_index = 80
		add_child(_rect)

	func reveal(sec: float) -> void:
		_revealed = maxf(_revealed, sec)

	func _process(delta: float) -> void:
		_revealed -= delta
		var want := 0.96
		var bat := false
		for c in get_tree().get_nodes_in_group("sees_dark"):
			if c is Creature and c.alive and Rect2(global_position - Vector2(TILE * 4, TILE * 4), size + Vector2(TILE * 8, TILE * 8)).has_point(c.global_position):
				bat = true
		if bat:
			want = 0.25
		if _revealed > 0.0:
			want = 0.12
		_rect.color.a = move_toward(_rect.color.a, want, delta * 2.0)


class SecretWall extends Node2D:
	var _s: Node2D
	var _revealed := false

	func _ready() -> void:
		add_to_group("secret")

	func reveal(_sec: float) -> void:
		if _revealed:
			return
		_revealed = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.25, 0.6)
		Fx.burst(global_position + Vector2(TILE * 0.5, TILE * 0.5), "pickup", Color(0.75, 0.55, 1), 8)


class GrapplePoint extends Node2D:
	var _t := 0.0
	var _s: Sprite2D

	func _ready() -> void:
		add_to_group("grapple_points")
		_s = Sprite2D.new()
		_s.texture = Fx.soft_tex
		_s.modulate = Color(0.95, 0.6, 0.7, 0.9)
		_s.scale = Vector2(0.35, 0.35)
		add_child(_s)
		var ring := Line2D.new()
		ring.width = 4.0
		ring.default_color = Color(1, 0.85, 0.9, 0.9)
		var pts := PackedVector2Array()
		for i in 17:
			var a := TAU * i / 16.0
			pts.append(Vector2(cos(a), sin(a)) * 16.0)
		ring.points = pts
		add_child(ring)

	func _process(delta: float) -> void:
		_t += delta
		_s.scale = Vector2.ONE * (0.32 + sin(_t * 4.0) * 0.04)


class Plate extends Area2D:
	signal toggled(on: bool)
	var group_id := "a"
	var pressed := false
	var _top: ColorRect

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2 | 4
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE * 0.9, 20)
		cs.shape = r
		cs.position = Vector2(TILE * 0.5, TILE - 10)
		add_child(cs)
		_top = ColorRect.new()
		_top.color = Color(0.85, 0.6, 0.3)
		_top.size = Vector2(TILE * 0.8, 10)
		_top.position = Vector2(TILE * 0.1, TILE - 12)
		add_child(_top)

	func _physics_process(_d: float) -> void:
		var on := false
		for b in get_overlapping_bodies():
			on = true
		if on != pressed:
			pressed = on
			_top.position.y = TILE - (6 if on else 12)
			_top.color = Color(0.5, 1, 0.6) if on else Color(0.85, 0.6, 0.3)
			Audio.play("click", -6.0)
			for d in get_tree().get_nodes_in_group("door_" + group_id):
				d.set_open(on)


class Door extends StaticBody2D:
	var height := 2
	var _vis: ColorRect
	var _cs: CollisionShape2D
	var open := false

	func _ready() -> void:
		collision_layer = 1
		_cs = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(TILE * 0.5, TILE * height)
		_cs.shape = r
		_cs.position = Vector2(TILE * 0.5, TILE * height * 0.5)
		add_child(_cs)
		_vis = ColorRect.new()
		_vis.color = Color(0.42, 0.3, 0.22)
		_vis.size = Vector2(TILE * 0.5, TILE * height)
		_vis.position = Vector2(TILE * 0.25, 0)
		add_child(_vis)

	func set_open(v: bool) -> void:
		if v == open:
			return
		open = v
		_cs.set_deferred("disabled", v)
		var tw := create_tween()
		tw.tween_property(_vis, "scale:y", 0.08 if v else 1.0, 0.25)


class Torch extends Node2D:
	var _f: Sprite2D
	var _g: Sprite2D
	var _t := randf() * 10.0

	func _ready() -> void:
		var stick := ColorRect.new()
		stick.color = Color(0.3, 0.2, 0.12)
		stick.size = Vector2(8, 34)
		stick.position = Vector2(TILE * 0.5 - 4, TILE * 0.4)
		add_child(stick)
		_g = Sprite2D.new()
		_g.texture = Fx.soft_tex
		_g.modulate = Color(1, 0.6, 0.25, 0.35)
		_g.scale = Vector2(2.6, 2.6)
		_g.position = Vector2(TILE * 0.5, TILE * 0.3)
		add_child(_g)
		_f = Sprite2D.new()
		_f.texture = Fx.soft_tex
		_f.modulate = Color(1, 0.75, 0.35, 0.95)
		_f.scale = Vector2(0.22, 0.32)
		_f.position = Vector2(TILE * 0.5, TILE * 0.32)
		add_child(_f)

	func _process(delta: float) -> void:
		_t += delta
		var k := 1.0 + sin(_t * 11.0) * 0.08 + sin(_t * 23.0) * 0.05
		_f.scale = Vector2(0.22, 0.32) * k
		_g.modulate.a = 0.3 + sin(_t * 7.0) * 0.05
