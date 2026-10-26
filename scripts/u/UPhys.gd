class_name UPhys

const PPU := 100.0
const DEFAULT_RAYCAST_LAYERS := -5

static var _cfg: Dictionary = {}
static var _handler_cache: Dictionary = {}
static var queriesHitTriggers := true

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var f := FileAccess.open("res://data/physics.json", FileAccess.READ)
		if f != null:
			var v = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_cfg = v
		if _cfg.is_empty():
			_cfg = {"layers": [], "sortingLayers": [], "matrix": [], "gravity": [0, -9.81]}
		queriesHitTriggers = bool(_cfg.get("queriesHitTriggers", true))
	return _cfg

static func to_godot(v: Vector2) -> Vector2:
	return Vector2(v.x * PPU, -v.y * PPU)

static func to_unity(p: Vector2) -> Vector2:
	return Vector2(p.x / PPU, -p.y / PPU)

static func layer_bit(layer: int) -> int:
	return 1 << clampi(layer, 0, 31)

static func mask_for(layer: int) -> int:
	var m: Array = cfg().get("matrix", [])
	if layer >= 0 and layer < m.size():
		return int(m[layer]) & 0xFFFFFFFF
	return 0xFFFFFFFF

static func query_mask(mask: int) -> int:
	return mask & 0xFFFFFFFF

static func NameToLayer(n: String) -> int:
	var ls: Array = cfg().get("layers", [])
	for i in ls.size():
		if str(ls[i]) == n:
			return i
	return -1

static func LayerToName(i: int) -> String:
	var ls: Array = cfg().get("layers", [])
	return str(ls[i]) if i >= 0 and i < ls.size() else ""

static func GetMask(names) -> int:
	var m := 0
	if names is String:
		names = [names]
	for n in names:
		var l := NameToLayer(str(n))
		if l >= 0:
			m |= 1 << l
	return m

static func sorting_rank(layer_id) -> int:
	var sl: Array = cfg().get("sortingLayers", [])
	var def_idx := 0
	for i in sl.size():
		if int(sl[i].get("id", 0)) == 0:
			def_idx = i
	for i in sl.size():
		if str(sl[i].get("id")) == str(layer_id) or str(sl[i].get("name")) == str(layer_id):
			return i - def_idx
	return 0

static func sorting_layer_name(layer_id) -> String:
	for e in cfg().get("sortingLayers", []):
		if str(e.get("id")) == str(layer_id):
			return str(e.get("name"))
	return "Default"

static func sorting_layer_id(n: String) -> int:
	for e in cfg().get("sortingLayers", []):
		if str(e.get("name")) == n:
			return int(e.get("id"))
	return 0

static func sorting_z(layer_id, order: int) -> int:
	return clampi(sorting_rank(layer_id) * 600 + clampi(order, -299, 299), -4000, 4000)

static func space() -> PhysicsDirectSpaceState2D:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.world_2d.direct_space_state

static func world_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene

static var gravity: Vector2:
	get:
		var g: Array = cfg().get("gravity", [0, -9.81])
		return Vector2(float(g[0]), float(g[1]))
	set(v):
		cfg()["gravity"] = [v.x, v.y]
		var tree := Engine.get_main_loop() as SceneTree
		var sp := tree.root.world_2d.space
		PhysicsServer2D.area_set_param(sp, PhysicsServer2D.AREA_PARAM_GRAVITY, v.length() * PPU)
		PhysicsServer2D.area_set_param(sp, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, to_godot(v).normalized() if v.length() > 0.0 else Vector2.DOWN)

static func collider_of(obj: Object, shape_idx: int):
	if obj == null or not is_instance_valid(obj):
		return null
	if obj is CollisionObject2D:
		var owner_id: int = obj.shape_find_owner(shape_idx)
		if owner_id >= 0:
			var n = obj.shape_owner_get_owner(owner_id)
			if n != null and n.has_meta("collider"):
				var c = n.get_meta("collider")
				if is_instance_valid(c):
					return c
		return first_collider(obj)
	if obj is TileMapLayer:
		return obj.get_meta("collider", null)
	return null

