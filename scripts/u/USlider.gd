class_name USlider
extends USelectable

enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, BOTTOM_TO_TOP, TOP_TO_BOTTOM }

var fillRect
var handleRect
var direction := 0
var _min := 0.0
var _max := 1.0
var _whole := false
var _value := 0.0
var onValueChanged := UEvent.new()
var _dragging := false

var minValue: float:
	get:
		return _min
	set(v):
		_min = v
		Set(_value, false)
		_update_visuals()

var maxValue: float:
	get:
		return _max
	set(v):
		_max = v
		Set(_value, false)
		_update_visuals()

var wholeNumbers: bool:
	get:
		return _whole
	set(v):
		_whole = v
		Set(_value, false)
		_update_visuals()

var value: float:
	get:
		return round(_value) if _whole else _value
	set(v):
		Set(v, true)

var normalizedValue: float:
	get:
		if is_equal_approx(_min, _max):
			return 0.0
		return inverse_lerp(_min, _max, value)
	set(v):
		value = lerpf(_min, _max, v)

func _selectable_injected(root: Node) -> void:
	fillRect = DB.conv(u.get("m_FillRect"), root)
	handleRect = DB.conv(u.get("m_HandleRect"), root)
	direction = int(u.get("m_Direction", 0))
	_min = float(u.get("m_MinValue", 0))
	_max = float(u.get("m_MaxValue", 1))
	_whole = int(u.get("m_WholeNumbers", 0)) != 0
	_value = float(u.get("m_Value", 0))
	var e = DB.conv(u.get("m_OnValueChanged"), root)
	if e is UEvent:
		onValueChanged = e

func Awake() -> void:
	_update_visuals()

func OnEnable() -> void:
	super.OnEnable()
	Set(_value, false)
	_update_visuals()

func SetValueWithoutNotify(v: float) -> void:
	Set(v, false)

func Set(v: float, notify: bool) -> void:
	var nv := clampf(v, minf(_min, _max), maxf(_min, _max))
	if _whole:
		nv = round(nv)
	if _value == nv:
		return
	_value = nv
	_update_visuals()
	if notify:
		onValueChanged.Invoke(nv)

func _axis() -> int:
	return 0 if direction < 2 else 1

func _reversed() -> bool:
	return direction == 1 or direction == 3

func _update_visuals() -> void:
	var nv := normalizedValue
	if fillRect is Control and is_instance_valid(fillRect):
		var amin := Vector2.ZERO
		var amax := Vector2.ONE
		var ax := _axis()
		if fillRect is UImage and fillRect.type == UImage.Type.FILLED:
			fillRect.fillAmount = nv
		elif _reversed():
			amin[ax] = 1.0 - nv
			amax[ax] = 1.0
		else:
			amin[ax] = 0.0
			amax[ax] = nv
		RT.set_anchor_min(fillRect, amin)
		RT.set_anchor_max(fillRect, amax)
	if handleRect is Control and is_instance_valid(handleRect):
		var hmin := Vector2.ZERO
		var hmax := Vector2.ONE
		var ax2 := _axis()
		var p := (1.0 - nv) if _reversed() else nv
		hmin[ax2] = p
		hmax[ax2] = p
		RT.set_anchor_min(handleRect, hmin)
		RT.set_anchor_max(handleRect, hmax)

func _drag_rect() -> Control:
	if handleRect is Control and is_instance_valid(handleRect) and handleRect.get_parent() is Control:
		return handleRect.get_parent()
	if fillRect is Control and is_instance_valid(fillRect) and fillRect.get_parent() is Control:
		return fillRect.get_parent()
	return gameObject

func _update_drag(e) -> void:
	var r := _drag_rect()
	if r == null:
		return
	var lp: Vector2 = RT.screen_to_local(r, e.position)
	var rr := RT.rect(r)
	var ax := _axis()
	var t := 0.0
	if ax == 0:
		t = (lp.x - rr.position.x) / maxf(1.0, rr.size.x)
	else:
		t = (lp.y - rr.position.y) / maxf(1.0, rr.size.y)
	t = clampf(t, 0.0, 1.0)
	normalizedValue = (1.0 - t) if _reversed() else t

func OnPointerDown(e) -> void:
	super.OnPointerDown(e)
	if not _active or not IsInteractable() or e.button != 0:
		return
	_update_drag(e)

func OnInitializePotentialDrag(e) -> void:
	e.useDragThreshold = false

func OnDrag(e) -> void:
	if not _active or not IsInteractable() or e.button != 0:
		return
	_update_drag(e)
