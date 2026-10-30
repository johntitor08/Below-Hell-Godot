extends Control

const GOLD := "#e6b85c"
const OZ := "#b48cff"
const KEY := "#ffe7b0"

var _text: RichTextLabel
var _tabs: VBoxContainer
var _page := 0

const PAGES := [
	["Öz ve Dönüşüm", "Essence & Transforming"],
	["Kontroller", "Controls"],
	["Bölümler", "Levels"],
	["Arena", "Arena"],
	["Online", "Online"],
]

func _ready() -> void:
	UI.backdrop(self, "graveyard", 0.72)
	var t := UI.title(Game.t("howto"), 76)
	t.position = Vector2(80, 40)
	add_child(t)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UI.panel(20))
	left.position = Vector2(70, 170)
	left.custom_minimum_size = Vector2(380, 0)
	add_child(left)
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 12)
	left.add_child(_tabs)
	for i in PAGES.size():
		var b := UI.button(PAGES[i][0] if Game.lang == "tr" else PAGES[i][1], _show.bind(i), 340, 64)
		b.toggle_mode = true
		b.focus_entered.connect(_show.bind(i))
		_tabs.add_child(b)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UI.panel(20))
	right.position = Vector2(490, 170)
	right.custom_minimum_size = Vector2(1360, 820)
	add_child(right)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = true
	_text.custom_minimum_size = Vector2(1320, 780)
	_text.add_theme_font_size_override("normal_font_size", 27)
	_text.add_theme_font_size_override("bold_font_size", 27)
	_text.add_theme_font_override("bold_font", load("res://assets/fonts/body_bold.otf"))
	_text.add_theme_constant_override("line_separation", 6)
	right.add_child(_text)
	var back := UI.button(Game.t("back"), _back, 300, 62)
	back.position = Vector2(80, 1000)
	add_child(back)
	var start := 0
	if Game.has_meta("howto_page"):
		start = int(Game.get_meta("howto_page"))
		Game.remove_meta("howto_page")
	_show(start)
	(_tabs.get_child(start) as Button).grab_focus.call_deferred()

func _show(i: int) -> void:
	_page = i
	for k in _tabs.get_child_count():
		(_tabs.get_child(k) as Button).set_pressed_no_signal(k == i)
	_text.text = _body(i)
	_text.scroll_to_line(0)

