class_name UGrid
extends Mono

var cellSize := Vector2.ONE
var cellGap := Vector2.ZERO

func _on_injected(_root: Node) -> void:
	var c = u.get("m_CellSize")
	if c is Dictionary:
		cellSize = Vector2(float(c.get("x", 1)), float(c.get("y", 1)))
	var g = u.get("m_CellGap")
	if g is Dictionary:
		cellGap = Vector2(float(g.get("x", 0)), float(g.get("y", 0)))

func WorldToCell(w) -> Vector2i:
	var l := UPhys.to_unity(gameObject.global_transform.affine_inverse() * UPhys.to_godot(Vector2(w.x, w.y)))
	var step := cellSize + cellGap
	return Vector2i(floori(l.x / step.x), floori(l.y / step.y))

func CellToWorld(c) -> Vector2:
	var step := cellSize + cellGap
	var l := Vector2(c.x * step.x, c.y * step.y)
	return UPhys.to_unity(gameObject.global_transform * UPhys.to_godot(l))

func GetCellCenterWorld(c) -> Vector2:
	var step := cellSize + cellGap
	var l := Vector2(c.x * step.x + cellSize.x * 0.5, c.y * step.y + cellSize.y * 0.5)
	return UPhys.to_unity(gameObject.global_transform * UPhys.to_godot(l))
