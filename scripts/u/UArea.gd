class_name UArea
extends Area2D

var blob: Dictionary = {}
var _ready_done := false
var is_internal := false
var _inside: Dictionary = {}

var gameObject:
	get:
		return owner_go()

var activeSelf: bool:
	get:
		return visible

var activeInHierarchy: bool:
	get:
		return U.activeInHierarchy(owner_go())

func owner_go():
	return get_meta("trigger_owner") if has_meta("trigger_owner") else self

func _ready() -> void:
	if _ready_done:
		return
	_ready_done = true
	if not is_internal:
		blob = UGo.init(self)
		UGo.apply_layer(self, UGo.layer_of(self))
		visibility_changed.connect(_on_vis)
		_on_vis()
	monitoring = true
	monitorable = true
	body_shape_entered.connect(_on_body_entered)
	body_shape_exited.connect(_on_body_exited)
	area_shape_entered.connect(_on_area_entered)
	area_shape_exited.connect(_on_area_exited)

func _on_vis() -> void:
	UGo.sync_physics_active(self)

func SetActive(v: bool) -> void:
	U.SetActive(self, v)

func CompareTag(t: String) -> bool:
	return UGo.tag_of(owner_go()) == t

var tag: String:
	get:
		return UGo.tag_of(owner_go())
	set(v):
		UGo.set_tag(owner_go(), v)

var layer: int:
	get:
		return UGo.layer_of(owner_go())
	set(v):
		UGo.set_layer(owner_go(), v)

static func _has_rb(go) -> bool:
	return UPhys.rigidbody_of(go) != null

func _pair_ok(other_go) -> bool:
	return _has_rb(owner_go()) or _has_rb(other_go)

func _fire(method: String, my_col, other_col, other_go) -> void:
	var me = owner_go()
	UPhys._send_to_owners(me, my_col, method, other_col)
	if other_go != null and is_instance_valid(other_go):
		UPhys._send_to_owners(other_go, other_col, method, my_col)

func _on_body_entered(_rid: RID, body: Node, body_shape: int, local_shape: int) -> void:
	if body == null or body == owner_go():
		return
	var other_go = UPhys.go_of_collision_object(body)
	if not _pair_ok(other_go):
		return
	var my_col = UPhys.collider_of(self, local_shape)
	var other_col = UPhys.collider_of(body, body_shape)
	if other_col == null:
		return
	var key := "b" + str(body.get_instance_id()) + ":" + str(body_shape) + ":" + str(local_shape)
	_inside[key] = [my_col, other_col, other_go]
	_fire("OnTriggerEnter2D", my_col, other_col, other_go)

func _on_body_exited(_rid: RID, body: Node, body_shape: int, local_shape: int) -> void:
	var key := "b" + (str(body.get_instance_id()) if body != null else "0") + ":" + str(body_shape) + ":" + str(local_shape)
	if not _inside.has(key):
		return
	var e: Array = _inside[key]
	_inside.erase(key)
	if e[1] != null and is_instance_valid(e[1]):
		_fire("OnTriggerExit2D", e[0], e[1], e[2])

func _on_area_entered(_rid: RID, area: Area2D, area_shape: int, local_shape: int) -> void:
	if area == null or not (area is UArea):
		return
	var other_go = area.owner_go()
	if other_go == owner_go() or get_instance_id() > area.get_instance_id():
		return
	if not _pair_ok(other_go):
		return
	var my_col = UPhys.collider_of(self, local_shape)
	var other_col = UPhys.collider_of(area, area_shape)
	if other_col == null:
		return
	var key := "a" + str(area.get_instance_id()) + ":" + str(area_shape) + ":" + str(local_shape)
	_inside[key] = [my_col, other_col, other_go]
	_fire("OnTriggerEnter2D", my_col, other_col, other_go)

func _on_area_exited(_rid: RID, area: Area2D, area_shape: int, local_shape: int) -> void:
	var key := "a" + (str(area.get_instance_id()) if area != null else "0") + ":" + str(area_shape) + ":" + str(local_shape)
	if not _inside.has(key):
		return
	var e: Array = _inside[key]
	_inside.erase(key)
	if e[1] != null and is_instance_valid(e[1]):
		_fire("OnTriggerExit2D", e[0], e[1], e[2])

func _physics_process(_d: float) -> void:
	if _inside.is_empty():
		return
	var me = owner_go()
	var want := UPhys.has_handler(me, "OnTriggerStay2D")
	if not want:
		for k in _inside:
			var og = _inside[k][2]
			if og != null and is_instance_valid(og) and UPhys.has_handler(og, "OnTriggerStay2D"):
				want = true
				break
	if not want:
		return
	for k in _inside.keys():
		var e: Array = _inside[k]
		if e[1] != null and is_instance_valid(e[1]):
			_fire("OnTriggerStay2D", e[0], e[1], e[2])