static func k(s: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [KEY, s]

static func h(s: String) -> String:
	return "[font_size=36][color=%s]%s[/color][/font_size]\n" % [GOLD, s]

func _body(i: int) -> String:
	var tr := Game.lang == "tr"
	match i:
		0:
			if tr:
				return h("Öz nedir?") + \
					"Bölümlerdeki [color=%s]mor küreler[/color] Öz'dür: küçükler [b]1[/b], büyükler [b]3[/b] Öz verir. Yenilen düşmanlar da Öz düşürür.\n" % OZ + \
					"Sol üstteki mor noktalar elindeki Öz'ü, toplam nokta sayısı kesenin [b]sınırını[/b] gösterir. Kese doluysa yeni Öz alınmaz.\n\n" + \
					h("Nasıl dönüşülür?") + \
					"1. %s tuşunu [b]basılı tut[/b]: zaman yavaşlar, 20 hayvan bir çemberde açılır.\n" % k("Q") + \
					"2. Fareyle ya da %s ile hayvanın yönüne git. Ortada adı, istatistikleri ve yeteneği görünür; simgenin altındaki sayı [b]bedelidir[/b].\n" % k("WASD / oklar") + \
					"3. %s'yu bırak: dönüşürsün, bedel Öz'ünden düşer. Gri formlar için Öz'ün yetmiyor.\n\n" % k("Q") + \
					h("Kurallar") + \
					"• [b]Sinek her zaman bedava[/b]: sıkışırsan menüden sineğe dön.\n" + \
					"• %s formu bırakır: bir önceki forma dönersin, harcadığın Öz'ün [b]yarısı[/b] geri gelir.\n" % k("R") + \
					"• Form [b]ölürse[/b] harcanan Öz kaybolur ve bir önceki forma düşersin. Kontrol noktasından devam edersin.\n" + \
					"• Uçan formların [b]dayanıklılığı[/b] sınırlıdır (can çubuğunun altındaki ince çubuk); yerde dolar.\n" + \
					"• Nefes alamayan formlar suda yavaşlar ve [b]boğulur[/b].\n\n" + \
					h("Strateji") + \
					"Pahalı bir formla ölmek Öz'ü yakar. Tehlikeden önce formu %s ile bırakıp Öz'ü cebe koymak, ya da ucuz bir formla yetinmek çoğu zaman daha akıllıcadır." % k("R")
			return h("What is Essence?") + \
				"The [color=%s]purple orbs[/color] are Essence: small ones give [b]1[/b], big ones [b]3[/b]. Defeated enemies drop Essence too.\n" % OZ + \
				"The purple dots at the top left show your Essence; the number of dots is your pouch [b]limit[/b].\n\n" + \
				h("How to transform") + \
				"1. [b]Hold[/b] %s: time slows and the 20 creatures open in a ring.\n" % k("Q") + \
				"2. Point at a creature with the mouse or %s. Its name, stats and ability appear in the middle; the number is its [b]cost[/b].\n" % k("WASD / arrows") + \
				"3. Release %s to transform; the cost is taken from your Essence. Greyed-out forms are too expensive.\n\n" % k("Q") + \
				h("Rules") + \
				"• [b]The Fly is always free[/b]: if you get stuck, turn back into the fly.\n" + \
				"• %s drops your form: you go back one form and get [b]half[/b] of the spent Essence back.\n" % k("R") + \
				"• If a form [b]dies[/b], its Essence is lost and you fall back to the previous form at the last checkpoint.\n" + \
				"• Flying forms have limited [b]stamina[/b] (the thin bar under health); it refills on the ground.\n" + \
				"• Forms that can't breathe underwater slow down and [b]drown[/b].\n\n" + \
				h("Strategy") + \
				"Dying in an expensive form burns your Essence. Dropping it with %s before danger, or settling for a cheaper form, is often smarter." % k("R")
		1:
			var rows := [
				[["Hareket", "Move"], "A / D"], [["Zıpla (uçarken yüksel)", "Jump (rise while flying)"], "Boşluk / Space"],
				[["Aşağı / alçal", "Down / descend"], "S"], [["Saldırı", "Attack"], "J"], [["1. yetenek", "1st ability"], "K"],
				[["2. yetenek", "2nd ability"], "L"], [["Dönüşüm menüsü (basılı tut)", "Transform menu (hold)"], "Q"],
				[["Formu bırak (yarı iade)", "Drop form (half refund)"], "R"], [["Duraklat", "Pause"], "Esc"],
			]
			var s := h("Klavye" if tr else "Keyboard") + "[table=2]"
			for r in rows:
				s += "[cell][b]%s[/b]      [/cell][cell]%s[/cell]" % [r[0][0] if tr else r[0][1], k(r[1])]
			s += "[/table]\n\n"
			s += h("Gamepad")
			s += ("Sol çubuk hareket · %s zıpla · %s saldırı · %s / %s yetenekler · %s dönüşüm · %s formu bırak · %s duraklat\n\n" if tr else "Left stick move · %s jump · %s attack · %s / %s abilities · %s transform · %s drop form · %s pause\n\n") % [k("A"), k("X"), k("B"), k("Y"), k("LB"), k("Back"), k("Start")]
			s += ("Platformun içinden aşağı inmek için %s basılıyken %s (Kurbağa'da bu süper zıplamadır). Hangi formun hangi yeteneği olduğu sol üstteki kutularda ve dönüşüm menüsünde yazar." if tr else "Hold %s and press %s to drop through a ledge (the Frog super-jumps instead). Each form's abilities are shown in the boxes at the top left and in the transform menu.") % [k("S"), k("Space")]
			if OS.has_feature("web"):
				s += ("\n\n[color=%s]Tarayıcıda: tuşların çalışması için önce oyun alanına bir kez tıkla.[/color]" if tr else "\n\n[color=%s]In the browser: click the game once so it receives your keys.[/color]") % OZ
			return s
		2:
			if tr:
				return h("Beş bölüm, beş anahtar") + \
					"Her bölüm bir formu ister; başında ipucu çıkar.\n\n" + \
					"[b]I · Uyanış[/b] — Sineğin uçuşu yüksek duvara yetmez: %s (3 Öz) zıplar, %s ile dil kancası atar. Kancayı pembe halkalara da atabilirsin.\n" % [k("Kurbağa"), k("K")] + \
					"[b]II · Batık Sular[/b] — Tavanı kapalı su altı tüneli: nefes alamayan boğulur. %s ya da %s geçer.\n" % [k("Aksolotl"), k("Yılan Balığı")] + \
					"[b]III · Kör Mağaralar[/b] — Karanlıkta dikenler görünmez. %s karanlıkta görür, %s ile ekolokasyon gizli yolları da açığa çıkarır.\n" % [k("Yarasa"), k("K")] + \
					"[b]IV · Kemik Ocağı[/b] — Çatlak duvarı %s (%s hücum) kırar; ağır kayayı yalnızca %s ya da %s. Kapı için basınç plakasına bir şey koymalısın: %s klonu (%s) işini görür.\n" % [k("Geyik"), k("K"), k("Ayı"), k("Ejderha"), k("Slime"), k("K")] + \
					"[b]V · Ateş Tahtı[/b] — Bekçiyi yen, sonra kapıdan çık. Kese 12 Öz alır: %s mümkün.\n\n" % k("Ejderha") + \
					"Mor alevli direkler [b]kontrol noktasıdır[/b]. Ölürsen oradan devam edersin; düşersen de."
			return h("Five levels, five keys") + \
				"Each level asks for a form; a hint appears at the start.\n\n" + \
				"[b]I · Awakening[/b] — The fly can't clear the tall wall: the %s (3 Essence) jumps it, %s fires its tongue grapple. Pink rings are grapple points.\n" % [k("Frog"), k("K")] + \
				"[b]II · Sunken Waters[/b] — A sealed underwater tunnel: air-breathers drown. The %s or the %s gets through.\n" % [k("Axolotl"), k("Eel")] + \
				"[b]III · Blind Caves[/b] — Spikes hide in the dark. The %s sees in darkness; %s echolocation also reveals hidden paths.\n" % [k("Bat"), k("K")] + \
				"[b]IV · Bone Quarry[/b] — The %s (%s charge) breaks cracked walls; boulders need the %s or %s. The door needs weight on the plate: a %s clone (%s) works.\n" % [k("Stag"), k("K"), k("Bear"), k("Dragon"), k("Slime"), k("K")] + \
				"[b]V · Throne of Fire[/b] — Defeat the warden, then leave through the gate. Your pouch holds 12: the %s is possible.\n\n" % k("Dragon") + \
				"Poles with a purple flame are [b]checkpoints[/b]."
		3:
			var s3 := h("Kurallar" if tr else "Rules")
			if tr:
				s3 += "• Her oyuncu bir hayvan seçer; arenada [b]dönüşüm ve Öz yoktur[/b].\n• Rakibin canını bitir ya da onu [b]kenardan aşağı düşür[/b].\n• [b]İki raund[/b] alan maçı kazanır. Sonunda rövanş yapabilirsin.\n• Büyük formlar dayanıklı ama hantal, küçükler hızlı ama kırılgan.\n\n"
			else:
				s3 += "• Each player picks a creature; there is [b]no transforming or Essence[/b] in the arena.\n• Drain your rival's health or [b]knock them off the edge[/b].\n• First to [b]two rounds[/b] wins. Rematch at the end.\n• Big forms are tough but slow, small ones fast but fragile.\n\n"
			s3 += h("Yerel düello" if tr else "Local duel") + _duel_table(tr)
			s3 += "\n" + ("Bilgisayara karşı ve online modda tek oyunculu tuşlar geçerlidir (A/D, Boşluk, J, K, L)." if tr else "Versus CPU and online use the single-player keys (A/D, Space, J, K, L).")
			return s3
		4:
			if tr:
				return h("Online arena") + \
					"Arena → [b]Online Arena[/b] → formunu seç → [b]Bağlan[/b]. Oyun resmi sunucuya kendiliğinden bağlanır.\n" + \
					"İlk seferde bir kullanıcı adı ve şifre (en az 6 karakter) yazıp [b]Kayıt ol[/b]; sonraki seferlerde [b]Giriş[/b].\n" + \
					"[b]Eşleşme Bul[/b] seni sırada bekleyen başka bir oyuncuyla eşleştirir. Galibiyetlerin ve bölüm sürelerin [b]liderlik tablosuna[/b] işlenir.\n\n" + \
					"Kendi sunucunu kurduysan adres alanına [b]ip:port[/b] yaz."
			return h("Online arena") + \
				"Arena → [b]Online Arena[/b] → choose your form → [b]Connect[/b]. The game reaches the official server on its own.\n" + \
				"The first time, enter a username and password (6+ characters) and [b]Sign up[/b]; afterwards [b]Log in[/b].\n" + \
				"[b]Find Match[/b] pairs you with another waiting player. Your wins and level times go on the [b]leaderboard[/b].\n\n" + \
				"Running your own server? Type its [b]ip:port[/b] in the address field."
	return ""

static func _duel_table(tr: bool) -> String:
	var rows := [
		[["Hareket", "Move"], "A / D", "← / →"], [["Zıpla", "Jump"], "Boşluk / Space", "Enter · Num 0"],
		[["Uçarken yukarı/aşağı", "Fly up/down"], "W / S", "↑ / ↓"], [["Saldırı", "Attack"], "F", ". · Num 1"],
		[["1. yetenek", "1st ability"], "G", ", · Num 2"], [["2. yetenek", "2nd ability"], "H", "/ · Num 3"],
	]
	var s := "[table=3][cell]      [/cell][cell][color=#8ccaff][b]%s[/b][/color]      [/cell][cell][color=#ff8c80][b]%s[/b][/color][/cell]" % [Game.t("p1"), Game.t("p2")]
	for r in rows:
		s += "[cell][b]%s[/b]      [/cell][cell]%s      [/cell][cell]%s[/cell]" % [r[0][0] if tr else r[0][1], k(r[1]), k(r[2])]
	s += "[/table]\n"
	s += ("İki gamepad takılıysa her oyuncu kendi gamepad'ini kullanabilir." if tr else "With two gamepads connected, each player can use their own.")
	return s

func _back() -> void:
	Transition.go("res://game/ui/main_menu.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		_back()
