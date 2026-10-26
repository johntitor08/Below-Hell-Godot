class_name Mono
extends Node

var _enabled_flag := true
var _awoken := false
var _started := false
var _active := false
var _destroyed := false
var _injected := false
var _epoch := 0
var _has_update := false
var _has_late := false
var u: Dictionary = {}

var enabled: bool:
	get:
		return _enabled_flag
	set(v):
		if _enabled_flag == v:
			return
		_enabled_flag = v
		_sync(U.activeInHierarchy(get_parent()))

var gameObject:
	get:
		return get_parent()

var transform:
	get:
		return get_parent()

var rectTransform:
	get:
		return get_parent()

var isActiveAndEnabled: bool:
	get:
		return _active

var go_name: String:
	get:
		var p = get_parent()
		return p.get_meta("u_name", p.name) if p != null else ""

func _enter_tree() -> void:
	add_to_group("mono")

func _inject(root: Node) -> void:
	if _injected:
		return
	_injected = true
	var raw = get_meta("u", "")
	if raw is String and raw != "":
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			u = parsed
	if u.has("m_Enabled"):
		_enabled_flag = int(u["m_Enabled"]) != 0
	var props := {}
	for p in get_property_list():
		props[p.name] = p
	for k in u:
		if k.begins_with("$") or k.begins_with("m_"):
			continue
		if props.has(k):
			var v = DB.conv(u[k], root)
			_assign_field(k, v, props[k])
	_on_injected(root)

func _assign_field(k: String, v, prop: Dictionary) -> void:
	var t: int = prop.get("type", TYPE_NIL)
	if v == null:
		if t == TYPE_NIL or t == TYPE_OBJECT:
			set(k, null)
		return
	match t:
		TYPE_NIL:
			set(k, v)
		TYPE_BOOL:
			set(k, bool(v))
		TYPE_INT:
			set(k, int(v))
		TYPE_FLOAT:
			set(k, float(v))
		TYPE_STRING:
			set(k, str(v))
		TYPE_ARRAY:
			if v is Array:
				var cur = get(k)
				if cur is Array and cur.is_typed():
					var a = cur.duplicate()
					a.clear()
					for x in v:
						a.append(x)
					set(k, a)
				else:
					set(k, v)
		_:
			set(k, v)

func _on_injected(_root: Node) -> void:
	pass

func _ready() -> void:
	_has_update = has_method("Update")
	_has_late = has_method("LateUpdate")
	set_process(false)

func _sync(parent_on: bool) -> void:
	if _destroyed:
		return
	if parent_on and not _awoken:
		_awoken = true
		if has_method("Awake"):
			call("Awake")
		if _destroyed:
			return
	var want := parent_on and _enabled_flag
	if want == _active:
		return
	_active = want
	if want:
		set_process(true)
		if _has_late:
			U.register_late(self)
		if has_method("OnEnable"):
			call("OnEnable")
	else:
		_epoch += 1
		set_process(false)
		if _has_late:
			U.unregister_late(self)
		if has_method("OnDisable"):
			call("OnDisable")

func _process(_delta: float) -> void:
	if not _active:
		set_process(false)
		return
	if not _started:
		_started = true
		if has_method("Start"):
			call("Start")
		if not _active:
			return
	if _has_update:
		call("Update")
	elif _started:
		set_process(false)

func _destroy() -> void:
	if _destroyed:
		return
	if _active:
		_active = false
		_epoch += 1
		if _has_late:
			U.unregister_late(self)
		if has_method("OnDisable"):
			call("OnDisable")
	_destroyed = true
	if _awoken and has_method("OnDestroy"):
		call("OnDestroy")

func _exit_tree() -> void:
	if is_queued_for_deletion() and not _destroyed:
		_destroy()

func co() -> int:
	return _epoch

func dead(e: int) -> bool:
	return e != _epoch or _destroyed or not is_inside_tree()

func StopAllCoroutines() -> void:
	_epoch += 1

func TryGetComponent(cls):
	return U.GetComponent(get_parent(), cls)

func GetComponent(cls):
	return U.GetComponent(get_parent(), cls)

func GetComponents(cls) -> Array:
	return U.GetComponents(get_parent(), cls)

func GetComponentInChildren(cls, include_inactive := false):
	return U.GetComponentInChildren(get_parent(), cls, include_inactive)

func GetComponentsInChildren(cls, include_inactive := false) -> Array:
	return U.GetComponentsInChildren(get_parent(), cls, include_inactive)

func GetComponentInParent(cls):
	return U.GetComponentInParent(get_parent(), cls)

func AddComponent(cls):
	return U.AddComponent(get_parent(), cls)
