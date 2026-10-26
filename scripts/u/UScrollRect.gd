class_name UScrollRect
extends Mono

enum MovementType { UNRESTRICTED, ELASTIC, CLAMPED }

var content
var viewport
var horizontal := true
var vertical := true
var movementType := 1
var elasticity := 0.1
var inertia := true
var decelerationRate := 0.135
var scrollSensitivity := 1.0
var horizontalScrollbar
var verticalScrollbar
var horizontalScrollbarVisibility := 0
var verticalScrollbarVisibility := 0
var onValueChanged := UEvent.new()
var velocity := Vector2.ZERO
var _dragging := false
var _pointer_start := Vector2.ZERO
var _content_start := Vector2.ZERO
var _prev_pos := Vector2.ZERO
var _view_min := Vector2.ZERO
var _view_max := Vector2.ZERO
var _cont_min := Vector2.ZERO
var _cont_max := Vector2.ZERO
var _sb_updating := false

func _on_injected(root: Node) -> void:
	content = DB.conv(u.get("m_Content"), root)
	viewport = DB.conv(u.get("m_Viewport"), root)
	horizontal = int(u.get("m_Horizontal", 1)) != 0
	vertical = int(u.get("m_Vertical", 1)) != 0
	movementType = int(u.get("m_MovementType", 1))
	elasticity = float(u.get("m_Elasticity", 0.1))
	inertia = int(u.get("m_Inertia", 1)) != 0
	decelerationRate = float(u.get("m_DecelerationRate", 0.135))
	scrollSensitivity = float(u.get("m_ScrollSensitivity", 1))
	horizontalScrollbar = DB.conv(u.get("m_HorizontalScrollbar"), root)
	verticalScrollbar = DB.conv(u.get("m_VerticalScrollbar"), root)
	horizontalScrollbarVisibility = int(u.get("m_HorizontalScrollbarVisibility", 0))
	verticalScrollbarVisibility = int(u.get("m_VerticalScrollbarVisibility", 0))
	var e = DB.conv(u.get("m_OnValueChanged"), root)
	if e is UEvent:
		onValueChanged = e

func view_rect() -> Control:
	if viewport is Control and is_instance_valid(viewport):
		return viewport
	return gameObject

func OnEnable() -> void:
	if horizontalScrollbar is UScrollbar:
		horizontalScrollbar.onValueChanged.AddListener(_set_h_norm)
	if verticalScrollbar is UScrollbar:
		verticalScrollbar.onValueChanged.AddListener(_set_v_norm)

func OnDisable() -> void:
	if horizontalScrollbar is UScrollbar:
		horizontalScrollbar.onValueChanged.RemoveListener(_set_h_norm)
	if verticalScrollbar is UScrollbar:
		verticalScrollbar.onValueChanged.RemoveListener(_set_v_norm)
	_dragging = false
	velocity = Vector2.ZERO

func _set_h_norm(v) -> void:
	if not _sb_updating:
		set_normalized(float(v), 0)

func _set_v_norm(v) -> void:
	if not _sb_updating:
		set_normalized(float(v), 1)

func update_bounds() -> void:
	var vr := view_rect()
	if not (content is Control) or vr == null:
		return
	var inv := vr.get_global_transform_with_canvas().affine_inverse()
	var cx: Transform2D = content.get_global_transform_with_canvas()
	var cs: Vector2 = content.size
	var p0: Vector2 = inv * (cx * Vector2.ZERO)
	var p1: Vector2 = inv * (cx * cs)
	var vs := vr.size
	var vp := RT.pivot(vr)
	_view_min = Vector2(-vp.x * vs.x, -vp.y * vs.y)
	_view_max = _view_min + vs
	var gmin := Vector2(min(p0.x, p1.x), min(p0.y, p1.y))
	var gmax := Vector2(max(p0.x, p1.x), max(p0.y, p1.y))
	_cont_min = Vector2(gmin.x - vp.x * vs.x, (vs.y - gmax.y) - vp.y * vs.y)
	_cont_max = Vector2(gmax.x - vp.x * vs.x, (vs.y - gmin.y) - vp.y * vs.y)
	var csize := _cont_max - _cont_min
	var cpos := (_cont_min + _cont_max) * 0.5
	var cpiv := RT.pivot(content)
	var vsize := _view_max - _view_min
	var excess := vsize - csize
	if excess.x > 0:
		cpos.x -= excess.x * (cpiv.x - 0.5)
		csize.x = vsize.x
	if excess.y > 0:
		cpos.y -= excess.y * (cpiv.y - 0.5)
		csize.y = vsize.y
	_cont_min = cpos - csize * 0.5
	_cont_max = cpos + csize * 0.5

