class_name UI

const GOLD := Color("e6b85c")
const TEXT := Color("efe6f5")
const MUTED := Color("a895b8")
const TITLE_FONT := preload("res://assets/fonts/title.otf")
const DISPLAY_FONT := preload("res://assets/fonts/display.otf")

static func label(text := "", size := 26, font: Font = null, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func title(text: String, size := 72) -> Label:
	return label(text, size, TITLE_FONT, GOLD)

static func panel(radius := 16, color := Color(0.1, 0.07, 0.13, 0.9), border := Color(0.43, 0.29, 0.55, 0.9), bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.shadow_size = 10
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.anti_aliasing = true
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

static func button(text: String, cb: Callable, min_w := 0.0, h := 62.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, h)
	var on_press := func():
		Audio.play("press", -4.0)
		cb.call()
	b.pressed.connect(on_press)
	var on_hover := func():
		Audio.play("hover", -14.0)
	b.mouse_entered.connect(on_hover)
	return b

static func backdrop(root: Control, theme := "graveyard", dim := 0.55) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	for i in 5:
		var path := "res://assets/bg/%s/Layer_%d.png" % [theme, i]
		if not ResourceLoader.exists(path):
			continue
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

static func stat_bar(name: String, value: int, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := label(name, 22, null, MUTED)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in 10:
		var p := Panel.new()
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(3)
		s.bg_color = color if i < value else Color(1, 1, 1, 0.08)
		p.add_theme_stylebox_override("panel", s)
		p.custom_minimum_size = Vector2(22, 14)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(p)
	h.add_child(pips)
	return h

