@tool
class_name SO
extends RefCounted

var d: Dictionary = {}
var guid: String = ""
var asset_path: String = ""

var name: String:
	get:
		return str(d.get("name", ""))
	set(v):
		d["name"] = v

func _get(property: StringName):
	var k := String(property)
	if d.has(k):
		return d[k]
	return null

func _set(property: StringName, value) -> bool:
	var k := String(property)
	if k in ["d", "guid", "asset_path", "name"]:
		return false
	d[k] = value
	return true

func duplicate_so() -> SO:
	var s: SO = get_script().new()
	s.d = d.duplicate(true)
	s.guid = guid
	s.asset_path = asset_path
	return s

func _to_string() -> String:
	return "<%s %s>" % [get_script().get_global_name(), name]
