class_name UCollision2D
extends RefCounted

var gameObject = null
var collider = null
var otherCollider = null
var rigidbody = null
var otherRigidbody = null
var relativeVelocity := Vector2.ZERO
var contacts: Array = []

var transform:
	get:
		return gameObject

var contactCount: int:
	get:
		return contacts.size()

func GetContact(i: int) -> UContactPoint2D:
	return contacts[i] if i < contacts.size() else UContactPoint2D.new()
