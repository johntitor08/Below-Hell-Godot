class_name ULayoutGroupBase
extends Mono

var padding := {"left": 0, "right": 0, "top": 0, "bottom": 0}
var _childAlignment := 0
var _totals := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]

var childAlignment: int:
	get:
		return _childAlignment
	set(v):
		_childAlignment = v
		ES.mark_layout_dirty()

func _on_injected(root: Node) -> void:
	var p = u.get("m_Padding")
	if p is Dictionary:
		padding = {"left": float(p.get("m_Left", 0)), "right": float(p.get("m_Right", 0)), "top": float(p.get("m_Top", 0)), "bottom": float(p.get("m_Bottom", 0))}
	_childAlignment = int(u.get("m_ChildAlignment", 0))
	_group_injected(root)

func _group_injected(_root: Node) -> void:
	pass

func SetPadding(l: float, r: float, t: float, b: float) -> void:
	padding = {"left": l, "right": r, "top": t, "bottom": b}
	ES.mark_layout_dirty()

func OnEnable() -> void:
	ES.mark_layout_dirty()

func OnDisable() -> void:
	ES.mark_layout_dirty()

func pad_axis(axis: int) -> float:
	return (padding.left + padding.right) if axis == 0 else (padding.top + padding.bottom)

func pad_start(axis: int) -> float:
	return padding.left if axis == 0 else padding.top

func rect_children() -> Array:
	var a := []
	var go = gameObject
	if go == null:
		return a
	for c in go.get_children():
		if c is Control and c.has_meta("u") and c.visible and not ES.ignore_layout(c):
			a.append(c)
	return a

func totals(axis: int) -> Array:
	return _totals[axis]

func set_totals(mn: float, pr: float, fl: float, axis: int) -> void:
	_totals[axis] = [mn, pr, fl]

func alignment_on_axis(axis: int) -> float:
	if axis == 0:
		return (_childAlignment % 3) * 0.5
	return (_childAlignment / 3) * 0.5

func size_axis(axis: int) -> float:
	var s: Vector2 = gameObject.size
	return s.x if axis == 0 else s.y

func start_offset(axis: int, required_without_padding: float) -> float:
	var required := required_without_padding + pad_axis(axis)
	var surplus := size_axis(axis) - required
	return pad_start(axis) + surplus * alignment_on_axis(axis)

static func set_child_along_axis(c: Control, axis: int, pos: float, size := -1.0, scale_factor := 1.0) -> void:
	c.set_anchor(SIDE_LEFT, 0.0, true, false)
	c.set_anchor(SIDE_RIGHT, 0.0, true, false)
	c.set_anchor(SIDE_TOP, 0.0, true, false)
	c.set_anchor(SIDE_BOTTOM, 0.0, true, false)
	if axis == 0:
		var w := size if size >= 0.0 else (c.offset_right - c.offset_left)
		c.offset_left = pos
		c.offset_right = pos + w
		if scale_factor != 1.0 and size >= 0.0:
			c.offset_right = pos + w
	else:
		var h := size if size >= 0.0 else (c.offset_bottom - c.offset_top)
		c.offset_top = pos
		c.offset_bottom = pos + h

func calc_axis(_axis: int) -> void:
	pass

func set_axis(_axis: int) -> void:
	pass
