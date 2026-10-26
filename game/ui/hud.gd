extends CanvasLayer

const GOLD := Color("e6b85c")
const TITLE_FONT := preload("res://assets/fonts/title.otf")
const DISPLAY_FONT := preload("res://assets/fonts/display.otf")

var level: Level
var root: Control
var portrait: TextureRect
var portrait_ring: Panel
var form_name: Label
var hp_bar: ProgressBar
var hp_label: Label
var oz_box: HBoxContainer
var timer_label: Label
var ab1: Control
var ab2: Control
var toast_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var radial: Control
var radial_items: Array = []
var radial_sel := -1
var radial_info: Label
var radial_name: Label
var radial_stats: Label
var pause_panel: Control
var complete_panel: Control
var hint: Label

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status()
	_build_abilities()
	_build_misc()
	_build_radial()
	_build_pause()

func bind(l: Level) -> void:
	level = l
	l.essence.changed.connect(_on_oz)
	l.essence.message.connect(toast)
	l.player.hp_changed.connect(_on_hp)
	l.player.form_changed.connect(_on_form)
	_on_form(l.player.def)
	_on_hp(l.player.hp, l.player.max_hp)
	_on_oz(l.essence.oz, l.essence.cap)
	hint.text = Game.t("transform_hint") + "    " + Game.t("revert_hint")

func _panel(radius := 16, color := Color(0.1, 0.07, 0.13, 0.82), border := Color(0.43, 0.29, 0.55, 0.9)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.shadow_size = 10
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.anti_aliasing = true
	return s

func _label(text := "", size := 26, font: Font = null, color := Color("efe6f5")) -> Label:
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

func _build_status() -> void:
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", _panel(22))
	box.position = Vector2(28, 24)
	box.size = Vector2(520, 150)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	portrait_ring = Panel.new()
	var ps := _panel(64, Color(0.05, 0.03, 0.07, 1.0), GOLD)
	ps.set_border_width_all(4)
	portrait_ring.add_theme_stylebox_override("panel", ps)
	portrait_ring.position = Vector2(14, 14)
	portrait_ring.size = Vector2(122, 122)
	portrait_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait_ring)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(12, 12)
	portrait.size = Vector2(98, 98)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_ring.add_child(portrait)
	form_name = _label("", 34, TITLE_FONT, GOLD)
	form_name.position = Vector2(152, 10)
	box.add_child(form_name)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(152, 60)
	hp_bar.size = Vector2(350, 26)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hp_bar)
	hp_label = _label("", 18)
	hp_label.position = Vector2(152, 60)
	hp_label.size = Vector2(350, 26)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(hp_label)
	oz_box = HBoxContainer.new()
	oz_box.position = Vector2(152, 100)
	oz_box.add_theme_constant_override("separation", 6)
	oz_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(oz_box)
	timer_label = _label("0:00.00", 30, DISPLAY_FONT)
	timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer_label.position = Vector2(-220, 30)
	timer_label.size = Vector2(190, 40)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(timer_label)

