extends CanvasLayer

const COLORS := [Color(0.55, 0.8, 1.0), Color(1.0, 0.55, 0.5)]

var arena: Arena
var root: Control
var bars: Array = []
var pips: Array = []
var center_label: Label
var sub_label: Label
var end_panel: Control
var pause_panel: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	center_label = UI.label("", 150, UI.TITLE_FONT, UI.GOLD)
	center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_label.position = Vector2(-800, -200)
	center_label.size = Vector2(1600, 200)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.pivot_offset = Vector2(800, 100)
	root.add_child(center_label)
	sub_label = UI.label("", 36)
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub_label.position = Vector2(-800, 10)
	sub_label.size = Vector2(1600, 60)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub_label)

func bind(a: Arena) -> void:
	arena = a
	for i in 2:
		_build_side(i)
		a.fighters[i].hp_changed.connect(_on_hp.bind(i))
		_on_hp(a.fighters[i].hp, a.fighters[i].max_hp, i)

func _build_side(i: int) -> void:
	var f: Creature = arena.fighters[i]
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UI.panel(20, Color(0.1, 0.07, 0.13, 0.85), COLORS[i]))
	box.size = Vector2(720, 120)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if i == 0:
		box.position = Vector2(30, 24)
	else:
		box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		box.position = Vector2(-750, 24)
	root.add_child(box)
	var por := TextureRect.new()
	por.texture = f.def.texture
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	por.size = Vector2(96, 96)
	por.position = Vector2(12, 12) if i == 0 else Vector2(612, 12)
	por.flip_h = i == 1
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(por)
	var who := ""
	match arena.mode:
		"local":
			who = Game.t("p1") if i == 0 else Game.t("p2")
		"online":
			who = Net.name_of(i)
		_:
			who = Game.t("p1") if i == 0 else Game.t("cpu")
	var nm := UI.label("%s · %s" % [who, f.def.display_name], 26, UI.TITLE_FONT, COLORS[i])
	nm.position = Vector2(124, 10) if i == 0 else Vector2(24, 10)
	nm.size = Vector2(570, 36)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(nm)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size = Vector2(570, 30)
	bar.position = Vector2(124, 52) if i == 0 else Vector2(24, 52)
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = COLORS[i]
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	bars.append(bar)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	ph.position = Vector2(124, 90) if i == 0 else Vector2(640 - 2 * 30, 90)
	box.add_child(ph)
	var arr := []
	for k in Arena.WINS_NEEDED:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(22, 22)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.add_child(p)
		arr.append(p)
	pips.append(arr)
	_paint_pips(i, 0)

func _paint_pips(i: int, w: int) -> void:
	for k in pips[i].size():
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(11)
		s.bg_color = UI.GOLD if k < w else Color(1, 1, 1, 0.1)
		s.border_color = Color(1, 1, 1, 0.3)
		s.set_border_width_all(2)
		pips[i][k].add_theme_stylebox_override("panel", s)

func _on_hp(hp: int, mx: int, i: int) -> void:
	var bar: ProgressBar = bars[i]
	bar.max_value = mx
	create_tween().tween_property(bar, "value", float(hp), 0.15)

func _flash_text(t: String, sub := "", color := UI.GOLD) -> void:
	center_label.text = t
	center_label.add_theme_color_override("font_color", color)
	sub_label.text = sub
	center_label.scale = Vector2(1.6, 1.6)
	center_label.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(center_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(center_label, "modulate:a", 1.0, 0.12)

func countdown(r: int) -> void:
	for n in ["3", "2", "1"]:
		_flash_text(n, "%s %d" % [Game.t("round"), r], Color(1, 1, 1))
		Audio.play("countdown", -6.0, 0.0)
		await get_tree().create_timer(0.85).timeout
	_flash_text(Game.t("fight"), "", UI.GOLD)
	Audio.play("explosion", -8.0, 0.0)
	await get_tree().create_timer(0.8).timeout
	var tw := create_tween()
	tw.tween_property(center_label, "modulate:a", 0.0, 0.3)
	sub_label.text = ""

func ko(winner: int, wins: Array) -> void:
	_flash_text("K.O.", "", COLORS[winner])
	for i in 2:
		_paint_pips(i, wins[i])

func show_winner(w: int) -> void:
	var who := ""
	match arena.mode:
		"local":
			who = Game.t("p1") if w == 0 else Game.t("p2")
		"online":
			who = Net.name_of(w)
		_:
			who = Game.t("p1") if w == 0 else Game.t("cpu")
	var headline := "%s %s" % [who, Game.t("wins")]
	if arena.mode == "cpu" or arena.mode == "online":
		headline = Game.t("victory") if w == arena.my_slot else Game.t("defeat")
	_flash_text(headline, arena.fighters[w].def.display_name, COLORS[w])
	end_panel = HBoxContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-330, 120)
	end_panel.add_theme_constant_override("separation", 20)
	root.add_child(end_panel)
	var a := UI.button(Game.t("rematch"), arena.rematch, 320, 70)
	if arena.mode == "online":
		a.text = Game.t("find_match")
	end_panel.add_child(a)
	end_panel.add_child(UI.button(Game.t("back"), arena.leave, 320, 70))
	a.grab_focus()

func opponent_left() -> void:
	_flash_text(Game.t("opponent_left"), "", UI.MUTED)
	var b := UI.button(Game.t("back"), arena.leave, 320, 70)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.position = Vector2(-160, 120)
	root.add_child(b)
	b.grab_focus()

func _process(_d: float) -> void:
	if Input.is_action_just_pressed("pause") and arena != null and not arena.match_over and arena.mode != "online":
		_toggle_pause()

func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	if p:
		pause_panel = Control.new()
		pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(pause_panel)
		var dim := ColorRect.new()
		dim.color = Color(0.03, 0.01, 0.05, 0.7)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pause_panel.add_child(dim)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_CENTER)
		v.position = Vector2(-220, -120)
		v.add_theme_constant_override("separation", 16)
		pause_panel.add_child(v)
		var t := UI.title(Game.t("paused"), 64)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var r := UI.button(Game.t("resume"), _toggle_pause, 440, 64)
		v.add_child(r)
		v.add_child(UI.button(Game.t("back"), arena.leave, 440, 64))
		r.grab_focus()
	elif pause_panel != null:
		pause_panel.queue_free()
