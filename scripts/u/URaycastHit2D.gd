class_name URaycastHit2D
extends RefCounted

var collider = null
var point := Vector2.ZERO
var normal := Vector2.ZERO
var distance := 0.0
var fraction := 0.0
var centroid := Vector2.ZERO

var transform:
	get:
		return collider.gameObject if collider != null and is_instance_valid(collider) else null

var rigidbody:
	get:
		return UPhys.rigidbody_of(collider.gameObject) if collider != null and is_instance_valid(collider) else null

var hit: bool:
	get:
		return collider != null and is_instance_valid(collider)