static func first_collider(body: Node):
	for c in body.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			if c.has_meta("collider"):
				return c.get_meta("collider")
	var go = U.go_of(body)
	if go != null:
		for c in go.get_children():
			if c is UCollider2D:
				return c
	return null

static func go_of_collision_object(obj: Object):
	if obj == null or not is_instance_valid(obj):
		return null
	if obj is Node and obj.has_meta("go_owner"):
		return obj.get_meta("go_owner")
	if obj is Area2D and obj.has_meta("trigger_owner"):
		return obj.get_meta("trigger_owner")
	return obj

static func rigidbody_of(go) -> URigidbody2D:
	var n = go
	while n != null and n is Node:
		if n is URigidbody2D:
			return n
		n = n.get_parent()
	return null

static func _shape_query(shape: Shape2D, xf: Transform2D, mask: int, max_results := 32) -> Array:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = xf
	q.collision_mask = query_mask(mask)
	q.collide_with_areas = queriesHitTriggers
	q.collide_with_bodies = true
	var hits := space().intersect_shape(q, max_results)
	var out := []
	for h in hits:
		var c = collider_of(h.get("collider"), int(h.get("shape", 0)))
		if c != null and is_instance_valid(c) and c.enabled and not out.has(c):
			out.append(c)
	return out

static func OverlapCircleAll(point: Vector2, radius: float, mask := DEFAULT_RAYCAST_LAYERS) -> Array:
	var s := CircleShape2D.new()
	s.radius = maxf(radius * PPU, 0.01)
	return _shape_query(s, Transform2D(0.0, to_godot(point)), mask)

static func OverlapCircle(point: Vector2, radius: float, mask := DEFAULT_RAYCAST_LAYERS):
	var a := OverlapCircleAll(point, radius, mask)
	return a[0] if a.size() > 0 else null

static func OverlapBoxAll(point: Vector2, size: Vector2, angle: float, mask := DEFAULT_RAYCAST_LAYERS) -> Array:
	var s := RectangleShape2D.new()
	s.size = Vector2(maxf(absf(size.x) * PPU, 0.01), maxf(absf(size.y) * PPU, 0.01))
	return _shape_query(s, Transform2D(-deg_to_rad(angle), to_godot(point)), mask)

static func OverlapBox(point: Vector2, size: Vector2, angle: float, mask := DEFAULT_RAYCAST_LAYERS):
	var a := OverlapBoxAll(point, size, angle, mask)
	return a[0] if a.size() > 0 else null

static func OverlapPoint(point: Vector2, mask := DEFAULT_RAYCAST_LAYERS):
	var q := PhysicsPointQueryParameters2D.new()
	q.position = to_godot(point)
	q.collision_mask = query_mask(mask)
	q.collide_with_areas = queriesHitTriggers
	for h in space().intersect_point(q, 8):
		var c = collider_of(h.get("collider"), int(h.get("shape", 0)))
		if c != null:
			return c
	return null

static func Raycast(origin: Vector2, direction: Vector2, distance := INF, mask := DEFAULT_RAYCAST_LAYERS) -> URaycastHit2D:
	var d := direction.normalized()
	var dist := minf(distance, 100000.0)
	var q := PhysicsRayQueryParameters2D.create(to_godot(origin), to_godot(origin + d * dist), query_mask(mask))
	q.collide_with_areas = queriesHitTriggers
	q.hit_from_inside = true
	var r := space().intersect_ray(q)
	var hit := URaycastHit2D.new()
	if r.is_empty():
		return hit
	hit.collider = collider_of(r.get("collider"), int(r.get("shape", 0)))
	hit.point = to_unity(r.get("position"))
	var n: Vector2 = r.get("normal")
	hit.normal = Vector2(n.x, -n.y)
	hit.distance = origin.distance_to(hit.point)
	hit.fraction = hit.distance / dist if dist > 0.0 else 0.0
	return hit

