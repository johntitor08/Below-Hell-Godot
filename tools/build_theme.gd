extends SceneTree

const BG := Color("1b1222")
const BG2 := Color("2a1c34")
const BG3 := Color("3b2749")
const EDGE := Color("6d4a8c")
const GOLD := Color("e6b85c")
const TEXT := Color("efe6f5")
const MUTED := Color("a895b8")
const DANGER := Color("e0574c")

func sb(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 12, shadow := 0, pad := Vector4(18, 10, 18, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	s.shadow_size = shadow
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s

func _init() -> void:
	var t := Theme.new()
	var body := load("res://assets/fonts/body.otf")
	var bold := load("res://assets/fonts/body_bold.otf")
	t.default_font = body
	t.default_font_size = 26
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 28)
	t.set_stylebox("normal", "Button", sb(BG2, EDGE.darkened(0.3), 2, 12, 4, Vector4(26, 12, 26, 12)))
	t.set_stylebox("hover", "Button", sb(BG3, GOLD, 2, 12, 8, Vector4(26, 12, 26, 12)))
	t.set_stylebox("pressed", "Button", sb(BG.darkened(0.3), GOLD.darkened(0.2), 2, 12, 0, Vector4(26, 14, 26, 10)))
	t.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), GOLD, 3, 12, 0))
	t.set_stylebox("disabled", "Button", sb(BG2.darkened(0.4), EDGE.darkened(0.6), 2, 12, 0, Vector4(26, 12, 26, 12)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("ffe7b0"))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", Color("ffe7b0"))
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_stylebox("panel", "Panel", sb(Color(BG, 0.94), EDGE, 2, 16, 18))
	t.set_stylebox("panel", "PanelContainer", sb(Color(BG, 0.94), EDGE, 2, 16, 18, Vector4(28, 24, 28, 24)))
	var bar_bg := sb(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.12), 2, 8, 0, Vector4(0, 0, 0, 0))
	var bar_fill := sb(DANGER, Color(0, 0, 0, 0), 0, 8, 0, Vector4(0, 0, 0, 0))
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_stylebox("slider", "HSlider", sb(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 0, 6, 0, Vector4(0, 4, 0, 4)))
	t.set_stylebox("grabber_area", "HSlider", sb(GOLD.darkened(0.2), Color(0, 0, 0, 0), 0, 6, 0, Vector4(0, 4, 0, 4)))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb(GOLD, Color(0, 0, 0, 0), 0, 6, 0, Vector4(0, 4, 0, 4)))
	t.set_stylebox("normal", "LineEdit", sb(Color(0, 0, 0, 0.45), EDGE, 2, 10, 0, Vector4(16, 10, 16, 10)))
	t.set_stylebox("focus", "LineEdit", sb(Color(0, 0, 0, 0), GOLD, 2, 10, 0))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_font("font", "CheckButton", body)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color("ffe7b0"))
	t.set_stylebox("normal", "CheckButton", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10, 0, Vector4(6, 6, 6, 6)))
	t.set_stylebox("hover", "CheckButton", sb(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 10, 0, Vector4(6, 6, 6, 6)))
	t.set_stylebox("focus", "CheckButton", sb(Color(0, 0, 0, 0), GOLD, 2, 10, 0))
	t.set_stylebox("panel", "TooltipPanel", sb(BG, GOLD, 1, 8, 6, Vector4(12, 8, 12, 8)))
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0, 6, 0, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber", "VScrollBar", sb(EDGE, Color(0, 0, 0, 0), 0, 6, 0, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(GOLD.darkened(0.2), Color(0, 0, 0, 0), 0, 6, 0, Vector4(4, 4, 4, 4)))
	var err := ResourceSaver.save(t, "res://game/ui/theme.tres")
	print("theme saved ", err)
	quit()
