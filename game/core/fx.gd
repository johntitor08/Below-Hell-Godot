extends Node

var _hitstop_until := 0
var soft_tex: Texture2D
var square_tex: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	soft_tex = load("res://assets/fx/soft_circle.png")
	square_tex = load("res://assets/fx/white_square.png")

var _base_scale := 1.0
var _stopping := false

func hitstop(sec := 0.06, scale := 0.05) -> void:
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(sec * 1000.0))
	_stopping = true
	Engine.time_scale = minf(scale, _base_scale)

func slowmo(scale: float) -> void:
	_base_scale = scale
	if not _stopping:
		Engine.time_scale = scale

func _process(_d: float) -> void:
	if _stopping and Time.get_ticks_msec() >= _hitstop_until:
		_stopping = false
		Engine.time_scale = _base_scale

func shake(amount := 8.0, duration := 0.25) -> void:
	if not Game.settings.get("shake", true):
		return
	for c in get_tree().get_nodes_in_group("game_camera"):
		if c.has_method("add_shake"):
			c.add_shake(amount, duration)

func _parent() -> Node:
	var s := get_tree().current_scene
	var w = s.get_node_or_null("World") if s != null else null
	return w if w != null else s

func burst(pos: Vector2, preset := "dust", color := Color.WHITE, amount := -1) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.texture = soft_tex
	p.global_position = pos
	p.z_index = 50
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	match preset:
		"dust":
			p.amount = 10 if amount < 0 else amount
			p.lifetime = 0.45
			p.direction = Vector2.UP
			p.spread = 70.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 160.0
			p.gravity = Vector2(0, 300)
			p.scale_amount_min = 0.04
			p.scale_amount_max = 0.09
		"hit":
			p.amount = 14 if amount < 0 else amount
			p.lifetime = 0.35
			p.spread = 180.0
			p.initial_velocity_min = 180.0
			p.initial_velocity_max = 420.0
			p.damping_min = 300.0
			p.damping_max = 500.0
			p.scale_amount_min = 0.03
			p.scale_amount_max = 0.07
		"transform":
			p.amount = 46 if amount < 0 else amount
			p.lifetime = 0.8
			p.spread = 180.0
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 520.0
			p.damping_min = 250.0
			p.damping_max = 450.0
			p.gravity = Vector2(0, -80)
			p.scale_amount_min = 0.05
			p.scale_amount_max = 0.16
		"pickup":
			p.amount = 18 if amount < 0 else amount
			p.lifetime = 0.55
			p.spread = 180.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 200.0
			p.gravity = Vector2(0, -260)
			p.scale_amount_min = 0.03
			p.scale_amount_max = 0.08
		"death":
			p.amount = 40 if amount < 0 else amount
			p.lifetime = 1.0
			p.spread = 180.0
			p.initial_velocity_min = 100.0
			p.initial_velocity_max = 380.0
			p.gravity = Vector2(0, 500)
			p.scale_amount_min = 0.05
			p.scale_amount_max = 0.14
		"fire":
			p.amount = 30 if amount < 0 else amount
			p.lifetime = 0.5
			p.explosiveness = 0.2
			p.spread = 18.0
			p.initial_velocity_min = 420.0
			p.initial_velocity_max = 620.0
			p.gravity = Vector2(0, -200)
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.2
	var root := _parent()
	if root == null:
		return p
	root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

func popup(pos: Vector2, text: String, color := Color.WHITE, size := 34) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_font_override("font", load("res://assets/fonts/display.otf"))
	l.z_index = 100
	l.position = pos - Vector2(60, 40)
	l.size = Vector2(120, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var root := _parent()
	if root == null:
		return
	root.add_child(l)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 70.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

func flash(node: CanvasItem, color := Color(1, 1, 1), time := 0.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	var m := node.material as ShaderMaterial
	if m != null and m.shader != null and m.get_shader_parameter("flash_color") != null:
		m.set_shader_parameter("flash_color", color)
		m.set_shader_parameter("flash", 1.0)
		var tw := node.create_tween()
		tw.tween_method(func(v): m.set_shader_parameter("flash", v), 1.0, 0.0, time)
	else:
		node.modulate = Color(2, 2, 2)
		var tw2 := node.create_tween()
		tw2.tween_property(node, "modulate", Color.WHITE, time)
