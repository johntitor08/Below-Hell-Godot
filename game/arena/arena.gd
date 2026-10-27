class_name Arena
extends Node2D

signal round_over(winner: int)

const TILE := 64.0
const WINS_NEEDED := 2
const THEMES := [["graveyard", "#f0e6ff"], ["snow", "#eef2ff"], ["mountain", "#eaf4ff"], ["desert", "#ffe6d6"]]
const LAYOUTS := [
	[
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"         ====      ====       ",
		"                              ",
		"                              ",
		"    =====              =====  ",
		"                              ",
		"              ==              ",
		"                              ",
		"      1                2      ",
		"   ########################   ",
		"   ########################   ",
		"   ########################   ",
	],
	[
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"             ====             ",
		"                              ",
		"      ====          ====      ",
		"                              ",
		"                              ",
		"  ====       ####       ====  ",
		"             ####             ",
		"                              ",
		"     1                  2     ",
		"  #########        #########  ",
		"  #########        #########  ",
		"  #########        #########  ",
	],
	[
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"                              ",
		"   ===                  ===   ",
		"                              ",
		"         ###      ###         ",
		"         ###      ###         ",
		"                              ",
		"   =====            =====     ",
		"                              ",
		"     1                 2      ",
		"  ##########################  ",
		"  ##########################  ",
		"  ##########################  ",
	],
]

var mode := "cpu"
var picks := ["06-kurbaga", "17-kurt"]
var fighters: Array[Creature] = []
var wins := [0, 0]
var round_no := 0
var resolving := false
var match_over := false
var spawns: Array[Vector2] = []
var world: Node2D
var hud: Node
var camera: Camera2D
var net_role := ""
var rng_seed := 0
var my_slot := 0
var _send_t := 0.0
var _local_in := CreatureInput.new()
var _local_src: PlayerInput

func _ready() -> void:
	add_to_group("arena")
	var cfg: Dictionary = Game.get_meta("arena") if Game.has_meta("arena") else {}
	mode = str(cfg.get("mode", "cpu"))
	picks = [str(cfg.get("p1", picks[0])), str(cfg.get("p2", picks[1]))]
	rng_seed = int(cfg.get("seed", randi()))
	if mode == "online":
		var mi: Dictionary = Net.match_info
		my_slot = int(mi.get("slot", 0))
		net_role = "host" if my_slot == 0 else "guest"
		picks = [str(mi.forms[0]), str(mi.forms[1])]
		rng_seed = int(mi.get("seed", 1))
		Net.remote_state.connect(_on_remote_state)
		Net.remote_event.connect(_on_remote_event)
		Net.opponent_left.connect(_on_opponent_left)
	seed(rng_seed)
	var th: Array = THEMES[randi() % THEMES.size()]
	var rows: Array = LAYOUTS[randi() % LAYOUTS.size()]
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	Level.add_background(self, th[0], th[1])
	var map := LevelMap.from_rows(rows)
	for y in map.height:
		for x in map.width:
			var c := map.at(x, y)
			if c == "1" or c == "2":
				spawns.append(Vector2(x * TILE + TILE * 0.5, (y + 1) * TILE))
	if spawns.size() < 2:
		spawns = [Vector2(400, 900), Vector2(1500, 900)]
	var clean: Array = []
	for r in rows:
		clean.append(str(r).replace("1", " ").replace("2", " "))
	Level.build_tiles(world, LevelMap.from_rows(clean))
	camera = GameCamera.new()
	camera.position = Vector2(map.width * TILE * 0.5, map.height * TILE * 0.5 - 20)
	world.add_child(camera)
	_fit_camera.call_deferred(Vector2(map.width * TILE, map.height * TILE))
	for i in 2:
		var c := Creature.new()
		c.team = i
		world.add_child(c)
		c.set_form(Creatures.get_def(picks[i]))
		c.died.connect(_on_died)
		fighters.append(c)
	_assign_inputs()
	hud = load("res://game/arena/arena_hud.tscn").instantiate()
	add_child(hud)
	hud.bind(self)
	Audio.music("arena")
	if net_role != "guest":
		start_round()

