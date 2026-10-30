class_name Level
extends Node2D

signal oz_collected(total: int)
signal level_completed(stats: Dictionary)

const TILE := 64.0
const SRC := 32
const LEVELS := ["res://levels/01_uyanis.txt", "res://levels/02_sular.txt", "res://levels/03_karanlik.txt", "res://levels/04_kemik.txt", "res://levels/05_ates.txt"]

@export var level_index := 0
var map: LevelMap
var world: Node2D
var ground: TileMapLayer
var ledges: TileMapLayer
var player: Creature
var essence: Essence
var camera: GameCamera
var hud: Node
var spawn := Vector2.ZERO
var checkpoint := Vector2.ZERO
var bounds := Rect2()
var time := 0.0
var deaths := 0
var collected := 0
var finished := false
var running := false
var boss: Enemy

static var _tileset: TileSet

func _ready() -> void:
	add_to_group("level")
	if Game.has_meta("level_index"):
		level_index = int(Game.get_meta("level_index"))
	level_index = clampi(level_index, 0, LEVELS.size() - 1)
	map = LevelMap.load_file(LEVELS[level_index])
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_build_background()
	_build_tiles()
	_build_entities()
	bounds = Rect2(Vector2(0, -TILE * 6), Vector2(map.width * TILE, (map.height + 6) * TILE))
	_spawn_player()
	hud = load("res://game/ui/hud.tscn").instantiate()
	add_child(hud)
	hud.bind(self)
	Audio.music(str(map.meta.get("music", "level")))
	running = true
	hud.banner(map.text("name"), map.text("hint"))
	essence.form_changed.connect(_on_form_changed)
	if level_index == 0:
		get_tree().create_timer(4.0, false).timeout.connect(_tip.bind("tip_start"))

func _process(delta: float) -> void:
	if running and not finished:
		time += delta
	if player != null and player.alive and player.global_position.y > (map.height + 3) * TILE:
		player.die()

static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SRC, SRC)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 64)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/ground.png")
	src.texture_region_size = Vector2i(SRC, SRC)
	ts.add_source(src, 0)
	var h := SRC * 0.5
	var sq := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var top := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 10), Vector2(-h, -h + 10)])
	for c in GROUND_COORDS:
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, sq)
	for c in LEDGE_COORDS:
		src.create_tile(c)
		var td2 := src.get_tile_data(c, 0)
		td2.add_collision_polygon(1)
		td2.set_collision_polygon_points(1, 0, top)
		td2.set_collision_polygon_one_way(1, 0, true)
	for c in DECO_COORDS:
		if src.get_tile_at_coords(c) == Vector2i(-1, -1):
			src.create_tile(c)
	_tileset = ts
	return ts

const GROUND_COORDS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(0, 8), Vector2i(0, 9), Vector2i(0, 10), Vector2i(0, 14), Vector2i(1, 14), Vector2i(2, 14)]
const LEDGE_COORDS := [Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)]
const DECO_COORDS := [Vector2i(1, 1)]

static func ground_coord(map: LevelMap, x: int, y: int) -> Vector2i:
	var u := map.is_solid(x, y - 1)
	var d := map.is_solid(x, y + 1)
	var l := map.is_solid(x - 1, y)
	var r := map.is_solid(x + 1, y)
	if not l and not r:
		if not u:
			return Vector2i(0, 8)
		return Vector2i(0, 9) if d else Vector2i(0, 10)
	if not u and not d:
		if not l:
			return Vector2i(0, 14)
		if not r:
			return Vector2i(2, 14)
		return Vector2i(1, 14)
	var col := 1
	if not l:
		col = 0
	elif not r:
		col = 2
	var row := 1
	if not u:
		row = 0
	elif not d:
		row = 2
	return Vector2i(col, row)

static func make_layer(parent: Node, n: String) -> TileMapLayer:
	var t := TileMapLayer.new()
	t.name = n
	t.tile_set = tileset()
	t.scale = Vector2(TILE / SRC, TILE / SRC)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(t)
	return t

static func build_tiles(parent: Node, map: LevelMap) -> Array:
	var g := make_layer(parent, "Ground")
	var l := make_layer(parent, "Ledges")
	for y in map.height:
		for x in map.width:
			var c := map.at(x, y)
			if c == "#":
				g.set_cell(Vector2i(x, y), 0, ground_coord(map, x, y))
			elif c == "=":
				var lf := map.at(x - 1, y) == "="
				var rt := map.at(x + 1, y) == "="
				var co := Vector2i(7, 3)
				if not lf:
					co = Vector2i(6, 3)
				elif not rt:
					co = Vector2i(8, 3)
				l.set_cell(Vector2i(x, y), 0, co)
	return [g, l]

