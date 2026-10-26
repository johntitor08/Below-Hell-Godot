class_name USpriteRenderer
extends Mono

const P := UPhys.PPU

var node: Sprite2D
var _sprite: USprite
var _color := Color.WHITE
var _flipX := false
var _flipY := false
var _layer_id = 0
var _order := 0
var _draw_mode := 0
var _size := Vector2.ONE
var _material = null

func _on_injected(root: Node) -> void:
	_sprite = DB.conv(u.get("m_Sprite"), root)
	var c = DB.conv(u.get("m_Color"), root)
	_color = c if c is Color else Color.WHITE
	_flipX = int(u.get("m_FlipX", 0)) != 0
	_flipY = int(u.get("m_FlipY", 0)) != 0
	_layer_id = u.get("m_SortingLayerID", 0)
	_order = int(u.get("m_SortingOrder", 0))
	_draw_mode = int(u.get("m_DrawMode", 0))
	var sz = u.get("m_Size")
	if sz is Dictionary:
		_size = Vector2(float(sz.get("x", 1)), float(sz.get("y", 1)))
	_ensure()
	_refresh()

func _ensure() -> void:
	if node != null and is_instance_valid(node):
		return
	node = Sprite2D.new()
	node.name = "_sprite_" + str(get_instance_id())
	node.centered = false
	node.z_as_relative = false
	gameObject.add_child(node, false, Node.INTERNAL_MODE_FRONT)

func _refresh() -> void:
	_ensure()
	node.visible = _enabled_flag and _sprite != null
	node.modulate = _color
	node.z_index = UPhys.sorting_z(_layer_id, _order)
	if _sprite == null:
		node.texture = null
		return
	var tex := _sprite.texture
	node.texture = tex
	if tex == null:
		return
	var r := _sprite.get_region()
	node.region_enabled = true
	node.region_rect = r
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _sprite.filter == 0 else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	var k := P / maxf(_sprite.pixelsPerUnit, 0.0001)
	var sc := Vector2(k, k)
	if _draw_mode != 0 and r.size.x > 0.0 and r.size.y > 0.0:
		sc = Vector2(_size.x * P / r.size.x, _size.y * P / r.size.y)
	var pv := _sprite.pivot
	var off := Vector2(-pv.x * r.size.x, -(1.0 - pv.y) * r.size.y)
	node.offset = off
	node.scale = Vector2(sc.x * (-1.0 if _flipX else 1.0), sc.y * (-1.0 if _flipY else 1.0))
	node.position = Vector2.ZERO

func OnEnable() -> void:
	if node != null and is_instance_valid(node):
		node.visible = _sprite != null

func OnDisable() -> void:
	if node != null and is_instance_valid(node) and not _enabled_flag:
		node.visible = false

var sprite:
	get:
		return _sprite
	set(v):
		_sprite = v
		_refresh()

var color: Color:
	get:
		return _color
	set(v):
		_color = v
		if node != null and is_instance_valid(node):
			node.modulate = v

var flipX: bool:
	get:
		return _flipX
	set(v):
		if v != _flipX:
			_flipX = v
			_refresh()

var flipY: bool:
	get:
		return _flipY
	set(v):
		if v != _flipY:
			_flipY = v
			_refresh()

var sortingOrder: int:
	get:
		return _order
	set(v):
		_order = v
		if node != null and is_instance_valid(node):
			node.z_index = UPhys.sorting_z(_layer_id, _order)

var sortingLayerName: String:
	get:
		return UPhys.sorting_layer_name(_layer_id)
	set(v):
		_layer_id = UPhys.sorting_layer_id(v)
		sortingOrder = _order

var sortingLayerID:
	get:
		return _layer_id
	set(v):
		_layer_id = v
		sortingOrder = _order

var size: Vector2:
	get:
		return _size
	set(v):
		_size = v
		_refresh()

var drawMode: int:
	get:
		return _draw_mode
	set(v):
		_draw_mode = v
		_refresh()

var material:
	get:
		return _material
	set(v):
		_material = v
		if node != null and is_instance_valid(node):
			node.material = v if v is Material else null

var isVisible: bool:
	get:
		return node != null and is_instance_valid(node) and node.is_visible_in_tree()

var enabled_override: bool:
	get:
		return _enabled_flag

func _set_enabled_visual() -> void:
	if node != null and is_instance_valid(node):
		node.visible = _enabled_flag and _sprite != null

var bounds: UBounds:
	get:
		if node == null or not is_instance_valid(node) or node.texture == null:
			return UBounds.make(U.pos(gameObject), Vector2.ZERO)
		var r := node.get_rect()
		var xf := node.global_transform
		var a := xf * r.position
		var b := xf * r.end
		var ua := UPhys.to_unity(a)
		var ub := UPhys.to_unity(b)
		return UBounds.make((ua + ub) * 0.5, Vector2(absf(ub.x - ua.x), absf(ub.y - ua.y)))
