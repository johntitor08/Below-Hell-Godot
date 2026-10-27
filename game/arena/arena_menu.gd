extends Control

var mode := ""
var step := 0
var picks: Array = [null, null]
var _layer: Control
var _grid: GridContainer
var _preview: TextureRect
var _pname: Label
var _pinfo: Label
var _who: Label
var _hover := 0

func _ready() -> void:
	UI.backdrop(self, "snow", 0.66)
	Audio.music("arena")
	var t := UI.title(Game.t("arena"), 84)
	t.position = Vector2(80, 40)
	add_child(t)
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_show_modes()

func _clear() -> void:
	for c in _layer.get_children():
		c.queue_free()

func _show_modes() -> void:
	_clear()
	step = 0
	var v := VBoxContainer.new()
	v.position = Vector2(120, 260)
	v.add_theme_constant_override("separation", 18)
	_layer.add_child(v)
	var items := [["vs_cpu", "cpu", "Tek oyunculu · bilgisayara karşı üç raund", "Solo · three rounds against the computer"],
		["local", "local", "Aynı klavyede iki oyuncu · WASD+F/G ↔ Oklar+./,", "Two players, one keyboard · WASD+F/G vs Arrows+./,"],
		["online", "online", "İnternet üzerinden rakip bul", "Find an opponent over the internet"]]
	var first: Button = null
	for it in items:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 26)
		var m: String = it[1]
		var b := UI.button(Game.t(it[0]), _choose_mode.bind(m), 420, 76)
		b.add_theme_font_size_override("font_size", 32)
		h.add_child(b)
		var d := UI.label(it[2] if Game.lang == "tr" else it[3], 24, null, UI.MUTED)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(d)
		v.add_child(h)
		if first == null:
			first = b
	var back := UI.button(Game.t("back"), func(): Transition.go("res://game/ui/main_menu.tscn"), 260, 60)
	back.position = Vector2(120, 960)
	_layer.add_child(back)
	first.grab_focus.call_deferred()

func _choose_mode(m: String) -> void:
	mode = m
	picks = [null, null]
	if m == "online":
		Game.set_meta("arena", {"mode": "online"})
		_show_picker(0)
		return
	_show_picker(0)

func _show_picker(who: int) -> void:
	_clear()
	step = who + 1
	_who = UI.label("", 40, UI.TITLE_FONT, Color(0.55, 0.8, 1) if who == 0 else Color(1, 0.55, 0.5))
	_who.text = "%s · %s" % [Game.t("p1") if who == 0 else (Game.t("p2") if mode == "local" else Game.t("cpu")), Game.t("pick")]
	_who.position = Vector2(84, 160)
	_layer.add_child(_who)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel(20))
	panel.position = Vector2(70, 230)
	_layer.add_child(panel)
	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(_grid)
	for i in Creatures.all.size():
		var d: CreatureDef = Creatures.all[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 150)
		b.icon = d.texture
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 130)
		var idx := i
		var hover := func():
			_preview_pick(idx)
		b.focus_entered.connect(hover)
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_confirm.bind(idx))
		_grid.add_child(b)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.position = Vector2(120, 600)
	_preview.size = Vector2(380, 380)
	if who == 1:
		_preview.flip_h = true
	_layer.add_child(_preview)
	_pname = UI.label("", 64, UI.TITLE_FONT, UI.GOLD)
	_pname.position = Vector2(560, 620)
	_layer.add_child(_pname)
	_pinfo = UI.label("", 26)
	_pinfo.position = Vector2(564, 720)
	_pinfo.size = Vector2(1200, 200)
	_pinfo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layer.add_child(_pinfo)
	var back := UI.button(Game.t("back"), _show_modes, 260, 60)
	back.position = Vector2(1580, 960)
	_layer.add_child(back)
	var rnd := UI.button("?", _confirm.bind(-1), 120, 60)
	rnd.position = Vector2(1440, 960)
	_layer.add_child(rnd)
	var start := _hover if who == 0 else randi() % Creatures.all.size()
	(_grid.get_child(start) as Button).grab_focus.call_deferred()
	if who == 1 and mode == "cpu":
		_cpu_pick.call_deferred()

func _cpu_pick() -> void:
	var b := _grid.get_child(0) as Button
	for i in 8:
		var idx := randi() % Creatures.all.size()
		(_grid.get_child(idx) as Button).grab_focus()
		Audio.play("hover", -12.0)
		await get_tree().create_timer(0.09 + i * 0.03).timeout
		b = _grid.get_child(idx) as Button
	await get_tree().create_timer(0.35).timeout
	b.pressed.emit()

func _preview_pick(i: int) -> void:
	_hover = i
	var d: CreatureDef = Creatures.all[i]
	_preview.texture = d.texture
	_pname.text = d.display_name
	_pname.add_theme_color_override("font_color", d.accent)
	var st := "%s %d   %s %d   %s %d   %s" % [Game.t("hp"), d.hp, Game.t("dmg"), d.damage, Game.t("spd"), d.speed, ("◆ " + Game.t("flight")) if d.flight else "%s %d" % [Game.t("jmp"), d.jump]]
	_pinfo.text = st + "\n" + d.ability_text
	Audio.play("hover", -16.0)

func _confirm(i: int) -> void:
	if i < 0:
		i = randi() % Creatures.all.size()
	var who := step - 1
	picks[who] = Creatures.all[i].id
	Audio.play("spawn", -4.0)
	Fx.slowmo(1.0)
	if mode == "online":
		Game.set_meta("arena", {"mode": "online", "p1": picks[0]})
		Transition.go("res://game/net/online_lobby.tscn")
		return
	if who == 0:
		_show_picker(1)
		return
	Game.set_meta("arena", {"mode": mode, "p1": picks[0], "p2": picks[1]})
	Transition.go("res://game/arena/arena.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		if step == 0:
			Transition.go("res://game/ui/main_menu.tscn")
		else:
			_show_modes()
