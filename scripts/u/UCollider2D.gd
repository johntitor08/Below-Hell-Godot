class_name UCollider2D
extends Mono

const P := UPhys.PPU

var kind := ""
var _isTrigger := false
var _offset := Vector2.ZERO
var _size := Vector2.ONE
var _radius := 0.5
var _direction := 0
var _paths: Array = []
var _points: Array = []
var _edge_radius := 0.0
var _shapes: Array = []
var _target: CollisionObject2D
var _body: CollisionObject2D
var _follow := false
var _one_way := false
var usedByEffector := false
var density := 1.0
var sharedMaterial = null

func _on_injected(_root: Node) -> void:
	kind = str(u.get("$type", "BoxCollider2D"))
	_isTrigger = int(u.get("m_IsTrigger", 0)) != 0
	usedByEffector = int(u.get("m_UsedByEffector", 0)) != 0
	density = float(u.get("m_Density", 1))
	_offset = _v2(u.get("m_Offset"), Vector2.ZERO)
	match kind:
		"BoxCollider2D":
			_size = _v2(u.get("m_Size"), Vector2.ONE)
			_edge_radius = float(u.get("m_EdgeRadius", 0))
		"CircleCollider2D":
			_radius = float(u.get("m_Radius", 0.5))
		"CapsuleCollider2D":
			_size = _v2(u.get("m_Size"), Vector2(0.5, 1))
			_direction = int(u.get("m_Direction", 0))
		"PolygonCollider2D":
			var pts = u.get("m_Points")
			_paths = []
			if pts is Dictionary:
				for path in pts.get("m_Paths", []):
					var a := []
					for p in path:
						a.append(_v2(p, Vector2.ZERO))
					_paths.append(a)
		"EdgeCollider2D":
			_points = []
			for p in u.get("m_Points", []):
				_points.append(_v2(p, Vector2.ZERO))
			_edge_radius = float(u.get("m_EdgeRadius", 0))
	_build()

static func _v2(v, d: Vector2) -> Vector2:
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	if v is Vector2:
		return v
	return d

func body() -> CollisionObject2D:
	if _body != null and is_instance_valid(_body):
		return _body
	var n = get_parent()
	if n is CollisionObject2D:
		_body = n
		return _body
	var p = n.get_parent() if n != null else null
	while p != null:
		if p is URigidbody2D:
			_body = p
			return _body
		p = p.get_parent()
	if n is CollisionObject2D:
		_body = n
	return _body

func _clear() -> void:
	for s in _shapes:
		if is_instance_valid(s):
			s.queue_free()
	_shapes.clear()

func _build() -> void:
	_clear()
	if kind in ["CompositeCollider2D", "TilemapCollider2D"]:
		return
	var b := body()
	if b == null:
		return
	var go = gameObject
	if _isTrigger and not (b is Area2D):
		_target = UGo.trigger_area(b)
	else:
		_target = b
	_follow = go != b
	var eff = U.GetComponent(go, UEffector2D)
	_one_way = eff != null and usedByEffector and eff.is_platform()
	match kind:
		"BoxCollider2D":
			var s := RectangleShape2D.new()
			s.size = Vector2(absf(_size.x) + _edge_radius * 2.0, absf(_size.y) + _edge_radius * 2.0) * P
			_add_shape(s, Transform2D(0.0, Vector2(_offset.x * P, -_offset.y * P)))
		"CircleCollider2D":
			var c := CircleShape2D.new()
			c.radius = maxf(_radius * P, 0.01)
			_add_shape(c, Transform2D(0.0, Vector2(_offset.x * P, -_offset.y * P)))
		"CapsuleCollider2D":
			var cap := CapsuleShape2D.new()
			var w := absf(_size.x) * P
			var h := absf(_size.y) * P
			var rot := 0.0
			if _direction == 1:
				var t := w
				w = h
				h = t
				rot = PI / 2.0
			cap.radius = maxf(w * 0.5, 0.01)
			cap.height = maxf(h, cap.radius * 2.0)
			_add_shape(cap, Transform2D(rot, Vector2(_offset.x * P, -_offset.y * P)))
		"PolygonCollider2D":
			for path in _paths:
				if path.size() < 3:
					continue
				var poly := PackedVector2Array()
				for p in path:
					poly.append(Vector2((p.x + _offset.x) * P, -(p.y + _offset.y) * P))
				var cp := CollisionPolygon2D.new()
				cp.polygon = poly
				cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
				_attach(cp, Transform2D.IDENTITY)
		"EdgeCollider2D":
			if _points.size() >= 2:
				var segs := PackedVector2Array()
				for i in range(_points.size() - 1):
					segs.append(Vector2((_points[i].x + _offset.x) * P, -(_points[i].y + _offset.y) * P))
					segs.append(Vector2((_points[i + 1].x + _offset.x) * P, -(_points[i + 1].y + _offset.y) * P))
				var cs := ConcavePolygonShape2D.new()
				cs.segments = segs
				_add_shape(cs, Transform2D.IDENTITY)
	_sync_xf()
	_apply_enabled(_enabled_flag and U.activeInHierarchy(gameObject))