func _ability_widget(key: String) -> Control:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _panel(14))
	p.size = Vector2(250, 64)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := _label(key, 22, DISPLAY_FONT, GOLD)
	k.position = Vector2(14, 16)
	p.add_child(k)
	var n := _label("", 20)
	n.name = "Name"
	n.position = Vector2(60, 8)
	n.size = Vector2(180, 30)
	n.clip_text = true
	p.add_child(n)
	var bar := ProgressBar.new()
	bar.name = "CD"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.position = Vector2(60, 40)
	bar.size = Vector2(174, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	p.add_child(bar)
	return p

func _build_abilities() -> void:
	ab1 = _ability_widget("K")
	ab1.position = Vector2(28, 186)
	root.add_child(ab1)
	ab2 = _ability_widget("L")
	ab2.position = Vector2(290, 186)
	root.add_child(ab2)

func _build_misc() -> void:
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-300, 120)
	toast_box.size = Vector2(600, 200)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	banner_title = _label("", 96, TITLE_FONT, GOLD)
	banner_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner_title.position = Vector2(-800, -160)
	banner_title.size = Vector2(1600, 120)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.modulate.a = 0.0
	root.add_child(banner_title)
	banner_sub = _label("", 30)
	banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner_sub.position = Vector2(-800, -30)
	banner_sub.size = Vector2(1600, 50)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.modulate.a = 0.0
	root.add_child(banner_sub)
	hint = _label("", 22, null, Color(0.85, 0.8, 0.9, 0.85))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-700, -60)
	hint.size = Vector2(1400, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

func banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	var tw := create_tween()
	tw.tween_property(banner_title, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(banner_sub, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.4)
	tw.tween_property(banner_title, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(banner_sub, "modulate:a", 0.0, 0.8)

func toast(text: String, color := Color.WHITE) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel(12))
	var l := _label(text, 26, null, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

func _on_hp(hp: int, mx: int) -> void:
	hp_bar.max_value = mx
	var tw := create_tween()
	tw.tween_property(hp_bar, "value", float(hp), 0.15)
	hp_label.text = "%d / %d" % [hp, mx]

func _on_oz(oz: int, cap: int) -> void:
	for c in oz_box.get_children():
		c.queue_free()
	for i in cap:
		var d := Panel.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.7, 0.45, 1.0) if i < oz else Color(0.15, 0.1, 0.2, 0.9)
		s.border_color = Color(0.85, 0.7, 1.0, 0.9) if i < oz else Color(0.4, 0.3, 0.5, 0.9)
		s.set_border_width_all(2)
		s.set_corner_radius_all(9)
		if i < oz:
			s.shadow_color = Color(0.6, 0.35, 1.0, 0.7)
			s.shadow_size = 6
		d.add_theme_stylebox_override("panel", s)
		d.custom_minimum_size = Vector2(22, 22)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		oz_box.add_child(d)

func _on_form(def: CreatureDef) -> void:
	if def == null:
		return
	portrait.texture = def.texture
	form_name.text = def.display_name
	var ps := portrait_ring.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	ps.border_color = def.accent
	portrait_ring.add_theme_stylebox_override("panel", ps)
	var tw := create_tween()
	portrait_ring.pivot_offset = portrait_ring.size * 0.5
	portrait_ring.scale = Vector2(1.25, 1.25)
	tw.tween_property(portrait_ring, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(_delta: float) -> void:
	if level == null:
		return
	timer_label.text = Game.format_time(level.time)
	var p := level.player
	if p == null:
		return
	_update_ab(ab1, Abilities.primary_of(p))
	_update_ab(ab2, Abilities.secondary_of(p))
	_radial_input()
	if Input.is_action_just_pressed("pause") and complete_panel == null:
		toggle_pause()
	if Input.is_action_just_pressed("revert") and not get_tree().paused and level.running and not level.finished:
		level.essence.revert()

func _update_ab(w: Control, a: Ability) -> void:
	w.visible = a != null
	if a == null:
		return
	(w.get_node("Name") as Label).text = _ability_name(a.id)
	(w.get_node("CD") as ProgressBar).value = a.ready_ratio()

func _ability_name(id: String) -> String:
	var n := {
		"tongue_grapple": ["Dil Kancası", "Tongue Grapple"], "dive_attack_height_scaled": ["Dalış", "Dive"], "echolocation_reveal": ["Ekolokasyon", "Echolocation"],
		"camouflage_stealth": ["Kamuflaj", "Camouflage"], "tongue_pull_items": ["Dil Çekişi", "Tongue Pull"], "roll_form": ["Yuvarlan", "Roll"],
		"split_clone": ["Bölün", "Split"], "clone_sacrifice": ["Klonu Patlat", "Pop Clone"], "electric_field_aoe_water": ["Elektrik", "Shock"],
		"antler_charge_break_walls": ["Boynuz Hücumu", "Antler Charge"], "ink_blind": ["Mürekkep", "Ink"], "summon_pack_10s": ["Sürü Çağrısı", "Pack Call"],
		"grab_carry_drop": ["Kap / Bırak", "Grab / Drop"], "roar_stun": ["Kükreme", "Roar"], "fire_breath_aoe": ["Alev Nefesi", "Fire Breath"],
		"web_bridge": ["Ağ Köprüsü", "Web Bridge"], "web_trap": ["Ağ Tuzağı", "Web Trap"], "parry_reflect": ["Savuştur", "Parry"],
		"burrow": ["Gömül", "Burrow"], "pit_trap": ["Çukur", "Pit Trap"],
	}
	var e = n.get(id)
	if e == null:
		return id
	return e[0] if Game.lang == "tr" else e[1]

func _build_radial() -> void:
	radial = Control.new()
	radial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radial.visible = false
	root.add_child(radial)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radial.add_child(dim)
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radial.add_child(center)
	var n := Creatures.all.size()
	for i in n:
		var def: CreatureDef = Creatures.all[i]
		var a := -PI * 0.5 + TAU * i / n
		var r := 390.0
		var item := Panel.new()
		item.size = Vector2(104, 104)
		item.position = Vector2(cos(a), sin(a)) * r - item.size * 0.5
		item.pivot_offset = item.size * 0.5
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.texture = def.texture
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(10, 8)
		tr.size = Vector2(84, 78)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(tr)
		var cost := _label(str(def.oz_cost), 20, DISPLAY_FONT, Color(0.85, 0.7, 1.0))
		cost.position = Vector2(0, 76)
		cost.size = Vector2(104, 26)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(cost)
		center.add_child(item)
		radial_items.append(item)
	radial_name = _label("", 54, TITLE_FONT, GOLD)
	radial_name.position = Vector2(-300, -120)
	radial_name.size = Vector2(600, 70)
	radial_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(radial_name)
	radial_stats = _label("", 22, null, Color(0.85, 0.78, 0.95))
	radial_stats.position = Vector2(-300, -48)
	radial_stats.size = Vector2(600, 34)
	radial_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(radial_stats)
	radial_info = _label("", 24)
	radial_info.position = Vector2(-260, -6)
	radial_info.size = Vector2(520, 140)
	radial_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radial_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(radial_info)

func _radial_input() -> void:
	if level == null or level.finished or get_tree().paused:
		return
	var held := Input.is_action_pressed("forms")
	if held and not radial.visible:
		radial.visible = true
		Fx.slowmo(0.12)
		radial_sel = Creatures.all.find(level.essence.current())
		_refresh_radial()
		Audio.play("whoosh", -10.0)
	elif not held and radial.visible:
		radial.visible = false
		Fx.slowmo(1.0)
		if radial_sel >= 0:
			level.essence.transform_to(Creatures.all[radial_sel])
	if not radial.visible:
		return
	var v := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
	var mouse := root.get_global_mouse_position() - root.size * 0.5
	if v.length() < 0.4 and mouse.length() > 140.0:
		v = mouse
	if v.length() > 0.3:
		var a := fposmod(v.angle() + PI * 0.5, TAU)
		var i := int(round(a / TAU * Creatures.all.size())) % Creatures.all.size()
		if i != radial_sel:
			radial_sel = i
			_refresh_radial()
			Audio.play("hover", -14.0)

func _refresh_radial() -> void:
	for i in radial_items.size():
		var def: CreatureDef = Creatures.all[i]
		var item: Panel = radial_items[i]
		var ok := level.essence.can_afford(def)
		var cur := def == level.essence.current()
		var s := _panel(52, Color(0.12, 0.08, 0.16, 0.95), def.accent if i == radial_sel else Color(0.35, 0.25, 0.45))
		s.set_border_width_all(4 if i == radial_sel else 2)
		if cur:
			s.bg_color = Color(0.25, 0.18, 0.08, 0.95)
		item.add_theme_stylebox_override("panel", s)
		item.modulate = Color.WHITE if ok else Color(0.45, 0.42, 0.5, 0.8)
		item.scale = Vector2(1.18, 1.18) if i == radial_sel else Vector2.ONE
	if radial_sel < 0:
		return
	var d: CreatureDef = Creatures.all[radial_sel]
	radial_name.text = d.display_name
	radial_name.add_theme_color_override("font_color", d.accent)
	var cost := Game.t("free") if d == Creatures.fallback() else "%s %d" % [Game.t("cost"), d.oz_cost]
	radial_stats.text = "%s %d  ·  %s  ·  %s %d  %s %d  %s %d" % [Game.t("tier"), d.tier, cost, Game.t("hp"), d.hp, Game.t("dmg"), d.damage, Game.t("spd"), d.speed]
	radial_info.text = d.ability_text + "\n" + d.blurb
	if not level.essence.can_afford(d):
		radial_info.text += "\n" + Game.t("need_oz")

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.05, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(520, 0)
	box.position = Vector2(-260, -230)
	pause_panel.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	box.add_child(v)
	var t := _label(Game.t("paused"), 64, TITLE_FONT, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for pair in [["resume", toggle_pause], ["restart", func(): level.restart()], ["menu", func(): Transition.go("res://game/ui/main_menu.tscn")]]:
		var b := Button.new()
		b.text = Game.t(pair[0])
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(pair[1])
		b.mouse_entered.connect(Audio.play.bind("hover", -14.0))
		v.add_child(b)

func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	if p:
		Fx.slowmo(1.0)
		radial.visible = false
		var first := pause_panel.find_children("*", "Button", true, false)
		if first.size() > 0:
			first[0].grab_focus()
	Audio.play("click", -6.0)

func show_complete(stats: Dictionary) -> void:
	complete_panel = Control.new()
	complete_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(complete_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.05, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	complete_panel.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.7, 0.5)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(640, 0)
	box.position = Vector2(-320, -260)
	complete_panel.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)
	var t := _label(Game.t("game_done") if stats.last else Game.t("level_done"), 60, TITLE_FONT, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for row in [[Game.t("time"), Game.format_time(stats.time)], [Game.t("deaths"), str(stats.deaths)], [Game.t("collected"), str(stats.oz)]]:
		var h := HBoxContainer.new()
		var a := _label(row[0], 28)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(_label(row[1], 28, DISPLAY_FONT, Color("ffe7b0")))
		v.add_child(h)
	var nb := Button.new()
	nb.text = Game.t("menu") if stats.last else Game.t("next")
	nb.custom_minimum_size = Vector2(0, 66)
	nb.pressed.connect(level.next_level)
	v.add_child(nb)
	var mb := Button.new()
	mb.text = Game.t("menu")
	mb.custom_minimum_size = Vector2(0, 60)
	mb.pressed.connect(func(): Transition.go("res://game/ui/main_menu.tscn"))
	mb.visible = not stats.last
	v.add_child(mb)
	box.pivot_offset = Vector2(320, 260)
	box.scale = Vector2(0.85, 0.85)
	box.modulate.a = 0.0
	var tw := box.create_tween().set_parallel(true)
	tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.25)
	nb.grab_focus()
