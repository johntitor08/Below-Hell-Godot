extends Node

signal language_changed
signal settings_changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"

var lang := "tr"
var settings := {"master": 0.9, "music": 0.7, "sfx": 0.9, "fullscreen": false, "shake": true}
var save := {"level": 0, "oz_cap": 6, "oz": 0, "best": {}, "seen": []}

const KEYS := {
	"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE], "attack": [KEY_J, KEY_Z], "ability": [KEY_K, KEY_X], "ability2": [KEY_L, KEY_V],
	"forms": [KEY_Q, KEY_TAB], "revert": [KEY_R], "pause": [KEY_ESCAPE, KEY_P],
}
const PADS := {
	"left": [[JOY_AXIS_LEFT_X, -1]], "right": [[JOY_AXIS_LEFT_X, 1]], "up": [[JOY_AXIS_LEFT_Y, -1]], "down": [[JOY_AXIS_LEFT_Y, 1]],
	"jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "ability": [JOY_BUTTON_B], "ability2": [JOY_BUTTON_Y],
	"forms": [JOY_BUTTON_LEFT_SHOULDER], "revert": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START],
}
const P2_KEYS := {
	"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
	"jump": [KEY_KP_0, KEY_ENTER], "attack": [KEY_KP_1, KEY_PERIOD], "ability": [KEY_KP_2, KEY_COMMA], "ability2": [KEY_KP_3, KEY_SLASH],
}
const P1_ARENA_KEYS := {
	"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
	"jump": [KEY_SPACE], "attack": [KEY_F], "ability": [KEY_G], "ability2": [KEY_H],
}

const TEXT := {
	"play": ["Maceraya Başla", "Start Adventure"], "continue": ["Devam Et", "Continue"], "arena": ["Arena", "Arena"],
	"bestiary": ["Bestiyer", "Bestiary"], "settings": ["Ayarlar", "Settings"], "quit": ["Çıkış", "Quit"],
	"online": ["Online Arena", "Online Arena"], "local": ["Yerel Düello", "Local Duel"], "vs_cpu": ["Bilgisayara Karşı", "Versus CPU"],
	"back": ["Geri", "Back"], "resume": ["Devam", "Resume"], "restart": ["Yeniden Başla", "Restart"], "menu": ["Ana Menü", "Main Menu"],
	"paused": ["Duraklatıldı", "Paused"], "oz": ["Öz", "Essence"], "cost": ["Bedel", "Cost"], "free": ["Bedava", "Free"],
	"level_done": ["Bölüm Tamamlandı", "Level Complete"], "game_done": ["Cehennemden Çıktın", "You Escaped Below Hell"],
	"tier": ["Kademe", "Tier"], "hp": ["Can", "Health"], "dmg": ["Hasar", "Damage"], "spd": ["Hız", "Speed"], "jmp": ["Zıplama", "Jump"],
	"flight": ["Uçuş", "Flight"], "locked": ["Kilitli", "Locked"], "transform_hint": ["Q basılı tut: dönüş", "Hold Q: transform"],
	"revert_hint": ["R: formu bırak (yarı iade)", "R: drop form (half refund)"], "need_oz": ["Yeterli Öz yok", "Not enough Essence"],
	"cap_full": ["Öz kesesi dolu", "Essence pouch full"], "checkpoint": ["Kontrol noktası", "Checkpoint"],
	"round": ["Raund", "Round"], "fight": ["DÖVÜŞ!", "FIGHT!"], "wins": ["kazandı", "wins"], "pick": ["Formunu seç", "Choose your form"],
	"ready": ["Hazır", "Ready"], "language": ["Dil", "Language"], "master": ["Ana ses", "Master volume"], "music": ["Müzik", "Music"],
	"sfx": ["Efektler", "Effects"], "fullscreen": ["Tam ekran", "Fullscreen"], "shake": ["Ekran sarsıntısı", "Screen shake"],
	"controls": ["Kontroller", "Controls"], "time": ["Süre", "Time"], "deaths": ["Ölüm", "Deaths"], "collected": ["Toplanan Öz", "Essence collected"],
	"next": ["Sonraki Bölüm", "Next Level"], "username": ["Kullanıcı adı", "Username"], "password": ["Şifre", "Password"],
	"login": ["Giriş", "Log in"], "register": ["Kayıt ol", "Sign up"], "leaderboard": ["Liderlik", "Leaderboard"],
	"find_match": ["Eşleşme Bul", "Find Match"], "searching": ["Rakip aranıyor…", "Searching for an opponent…"],
	"offline": ["Sunucuya bağlanılamadı", "Couldn't reach the server"], "cancel": ["İptal", "Cancel"], "p1": ["Oyuncu 1", "Player 1"],
	"p2": ["Oyuncu 2", "Player 2"], "cpu": ["Bilgisayar", "CPU"], "victory": ["Zafer", "Victory"], "defeat": ["Yenilgi", "Defeat"],
	"rematch": ["Rövanş", "Rematch"], "boss_down": ["Bekçi düştü · kapı açıldı", "The warden falls · the gate opens"],
	"boss_first": ["Önce bekçiyi yen", "Defeat the warden first"], "no_room": ["Bu forma burada yer yok", "No room for that form here"], "opponent_left": ["Rakip ayrıldı", "Opponent left"],
	"logged_in_as": ["Giriş yapıldı:", "Signed in as"], "record": ["Galibiyet / Mağlubiyet", "Wins / Losses"], "server": ["Sunucu", "Server"],
	"err_name": ["Kullanıcı adı 3-16 harf/rakam olmalı", "Username must be 3-16 letters/digits"], "err_taken": ["Bu ad alınmış", "That name is taken"],
	"err_bad": ["Kullanıcı adı ya da şifre yanlış", "Wrong username or password"], "err_short": ["Şifre en az 6 karakter olmalı", "Password must be at least 6 characters"],
	"best_times": ["En iyi süreler", "Best times"], "arena_top": ["Arena · en çok galibiyet", "Arena · most wins"], "connect": ["Bağlan", "Connect"], "tagline": ["Öz topla. Dönüş. Yukarı tırman.", "Gather Essence. Transform. Climb out."],
}

