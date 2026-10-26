class_name UTilemap
extends Mono

const P := UPhys.PPU

var cells: Dictionary = {}
var _sprites: Array = []
var _tiles: Array = []
var _mats: Array = []
var _colors: Array = []
var _anchor := Vector2(0.5, 0.5)
var _color := Color.WHITE
var _layer_id = 0
var _order := 0
var draw_node: Node2D
var body: CollisionObject2D
var _dirty_collision := false

func _on_injected(root: Node) -> void:
	_sprites = []
	for s in u.get("sprites", []):
		_sprites.append(DB.conv(s, root))
	_tiles = []
	for t in u.get("tiles", []):
		_tiles.append(DB.conv(t, root) if t != null else null)
	_mats = u.get("matrices", [])
	_colors = []
	for c in u.get("colors", []):
		_colors.append(Color(c[0], c[1], c[2], c[3]))
	var a = u.get("anchor", [0.5, 0.5])
	_anchor = Vector2(a[0], a[1])
	var c2 = u.get("color", [1, 1, 1, 1])
	_color = Color(c2[0], c2[1], c2[2], c2[3])
	_layer_id = u.get("sortingLayer", 0)
	_order = int(u.get("sortingOrder", 0))
	cells.clear()
	for e in u.get("cells", []):
		var key := Vector2i(int(e[0]), int(e[1]))
		var ti := int(e[3])
		var tile = _tiles[ti] if ti < _tiles.size() else null
		var si := int(e[2])
		var spr = _sprites[si] if si < _sprites.size() else (tile.sprite if tile != null else null)
		var mi := int(e[4])
		var ci := int(e[5])
		cells[key] = {"tile": tile, "sprite": spr, "mat": _mats[mi] if mi < _mats.size() else [1, 0, 0, 1], "color": _colors[ci] if ci < _colors.size() else Color.WHITE}
	draw_node = Node2D.new()
	draw_node.name = "_tiles"
	draw_node.z_as_relative = false
	draw_node.z_index = UPhys.sorting_z(_layer_id, _order)
	draw_node.draw.connect(_draw_tiles)
	gameObject.add_child(draw_node, false, Node.INTERNAL_MODE_FRONT)
	_rebuild_collision.call_deferred()

func grid() -> UGrid:
	var p = gameObject.get_parent()
	return U.GetComponent(p, UGrid) if p != null else null

func cell_size() -> Vector2:
	var g := grid()
	return g.cellSize if g != null else Vector2.ONE

func _cell_center_local(c: Vector2i) -> Vector2:
	var cs := cell_size()
	return Vector2((c.x + _anchor.x) * cs.x, (c.y + _anchor.y) * cs.y)

func _draw_tiles() -> void:
	var nearest := false
	for k in cells:
		var e: Dictionary = cells[k]
		var s = e.get("sprite")
		if s == null or s.texture == null:
			continue
		if s.filter == 0:
			nearest = true
		var r: Rect2 = s.get_region()
		var k2 := P / maxf(s.pixelsPerUnit, 0.0001)
		var w := r.size.x * k2
		var h := r.size.y * k2
		var center := UPhys.to_godot(_cell_center_local(k))
		var m: Array = e.get("mat", [1, 0, 0, 1])
		var xf := Transform2D(Vector2(float(m[0]), -float(m[2])), Vector2(-float(m[1]), float(m[3])), center)
		draw_node.draw_set_transform_matrix(xf)
		var pv: Vector2 = s.pivot
		var dst := Rect2(-pv.x * w, -(1.0 - pv.y) * h, w, h)
		draw_node.draw_texture_rect_region(s.texture, dst, r, (e.get("color", Color.WHITE) as Color) * _color)
	draw_node.draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_PARENT_NODE

func _collider():
	for c in gameObject.get_children():
		if c is UCollider2D and c.kind == "TilemapCollider2D":
			return c
	return null

