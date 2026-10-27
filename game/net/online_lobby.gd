extends Control

var form_id := "06-kurbaga"
var _left: VBoxContainer
var _status: Label
var _board: VBoxContainer
var _user: LineEdit
var _pass: LineEdit
var _addr: LineEdit
var _searching := false

func _ready() -> void:
	UI.backdrop(self, "mountain", 0.7)
	Audio.music("arena")
	var cfg: Dictionary = Game.get_meta("arena") if Game.has_meta("arena") else {}
	form_id = str(cfg.get("p1", form_id))
	var t := UI.title(Game.t("online"), 80)
	t.position = Vector2(80, 40)
	add_child(t)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UI.panel(20))
	lp.position = Vector2(80, 170)
	lp.custom_minimum_size = Vector2(760, 760)
	add_child(lp)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 16)
	lp.add_child(_left)
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.panel(20))
	rp.position = Vector2(900, 170)
	rp.custom_minimum_size = Vector2(940, 760)
	add_child(rp)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 10)
	rp.add_child(_board)
	_status = UI.label("", 26, null, Color(1, 0.75, 0.6))
	_status.position = Vector2(84, 950)
	add_child(_status)
	var back := UI.button(Game.t("back"), _back, 260, 60)
	back.position = Vector2(1580, 960)
	add_child(back)
	Net.status_changed.connect(_on_status)
	Net.auth_done.connect(_on_auth)
	Net.connection_changed.connect(_on_conn)
	Net.match_found.connect(_on_match)
	Net.leaderboard_received.connect(_on_board)
	_board.add_child(UI.label(Game.t("leaderboard"), 40, UI.TITLE_FONT, UI.GOLD))
	if Net.connected and Net.username != "":
		_show_account()
		Net.request_leaderboard()
	elif Net.connected:
		_show_login()
	else:
		_show_connect()

func _clear_left() -> void:
	for c in _left.get_children():
		c.queue_free()

func _show_connect() -> void:
	_clear_left()
	_left.add_child(UI.label(Game.t("server"), 30, UI.TITLE_FONT, UI.GOLD))
	_addr = LineEdit.new()
	_addr.text = Net.host_address()
	_addr.custom_minimum_size = Vector2(0, 60)
	_addr.add_theme_font_size_override("font_size", 26)
	_left.add_child(_addr)
	var b := UI.button(Game.t("connect"), _connect, 0, 64)
	_left.add_child(b)
	_left.add_child(UI.label("Sunucu: ./sunucu.sh  ·  Server: ./sunucu.sh", 20, null, UI.MUTED))
	b.grab_focus.call_deferred()

func _connect() -> void:
	Game.settings["server"] = _addr.text.strip_edges()
	Game.save_settings()
	Net.connect_to_server()

func _on_conn(online: bool) -> void:
	if online:
		_show_login()
	else:
		_show_connect()

func _show_login() -> void:
	_clear_left()
	_left.add_child(UI.label(Game.t("login"), 34, UI.TITLE_FONT, UI.GOLD))
	_user = LineEdit.new()
	_user.placeholder_text = Game.t("username")
	_user.text = str(Game.settings.get("last_user", ""))
	_user.max_length = 16
	_user.custom_minimum_size = Vector2(0, 60)
	_user.add_theme_font_size_override("font_size", 26)
	_left.add_child(_user)
	_pass = LineEdit.new()
	_pass.placeholder_text = Game.t("password")
	_pass.secret = true
	_pass.custom_minimum_size = Vector2(0, 60)
	_pass.add_theme_font_size_override("font_size", 26)
	var submit := func(_t): _login()
	_pass.text_submitted.connect(submit)
	_left.add_child(_pass)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var lb := UI.button(Game.t("login"), _login, 340, 64)
	h.add_child(lb)
	h.add_child(UI.button(Game.t("register"), _register, 340, 64))
	_left.add_child(h)
	if _user.text == "":
		_user.grab_focus.call_deferred()
	else:
		_pass.grab_focus.call_deferred()
	Net.request_leaderboard()

