@tool
extends Node

const REF_W := 1920.0
const REF_H := 1080.0

var deltaTime: float = 0.0
var unscaledDeltaTime: float = 0.0
var time: float = 0.0
var unscaledTime: float = 0.0
var frameCount: int = 0
var _last_ticks: int = 0
var _keys_down: Dictionary = {}
var _keys_up: Dictionary = {}
var _mouse_down: Dictionary = {}
var _mouse_up: Dictionary = {}
var _scroll: float = 0.0
var _late: Array = []
var _prefs := ConfigFile.new()
var _prefs_loaded := false
var _rng := RandomNumberGenerator.new()
var _destroy_queue: Array = []

var timeScale: float:
	get:
		return Engine.time_scale
	set(v):
		Engine.time_scale = maxf(0.0, v)

func _ready() -> void:
	process_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks = Time.get_ticks_usec()
	_rng.randomize()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now := Time.get_ticks_usec()
	unscaledDeltaTime = minf(0.1, (now - _last_ticks) / 1000000.0)
	_last_ticks = now
	deltaTime = delta
	time += delta
	unscaledTime += unscaledDeltaTime
	frameCount += 1

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var k: int = event.physical_keycode if event.keycode == 0 else event.keycode
		if event.pressed:
			_keys_down[k] = frameCount + 1
		else:
			_keys_up[k] = frameCount + 1
	elif event is InputEventMouseButton:
		var b: int = event.button_index
		if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_scroll += (1.0 if b == MOUSE_BUTTON_WHEEL_UP else -1.0) * max(event.factor, 1.0)
			return
		var ub := 0 if b == MOUSE_BUTTON_LEFT else (1 if b == MOUSE_BUTTON_RIGHT else 2)
		if event.pressed:
			_mouse_down[ub] = frameCount + 1
		else:
			_mouse_up[ub] = frameCount + 1

func consume_scroll() -> float:
	var s := _scroll
	_scroll = 0.0
	return s

func GetKeyDown(k: int) -> bool:
	return _keys_down.get(k, -1) == frameCount

func GetKeyUp(k: int) -> bool:
	return _keys_up.get(k, -1) == frameCount

func GetKey(k: int) -> bool:
	return Input.is_key_pressed(k)

func GetMouseButtonDown(b: int) -> bool:
	return _mouse_down.get(b, -1) == frameCount

func GetMouseButtonUp(b: int) -> bool:
	return _mouse_up.get(b, -1) == frameCount

func GetMouseButton(b: int) -> bool:
	var mb: int = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE][b]
	return Input.is_mouse_button_pressed(mb)

func anyKeyDown() -> bool:
	for k in _keys_down:
		if _keys_down[k] == frameCount:
			return true
	for b in _mouse_down:
		if _mouse_down[b] == frameCount:
			return true
	return false

func mouse_canvas() -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * _mouse() if vp else Vector2.ZERO

func mousePosition() -> Vector2:
	var p := _mouse()
	return Vector2(p.x, REF_H - p.y)

func _mouse() -> Vector2:
	if ES.mouse_override.x >= 0.0:
		return ES.mouse_override
	return get_viewport().get_mouse_position()

func to_unity_screen(p: Vector2) -> Vector2:
	return Vector2(p.x, REF_H - p.y)

func from_unity_screen(p: Vector2) -> Vector2:
	return Vector2(p.x, REF_H - p.y)

func register_late(m) -> void:
	if not _late.has(m):
		_late.append(m)

func unregister_late(m) -> void:
	_late.erase(m)

func run_late() -> void:
	for m in _late.duplicate():
		if is_instance_valid(m) and m._active:
			m.LateUpdate()

func is_go(n) -> bool:
	return n is CanvasItem and n.has_meta("u")

func go_of(n):
	if n == null or not is_instance_valid(n):
		return null
	if n is Mono:
		return n.get_parent()
	return n

func activeSelf(go) -> bool:
	go = go_of(go)
	return go != null and go.visible

func activeInHierarchy(go) -> bool:
	go = go_of(go)
	if go == null or not go.is_inside_tree():
		return false
	var n: Node = go
	while n != null:
		if n is CanvasItem and not n.visible:
			return false
		if n is CanvasLayer and not n.visible:
			return false
		n = n.get_parent()
	return true

