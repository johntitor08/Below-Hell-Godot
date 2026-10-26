class_name ULayoutGroup
extends ULayoutGroupBase

var isVertical := true
var _spacing := 0.0
var childControlWidth := true
var childControlHeight := true
var childForceExpandWidth := true
var childForceExpandHeight := true
var childScaleWidth := false
var childScaleHeight := false
var reverseArrangement := false

var spacing: float:
	get:
		return _spacing
	set(v):
		_spacing = v
		ES.mark_layout_dirty()

func _group_injected(_root: Node) -> void:
	isVertical = str(u.get("$type", "")) == "VerticalLayoutGroup"
	_spacing = float(u.get("m_Spacing", 0))
	childControlWidth = int(u.get("m_ChildControlWidth", 1)) != 0
	childControlHeight = int(u.get("m_ChildControlHeight", 1)) != 0
	childForceExpandWidth = int(u.get("m_ChildForceExpandWidth", 1)) != 0
	childForceExpandHeight = int(u.get("m_ChildForceExpandHeight", 1)) != 0
	childScaleWidth = int(u.get("m_ChildScaleWidth", 0)) != 0
	childScaleHeight = int(u.get("m_ChildScaleHeight", 0)) != 0
	reverseArrangement = int(u.get("m_ReverseArrangement", 0)) != 0

func _child_sizes(c: Control, axis: int, control: bool, force: bool) -> Array:
	var mn := 0.0
	var pr := 0.0
	var fl := 0.0
	if control:
		var p := ES.layout_props(c, axis)
		mn = p[0]
		pr = p[1]
		fl = p[2]
	else:
		var sd := RT.size_delta(c)
		mn = sd.x if axis == 0 else sd.y
		pr = mn
		fl = 0.0
	if force:
		fl = maxf(fl, 1.0)
	return [mn, pr, fl]

func _scale_of(c: Control, axis: int, use: bool) -> float:
	if not use:
		return 1.0
	return c.scale.x if axis == 0 else c.scale.y

func calc_axis(axis: int) -> void:
	var cp := pad_axis(axis)
	var control := childControlWidth if axis == 0 else childControlHeight
	var use_scale := childScaleWidth if axis == 0 else childScaleHeight
	var force := childForceExpandWidth if axis == 0 else childForceExpandHeight
	var tmin := cp
	var tpref := cp
	var tflex := 0.0
	var along_other := isVertical != (axis == 1)
	var kids := rect_children()
	for c in kids:
		var s := _child_sizes(c, axis, control, force)
		var sc := _scale_of(c, axis, use_scale)
		if along_other:
			tmin = maxf(s[0] * sc + cp, tmin)
			tpref = maxf(s[1] * sc + cp, tpref)
			tflex = maxf(s[2], tflex)
		else:
			tmin += s[0] * sc + _spacing
			tpref += s[1] * sc + _spacing
			tflex += s[2]
	if not along_other and kids.size() > 0:
		tmin -= _spacing
		tpref -= _spacing
	tpref = maxf(tmin, tpref)
	set_totals(tmin, tpref, tflex, axis)

func set_axis(axis: int) -> void:
	var size := size_axis(axis)
	var control := childControlWidth if axis == 0 else childControlHeight
	var use_scale := childScaleWidth if axis == 0 else childScaleHeight
	var force := childForceExpandWidth if axis == 0 else childForceExpandHeight
	var align := alignment_on_axis(axis)
	var along_other := isVertical != (axis == 1)
	var kids := rect_children()
	if reverseArrangement:
		kids.reverse()
	if along_other:
		var inner := size - pad_axis(axis)
		for c in kids:
			var s := _child_sizes(c, axis, control, force)
			var sc := _scale_of(c, axis, use_scale)
			var required := clampf(inner, s[0], s[1] if s[2] <= 0 else size)
			var so := start_offset(axis, required * sc)
			if control:
				set_child_along_axis(c, axis, so, required, sc)
			else:
				var sd := RT.size_delta(c)
				var cur := sd.x if axis == 0 else sd.y
				var off_in_cell := (required - cur) * align
				set_child_along_axis(c, axis, so + off_in_cell * sc, -1.0, sc)
	else:
		var pos := pad_start(axis)
		var flex_mult := 0.0
		var t: Array = totals(axis)
		var surplus: float = size - t[1]
		if surplus > 0:
			if t[2] == 0:
				pos = start_offset(axis, t[1] - pad_axis(axis))
			elif t[2] > 0:
				flex_mult = surplus / t[2]
		var min_max_lerp := 0.0
		if t[0] != t[1]:
			min_max_lerp = clampf((size - t[0]) / (t[1] - t[0]), 0.0, 1.0)
		for c in kids:
			var s := _child_sizes(c, axis, control, force)
			var sc := _scale_of(c, axis, use_scale)
			var child_size := lerpf(s[0], s[1], min_max_lerp)
			child_size += s[2] * flex_mult
			if control:
				set_child_along_axis(c, axis, pos, child_size, sc)
			else:
				var sd := RT.size_delta(c)
				var cur := sd.x if axis == 0 else sd.y
				var off_in_cell := (child_size - cur) * align
				set_child_along_axis(c, axis, pos + off_in_cell, -1.0, sc)
			pos += child_size * sc + _spacing