func t(key: String) -> String:
	var e = TEXT.get(key)
	if e == null:
		return key
	return e[0] if lang == "tr" else e[1]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_load_save()
	_setup_input()
	apply_settings()

func _setup_input() -> void:
	for a in KEYS:
		_add_action(a, KEYS[a], PADS.get(a, []), 0)
	for a in P1_ARENA_KEYS:
		_add_action("p1_" + a, P1_ARENA_KEYS[a], PADS.get(a, []), 0)
	for a in P2_KEYS:
		_add_action("p2_" + a, P2_KEYS[a], PADS.get(a, []), 1)
	if not InputMap.has_action("click"):
		InputMap.add_action("click")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("click", mb)

func _add_action(name: String, keys: Array, pads: Array, device: int) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.35)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for p in pads:
		if p is Array:
			var m := InputEventJoypadMotion.new()
			m.axis = p[0]
			m.axis_value = p[1]
			m.device = device
			InputMap.action_add_event(name, m)
		else:
			var b := InputEventJoypadButton.new()
			b.button_index = p
			b.device = device
			InputMap.action_add_event(name, b)

func set_lang(l: String) -> void:
	lang = l
	save_settings()
	language_changed.emit()

func apply_settings() -> void:
	Audio.set_volumes(settings.master, settings.music, settings.sfx)
	var fs: bool = settings.fullscreen
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _write_json(path: String, v) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(v, "\t"))

func _load_settings() -> void:
	var v = _read_json(SETTINGS_PATH)
	if v is Dictionary:
		for k in v:
			if k == "lang":
				lang = str(v[k])
			else:
				settings[k] = v[k]

func save_settings() -> void:
	var v := settings.duplicate()
	v["lang"] = lang
	_write_json(SETTINGS_PATH, v)

func _load_save() -> void:
	var v = _read_json(SAVE_PATH)
	if v is Dictionary:
		for k in v:
			save[k] = v[k]

func write_save() -> void:
	_write_json(SAVE_PATH, save)

func has_progress() -> bool:
	return int(save.level) > 0

func reset_progress() -> void:
	save = {"level": 0, "oz_cap": Creatures.starting_cap(), "oz": 0, "best": {}, "seen": save.get("seen", [])}
	write_save()

func mark_seen(id: String) -> void:
	var s: Array = save.get("seen", [])
	if not s.has(id):
		s.append(id)
		save["seen"] = s
		write_save()

func format_time(sec: float) -> String:
	return "%d:%05.2f" % [int(sec) / 60, fmod(sec, 60.0)]
