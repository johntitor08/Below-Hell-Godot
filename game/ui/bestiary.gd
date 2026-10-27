extends Control

var _grid: GridContainer
var _art: TextureRect
var _name: Label
var _sub: Label
var _ability: Label
var _blurb: Label
var _stats: VBoxContainer
var _glow: TextureRect
var _sel := 0
var _t := 0.0

func _ready() -> void:
	UI.backdrop(self, "graveyard", 0.72)
	var t := UI.title(Game.t("bestiary"), 76)
	t.position = Vector2(80, 40)
	add_child(t)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UI.panel(20))
	left.position = Vector2(70, 160)
	left.size = Vector2(760, 840)
	add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	left.add_child(_grid)
	for i in Creatures.all.size():
		var d: CreatureDef = Creatures.all[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 180)
		b.icon = d.texture
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = "%d" % d.oz_cost
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("icon_max_width", 110)
		var idx := i
		var pick := func():
			_select(idx)
			Audio.play("hover", -12.0)
		b.focus_entered.connect(pick)
		b.mouse_entered.connect(b.grab_focus)
		_grid.add_child(b)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UI.panel(20))
	right.position = Vector2(870, 160)
	right.size = Vector2(980, 840)
	add_child(right)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(940, 800)
	right.add_child(stage)
	_glow = TextureRect.new()
	_glow.texture = Fx.soft_tex
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.position = Vector2(40, 0)
	_glow.size = Vector2(440, 440)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.position = Vector2(60, 30)
	_art.size = Vector2(400, 380)
	_art.pivot_offset = Vector2(200, 380)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_art)
	_name = UI.label("", 64, UI.TITLE_FONT, UI.GOLD)
	_name.position = Vector2(500, 40)
	stage.add_child(_name)
	_sub = UI.label("", 24, null, UI.MUTED)
	_sub.position = Vector2(504, 130)
	stage.add_child(_sub)
	_stats = VBoxContainer.new()
	_stats.position = Vector2(504, 190)
	_stats.add_theme_constant_override("separation", 12)
	stage.add_child(_stats)
	_ability = UI.label("", 28)
	_ability.position = Vector2(40, 460)
	_ability.size = Vector2(860, 120)
	_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_ability)
	_blurb = UI.label("", 24, null, UI.MUTED)
	_blurb.position = Vector2(40, 580)
	_blurb.size = Vector2(860, 100)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_blurb)
	var back := UI.button(Game.t("back"), _back, 240, 60)
	back.position = Vector2(80, 1010)
	add_child(back)
	_select(0)
	(_grid.get_child(0) as Button).grab_focus.call_deferred()

func _select(i: int) -> void:
	_sel = i
	var d: CreatureDef = Creatures.all[i]
	_art.texture = d.texture
	_glow.modulate = Color(d.accent, 0.45)
	_name.text = d.display_name
	_name.add_theme_color_override("font_color", d.accent)
	var cost := Game.t("free") if d == Creatures.fallback() else "%s %d %s" % [Game.t("cost"), d.oz_cost, Game.t("oz")]
	_sub.text = "%s %s  ·  %s" % [Game.t("tier"), ["I", "II", "III", "IV"][clampi(d.tier - 1, 0, 3)], cost]
	for c in _stats.get_children():
		c.queue_free()
	_stats.add_child(UI.stat_bar(Game.t("hp"), d.hp, Color(0.9, 0.35, 0.35)))
	_stats.add_child(UI.stat_bar(Game.t("dmg"), d.damage, Color(1, 0.65, 0.3)))
	_stats.add_child(UI.stat_bar(Game.t("spd"), d.speed, Color(0.45, 0.8, 1)))
	if d.flight:
		_stats.add_child(UI.label("◆ " + Game.t("flight"), 24, null, Color(0.75, 0.85, 1)))
	else:
		_stats.add_child(UI.stat_bar(Game.t("jmp"), d.jump, Color(0.55, 1, 0.55)))
	_ability.text = d.ability_text
	_blurb.text = d.blurb
	_art.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(_art, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_t += delta
	if _art != null:
		_art.rotation = sin(_t * 1.6) * 0.02
		_glow.modulate.a = 0.38 + sin(_t * 2.0) * 0.08

func _back() -> void:
	Transition.go("res://game/ui/main_menu.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		_back()