func _rebuild_collision() -> void:
	var col = _collider()
	if col == null:
		return
	if body == null or not is_instance_valid(body):
		if col.isTrigger:
			var a := UArea.new()
			a.is_internal = true
			a.set_meta("trigger_owner", gameObject)
			body = a
		else:
			body = StaticBody2D.new()
			var pm := PhysicsMaterial.new()
			pm.friction = 0.4
			body.physics_material_override = pm
		body.name = "_tilebody"
		body.set_meta("go_owner", gameObject)
		gameObject.add_child(body, false, Node.INTERNAL_MODE_BACK)
		UGo.apply_layer(body, UGo.layer_of(gameObject))
	for c in body.get_children():
		if c is CollisionShape2D:
			c.queue_free()
	var eff = U.GetComponent(gameObject, UEffector2D)
	var one_way: bool = eff != null and col.usedByEffector and eff.is_platform()
	var cs := cell_size()
	var solid := {}
	for k in cells:
		var t = cells[k].get("tile")
		var ct: int = t.colliderType if t != null else 1
		if ct != 0 and cells[k].get("sprite") != null:
			solid[k] = true
	var used := {}
	var keys := solid.keys()
	keys.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var runs := []
	for k in keys:
		if used.has(k):
			continue
		var x0: int = k.x
		var x1: int = k.x
		while solid.has(Vector2i(x1 + 1, k.y)) and not used.has(Vector2i(x1 + 1, k.y)):
			x1 += 1
		for x in range(x0, x1 + 1):
			used[Vector2i(x, k.y)] = true
		runs.append([x0, x1, k.y, k.y])
	var merged := []
	runs.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))))
	for r in runs:
		if merged.size() > 0:
			var last: Array = merged[merged.size() - 1]
			if last[0] == r[0] and last[1] == r[1] and last[3] + 1 == r[2]:
				last[3] = r[2]
				continue
		merged.append(r.duplicate())
	for r in merged:
		var sh := RectangleShape2D.new()
		var wu: float = (r[1] - r[0] + 1) * cs.x
		var hu: float = (r[3] - r[2] + 1) * cs.y
		sh.size = Vector2(wu, hu) * P
		var n := CollisionShape2D.new()
		n.shape = sh
		n.one_way_collision = one_way
		var cu := Vector2(r[0] * cs.x + wu * 0.5, r[2] * cs.y + hu * 0.5)
		n.position = UPhys.to_godot(cu)
		n.set_meta("collider", col)
		body.add_child(n)

func refresh() -> void:
	if draw_node != null and is_instance_valid(draw_node):
		draw_node.queue_redraw()
	if not _dirty_collision:
		_dirty_collision = true
		_deferred_collision.call_deferred()

func _deferred_collision() -> void:
	_dirty_collision = false
	_rebuild_collision()

static func _key(c) -> Vector2i:
	return Vector2i(int(c.x), int(c.y))

func HasTile(c) -> bool:
	return cells.has(_key(c))

func GetTile(c):
	var e = cells.get(_key(c))
	return e.get("tile") if e != null else null

func GetSprite(c):
	var e = cells.get(_key(c))
	return e.get("sprite") if e != null else null

func SetTile(c, tile) -> void:
	var k := _key(c)
	if tile == null:
		cells.erase(k)
	else:
		cells[k] = {"tile": tile, "sprite": tile.sprite, "mat": [1, 0, 0, 1], "color": tile.color}
	refresh()

func SetTiles(cs: Array, ts: Array) -> void:
	for i in cs.size():
		var k := _key(cs[i])
		var t = ts[i] if i < ts.size() else null
		if t == null:
			cells.erase(k)
		else:
			cells[k] = {"tile": t, "sprite": t.sprite, "mat": [1, 0, 0, 1], "color": t.color}
	refresh()

func ClearAllTiles() -> void:
	cells.clear()
	refresh()

func RefreshAllTiles() -> void:
	refresh()

func SetColor(c, col: Color) -> void:
	var e = cells.get(_key(c))
	if e != null:
		e["color"] = col
		refresh()

func GetColor(c) -> Color:
	var e = cells.get(_key(c))
	return e.get("color", Color.WHITE) if e != null else Color.WHITE

var color: Color:
	get:
		return _color
	set(v):
		_color = v
		refresh()

func WorldToCell(w) -> Vector2i:
	var l := UPhys.to_unity(gameObject.global_transform.affine_inverse() * UPhys.to_godot(Vector2(w.x, w.y)))
	var cs := cell_size()
	return Vector2i(floori(l.x / cs.x), floori(l.y / cs.y))

func CellToWorld(c) -> Vector2:
	var cs := cell_size()
	return UPhys.to_unity(gameObject.global_transform * UPhys.to_godot(Vector2(c.x * cs.x, c.y * cs.y)))

func GetCellCenterWorld(c) -> Vector2:
	return UPhys.to_unity(gameObject.global_transform * UPhys.to_godot(_cell_center_local(_key(c))))

var cellBounds: Rect2i:
	get:
		var first := true
		var r := Rect2i()
		for k in cells:
			if first:
				r = Rect2i(k, Vector2i.ONE)
				first = false
			else:
				r = r.expand(k).expand(k + Vector2i.ONE)
		return r
