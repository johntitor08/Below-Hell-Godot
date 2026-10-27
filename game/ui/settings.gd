extends Control

func _ready() -> void:
	UI.backdrop(self, "mountain", 0.7)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel(20))
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(760, 0)
	box.position = Vector2(-380, -380)
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	box.add_child(v)
	var t := UI.title(Game.t("settings"), 68)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var first: Control = null
	for key in ["master", "music", "sfx"]:
		var h := HBoxContainer.new()
		var l := UI.label(Game.t(key), 26)
		l.custom_minimum_size = Vector2(260, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(Game.settings[key])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(0, 40)
		var k: String = key
		var changed := func(val: float):
			Game.settings[k] = val
			Game.apply_settings()
			if k == "sfx":
				Audio.play("click", -4.0)
		s.value_changed.connect(changed)
		h.add_child(s)
		v.add_child(h)
		if first == null:
			first = s
	for key in ["fullscreen", "shake"]:
		var c := CheckButton.new()
		c.text = Game.t(key)
		c.button_pressed = bool(Game.settings[key])
		c.add_theme_font_size_override("font_size", 26)
		var k2: String = key
		var toggled := func(on: bool):
			Game.settings[k2] = on
			Game.apply_settings()
		c.toggled.connect(toggled)
		v.add_child(c)
	var lang := HBoxContainer.new()
	lang.add_theme_constant_override("separation", 12)
	var ll := UI.label(Game.t("language"), 26)
	ll.custom_minimum_size = Vector2(260, 0)
	lang.add_child(ll)
	for code in [["tr", "Türkçe"], ["en", "English"]]:
		var c2: String = code[0]
		var pick := func():
			Game.set_lang(c2)
			get_tree().reload_current_scene()
		var b := UI.button(code[1], pick, 200, 54)
		b.toggle_mode = true
		b.button_pressed = Game.lang == c2
		lang.add_child(b)
	v.add_child(lang)
	v.add_child(UI.label(Game.t("controls"), 30, UI.TITLE_FONT, UI.GOLD))
	var ctl := UI.label(_controls_text(), 22, null, UI.MUTED)
	v.add_child(ctl)
	var back := UI.button(Game.t("back"), _back, 0, 64)
	v.add_child(back)
	if first != null:
		first.grab_focus.call_deferred()

func _controls_text() -> String:
	if Game.lang == "tr":
		return "A/D · hareket    Boşluk · zıpla    J · saldırı    K / L · yetenekler\nQ (basılı) · dönüşüm    R · formu bırak    Esc · duraklat    Gamepad desteklenir"
	return "A/D · move    Space · jump    J · attack    K / L · abilities\nQ (hold) · transform    R · drop form    Esc · pause    Gamepads supported"

func _back() -> void:
	Game.save_settings()
	Transition.go("res://game/ui/main_menu.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		_back()
