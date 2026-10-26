class_name UScrollbar
extends USelectable

var handleRect
var direction := 0
var _value := 0.0
var _size := 0.2
var numberOfSteps := 0
var onValueChanged := UEvent.new()
var _drag_offset := Vector2.ZERO

var value: float:
	get:
		var v := _value
		if numberOfSteps > 1:
			v = round(v * (numberOfSteps - 1)) / (numberOfSteps - 1)
		return v
	set(v):
		Set(v, true)

var size: float:
	get:
		return _size
	set(v):
		_size = clampf(v, 0.0, 1.0)
		_update_visuals()

func _selectable_injected(root: Node) -> void:
	handleRect = DB.conv(u.get("m_HandleRect"), root)
	direction = int(u.get("m_Direction", 0))
	_value = float(u.get("m_Value", 0))
	_size = float(u.get("m_Size", 0.2))
	numberOfSteps = int(u.get("m_NumberOfSteps", 0))
	var e = DB.conv(u.get("m_OnValueChanged"), root)
	if e is UEvent:
		onValueChanged = e

func OnEnable() -> void:
	super.OnEnable()
	_update_visuals()

func SetValueWithoutNotify(v: float) -> void:
	Set(v, false)

func Set(v: float, notify: bool) -> void:
	var nv := clampf(v, 0.0, 1.0)
	if _value == nv:
		return
	_value = nv
	_update_visuals()
	if notify:
		onValueChanged.Invoke(value)

func _axis() -> int:
	return 0 if direction < 2 else 1

func _reversed() -> bool:
	return direction == 1 or direction == 3

func _update_visuals() -> void:
	if not (handleRect is Control) or not is_instance_valid(handleRect):
		return
	var amin := RT.anchor_min(handleRect)
	var amax := RT.anchor_max(handleRect)
	var ax := _axis()
	var v := value
	var lo := v * (1.0 - _size)
	if _reversed():
		lo = 1.0 - v * (1.0 - _size) - _size
	amin[ax] = lo
	amax[ax] = lo + _size
	RT.set_anchor_min(handleRect, amin)
	RT.set_anchor_max(handleRect, amax)

func _container() -> Control:
	if handleRect is Control and handleRect.get_parent() is Control:
		return handleRect.get_parent()
	return gameObject

func OnBeginDrag(e) -> void:
	_drag_offset = Vector2.ZERO
	if handleRect is Control and RT.contains_screen_point(handleRect, e.pressPosition):
		var lp: Vector2 = RT.screen_to_local(handleRect, e.pressPosition)
		_drag_offset = lp - RT.rect(handleRect).get_center()

func OnDrag(e) -> void:
	if not _active or not IsInteractable() or e.button != 0:
		return
	var c := _container()
	var lp: Vector2 = RT.screen_to_local(c, e.position) - _drag_offset
	var r := RT.rect(c)
	var ax := _axis()
	var handle_len := (r.size.x if ax == 0 else r.size.y) * _size
	var start := (r.position.x if ax == 0 else r.position.y) + handle_len * 0.5
	var span := (r.size.x if ax == 0 else r.size.y) - handle_len
	var p := (lp.x if ax == 0 else lp.y) - start
	var t := clampf(p / maxf(1.0, span), 0.0, 1.0)
	value = (1.0 - t) if _reversed() else t

func OnPointerDown(e) -> void:
	super.OnPointerDown(e)
	if handleRect is Control and not RT.contains_screen_point(handleRect, e.position):
		var c := _container()
		var lp: Vector2 = RT.screen_to_local(c, e.position)
		var r := RT.rect(c)
		var ax := _axis()
		var t := ((lp.x - r.position.x) / maxf(1.0, r.size.x)) if ax == 0 else ((lp.y - r.position.y) / maxf(1.0, r.size.y))
		t = clampf(t, 0.0, 1.0)
		value = (1.0 - t) if _reversed() else t