func calc_offset(delta: Vector2) -> Vector2:
	var off := Vector2.ZERO
	if movementType == MovementType.UNRESTRICTED:
		return off
	var mn := _cont_min + delta
	var mx := _cont_max + delta
	if horizontal:
		if mn.x > _view_min.x:
			off.x = _view_min.x - mn.x
		elif mx.x < _view_max.x:
			off.x = _view_max.x - mx.x
	if vertical:
		if mx.y < _view_max.y:
			off.y = _view_max.y - mx.y
		elif mn.y > _view_min.y:
			off.y = _view_min.y - mn.y
	return off

func set_content_pos(p: Vector2) -> void:
	if not (content is Control):
		return
	var cur: Vector2 = RT.anchored_position(content)
	if not horizontal:
		p.x = cur.x
	if not vertical:
		p.y = cur.y
	if p != cur:
		RT.set_anchored_position(content, p)
		update_bounds()

func OnScroll(e) -> void:
	if not _active:
		return
	update_bounds()
	var d: Vector2 = e.scrollDelta
	d.y *= -1.0
	if vertical and not horizontal:
		if absf(d.x) > absf(d.y):
			d.y = d.x
		d.x = 0
	if horizontal and not vertical:
		if absf(d.y) > absf(d.x):
			d.x = d.y
		d.y = 0
	var pos: Vector2 = RT.anchored_position(content)
	pos += d * scrollSensitivity * 40.0
	if movementType == MovementType.CLAMPED or movementType == MovementType.ELASTIC:
		pos += calc_offset(pos - RT.anchored_position(content))
	set_content_pos(pos)
	_after_move()

func OnInitializePotentialDrag(e) -> void:
	if e.button != 0:
		return
	velocity = Vector2.ZERO

func OnBeginDrag(e) -> void:
	if e.button != 0 or not _active:
		return
	update_bounds()
	_pointer_start = RT.screen_to_local(view_rect(), e.position)
	_content_start = RT.anchored_position(content)
	_dragging = true

func OnDrag(e) -> void:
	if not _dragging or e.button != 0 or not _active:
		return
	var lp: Vector2 = RT.screen_to_local(view_rect(), e.position)
	update_bounds()
	var pos := _content_start + (lp - _pointer_start)
	var off := calc_offset(pos - RT.anchored_position(content))
	pos += off
	if movementType == MovementType.ELASTIC:
		var vsz := _view_max - _view_min
		if off.x != 0:
			pos.x = pos.x - _rubber(off.x, vsz.x)
		if off.y != 0:
			pos.y = pos.y - _rubber(off.y, vsz.y)
	set_content_pos(pos)
	_after_move()

func OnEndDrag(e) -> void:
	if e.button != 0:
		return
	_dragging = false

func _rubber(over: float, view: float) -> float:
	return (1.0 - (1.0 / ((absf(over) * 0.55 / maxf(1.0, view)) + 1.0))) * view * signf(over)

