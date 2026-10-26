class_name UBounds
extends RefCounted

var center := Vector2.ZERO
var size := Vector2.ZERO

static func make(c: Vector2, s: Vector2) -> UBounds:
	var b := UBounds.new()
	b.center = c
	b.size = s
	return b

static func from_rect(r: Rect2) -> UBounds:
	return make(r.get_center(), r.size)

var extents: Vector2:
	get:
		return size * 0.5

var min: Vector2:
	get:
		return center - size * 0.5

var max: Vector2:
	get:
		return center + size * 0.5

func Contains(p: Vector2) -> bool:
	return p.x >= min.x and p.x <= max.x and p.y >= min.y and p.y <= max.y

func Intersects(o: UBounds) -> bool:
	return min.x <= o.max.x and max.x >= o.min.x and min.y <= o.max.y and max.y >= o.min.y

func ClosestPoint(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, min.x, max.x), clampf(p.y, min.y, max.y))
