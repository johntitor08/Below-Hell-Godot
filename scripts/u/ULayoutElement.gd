class_name ULayoutElement
extends Mono

var _ignore := false
var _vals := {"minWidth": -1.0, "minHeight": -1.0, "preferredWidth": -1.0, "preferredHeight": -1.0, "flexibleWidth": -1.0, "flexibleHeight": -1.0}
var layoutPriority := 1

func _on_injected(_root: Node) -> void:
	_ignore = int(u.get("m_IgnoreLayout", 0)) != 0
	_vals.minWidth = float(u.get("m_MinWidth", -1))
	_vals.minHeight = float(u.get("m_MinHeight", -1))
	_vals.preferredWidth = float(u.get("m_PreferredWidth", -1))
	_vals.preferredHeight = float(u.get("m_PreferredHeight", -1))
	_vals.flexibleWidth = float(u.get("m_FlexibleWidth", -1))
	_vals.flexibleHeight = float(u.get("m_FlexibleHeight", -1))
	layoutPriority = int(u.get("m_LayoutPriority", 1))

func _get(property: StringName):
	var k := String(property)
	if _vals.has(k):
		return _vals[k]
	return null

func _set(property: StringName, value) -> bool:
	var k := String(property)
	if _vals.has(k):
		_vals[k] = float(value)
		ES.mark_layout_dirty()
		return true
	return false

var ignoreLayout: bool:
	get:
		return _ignore
	set(v):
		_ignore = v
		ES.mark_layout_dirty()

var minWidth: float:
	get:
		return _vals.minWidth
	set(v):
		_vals.minWidth = v
		ES.mark_layout_dirty()

var minHeight: float:
	get:
		return _vals.minHeight
	set(v):
		_vals.minHeight = v
		ES.mark_layout_dirty()

var preferredWidth: float:
	get:
		return _vals.preferredWidth
	set(v):
		_vals.preferredWidth = v
		ES.mark_layout_dirty()

var preferredHeight: float:
	get:
		return _vals.preferredHeight
	set(v):
		_vals.preferredHeight = v
		ES.mark_layout_dirty()

var flexibleWidth: float:
	get:
		return _vals.flexibleWidth
	set(v):
		_vals.flexibleWidth = v
		ES.mark_layout_dirty()

var flexibleHeight: float:
	get:
		return _vals.flexibleHeight
	set(v):
		_vals.flexibleHeight = v
		ES.mark_layout_dirty()

func props(axis: int) -> Array:
	if axis == 0:
		return [_vals.minWidth, _vals.preferredWidth, _vals.flexibleWidth]
	return [_vals.minHeight, _vals.preferredHeight, _vals.flexibleHeight]