func _creds_ok() -> bool:
	if _user.text.strip_edges().length() < 3:
		_on_status(Game.t("err_name"))
		return false
	if _pass.text.length() < 6:
		_on_status(Game.t("err_short"))
		return false
	return true

func _login() -> void:
	if _creds_ok():
		Net.login(_user.text.strip_edges(), _pass.text)

func _register() -> void:
	if _creds_ok():
		Net.register(_user.text.strip_edges(), _pass.text)

func _on_auth(ok: bool, msg: String) -> void:
	if not ok:
		_on_status(Game.t("err_" + msg) if Game.TEXT.has("err_" + msg) else msg)
		return
	Game.settings["last_user"] = Net.username
	Game.save_settings()
	_on_status("")
	_show_account()
	Net.request_leaderboard()

func _show_account() -> void:
	_clear_left()
	_left.add_child(UI.label("%s %s" % [Game.t("logged_in_as"), Net.username], 30, UI.TITLE_FONT, UI.GOLD))
	_left.add_child(UI.label("%s: %d / %d" % [Game.t("record"), int(Net.stats.get("wins", 0)), int(Net.stats.get("losses", 0))], 26))
	var d := Creatures.get_def(form_id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var tr := TextureRect.new()
	tr.texture = d.texture
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(220, 220)
	h.add_child(tr)
	var v := VBoxContainer.new()
	v.add_child(UI.label(d.display_name, 44, UI.TITLE_FONT, d.accent))
	v.add_child(UI.button(Game.t("pick"), func(): Transition.go("res://game/arena/arena_menu.tscn"), 320, 56))
	h.add_child(v)
	_left.add_child(h)
	var fb := UI.button(Game.t("find_match"), _toggle_search, 0, 76)
	fb.add_theme_font_size_override("font_size", 32)
	fb.name = "Find"
	_left.add_child(fb)
	fb.grab_focus.call_deferred()

func _toggle_search() -> void:
	var fb := _left.get_node_or_null("Find") as Button
	if _searching:
		_searching = false
		Net.cancel_match()
		_on_status("")
		if fb != null:
			fb.text = Game.t("find_match")
		return
	_searching = true
	Net.find_match(form_id)
	_on_status(Game.t("searching"))
	if fb != null:
		fb.text = Game.t("cancel")

func _on_match(info: Dictionary) -> void:
	_searching = false
	Audio.play("bonus", 0.0, 0.0)
	Game.set_meta("arena", {"mode": "online", "p1": form_id})
	_on_status("%s  vs  %s" % [info.names[0], info.names[1]])
	await get_tree().create_timer(0.8).timeout
	Transition.go("res://game/arena/arena.tscn")

func _on_board(data: Dictionary) -> void:
	for c in _board.get_children():
		c.queue_free()
	_board.add_child(UI.label(Game.t("leaderboard"), 40, UI.TITLE_FONT, UI.GOLD))
	_board.add_child(UI.label(Game.t("arena_top"), 26, null, UI.MUTED))
	var rank := 1
	for r in data.get("arena", []):
		_board.add_child(_row("%d. %s" % [rank, r[0]], "%d / %d" % [r[1], r[2]]))
		rank += 1
	if data.get("arena", []).is_empty():
		_board.add_child(UI.label("—", 24, null, UI.MUTED))
	_board.add_child(UI.label(Game.t("best_times"), 26, null, UI.MUTED))
	var times: Dictionary = data.get("times", {})
	for lv in range(Level.LEVELS.size()):
		var lst: Array = times.get(str(lv), [])
		if lst.is_empty():
			continue
		_board.add_child(_row("%s · %s" % [["I", "II", "III", "IV", "V"][lv], lst[0][0]], Game.format_time(float(lst[0][1]))))

func _row(a: String, b: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UI.label(a, 24)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UI.label(b, 24, UI.DISPLAY_FONT, Color("ffe7b0")))
	return h

func _on_status(t: String) -> void:
	if is_instance_valid(_status):
		_status.text = t

func _back() -> void:
	if _searching:
		Net.cancel_match()
	Transition.go("res://game/arena/arena_menu.tscn")
