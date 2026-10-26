class_name UCamera
extends Mono

const P := UPhys.PPU

var cam: Camera2D
var _size := 5.0
var _bg := Color.BLACK
var _clear := 2
var orthographic := true

func _on_injected(root: Node) -> void:
	_size = float(u.get("orthographic size", 5))
	var c = DB.conv(u.get("m_BackGroundColor"), root)
	_bg = c if c is Color else Color.BLACK
	_clear = int(u.get("m_ClearFlags", 2))
	cam = Camera2D.new()
	cam.name = "_camera"
	cam.ignore_rotation = false
	gameObject.add_child(cam, false, Node.INTERNAL_MODE_FRONT)
	add_to_group("u_cameras")
	_apply_zoom()

func _apply_zoom() -> void:
	if cam != null:
		var z := 1080.0 / (2.0 * maxf(_size, 0.001) * P)
		cam.zoom = Vector2(z, z)

func OnEnable() -> void:
	if cam != null and is_instance_valid(cam):
		cam.enabled = true
		cam.make_current()
	if _clear == 2 or _clear == 1:
		RenderingServer.set_default_clear_color(_bg)

func OnDisable() -> void:
	if cam != null and is_instance_valid(cam):
		cam.enabled = false

var orthographicSize: float:
	get:
		return _size
	set(v):
		_size = v
		_apply_zoom()

var backgroundColor: Color:
	get:
		return _bg
	set(v):
		_bg = v
		RenderingServer.set_default_clear_color(v)

var pixelWidth: int:
	get:
		return int(U.screen_w())

var pixelHeight: int:
	get:
		return int(U.screen_h())

var aspect: float:
	get:
		return U.screen_w() / maxf(U.screen_h(), 1.0)

func _canvas_xf() -> Transform2D:
	if cam != null and is_instance_valid(cam):
		return cam.get_canvas_transform()
	return get_viewport().get_canvas_transform()

func ScreenToWorldPoint(sp) -> Vector2:
	var g := Vector2(sp.x, U.screen_h() - sp.y)
	return UPhys.to_unity(_canvas_xf().affine_inverse() * g)

func WorldToScreenPoint(wp) -> Vector2:
	var g := _canvas_xf() * UPhys.to_godot(Vector2(wp.x, wp.y))
	return Vector2(g.x, U.screen_h() - g.y)

func ViewportToWorldPoint(vp) -> Vector2:
	return ScreenToWorldPoint(Vector2(vp.x * U.screen_w(), vp.y * U.screen_h()))

func WorldToViewportPoint(wp) -> Vector2:
	var s := WorldToScreenPoint(wp)
	return Vector2(s.x / U.screen_w(), s.y / U.screen_h())

func ScreenPointToRay(sp) -> Vector2:
	return ScreenToWorldPoint(sp)
