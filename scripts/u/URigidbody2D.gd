class_name URigidbody2D
extends RigidBody2D

const P := UPhys.PPU

var blob: Dictionary = {}
var _ready_done := false
var _bodyType := 0
var _constraints := 0
var _simulated := true
var _saved_layers := Vector2i.ZERO
var _kin_velocity := Vector2.ZERO
var _move_target = null
var _move_rot = null
var _fixed_pos := Vector2.ZERO
var _contacts: Dictionary = {}
var _touching: Dictionary = {}
var _full_kin := false

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
	var rb: Dictionary = blob.get("rb", {})
	contact_monitor = true
	max_contacts_reported = 16
	can_sleep = true
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	mass = maxf(float(rb.get("mass", 1.0)), 0.0001)
	gravity_scale = float(rb.get("gravityScale", 1.0))
	linear_damp = float(rb.get("drag", 0.0))
	angular_damp = float(rb.get("angularDrag", 0.05))
	_full_kin = bool(rb.get("useFullKinematicContacts", false))
	var m = rb.get("material")
	var pm := PhysicsMaterial.new()
	pm.friction = float(m.get("friction", 0.4)) if m is Dictionary else 0.4
	pm.bounce = float(m.get("bounciness", 0.0)) if m is Dictionary else 0.0
	physics_material_override = pm
	if int(rb.get("collisionDetection", 0)) == 1:
		continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	UGo.apply_layer(self, UGo.layer_of(self))
	constraints = int(rb.get("constraints", 0))
	bodyType = int(rb.get("bodyType", 0))
	if not bool(rb.get("simulated", true)):
		simulated = false
	body_shape_entered.connect(_on_shape_entered)
	body_shape_exited.connect(_on_shape_exited)
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

var velocity: Vector2:
	get:
		if _bodyType == 1:
			return _kin_velocity
		return Vector2(linear_velocity.x / P, -linear_velocity.y / P)
	set(v):
		if _bodyType == 1:
			_kin_velocity = v
		elif _bodyType == 0:
			linear_velocity = Vector2(v.x * P, -v.y * P)
			if v != Vector2.ZERO:
				sleeping = false

var linearVelocity: Vector2:
	get:
		return velocity
	set(v):
		velocity = v

var linearVelocityX: float:
	get:
		return velocity.x
	set(v):
		velocity = Vector2(v, velocity.y)

var linearVelocityY: float:
	get:
		return velocity.y
	set(v):
		velocity = Vector2(velocity.x, v)

var angularVelocity: float:
	get:
		return -rad_to_deg(angular_velocity)
	set(v):
		angular_velocity = -deg_to_rad(v)

var gravityScale: float:
	get:
		return gravity_scale
	set(v):
		gravity_scale = v

var drag: float:
	get:
		return linear_damp
	set(v):
		linear_damp = v

var linearDamping: float:
	get:
		return linear_damp
	set(v):
		linear_damp = v

var angularDrag: float:
	get:
		return angular_damp
	set(v):
		angular_damp = v

var bodyType: int:
	get:
		return _bodyType
	set(v):
		_bodyType = v
		match v:
			0:
				freeze = false
			1:
				freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
				freeze = true
				_kin_velocity = Vector2.ZERO
			_:
				freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
				freeze = true

var isKinematic: bool:
	get:
		return _bodyType == 1
	set(v):
		bodyType = 1 if v else 0

var simulated: bool:
	get:
		return _simulated
	set(v):
		if v == _simulated:
			return
		_simulated = v
		if not v:
			_saved_layers = Vector2i(collision_layer, collision_mask)
			collision_layer = 0
			collision_mask = 0
			freeze = true
		else:
			collision_layer = _saved_layers.x
			collision_mask = _saved_layers.y
			bodyType = _bodyType

var constraints: int:
	get:
		return _constraints
	set(v):
		_constraints = v
		lock_rotation = (v & 4) != 0
		if (v & 3) != 0:
			_fixed_pos = global_position

var freezeRotation: bool:
	get:
		return (_constraints & 4) != 0
	set(f):
		constraints = (_constraints | 4) if f else (_constraints & ~4)

var rbPosition: Vector2:
	get:
		return UPhys.to_unity(global_position)
	set(v):
		global_position = UPhys.to_godot(v)
		_fixed_pos = global_position
		if not freeze:
			PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)

var rbRotation: float:
	get:
		return -rad_to_deg(global_rotation)
	set(v):
		global_rotation = -deg_to_rad(v)

var worldCenterOfMass: Vector2:
	get:
		return UPhys.to_unity(global_position + center_of_mass.rotated(global_rotation))

func AddForce(force: Vector2, mode := 0) -> void:
	if _bodyType != 0:
		return
	var f := Vector2(force.x * P, -force.y * P)
	if mode == 1:
		apply_central_impulse(f)
	else:
		apply_central_force(f)
	sleeping = false

func AddRelativeForce(force: Vector2, mode := 0) -> void:
	AddForce(force.rotated(deg_to_rad(rbRotation)), mode)

func AddForceAtPosition(force: Vector2, pos: Vector2, mode := 0) -> void:
	if _bodyType != 0:
		return
	var f := Vector2(force.x * P, -force.y * P)
	var off := UPhys.to_godot(pos) - global_position
	if mode == 1:
		apply_impulse(f, off)
	else:
		apply_force(f, off)
	sleeping = false