func _add_shape(s: Shape2D, local: Transform2D) -> void:
	var n := CollisionShape2D.new()
	n.shape = s
	_attach(n, local)

func _attach(n: Node2D, local: Transform2D) -> void:
	n.set_meta("collider", self)
	n.set_meta("local_xf", local)
	n.name = "_col_" + str(get_instance_id())
	if n is CollisionShape2D:
		n.one_way_collision = _one_way
	elif n is CollisionPolygon2D:
		n.one_way_collision = _one_way
	_target.add_child(n, false, Node.INTERNAL_MODE_BACK)
	_shapes.append(n)

func _sync_xf() -> void:
	if _target == null:
		return
	var rel := Transform2D.IDENTITY
	var go = gameObject
	if go != _target and go is Node2D:
		rel = _target.global_transform.affine_inverse() * go.global_transform
	for s in _shapes:
		if is_instance_valid(s):
			s.transform = rel * (s.get_meta("local_xf") as Transform2D)

func _apply_enabled(on: bool) -> void:
	for s in _shapes:
		if is_instance_valid(s):
			s.set_deferred("disabled", not on)

func OnEnable() -> void:
	_apply_enabled(true)

func OnDisable() -> void:
	_apply_enabled(false)

func FixedUpdate() -> void:
	if _follow:
		_sync_xf()

var isTrigger: bool:
	get:
		return _isTrigger
	set(v):
		if v == _isTrigger:
			return
		_isTrigger = v
		_build()

var offset: Vector2:
	get:
		return _offset
	set(v):
		_offset = v
		_build()

var size: Vector2:
	get:
		return _size
	set(v):
		_size = v
		_build()

var radius: float:
	get:
		return _radius
	set(v):
		_radius = v
		_build()

var points: Array:
	get:
		return _points if kind == "EdgeCollider2D" else (_paths[0] if _paths.size() > 0 else [])
	set(v):
		if kind == "EdgeCollider2D":
			_points = v
		else:
			_paths = [v]
		_build()

var pathCount: int:
	get:
		return _paths.size()

func GetPath(i: int) -> Array:
	return _paths[i] if i < _paths.size() else []

func SetPath(i: int, pts: Array) -> void:
	while _paths.size() <= i:
		_paths.append([])
	_paths[i] = pts
	_build()

var attachedRigidbody:
	get:
		return UPhys.rigidbody_of(gameObject)

var bounds: UBounds:
	get:
		var r := Rect2()
		var first := true
		for s in _shapes:
			if not is_instance_valid(s):
				continue
			var rr := _shape_rect(s)
			if first:
				r = rr
				first = false
			else:
				r = r.merge(rr)
		if first:
			return UBounds.make(U.pos(gameObject), Vector2.ZERO)
		var a := UPhys.to_unity(r.position)
		var b := UPhys.to_unity(r.end)
		return UBounds.make((a + b) * 0.5, Vector2(absf(b.x - a.x), absf(b.y - a.y)))

func _shape_rect(n: Node2D) -> Rect2:
	var xf := n.global_transform
	var pts := PackedVector2Array()
	if n is CollisionShape2D and n.shape != null:
		var lr: Rect2 = n.shape.get_rect()
		pts = [lr.position, Vector2(lr.end.x, lr.position.y), lr.end, Vector2(lr.position.x, lr.end.y)]
	elif n is CollisionPolygon2D:
		pts = n.polygon
	var out := Rect2()
	for i in pts.size():
		var p := xf * pts[i]
		if i == 0:
			out = Rect2(p, Vector2.ZERO)
		else:
			out = out.expand(p)
	return out

func OverlapPoint(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = UPhys.to_godot(p)
	q.collide_with_areas = true
	q.collision_mask = 0xFFFFFFFF
	for h in UPhys.space().intersect_point(q, 16):
		if UPhys.collider_of(h.get("collider"), int(h.get("shape", 0))) == self:
			return true
	return false

func IsTouching(other) -> bool:
	if other == null:
		return false
	return bounds.Intersects(other.bounds)

func IsTouchingLayers(mask := -1) -> bool:
	for c in UPhys.OverlapBoxAll(bounds.center, bounds.size, 0.0, mask):
		if c != self:
			return true
	return false

func ClosestPoint(p: Vector2) -> Vector2:
	return bounds.ClosestPoint(p)
