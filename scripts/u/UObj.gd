@tool
class_name UObj
extends Node2D

var blob: Dictionary = {}
var _ready_done := false

var gameObject:
	get:
		return self

var activeSelf: bool:
	get:
		return visible

var activeInHierarchy: bool:
	get:
		return U.activeInHierarchy(self)

var u_name: String:
	get:
		return get_meta("u_name", name)
	set(v):
		set_meta("u_name", v)

var localScale:
	get:
		return Vector3(scale.x, scale.y, 1.0)
	set(v):
		scale = Vector2(v.x, v.y)

func _ready() -> void:
	if _ready_done:
		return
	_ready_done = true
	var raw = get_meta("u", "")
	if raw is String and raw != "":
		var p = JSON.parse_string(raw)
		if p is Dictionary:
			blob = p
	if blob.has("name"):
		set_meta("u_name", blob["name"])
	var tag := str(blob.get("tag", "Untagged"))
	if tag != "Untagged" and not Engine.is_editor_hint():
		add_to_group("go_tag_" + tag)

func SetActive(v: bool) -> void:
	U.SetActive(self, v)

func CompareTag(t: String) -> bool:
	return str(blob.get("tag", "Untagged")) == t