func _fit_camera(size: Vector2) -> void:
	var vs := get_viewport_rect().size
	var z := minf(vs.x / size.x, vs.y / (size.y + 80.0))
	camera.zoom = Vector2(z, z)
	camera.global_position = Vector2(size.x * 0.5, size.y * 0.5 - 30.0)

func _assign_inputs() -> void:
	match mode:
		"local":
			fighters[0].input_source = PlayerInput.new("p1_")
			fighters[1].input_source = PlayerInput.new("p2_")
		"online":
			if net_role == "host":
				fighters[0].input_source = PlayerInput.new()
				fighters[1].input_source = NetRemoteInput.new()
			else:
				_local_src = PlayerInput.new()
				for f in fighters:
					f.puppet = true
		_:
			fighters[0].input_source = PlayerInput.new()
			var bot := BotInput.new()
			bot.target = fighters[0]
			bot.level = 1.0
			fighters[1].input_source = bot

func start_round() -> void:
	round_no += 1
	resolving = false
	Fx.slowmo(1.0)
	for i in 2:
		var f := fighters[i]
		f.revive_at(spawns[i], Creatures.get_def(picks[i]))
		f.facing = 1 if i == 0 else -1
		f.controls_enabled = false
		f.invulnerable_until = 0.0
	hud.countdown(round_no)
	if net_role == "host":
		Net.send_event({"e": "round", "n": round_no})
	await get_tree().create_timer(3.4).timeout
	if not is_inside_tree() or match_over:
		return
	for f in fighters:
		f.controls_enabled = true

func _physics_process(delta: float) -> void:
	if net_role == "guest":
		_local_in.clear_edges()
		if not match_over:
			_local_src.poll(fighters[1], _local_in)
			Net.send_input(_local_in.to_array())
		return
	if net_role == "host":
		_send_t -= delta
		if _send_t <= 0.0:
			_send_t = 1.0 / 30.0
			Net.send_state({"f": [fighters[0].snapshot(), fighters[1].snapshot()]})
	if resolving or match_over:
		return
	for f in fighters:
		if f.alive and f.global_position.y > 17 * TILE + 260.0:
			f.hp = 0
			f.hp_changed.emit(0, f.max_hp)
			f.die()

func _on_died(c: Creature) -> void:
	if resolving or match_over:
		return
	resolving = true
	var winner := 1 - c.team
	wins[winner] += 1
	Fx.slowmo(0.35)
	Fx.shake(14.0, 0.5)
	Audio.play("explosion", -2.0)
	for f in fighters:
		f.controls_enabled = false
	round_over.emit(winner)
	hud.ko(winner, wins)
	if net_role == "host":
		Net.send_event({"e": "ko", "w": winner, "wins": wins})
	await get_tree().create_timer(0.9).timeout
	Fx.slowmo(1.0)
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree():
		return
	if wins[winner] >= WINS_NEEDED:
		match_over = true
		hud.show_winner(winner)
		Audio.play("bonus", 0.0, 0.0)
		if mode == "online":
			Net.send_event({"e": "win", "w": winner})
			Net.report_result(winner)
	else:
		start_round()

func _on_remote_state(st: Dictionary) -> void:
	var f: Array = st.get("f", [])
	for i in mini(2, f.size()):
		fighters[i].apply_snapshot(f[i])

func _on_remote_event(ev: Dictionary) -> void:
	match str(ev.get("e", "")):
		"round":
			round_no = int(ev.get("n", 1))
			hud.countdown(round_no)
		"ko":
			var w := int(ev.get("w", 0))
			wins = ev.get("wins", wins)
			Fx.shake(14.0, 0.5)
			Audio.play("explosion", -2.0)
			hud.ko(w, wins)
		"win":
			match_over = true
			hud.show_winner(int(ev.get("w", 0)))
			Audio.play("bonus", 0.0, 0.0)

func _on_opponent_left() -> void:
	if match_over:
		return
	match_over = true
	for f in fighters:
		f.controls_enabled = false
	hud.opponent_left()

func rematch() -> void:
	if mode == "online":
		Net.leave_match()
		Transition.go("res://game/net/online_lobby.tscn")
		return
	Transition.go("res://game/arena/arena.tscn")

func leave() -> void:
	if mode == "online":
		Net.leave_match()
	Transition.go("res://game/arena/arena_menu.tscn")