func _ground_coord(x: int, y: int) -> Vector2i:
	return ground_coord(map, x, y)

func _build_tiles() -> void:
	var layers := build_tiles(world, map)
	ground = layers[0]
	ledges = layers[1]

func _cell_pos(x: int, y: int) -> Vector2:
	return Vector2(x * TILE, y * TILE)

func _add(n: Node2D, x: int, y: int, off := Vector2.ZERO) -> Node2D:
	n.position = _cell_pos(x, y) + off
	world.add_child(n)
	return n

func _build_entities() -> void:
	var visited := {}
	for y in map.height:
		for x in map.width:
			var c := map.at(x, y)
			match c:
				"S":
					spawn = _cell_pos(x, y) + Vector2(TILE * 0.5, TILE)
				"o", "O":
					var o := OzOrb.new()
					o.value = 1 if c == "o" else 3
					_add(o, x, y, Vector2(TILE * 0.5, TILE * 0.5))
				"X":
					_add(Entities.ExitPortal.new(), x, y)
				"C":
					_add(Entities.Checkpoint.new(), x, y)
				"B", "H":
					var b := Entities.Breakable.new()
					b.strength = 2 if c == "B" else 3
					_add(b, x, y)
				"g":
					_add(Entities.GrapplePoint.new(), x, y, Vector2(TILE * 0.5, TILE * 0.5))
				"T":
					_add(Entities.Torch.new(), x, y)
				"P":
					var p := Entities.Plate.new()
					_add(p, x, y)
				"d":
					if not visited.has(Vector2i(x, y)):
						var h := 0
						while map.at(x, y + h) == "d":
							visited[Vector2i(x, y + h)] = true
							h += 1
						var dr := Entities.Door.new()
						dr.height = h
						dr.add_to_group("door_a")
						_add(dr, x, y)
				"?":
					var sw := Entities.SecretWall.new()
					var spr := Sprite2D.new()
					spr.texture = load("res://assets/tiles/ground.png")
					spr.region_enabled = true
					spr.region_rect = Rect2(Vector2(_ground_coord(x, y)) * SRC, Vector2(SRC, SRC))
					spr.centered = false
					spr.scale = Vector2(TILE / SRC, TILE / SRC)
					spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					sw.add_child(spr)
					_add(sw, x, y)
				"i", "k", "w", "b":
					var kinds := {"i": "imp", "k": "skeleton", "w": "wraith", "b": "boss"}
					var e := Enemy.new().setup(kinds[c])
					_add(e, x, y, Vector2(TILE * 0.5, TILE))
					if c == "b":
						boss = e
						e.defeated.connect(_on_boss_down)
	var make_spikes := func(x, y, w):
		var s := Entities.Spikes.new()
		s.width = w
		_add(s, x, y)
	_runs("^", make_spikes)
	var make_water := func(r: Rect2i):
		var wa := Entities.Water.new()
		wa.size = Vector2(r.size) * TILE
		_add(wa, r.position.x, r.position.y)
	_rects("~", make_water)
	for part in str(map.meta.get("dark", "")).split(";", false):
		var v := part.split(",")
		if v.size() == 4:
			var dz := Entities.DarkZone.new()
			dz.size = Vector2(float(v[2]), float(v[3])) * TILE
			_add(dz, int(v[0]), int(v[1]))

func _runs(ch: String, make: Callable) -> void:
	for y in map.height:
		var x := 0
		while x < map.width:
			if map.at(x, y) == ch:
				var x0 := x
				while map.at(x, y) == ch:
					x += 1
				make.call(x0, y, x - x0)
			else:
				x += 1

func _rects(ch: String, make: Callable) -> void:
	var used := {}
	for y in map.height:
		for x in map.width:
			if map.at(x, y) != ch or used.has(Vector2i(x, y)):
				continue
			var w := 0
			while map.at(x + w, y) == ch and not used.has(Vector2i(x + w, y)):
				w += 1
			var h := 1
			var ok := true
			while ok:
				for i in w:
					if map.at(x + i, y + h) != ch or used.has(Vector2i(x + i, y + h)):
						ok = false
						break
				if ok:
					h += 1
			for yy in h:
				for xx in w:
					used[Vector2i(x + xx, y + yy)] = true
			make.call(Rect2i(x, y, w, h))

func _build_background() -> void:
	add_background(self, str(map.meta.get("theme", "graveyard")), str(map.meta.get("tint", "#ffffff")))