func AddTorque(t: float, mode := 0) -> void:
	if _bodyType != 0:
		return
	if mode == 1:
		apply_torque_impulse(-deg_to_rad(t) * P * P)
	else:
		apply_torque(-t * P * P)

func MovePosition(p: Vector2) -> void:
	_move_target = UPhys.to_godot(p)

func MoveRotation(deg: float) -> void:
	_move_rot = -deg_to_rad(deg)

func Sleep() -> void:
	sleeping = true

func WakeUp() -> void:
	sleeping = false

func IsSleeping() -> bool:
	return sleeping

func IsAwake() -> bool:
	return not sleeping

func IsTouching(col) -> bool:
	for k in _touching:
		if _touching[k] == col:
			return true
	return false

func IsTouchingLayers(mask := -1) -> bool:
	for b in get_colliding_bodies():
		var l := UGo.layer_of(UPhys.go_of_collision_object(b))
		if (mask & (1 << l)) != 0:
			return true
	return false

func GetAttachedColliders() -> Array:
	var out := []
	for c in get_children():
		if c is UCollider2D:
			out.append(c)
	return out

func _physics_process(delta: float) -> void:
	if _bodyType == 1 and _kin_velocity != Vector2.ZERO and _move_target == null:
		global_position += Vector2(_kin_velocity.x * P, -_kin_velocity.y * P) * delta
	if freeze and _move_target != null:
		global_position = _move_target
		_move_target = null
	if freeze and _move_rot != null:
		global_rotation = _move_rot
		_move_rot = null
	_stay_events()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _move_target != null:
		var t := state.transform
		t.origin = _move_target
		state.transform = t
		_move_target = null
	if _move_rot != null:
		var t2 := state.transform
		t2 = Transform2D(_move_rot, t2.get_scale(), t2.get_skew(), t2.origin)
		state.transform = t2
		_move_rot = null
	if (_constraints & 3) != 0:
		var lv := state.linear_velocity
		var o := state.transform.origin
		if (_constraints & 1) != 0:
			lv.x = 0.0
			o.x = _fixed_pos.x
		if (_constraints & 2) != 0:
			lv.y = 0.0
			o.y = _fixed_pos.y
		state.linear_velocity = lv
		var t3 := state.transform
		t3.origin = o
		state.transform = t3
	else:
		_fixed_pos = state.transform.origin
	_contacts.clear()
	for i in state.get_contact_count():
		var obj := state.get_contact_collider_object(i)
		if obj == null:
			continue
		var key := obj.get_instance_id()
		if not _contacts.has(key):
			_contacts[key] = [state.get_contact_local_position(i), state.get_contact_local_normal(i), state.get_contact_collider_velocity_at_position(i)]

func _relevant(other) -> bool:
	if _bodyType == 0:
		return true
	if other is URigidbody2D and other._bodyType == 0:
		return true
	return _full_kin

func _pair_owner(other) -> bool:
	if other is URigidbody2D and other.contact_monitor and other._bodyType == 0 and _bodyType == 0:
		return get_instance_id() < other.get_instance_id()
	if other is URigidbody2D and _bodyType != 0 and other._bodyType == 0:
		return false
	return true

func _on_shape_entered(_rid: RID, body: Node, body_shape: int, local_shape: int) -> void:
	if body == null or not _relevant(body) or not _pair_owner(body):
		return
	var my_col = UPhys.collider_of(self, local_shape)
	var other_col = UPhys.collider_of(body, body_shape)
	_touching[str(local_shape) + ":" + str(body.get_instance_id()) + ":" + str(body_shape)] = other_col
	var info = _contacts.get(body.get_instance_id())
	var point := UPhys.to_unity(global_position)
	var normal := Vector2.UP
	var rel := velocity
	if info != null:
		point = UPhys.to_unity(info[0])
		var n: Vector2 = info[1]
		normal = Vector2(n.x, -n.y)
	if body is URigidbody2D:
		rel = velocity - body.velocity
	UPhys.dispatch_collision(self, my_col, UPhys.go_of_collision_object(body), other_col, "OnCollisionEnter2D", point, normal, rel)

func _on_shape_exited(_rid: RID, body: Node, body_shape: int, local_shape: int) -> void:
	var key := str(local_shape) + ":" + (str(body.get_instance_id()) if body != null else "0") + ":" + str(body_shape)
	if not _touching.has(key):
		return
	var other_col = _touching[key]
	_touching.erase(key)
	if body == null or not is_instance_valid(body):
		return
	var my_col = UPhys.collider_of(self, local_shape)
	UPhys.dispatch_collision(self, my_col, UPhys.go_of_collision_object(body), other_col, "OnCollisionExit2D", UPhys.to_unity(global_position), Vector2.UP, Vector2.ZERO)

func _stay_events() -> void:
	if _touching.is_empty():
		return
	var any := UPhys.has_handler(self, "OnCollisionStay2D")
	if not any:
		for k in _touching:
			var oc = _touching[k]
			if oc != null and is_instance_valid(oc) and UPhys.has_handler(oc.gameObject, "OnCollisionStay2D"):
				any = true
				break
	if not any:
		return
	for k in _touching.keys():
		var oc = _touching[k]
		if oc == null or not is_instance_valid(oc):
			continue
		var parts := str(k).split(":")
		var my_col = UPhys.collider_of(self, int(parts[0]))
		UPhys.dispatch_collision(self, my_col, UPhys.go_of_collision_object(oc.body()), oc, "OnCollisionStay2D", UPhys.to_unity(global_position), Vector2.UP, Vector2.ZERO)
