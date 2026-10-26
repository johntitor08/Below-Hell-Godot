class_name UGridLayout
extends ULayoutGroupBase

var cellSize := Vector2(100, 100)
var spacing := Vector2.ZERO
var startCorner := 0
var startAxis := 0
var constraint := 0
var constraintCount := 2

func _group_injected(root: Node) -> void:
	var cs = DB.conv(u.get("m_CellSize"), root)
	if cs is Vector2:
		cellSize = cs
	var sp = DB.conv(u.get("m_Spacing"), root)
	if sp is Vector2:
		spacing = sp
	startCorner = int(u.get("m_StartCorner", 0))
	startAxis = int(u.get("m_StartAxis", 0))
	constraint = int(u.get("m_Constraint", 0))
	constraintCount = maxi(1, int(u.get("m_ConstraintCount", 2)))

func calc_axis(axis: int) -> void:
	var n := rect_children().size()
	if axis == 0:
		var min_cols := 0
		var pref_cols := 0
		if constraint == 1:
			min_cols = constraintCount
			pref_cols = constraintCount
		elif constraint == 2:
			min_cols = ceili(float(n) / constraintCount - 0.001)
			pref_cols = min_cols
		else:
			min_cols = 1
			pref_cols = ceili(sqrt(n))
		set_totals(pad_axis(0) + (cellSize.x + spacing.x) * min_cols - spacing.x, pad_axis(0) + (cellSize.x + spacing.x) * pref_cols - spacing.x, -1.0, 0)
	else:
		var min_rows := 0
		if constraint == 1:
			min_rows = ceili(float(n) / constraintCount - 0.001)
		elif constraint == 2:
			min_rows = constraintCount
		else:
			var width := size_axis(0)
			var cx := maxi(1, floori((width - pad_axis(0) + spacing.x + 0.001) / (cellSize.x + spacing.x)))
			min_rows = ceili(float(n) / cx)
		var m := pad_axis(1) + (cellSize.y + spacing.y) * min_rows - spacing.y
		set_totals(m, m, -1.0, 1)

func set_axis(axis: int) -> void:
	var kids := rect_children()
	if axis == 0:
		for c in kids:
			set_child_along_axis(c, 0, c.offset_left, cellSize.x)
			set_child_along_axis(c, 1, c.offset_top, cellSize.y)
		return
	var n := kids.size()
	var width := size_axis(0)
	var height := size_axis(1)
	var ccx := 1
	var ccy := 1
	if constraint == 1:
		ccx = constraintCount
		if n > ccx:
			ccy = n / ccx + (1 if n % ccx > 0 else 0)
	elif constraint == 2:
		ccy = constraintCount
		if n > ccy:
			ccx = n / ccy + (1 if n % ccy > 0 else 0)
	else:
		ccx = 1000000 if cellSize.x + spacing.x <= 0 else maxi(1, floori((width - pad_axis(0) + spacing.x + 0.001) / (cellSize.x + spacing.x)))
		ccy = 1000000 if cellSize.y + spacing.y <= 0 else maxi(1, floori((height - pad_axis(1) + spacing.y + 0.001) / (cellSize.y + spacing.y)))
	var corner_x := startCorner % 2
	var corner_y := startCorner / 2
	var per_main := 1
	var acx := 1
	var acy := 1
	if startAxis == 0:
		per_main = ccx
		acx = clampi(ccx, 1, maxi(1, n))
		acy = clampi(ccy, 1, maxi(1, ceili(float(n) / per_main)))
	else:
		per_main = ccy
		acy = clampi(ccy, 1, maxi(1, n))
		acx = clampi(ccx, 1, maxi(1, ceili(float(n) / per_main)))
	var req := Vector2(acx * cellSize.x + (acx - 1) * spacing.x, acy * cellSize.y + (acy - 1) * spacing.y)
	var so := Vector2(start_offset(0, req.x), start_offset(1, req.y))
	for i in n:
		var px := 0
		var py := 0
		if startAxis == 0:
			px = i % per_main
			py = i / per_main
		else:
			px = i / per_main
			py = i % per_main
		if corner_x == 1:
			px = acx - 1 - px
		if corner_y == 1:
			py = acy - 1 - py
		set_child_along_axis(kids[i], 0, so.x + (cellSize.x + spacing.x) * px, cellSize.x)
		set_child_along_axis(kids[i], 1, so.y + (cellSize.y + spacing.y) * py, cellSize.y)
