@tool
class_name UPrefab
extends RefCounted

var path: String = ""
var node: String = ""
var _packed: PackedScene

var packed: PackedScene:
	get:
		if _packed == null:
			_packed = load(path)
		return _packed
