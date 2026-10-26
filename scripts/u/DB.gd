@tool
extends Node

var so_by_guid: Dictionary = {}
var so_by_class: Dictionary = {}
var sprite_meta: Dictionary = {}
var sprites: Dictionary = {}
var clips: Dictionary = {}
var fonts: Dictionary = {}
var prefabs: Dictionary = {}
var _script_cache: Dictionary = {}
var _loaded := false
var dup_orig: Node
var dup_copy: Node

func _enter_tree() -> void:
	ensure_loaded()

func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	sprite_meta = _read_json("res://data/sprites.json")
	var raw: Dictionary = _read_json("res://data/so.json")
	for guid in raw:
		var e: Dictionary = raw[guid]
		var so: SO = _make(str(e.get("class", "")))
		so.guid = guid
		so.asset_path = str(e.get("path", ""))
		so.d = e.get("d", {})
		so.set_meta("class", e.get("class", ""))
		so_by_guid[guid] = so
		var cls := str(e.get("class", ""))
		if not so_by_class.has(cls):
			so_by_class[cls] = []
		so_by_class[cls].append(so)
	for guid in so_by_guid:
		var so: SO = so_by_guid[guid]
		so.d = conv(so.d, null)
	for guid in so_by_guid:
		var so: SO = so_by_guid[guid]
		if so.has_method("OnLoaded"):
			so.OnLoaded()

func _read_json(p: String):
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("DB: cannot read " + p)
		return {}
	var txt := f.get_as_text()
	var v = JSON.parse_string(txt)
	return v if v != null else {}

func _make(cls: String) -> SO:
	var scr = _script_for(cls)
	if scr != null:
		return scr.new()
	return SO.new()

func _script_for(cls: String):
	if _script_cache.has(cls):
		return _script_cache[cls]
	var p := "res://scripts/so/%s.gd" % cls
	var s = load(p) if ResourceLoader.exists(p) else null
	_script_cache[cls] = s
	return s

func of_class(cls: String) -> Array:
	return so_by_class.get(cls, [])

func by_name(cls: String, n: String) -> SO:
	for s in of_class(cls):
		if s.name == n:
			return s
	return null

func get_so(guid: String) -> SO:
	return so_by_guid.get(guid)

func sprite(k: String) -> USprite:
	if k == "":
		return null
	if sprites.has(k):
		return sprites[k]
	var m = sprite_meta.get(k)
	var s: USprite
	if m == null:
		if ResourceLoader.exists(k):
			s = USprite.new()
			s.tex_path = k
			s.name = k.get_file().get_basename()
		else:
			return null
	else:
		s = USprite.from_meta(k, m)
	sprites[k] = s
	return s

func sprite_by_name(n: String) -> USprite:
	for k in sprite_meta:
		if sprite_meta[k].get("name", "") == n:
			return sprite(k)
	return null

func clip(p: String) -> UClip:
	if p == "":
		return null
	if not clips.has(p):
		var c := UClip.new()
		c.path = p
		clips[p] = c
	return clips[p]

func font(info) -> Font:
	if info == null:
		return null
	var ttf := str(info.get("ttf", "")) if info is Dictionary else str(info)
	if ttf == "":
		return null
	if fonts.has(ttf):
		return fonts[ttf]
	var f: FontFile = load(ttf)
	if f == null:
		return null
	if info is Dictionary:
		var fb: Array[Font] = []
		for p in info.get("fallbacks", []):
			var ff = load(p)
			if ff != null and ff != f:
				fb.append(ff)
		if not fb.is_empty():
			f.fallbacks = fb
	fonts[ttf] = f
	return f

func prefab(info: Dictionary) -> UPrefab:
	var k := str(info.get("$prefab", "")) + "|" + str(info.get("node", ""))
	if not prefabs.has(k):
		var p := UPrefab.new()
		p.path = str(info.get("$prefab", ""))
		p.node = str(info.get("node", "")) if info.get("node") != null else "."
		prefabs[k] = p
	return prefabs[k]

func conv(v, owner_root: Node):
	if v is Dictionary:
		if v.has("$so"):
			return so_by_guid.get(v["$so"])
		if v.has("$spr"):
			return sprite(v["$spr"])
		if v.has("$tex"):
			return sprite(v["$tex"])
		if v.has("$audio"):
			return clip(v["$audio"])
		if v.has("$c"):
			var c = v["$c"]
			return Color(c[0], c[1], c[2], c[3])
		if v.has("$font"):
			return font(v["$font"])
		if v.has("$prefab"):
			return prefab(v)
		if v.has("$n"):
			if owner_root == null or v["$n"] == null:
				return null
			var p := str(v["$n"])
			var nd = owner_root if p == "." else owner_root.get_node_or_null(NodePath(p))
			if dup_orig != null and nd != null and (nd == dup_orig or dup_orig.is_ancestor_of(nd)):
				var rel := dup_orig.get_path_to(nd)
				nd = dup_copy if str(rel) == "." else dup_copy.get_node_or_null(rel)
			return nd
		if v.has("$event"):
			var e := UEvent.new()
			for call in v["$event"]:
				var pc: Dictionary = call.duplicate()
				pc["target_node"] = conv(call.get("target"), owner_root)
				var a = call.get("arg")
				if a is Dictionary:
					pc["arg"] = conv(a, owner_root)
				e.persistent.append(pc)
			return e
		var keys: Array = v.keys()
		if keys.size() == 2 and v.has("x") and v.has("y"):
			return Vector2(v["x"], v["y"])
		if keys.size() == 3 and v.has("x") and v.has("y") and v.has("z"):
			return Vector3(v["x"], v["y"], v["z"])
		if keys.size() == 4 and v.has("x") and v.has("y") and v.has("z") and v.has("w"):
			return Vector4(v["x"], v["y"], v["z"], v["w"])
		if keys.size() == 4 and v.has("x") and v.has("y") and v.has("width") and v.has("height"):
			return Rect2(v["x"], v["y"], v["width"], v["height"])
		var out := {}
		for k in v:
			out[k] = conv(v[k], owner_root)
		return out
	if v is Array:
		var a := []
		a.resize(v.size())
		for i in v.size():
			a[i] = conv(v[i], owner_root)
		return a
	if v is float and v == floor(v) and abs(v) < 1e15:
		return int(v)
	return v