static func CircleCast(origin: Vector2, radius: float, direction: Vector2, distance := INF, mask := DEFAULT_RAYCAST_LAYERS) -> URaycastHit2D:
	var s := CircleShape2D.new()
	s.radius = maxf(radius * PPU, 0.01)
	var d := direction.normalized()
	var dist := minf(distance, 100000.0)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = s
	q.transform = Transform2D(0.0, to_godot(origin))
	q.motion = to_godot(origin + d * dist) - to_godot(origin)
	q.collision_mask = query_mask(mask)
	q.collide_with_areas = queriesHitTriggers
	var hit := URaycastHit2D.new()
	var frac := space().cast_motion(q)
	if frac.is_empty() or frac[0] >= 1.0:
		var still := space().intersect_shape(q, 1)
		if still.is_empty():
			return hit
		hit.collider = collider_of(still[0].get("collider"), int(still[0].get("shape", 0)))
		hit.point = origin
		return hit
	var at := origin + d * dist * frac[1]
	q.transform = Transform2D(0.0, to_godot(at))
	q.motion = Vector2.ZERO
	var info := space().get_rest_info(q)
	if info.is_empty():
		var hits := space().intersect_shape(q, 1)
		if hits.is_empty():
			return hit
		hit.collider = collider_of(hits[0].get("collider"), int(hits[0].get("shape", 0)))
		hit.point = at
	else:
		hit.collider = collider_of(instance_from_id(int(info.get("collider_id"))), int(info.get("shape", 0)))
		hit.point = to_unity(info.get("point"))
		var n: Vector2 = info.get("normal")
		hit.normal = Vector2(n.x, -n.y)
	hit.distance = dist * frac[1]
	hit.centroid = at
	return hit

static func IgnoreCollision(a, b, ignore := true) -> void:
	if a == null or b == null:
		return
	var ba = a.body() if a is UCollider2D else a
	var bb = b.body() if b is UCollider2D else b
	if not (ba is PhysicsBody2D and bb is PhysicsBody2D) or ba == bb:
		return
	if ignore:
		ba.add_collision_exception_with(bb)
	else:
		ba.remove_collision_exception_with(bb)

static func has_handler(go, method: String) -> bool:
	if go == null or not is_instance_valid(go):
		return false
	for c in go.get_children():
		if c is Mono and c.has_method(method):
			return true
	return false

static func send(go, method: String, arg) -> void:
	if go == null or not is_instance_valid(go):
		return
	for c in go.get_children():
		if c is Mono and c._active and c.has_method(method):
			c.call(method, arg)

static func make_collision(me_go, other_go, my_col, other_col, point: Vector2, normal: Vector2, rel_vel: Vector2) -> UCollision2D:
	var c := UCollision2D.new()
	c.gameObject = other_go
	c.collider = other_col
	c.otherCollider = my_col
	c.rigidbody = rigidbody_of(other_go)
	c.otherRigidbody = rigidbody_of(me_go)
	c.relativeVelocity = rel_vel
	var cp := UContactPoint2D.new()
	cp.point = point
	cp.normal = normal
	cp.collider = other_col
	cp.otherCollider = my_col
	c.contacts = [cp]
	return c

static func dispatch_collision(a_go, a_col, b_go, b_col, method: String, point: Vector2, normal_on_a: Vector2, rel_vel: Vector2) -> void:
	var ca := make_collision(a_go, b_go, a_col, b_col, point, normal_on_a, rel_vel)
	var cb := make_collision(b_go, a_go, b_col, a_col, point, -normal_on_a, -rel_vel)
	_send_to_owners(a_go, a_col, method, ca)
	_send_to_owners(b_go, b_col, method, cb)

static func _send_to_owners(body_go, col, method: String, arg) -> void:
	var cgo = col.gameObject if col != null and is_instance_valid(col) else null
	if cgo != null and cgo != body_go:
		send(cgo, method, arg)
	send(body_go, method, arg)