func LateUpdate() -> void:
	if not (content is Control):
		return
	update_bounds()
	var dt := U.unscaledDeltaTime
	var off := calc_offset(Vector2.ZERO)
	if not _dragging and (off != Vector2.ZERO or velocity != Vector2.ZERO):
		var pos: Vector2 = RT.anchored_position(content)
		for ax in 2:
			if movementType == MovementType.ELASTIC and off[ax] != 0:
				var target: float = pos[ax] + off[ax]
				pos[ax] = lerpf(pos[ax], target, clampf(dt / maxf(0.001, elasticity), 0.0, 1.0))
				if absf(pos[ax] - target) < 0.5:
					pos[ax] = target
				velocity[ax] = 0.0
			elif inertia:
				velocity[ax] *= pow(decelerationRate, dt)
				if absf(velocity[ax]) < 1:
					velocity[ax] = 0
				pos[ax] += velocity[ax] * dt
			else:
				velocity[ax] = 0
		if movementType == MovementType.CLAMPED:
			off = calc_offset(pos - RT.anchored_position(content))
			pos += off
		set_content_pos(pos)
	if _dragging and inertia:
		var cur: Vector2 = RT.anchored_position(content)
		var nv := (cur - _prev_pos) / maxf(0.0001, dt)
		velocity = velocity.lerp(nv, clampf(dt * 10.0, 0.0, 1.0))
	var now: Vector2 = RT.anchored_position(content)
	if now != _prev_pos:
		_prev_pos = now
		_after_move()

func _after_move() -> void:
	_update_scrollbars()
	onValueChanged.Invoke(normalizedPosition)

func _update_scrollbars() -> void:
	_sb_updating = true
	var vs := _view_max - _view_min
	var cs := _cont_max - _cont_min
	if horizontalScrollbar is UScrollbar and is_instance_valid(horizontalScrollbar):
		horizontalScrollbar.size = clampf(vs.x / maxf(1.0, cs.x), 0.0, 1.0) if cs.x > 0 else 1.0
		horizontalScrollbar.value = horizontalNormalizedPosition
		if horizontalScrollbarVisibility != 0:
			U.SetActive(horizontalScrollbar, cs.x > vs.x + 0.01)
	if verticalScrollbar is UScrollbar and is_instance_valid(verticalScrollbar):
		verticalScrollbar.size = clampf(vs.y / maxf(1.0, cs.y), 0.0, 1.0) if cs.y > 0 else 1.0
		verticalScrollbar.value = verticalNormalizedPosition
		if verticalScrollbarVisibility != 0:
			U.SetActive(verticalScrollbar, cs.y > vs.y + 0.01)
	_sb_updating = false

func get_normalized(ax: int) -> float:
	update_bounds()
	var csz := _cont_max[ax] - _cont_min[ax]
	var vsz := _view_max[ax] - _view_min[ax]
	if csz <= vsz + 0.0001:
		return 1.0 if _view_min[ax] > _cont_min[ax] else 0.0
	return (_view_min[ax] - _cont_min[ax]) / (csz - vsz)

func set_normalized(v: float, ax: int) -> void:
	update_bounds()
	if not (content is Control):
		return
	var hidden := (_cont_max[ax] - _cont_min[ax]) - (_view_max[ax] - _view_min[ax])
	var target_min := _view_min[ax] - v * hidden
	var pos: Vector2 = RT.anchored_position(content)
	var np := pos[ax] + target_min - _cont_min[ax]
	if absf(pos[ax] - np) > 0.01:
		pos[ax] = np
		RT.set_anchored_position(content, pos)
		velocity[ax] = 0
		update_bounds()
		_after_move()

var verticalNormalizedPosition: float:
	get:
		return get_normalized(1)
	set(v):
		set_normalized(v, 1)

var horizontalNormalizedPosition: float:
	get:
		return get_normalized(0)
	set(v):
		set_normalized(v, 0)

var normalizedPosition: Vector2:
	get:
		return Vector2(get_normalized(0), get_normalized(1))
	set(v):
		set_normalized(v.x, 0)
		set_normalized(v.y, 1)

func StopMovement() -> void:
	velocity = Vector2.ZERO