static func add_background(host: Node, theme: String, tint_hex: String) -> void:
	var dir := "res://assets/bg/%s/" % theme
	var factors := [0.0, 0.15, 0.3, 0.5, 0.7]
	for i in 5:
		var path := dir + "Layer_%d.png" % i
		if not ResourceLoader.exists(path):
			continue
		var px := Parallax2D.new()
		px.scroll_scale = Vector2(factors[i], factors[i] * 0.4 + (0.6 if i == 0 else 0.0))
		var tex: Texture2D = load(path)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		var k := 1200.0 / tex.get_height()
		s.scale = Vector2(k, k)
		px.repeat_size = Vector2(tex.get_width() * k, 0)
		px.repeat_times = 3
		px.z_index = -100 + i
		s.position = Vector2(0, -260)
		px.add_child(s)
		host.add_child(px)
		host.move_child(px, 0)
	var tint := CanvasModulate.new()
	tint.color = Color(tint_hex)
	host.add_child(tint)

func _spawn_player() -> void:
	player = Creature.new()
	player.team = 0
	player.input_source = PlayerInput.new()
	world.add_child(player)
	player.global_position = spawn
	checkpoint = spawn
	essence = Essence.new()
	essence.name = "Essence"
	player.add_child(essence)
	var cap := int(map.meta.get("oz_cap", Game.save.get("oz_cap", 6)))
	essence.setup(player, int(map.meta.get("start_oz", 0)), cap)
	player.died.connect(_on_player_died)
	camera = GameCamera.new()
	camera.target = player
	camera.bounds = bounds
	world.add_child(camera)
	camera.snap()

func collect_oz(n: int, _at: Vector2) -> bool:
	if not essence.add(n):
		return false
	collected += n
	oz_collected.emit(essence.oz)
	if level_index == 0:
		var frog := Creatures.get_def("kurbaga")
		if essence.current() == Creatures.fallback() and essence.oz >= frog.oz_cost:
			_tip("tip_can_transform")
		else:
			_tip("tip_first_oz")
	return true

func _tip(key: String) -> void:
	if hud == null or finished:
		return
	var seen: Array = Game.save.get("tips", [])
	if seen.has(key):
		return
	seen.append(key)
	Game.save["tips"] = seen
	Game.write_save()
	hud.tip(Game.t(key))

func _on_form_changed(d: CreatureDef) -> void:
	if level_index == 0 and d.id == "06-kurbaga":
		_tip("tip_transformed")
		get_tree().create_timer(9.0, false).timeout.connect(_tip.bind("tip_more"))

func set_checkpoint(p: Vector2) -> void:
	checkpoint = p
	hud.toast(Game.t("checkpoint"), Color(0.8, 0.6, 1))
	_tip("tip_checkpoint")

func _on_player_died(_c) -> void:
	deaths += 1
	_tip("tip_died")
	await get_tree().create_timer(0.9).timeout
	if finished:
		return
	player.revive_at(checkpoint, essence.current())
	camera.snap()
	Fx.burst(player.center(), "transform", player.def.accent, 24)

func _on_boss_down(_e) -> void:
	Audio.music("level", 2.0)
	hud.toast(Game.t("boss_down"), Color(1, 0.8, 0.4))

func complete() -> void:
	if finished:
		return
	if boss != null and is_instance_valid(boss) and boss.alive:
		hud.toast(Game.t("boss_first"), Color(1, 0.5, 0.45))
		return
	finished = true
	player.controls_enabled = false
	Audio.play("bonus", 0.0, 0.0)
	var stats := {"time": time, "deaths": deaths, "oz": collected, "index": level_index, "last": level_index >= LEVELS.size() - 1}
	var key := str(level_index)
	var best: Dictionary = Game.save.get("best", {})
	if not best.has(key) or float(best[key]) > time:
		best[key] = time
	Game.save["best"] = best
	Game.save["level"] = maxi(int(Game.save.get("level", 0)), level_index + 1)
	Game.save["oz_cap"] = maxi(int(Game.save.get("oz_cap", 6)), int(map.meta.get("next_cap", Game.save.get("oz_cap", 6))))
	Game.write_save()
	Net.submit_time(level_index, time)
	level_completed.emit(stats)
	hud.show_complete(stats)

func restart() -> void:
	Game.set_meta("level_index", level_index)
	Transition.go("res://game/world/level.tscn")

func next_level() -> void:
	if level_index + 1 >= LEVELS.size():
		Transition.go("res://game/ui/main_menu.tscn")
		return
	Game.set_meta("level_index", level_index + 1)
	Transition.go("res://game/world/level.tscn")
