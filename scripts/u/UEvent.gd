@tool
class_name UEvent
extends RefCounted

var persistent: Array = []
var listeners: Array[Callable] = []
var owner_node: Node

func AddListener(c: Callable) -> void:
	listeners.append(c)

func RemoveListener(c: Callable) -> void:
	for i in range(listeners.size() - 1, -1, -1):
		if listeners[i] == c:
			listeners.remove_at(i)

func RemoveAllListeners() -> void:
	listeners.clear()

func GetPersistentEventCount() -> int:
	return persistent.size()

func Invoke(arg = null) -> void:
	for p in persistent:
		_call_persistent(p, arg)
	for c in listeners.duplicate():
		if not c.is_valid():
			continue
		if c.get_argument_count() > 0:
			c.call(arg)
		else:
			c.call()

func _call_persistent(p: Dictionary, dyn_arg) -> void:
	if int(p.get("state", 2)) == 0:
		return
	var target = p.get("target_node")
	if target == null or not is_instance_valid(target):
		return
	var m := str(p.get("method", ""))
	var mode := int(p.get("mode", 1))
	if m == "SetActive" and not target.has_method("SetActive"):
		U.SetActive(target, bool(p.get("arg")))
		return
	if not target.has_method(m):
		if target.has_meta("u") and target.get_parent() != null:
			pass
		push_warning("UEvent: %s has no method %s" % [target.name, m])
		return
	match mode:
		0:
			if dyn_arg == null:
				target.call(m)
			else:
				target.call(m, dyn_arg)
		1:
			target.call(m)
		_:
			target.call(m, p.get("arg"))