func SetActive(go, v: bool) -> void:
	go = go_of(go)
	if go == null or not is_instance_valid(go):
		return
	if go.visible == v:
		return
	go.visible = v
	refresh_subtree(go)
	ES.mark_layout_dirty()

func refresh_subtree(n: Node) -> void:
	var on := activeInHierarchy(n) if (n is CanvasItem or n is CanvasLayer) else false
	_refresh(n, on)

func _refresh(n: Node, parent_on: bool) -> void:
	for c in n.get_children():
		if c is Mono:
			c._sync(parent_on)
	for c in n.get_children():
		if c is CanvasItem or c is CanvasLayer:
			_refresh(c, parent_on and c.visible)

func monos_in(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Mono:
			out.append(c)
	for c in n.get_children():
		if not (c is Mono):
			monos_in(c, out)

func kids(go) -> Array:
	go = go_of(go)
	var a := []
	if go == null:
		return a
	for c in go.get_children():
		if c is CanvasItem and c.has_meta("u"):
			a.append(c)
	return a

func child(go, i: int):
	var k := kids(go)
	return k[i] if i >= 0 and i < k.size() else null

func childCount(go) -> int:
	return kids(go).size()

func FindChild(go, path: String):
	go = go_of(go)
	var cur = go
	for part in path.split("/"):
		var found = null
		for c in kids(cur):
			if c.get_meta("u_name", c.name) == part or c.name == part:
				found = c
				break
		if found == null:
			return null
		cur = found
	return cur

func parent(go):
	go = go_of(go)
	if go == null:
		return null
	var p = go.get_parent()
	if p is CanvasItem and p.has_meta("u"):
		return p
	return null

func SetParent(go, p, world_stays := false) -> void:
	go = go_of(go)
	p = go_of(p)
	if go == null:
		return
	var old = go.get_parent()
	if old != null:
		old.remove_child(go)
	if p != null:
		p.add_child(go)
		_set_owner_rec(go, p.owner if p.owner != null else p)
	refresh_subtree(go)
	ES.mark_layout_dirty()

func _set_owner_rec(n: Node, o: Node) -> void:
	if n != o:
		n.owner = o
	for c in n.get_children():
		_set_owner_rec(c, o)

func SetAsLastSibling(go) -> void:
	go = go_of(go)
	if go != null and go.get_parent() != null:
		go.get_parent().move_child(go, -1)
		ES.mark_layout_dirty()

func SetAsFirstSibling(go) -> void:
	go = go_of(go)
	if go == null or go.get_parent() == null:
		return
	var p: Node = go.get_parent()
	var idx := 0
	for c in p.get_children():
		if c is Mono:
			idx += 1
		else:
			break
	p.move_child(go, idx)
	ES.mark_layout_dirty()

func SetSiblingIndex(go, i: int) -> void:
	go = go_of(go)
	if go == null or go.get_parent() == null:
		return
	var k := kids(go.get_parent())
	i = clampi(i, 0, k.size() - 1)
	if k[i] == go:
		return
	go.get_parent().move_child(go, k[i].get_index())
	ES.mark_layout_dirty()

func GetSiblingIndex(go) -> int:
	go = go_of(go)
	return kids(go.get_parent()).find(go) if go != null and go.get_parent() != null else 0

func GetComponent(go, cls):
	go = go_of(go)
	if go == null:
		return null
	if is_instance_of(go, cls):
		return go
	for c in go.get_children():
		if c is Mono and is_instance_of(c, cls):
			return c
	return null

func GetComponents(go, cls) -> Array:
	go = go_of(go)
	var a := []
	if go == null:
		return a
	if is_instance_of(go, cls):
		a.append(go)
	for c in go.get_children():
		if c is Mono and is_instance_of(c, cls):
			a.append(c)
	return a

func GetComponentInChildren(go, cls, include_inactive := false):
	go = go_of(go)
	if go == null:
		return null
	if include_inactive or go.visible:
		var c = GetComponent(go, cls)
		if c != null:
			return c
	for k in kids(go):
		if not include_inactive and not k.visible:
			continue
		var r = GetComponentInChildren(k, cls, include_inactive)
		if r != null:
			return r
	return null

func GetComponentsInChildren(go, cls, include_inactive := false) -> Array:
	var a := []
	_gcic(go_of(go), cls, include_inactive, a)
	return a

func _gcic(go, cls, inc: bool, a: Array) -> void:
	if go == null:
		return
	if not inc and not go.visible:
		return
	a.append_array(GetComponents(go, cls))
	for k in kids(go):
		_gcic(k, cls, inc, a)

func GetComponentInParent(go, cls):
	go = go_of(go)
	while go != null:
		var c = GetComponent(go, cls)
		if c != null:
			return c
		go = parent(go)
	return null

func scene_root() -> Node:
	return get_tree().current_scene

func Find(n: String):
	var r := scene_root()
	if r == null:
		return null
	return _find_name(r, n)

func _find_name(node: Node, n: String):
	for c in node.get_children():
		if c is Mono:
			continue
		if c is CanvasItem and c.has_meta("u"):
			if (c.get_meta("u_name", c.name) == n or c.name == n) and activeInHierarchy(c):
				return c
		var r = _find_name(c, n)
		if r != null:
			return r
	return null

func FindWithTag(tag: String):
	var r := scene_root()
	if r == null:
		return null
	for m in get_tree().get_nodes_in_group("go_tag_" + tag):
		if activeInHierarchy(m):
			return m
	return null

func FindAnyObjectByType(cls, include_inactive := false):
	for m in get_tree().get_nodes_in_group("mono"):
		if is_instance_of(m, cls) and (include_inactive or activeInHierarchy(m.get_parent())):
			return m
	return null

func FindObjectsByType(cls, include_inactive := false) -> Array:
	var a := []
	for m in get_tree().get_nodes_in_group("mono"):
		if is_instance_of(m, cls) and (include_inactive or activeInHierarchy(m.get_parent())):
			a.append(m)
	return a

func Instantiate(src, parent_go = null):
	var root: Node
	var target_path := "."
	var dup_src = null
	if src is UPrefab:
		root = src.packed.instantiate()
		target_path = src.node
	elif src is Node:
		var go = go_of(src)
		root = go.duplicate(Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SIGNALS)
		if src is Mono:
			target_path = str(go.get_path_to(src))
		dup_src = go
	else:
		push_error("Instantiate: bad source %s" % [src])
		return null
	root.set_meta("u_instance", true)
	var p = go_of(parent_go)
	if p != null:
		p.add_child(root)
		_set_owner_rec(root, root)
	else:
		var sr := scene_root()
		var layer := CanvasLayer.new()
		sr.add_child(layer)
		layer.add_child(root)
	if dup_src != null:
		_copy_state(dup_src, root)
		DB.dup_orig = dup_src
		DB.dup_copy = root
		UScene.boot_subtree(root, dup_src.owner if dup_src.owner != null else scene_root(), true)
		DB.dup_orig = null
		DB.dup_copy = null
	else:
		UScene.boot_subtree(root, root, false)
	ES.mark_layout_dirty()
	if target_path == "." or target_path == "":
		return root
	return root.get_node_or_null(NodePath(target_path))

func Destroy(obj, delay := 0.0) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
		if obj == null or not is_instance_valid(obj):
			return
	if obj is Mono and not obj.has_meta("u_is_go"):
		obj._destroy()
		obj.queue_free()
		return
	var go = go_of(obj)
	if go == null:
		return
	var list := []
	if go is Node:
		list = GetComponentsInChildren(go, Mono, true)
	for m in list:
		m._destroy()
	if go.get_parent() != null:
		go.get_parent().remove_child(go)
	go.queue_free()
	ES.mark_layout_dirty()

func wait(sec: float) -> void:
	if sec <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(sec, true, false, false).timeout

func wait_rt(sec: float) -> void:
	if sec <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(sec, true, false, true).timeout

func frame() -> void:
	await get_tree().process_frame

func on(sig: Signal, c: Callable) -> void:
	if not sig.is_connected(c):
		sig.connect(c)

func off(sig: Signal, c: Callable) -> void:
	if sig.is_connected(c):
		sig.disconnect(c)

func empty(s) -> bool:
	return s == null or (s is String and s == "") or (s is StringName and s == &"")

func blank(s) -> bool:
	return s == null or str(s).strip_edges() == ""

func value() -> float:
	return _rng.randf()

func rangei(a: int, b: int) -> int:
	if b <= a:
		return a
	return _rng.randi_range(a, b - 1)

func rangef(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

func RoundToInt(f: float) -> int:
	var fl := floorf(f)
	var diff := f - fl
	if is_equal_approx(diff, 0.5):
		return int(fl) if int(fl) % 2 == 0 else int(fl) + 1
	return int(roundf(f))

func Round(f: float) -> float:
	return float(RoundToInt(f))

func Clamp01(f: float) -> float:
	return clampf(f, 0.0, 1.0)

func Lerp(a: float, b: float, t: float) -> float:
	return lerpf(a, b, clampf(t, 0.0, 1.0))

func MoveTowards(cur: float, target: float, max_delta: float) -> float:
	if absf(target - cur) <= max_delta:
		return target
	return cur + signf(target - cur) * max_delta

func Approximately(a: float, b: float) -> bool:
	return absf(b - a) < max(0.000001 * max(absf(a), absf(b)), 1.1920929e-07 * 8.0)

func Repeat(t: float, length: float) -> float:
	return clampf(t - floorf(t / length) * length, 0.0, length)

func PingPong(t: float, length: float) -> float:
	t = Repeat(t, length * 2.0)
	return length - absf(t - length)

func clerp(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))

func hex(c: Color) -> String:
	return "#" + c.to_html(false).to_upper()

func Shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _prefs_ensure() -> void:
	if not _prefs_loaded:
		_prefs_loaded = true
		_prefs.load("user://prefs.cfg")

func HasKey(k: String) -> bool:
	_prefs_ensure()
	return _prefs.has_section_key("p", k)

func GetInt(k: String, def := 0) -> int:
	_prefs_ensure()
	return int(_prefs.get_value("p", k, def))

func GetFloat(k: String, def := 0.0) -> float:
	_prefs_ensure()
	return float(_prefs.get_value("p", k, def))

func GetString(k: String, def := "") -> String:
	_prefs_ensure()
	return str(_prefs.get_value("p", k, def))

func SetInt(k: String, v: int) -> void:
	_prefs_ensure()
	_prefs.set_value("p", k, v)

func SetFloat(k: String, v: float) -> void:
	_prefs_ensure()
	_prefs.set_value("p", k, v)

func SetString(k: String, v: String) -> void:
	_prefs_ensure()
	_prefs.set_value("p", k, v)

func DeleteKey(k: String) -> void:
	_prefs_ensure()
	if _prefs.has_section_key("p", k):
		_prefs.erase_section_key("p", k)

func PrefsSave() -> void:
	_prefs_ensure()
	_prefs.save("user://prefs.cfg")

func persistentDataPath() -> String:
	return "user://"

func LoadScene(path: String) -> void:
	ES.reset()
	_late.clear()
	get_tree().change_scene_to_file.call_deferred(path)

func _copy_state(src: Node, dst: Node) -> void:
	if src is UImage and dst is UImage:
		if not dst._ready_done:
			dst._ready()
		dst._sprite = src._sprite
		dst._color = src._color
		dst._enabled = src._enabled
		dst.type = src.type
		dst.preserveAspect = src.preserveAspect
		dst._fillAmount = src._fillAmount
		dst.raycastTarget = src.raycastTarget
		dst.queue_redraw()
	elif src is UText and dst is UText:
		if not dst._ready_done:
			dst._ready()
		dst._text = src._text
		dst._color = src._color
		dst._fontSize = src._fontSize
		dst._font = src._font
		dst._enabled = src._enabled
		dst._mark()
	var sk := kids(src)
	var dk := kids(dst)
	for i in mini(sk.size(), dk.size()):
		_copy_state(sk[i], dk[i])

func AddComponent(go, cls):
	go = go_of(go)
	var c = cls.new()
	c.name = "C_" + str(cls.get_global_name())
	go.add_child(c)
	c.owner = go.owner
	c._injected = true
	c._sync(activeInHierarchy(go))
	return c

func NewGO(n: String, parent_go, cls = UImage, blob := {}):
	var go = cls.new()
	go.name = n
	blob["name"] = n
	go.set_meta("u", JSON.stringify(blob))
	go.set_meta("pivot", [0.5, 0.5])
	var p = go_of(parent_go)
	p.add_child(go)
	go.owner = p.owner
	if go is Control:
		RT.set_anchor_min(go, Vector2(0.5, 0.5))
		RT.set_anchor_max(go, Vector2(0.5, 0.5))
		RT.set_size_delta(go, Vector2(100, 100))
	return go
