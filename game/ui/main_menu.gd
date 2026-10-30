extends Control

const GOLD := Color("e6b85c")
const TITLE_FONT := preload("res://assets/fonts/title.otf")
const DISPLAY_FONT := preload("res://assets/fonts/display.otf")

var _layers: Array = []
var _t := 0.0
var _buttons: VBoxContainer
var _parade: Array = []
var _sub: Control

func _ready() -> void:
	Fx.slowmo(1.0)
	get_tree().paused = false
	Audio.music("menu")
	_build_bg()
	_build_title()
	_build_buttons()
	_build_footer()
	Game.language_changed.connect(_rebuild)

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_layers.clear()
	_parade.clear()
	_ready_again.call_deferred()

func _ready_again() -> void:
	_build_bg()
	_build_title()
	_build_buttons()
	_build_footer()

func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in 5:
		var tex: Texture2D = load("res://assets/bg/graveyard/Layer_%d.png" % i)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_right = 2400
		tr.modulate = Color(0.75, 0.6, 0.85) if i < 4 else Color(0.5, 0.4, 0.55)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		_layers.append([tr, [2.0, 6.0, 12.0, 22.0, 34.0][i]])
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.03, 0.01, 0.05, 0.92))
	gr.set_color(1, Color(0.03, 0.01, 0.05, 0.0))
	g.gradient = gr
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(1, 0)
	shade.texture = g
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_right = -900
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var embers := CPUParticles2D.new()
	embers.texture = Fx.soft_tex
	embers.amount = 60
	embers.lifetime = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(1100, 10)
	embers.position = Vector2(960, 1120)
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(0, -20)
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 120.0
	embers.scale_amount_min = 0.02
	embers.scale_amount_max = 0.07
	var eg := Gradient.new()
	eg.set_color(0, Color(1, 0.55, 0.25, 0.0))
	eg.add_point(0.2, Color(1, 0.6, 0.3, 0.9))
	eg.set_color(eg.get_point_count() - 1, Color(0.8, 0.3, 0.6, 0.0))
	embers.color_ramp = eg
	embers.preprocess = 6.0
	add_child(embers)
	var ids := ["20-ejderha", "06-kurbaga", "17-kurt", "08-yarasa", "11-kirpi"]
	var xs := [1430.0, 1180.0, 1660.0, 1290.0, 1540.0]
	var ys := [690.0, 905.0, 925.0, 470.0, 960.0]
	var hs := [420.0, 150.0, 220.0, 130.0, 120.0]
	for i in ids.size():
		var d := Creatures.get_def(ids[i])
		var s := TextureRect.new()
		s.texture = d.texture
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var h: float = hs[i]
		var w: float = h * d.texture.get_width() / d.texture.get_height()
		s.size = Vector2(w, h)
		s.position = Vector2(xs[i] - w * 0.5, ys[i] - h)
		s.pivot_offset = Vector2(w * 0.5, h)
		s.flip_h = true
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow := TextureRect.new()
		glow.texture = Fx.soft_tex
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.size = Vector2(w * 1.3, h * 0.3)
		glow.position = Vector2(xs[i] - w * 0.65, ys[i] - h * 0.15)
		glow.modulate = Color(0, 0, 0, 0.5)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow)
		add_child(s)
		_parade.append([s, randf() * 6.0, d.flight])

func _build_title() -> void:
	var title := Label.new()
	title.text = "BELOW HELL"
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 150)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.02, 0.05))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_shadow_color", Color(0.8, 0.2, 0.1, 0.45))
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 30)
	title.position = Vector2(110, 120)
	add_child(title)
	var sub := Label.new()
	sub.text = Game.t("tagline")
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.92))
	sub.position = Vector2(122, 300)
	add_child(sub)

func _btn(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(460, 72 if primary else 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if primary:
		b.add_theme_font_size_override("font_size", 32)
	var on_press := func():
		Audio.play("press", -4.0)
		cb.call()
	b.pressed.connect(on_press)
	var on_hover := func():
		Audio.play("hover", -14.0)
		b.grab_focus()
	b.mouse_entered.connect(on_hover)
	return b

func _build_buttons() -> void:
	var holder := Control.new()
	holder.position = Vector2(120, 400)
	add_child(holder)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	holder.add_child(_buttons)
	if Game.has_progress():
		_buttons.add_child(_btn(Game.t("continue"), _continue, true))
	_buttons.add_child(_btn(Game.t("play"), _new_game, not Game.has_progress()))
	_buttons.add_child(_btn(Game.t("arena"), func(): Transition.go("res://game/arena/arena_menu.tscn")))
	_buttons.add_child(_btn(Game.t("bestiary"), func(): Transition.go("res://game/ui/bestiary.tscn")))
	_buttons.add_child(_btn(Game.t("howto"), func(): Transition.go("res://game/ui/howto.tscn")))
	_buttons.add_child(_btn(Game.t("settings"), func(): Transition.go("res://game/ui/settings.tscn")))
	if not OS.has_feature("web"):
		_buttons.add_child(_btn(Game.t("quit"), func(): get_tree().quit()))
	_focus_first.call_deferred()
	var i := 0
	for b in _buttons.get_children():
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.3)
		i += 1

func _focus_first() -> void:
	if is_inside_tree() and _buttons != null and is_instance_valid(_buttons) and _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()

func _build_footer() -> void:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	h.position = Vector2(-330, -90)
	h.add_theme_constant_override("separation", 10)
	add_child(h)
	for l in [["tr", "Türkçe"], ["en", "English"]]:
		var b := Button.new()
		b.text = l[1]
		b.toggle_mode = true
		b.button_pressed = Game.lang == l[0]
		b.custom_minimum_size = Vector2(150, 52)
		b.add_theme_font_size_override("font_size", 22)
		var code: String = l[0]
		b.pressed.connect(func(): Game.set_lang(code))
		h.add_child(b)
	var ver := Label.new()
	ver.text = "v%s · Godot" % ProjectSettings.get_setting("application/config/version", "1.0")
	ver.add_theme_font_size_override("font_size", 18)
	ver.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7, 0.7))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(24, -40)
	add_child(ver)

func _process(delta: float) -> void:
	_t += delta
	for l in _layers:
		var tr: TextureRect = l[0]
		tr.position.x = -fmod(_t * l[1], 600.0)
	for p in _parade:
		var s: TextureRect = p[0]
		var ph: float = p[1]
		if p[2]:
			s.position.y += sin(_t * 2.0 + ph) * 0.35
			s.rotation = sin(_t * 1.5 + ph) * 0.04
		else:
			var b := sin(_t * 2.4 + ph)
			s.scale = Vector2(1.0 - b * 0.015, 1.0 + b * 0.025)

func _continue() -> void:
	Game.set_meta("level_index", clampi(int(Game.save.level), 0, Level.LEVELS.size() - 1))
	Transition.go("res://game/world/level.tscn")

func _new_game() -> void:
	Game.reset_progress()
	Game.set_meta("level_index", 0)
	Transition.go("res://game/world/level.tscn")
