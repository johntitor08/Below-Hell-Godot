class_name UStaticBody
extends StaticBody2D

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

func _ready() -> void:
	if _ready_done:
		return
	_ready_done = true
	blob = UGo.init(self)
	UGo.apply_layer(self, UGo.layer_of(self))
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	physics_material_override = pm
	visibility_changed.connect(_on_vis)
	_on_vis()

func _on_vis() -> void:
	UGo.sync_physics_active(self)

func SetActive(v: bool) -> void:
	U.SetActive(self, v)

func CompareTag(t: String) -> bool:
	return UGo.tag_of(self) == t

var tag: String:
	get:
		return UGo.tag_of(self)
	set(v):
		UGo.set_tag(self, v)

var layer: int:
	get:
		return UGo.layer_of(self)
	set(v):
		UGo.set_layer(self, v)
