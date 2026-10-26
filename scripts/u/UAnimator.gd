class_name UAnimator
extends Mono

var data: Dictionary = {}
var state := ""
var state_time := 0.0
var _triggers: Dictionary = {}
var _defaults: Dictionary = {}
var speed := 1.0

func _on_injected(_root: Node) -> void:
	var a = u.get("$anim")
	if a is Dictionary:
		data = a
	state = str(data.get("default", ""))

func Awake() -> void:
	_capture_defaults()

func OnEnable() -> void:
	state = str(data.get("default", ""))
	state_time = 0.0
	_triggers.clear()

func _all_curves() -> Array:
	var out := []
	for s in data.get("states", {}).values():
		var clip = s.get("clip")
		if clip is Dictionary:
			out.append_array(clip.get("curves", []))
	return out

func _target(path: String):
	var go = gameObject
	if path == "":
		return go
	return U.FindChild(go, path)

func _capture_defaults() -> void:
	for c in _all_curves():
		var key: String = str(c.get("path", "")) + "|" + str(c.get("attr", ""))
		if _defaults.has(key):
			continue
		var t = _target(str(c.get("path", "")))
		if t != null:
			_defaults[key] = _read(t, str(c.get("attr", "")))

func SetTrigger(n: String) -> void:
	_triggers[n] = true

func ResetTrigger(n: String) -> void:
	_triggers.erase(n)

func SetBool(n: String, v: bool) -> void:
	_triggers[n] = v

func Play(n, _layer := 0, normalized_time := 0.0) -> void:
	var sname := str(n)
	if data.get("states", {}).has(sname):
		state = sname
		var clip = _clip()
		state_time = normalized_time * (float(clip.get("length", 1)) if clip is Dictionary else 1.0)
		_evaluate()

func Update(_dt = null) -> void:
	if _dt != null:
		_evaluate()
		return
	_step(U.deltaTime * speed)

func _clip():
	var s = data.get("states", {}).get(state)
	return s.get("clip") if s is Dictionary else null

func _step(dt: float) -> void:
	state_time += dt
	var s = data.get("states", {}).get(state)
	var transitions: Array = []
	transitions.append_array(data.get("any", []))
	if s is Dictionary:
		transitions.append_array(s.get("transitions", []))
	var clip = _clip()
	var length := float(clip.get("length", 1.0)) if clip is Dictionary else 1.0
	for tr in transitions:
		var conds: Array = tr.get("conds", [])
		var ok := true
		for cnd in conds:
			if not _triggers.get(cnd, false):
				ok = false
		if tr.get("exit", false) and conds.is_empty():
			ok = state_time >= float(tr.get("exitTime", 1.0)) * length
		elif tr.get("exit", false):
			ok = ok and state_time >= float(tr.get("exitTime", 1.0)) * length
		if ok and tr.get("to") != null and (not conds.is_empty() or tr.get("exit", false)):
			for cnd in conds:
				_triggers.erase(cnd)
			state = str(tr.get("to"))
			state_time = 0.0
			break
	_evaluate()

func _evaluate() -> void:
	var clip = _clip()
	var curves: Array = clip.get("curves", []) if clip is Dictionary else []
	var length := float(clip.get("length", 1.0)) if clip is Dictionary else 1.0
	var t := state_time
	if clip is Dictionary and clip.get("loop", false) and length > 0:
		t = fmod(t, length)
	else:
		t = min(t, length)
	var touched := {}
	for c in curves:
		var key: String = str(c.get("path", "")) + "|" + str(c.get("attr", ""))
		touched[key] = true
		var tgt = _target(str(c.get("path", "")))
		if tgt != null:
			_write(tgt, str(c.get("attr", "")), _eval_curve(c.get("keys", []), t))
	for key in _defaults:
		if touched.has(key):
			continue
		var parts: PackedStringArray = key.split("|")
		var tgt = _target(parts[0])
		if tgt != null:
			_write(tgt, parts[1], _defaults[key])

func _eval_curve(keys: Array, t: float) -> float:
	if keys.is_empty():
		return 0.0
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(keys.size() - 1):
		var k0 = keys[i]
		var k1 = keys[i + 1]
		var t0 := float(k0[0])
		var t1 := float(k1[0])
		if t <= t1:
			var dt := t1 - t0
			if dt <= 0.0:
				return float(k1[1])
			var s := (t - t0) / dt
			var m0 := float(k0[3]) * dt
			var m1 := float(k1[2]) * dt
			if is_inf(m0) or is_inf(m1):
				return float(k0[1])
			var s2 := s * s
			var s3 := s2 * s
			return (2 * s3 - 3 * s2 + 1) * float(k0[1]) + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * float(k1[1]) + (s3 - s2) * m1
	return float(keys[-1][1])

func _read(t, attr: String) -> float:
	match attr:
		"m_AnchoredPosition.x":
			return RT.anchored_position(t).x
		"m_AnchoredPosition.y":
			return RT.anchored_position(t).y
		"m_SizeDelta.x":
			return RT.size_delta(t).x
		"m_SizeDelta.y":
			return RT.size_delta(t).y
		"m_LocalScale.x":
			return t.scale.x
		"m_LocalScale.y":
			return t.scale.y
		"m_fontColor.a", "m_Color.a":
			return t.color.a if "color" in t else 1.0
		"m_Alpha":
			var g = U.GetComponent(t, UCanvasGroup)
			return g.alpha if g != null else 1.0
	return 0.0

func _write(t, attr: String, v: float) -> void:
	match attr:
		"m_AnchoredPosition.x":
			var p: Vector2 = RT.anchored_position(t)
			p.x = v
			RT.set_anchored_position(t, p)
		"m_AnchoredPosition.y":
			var p2: Vector2 = RT.anchored_position(t)
			p2.y = v
			RT.set_anchored_position(t, p2)
		"m_SizeDelta.x":
			var s: Vector2 = RT.size_delta(t)
			s.x = v
			RT.set_size_delta(t, s)
		"m_SizeDelta.y":
			var s2: Vector2 = RT.size_delta(t)
			s2.y = v
			RT.set_size_delta(t, s2)
		"m_LocalScale.x":
			t.scale.x = v
		"m_LocalScale.y":
			t.scale.y = v
		"m_fontColor.a", "m_Color.a":
			if "color" in t:
				var c: Color = t.color
				c.a = v
				t.color = c
		"m_Alpha":
			var g = U.GetComponent(t, UCanvasGroup)
			if g != null:
				g.alpha = v

func GetCurrentAnimatorStateInfo(_layer := 0) -> Dictionary:
	var clip = _clip()
	var length := float(clip.get("length", 0.0)) if clip is Dictionary else 0.0
	return {"length": length, "normalizedTime": state_time / length if length > 0 else 0.0, "name": state}

static func StringToHash(s: String) -> String:
	return s
