@tool
class_name RT

static func pivot(c: Control) -> Vector2:
	var p = c.get_meta("pivot", [0.5, 0.5])
	return Vector2(p[0], p[1]) if p is Array else p

static func set_pivot(c: Control, v: Vector2) -> void:
	c.set_meta("pivot", [v.x, v.y])
	c.pivot_offset_ratio = Vector2(v.x, 1.0 - v.y)

static func anchor_min(c: Control) -> Vector2:
	return Vector2(c.anchor_left, 1.0 - c.anchor_bottom)

static func anchor_max(c: Control) -> Vector2:
	return Vector2(c.anchor_right, 1.0 - c.anchor_top)

static func set_anchor_min(c: Control, v: Vector2) -> void:
	c.set_anchor(SIDE_LEFT, v.x, true, false)
	c.set_anchor(SIDE_BOTTOM, 1.0 - v.y, true, false)
	ES.mark_layout_dirty()

static func set_anchor_max(c: Control, v: Vector2) -> void:
	c.set_anchor(SIDE_RIGHT, v.x, true, false)
	c.set_anchor(SIDE_TOP, 1.0 - v.y, true, false)
	ES.mark_layout_dirty()

static func offset_min(c: Control) -> Vector2:
	return Vector2(c.offset_left, -c.offset_bottom)

static func offset_max(c: Control) -> Vector2:
	return Vector2(c.offset_right, -c.offset_top)

static func set_offset_min(c: Control, v: Vector2) -> void:
	c.offset_left = v.x
	c.offset_bottom = -v.y
	ES.mark_layout_dirty()

static func set_offset_max(c: Control, v: Vector2) -> void:
	c.offset_right = v.x
	c.offset_top = -v.y
	ES.mark_layout_dirty()

static func size_delta(c: Control) -> Vector2:
	return offset_max(c) - offset_min(c)

static func anchored_position(c: Control) -> Vector2:
	var p := pivot(c)
	var omin := offset_min(c)
	var sd := size_delta(c)
	return omin + sd * p

static func set_anchored_position(c: Control, ap: Vector2) -> void:
	var p := pivot(c)
	var sd := size_delta(c)
	var omin := ap - sd * p
	_apply(c, omin, omin + sd)

static func set_size_delta(c: Control, sd: Vector2) -> void:
	var p := pivot(c)
	var ap := anchored_position(c)
	var omin := ap - sd * p
	_apply(c, omin, omin + sd)

static func _apply(c: Control, omin: Vector2, omax: Vector2) -> void:
	c.offset_left = omin.x
	c.offset_right = omax.x
	c.offset_bottom = -omin.y
	c.offset_top = -omax.y
	ES.mark_layout_dirty()

static func set_pivot_keep_rect(c: Control, v: Vector2) -> void:
	set_pivot(c, v)

static func rect(c: Control) -> Rect2:
	var p := pivot(c)
	var s := c.size
	return Rect2(-p.x * s.x, -p.y * s.y, s.x, s.y)

static func parent_size(c: Control) -> Vector2:
	var par = c.get_parent()
	if par is Control:
		return par.size
	return Vector2(U.REF_W, U.REF_H)

static func set_size_with_current_anchors(c: Control, axis: int, size: float) -> void:
	var sd := size_delta(c)
	var ps := parent_size(c)
	if axis == 0:
		sd.x = size - (c.anchor_right - c.anchor_left) * ps.x
	else:
		sd.y = size - (c.anchor_bottom - c.anchor_top) * ps.y
	set_size_delta(c, sd)

static func set_inset_and_size(c: Control, edge: int, inset: float, size: float) -> void:
	var axis := 0 if edge == 0 or edge == 1 else 1
	var end := edge == 1 or edge == 2
	if axis == 0:
		var a := 1.0 if end else 0.0
		c.set_anchor(SIDE_LEFT, a, true, false)
		c.set_anchor(SIDE_RIGHT, a, true, false)
	else:
		var ay := 1.0 if end else 0.0
		c.set_anchor(SIDE_TOP, 1.0 - ay, true, false)
		c.set_anchor(SIDE_BOTTOM, 1.0 - ay, true, false)
	var sd := size_delta(c)
	var ap := anchored_position(c)
	var p := pivot(c)
	if axis == 0:
		sd.x = size
		ap.x = (-inset - size * (1.0 - p.x)) if end else (inset + size * p.x)
	else:
		sd.y = size
		ap.y = (-inset - size * (1.0 - p.y)) if end else (inset + size * p.y)
	var omin := ap - sd * p
	_apply(c, omin, omin + sd)

static func local_scale(c: CanvasItem) -> Vector3:
	if c is Control:
		return Vector3(c.scale.x, c.scale.y, 1.0)
	if c is Node2D:
		return Vector3(c.scale.x, c.scale.y, 1.0)
	return Vector3.ONE

static func set_local_scale(c: CanvasItem, v) -> void:
	var s := Vector2(v.x, v.y)
	if c is Control or c is Node2D:
		c.scale = s

static func world_corners(c: Control) -> Array:
	var xf := c.get_global_transform_with_canvas()
	var s := c.size
	return [xf * Vector2(0, s.y), xf * Vector2(0, 0), xf * Vector2(s.x, 0), xf * Vector2(s.x, s.y)]

static func screen_to_local(c: Control, unity_screen: Vector2) -> Vector2:
	var godot_pt := U.from_unity_screen(unity_screen)
	var inv := c.get_global_transform_with_canvas().affine_inverse()
	var lp := inv * godot_pt
	var p := pivot(c)
	return Vector2(lp.x - p.x * c.size.x, (c.size.y - lp.y) - p.y * c.size.y)

static func contains_screen_point(c: Control, unity_screen: Vector2) -> bool:
	var godot_pt := U.from_unity_screen(unity_screen)
	var inv := c.get_global_transform_with_canvas().affine_inverse()
	var lp := inv * godot_pt
	return Rect2(Vector2.ZERO, c.size).has_point(lp)

static func local_to_godot(c: Control, local_unity: Vector2) -> Vector2:
	var p := pivot(c)
	return Vector2(local_unity.x + p.x * c.size.x, c.size.y - (local_unity.y + p.y * c.size.y))
