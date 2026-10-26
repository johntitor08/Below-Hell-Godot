@tool
class_name USprite
extends RefCounted

enum Kind { TEX, ROUNDED, RING, SOLID, CIRCLE, BOTTOM_FADE }

var name: String = ""
var kind: int = Kind.TEX
var tex_path: String = ""
var _texture: Texture2D
var region: Rect2 = Rect2()
var border: Vector4 = Vector4.ZERO
var pixelsPerUnit: float = 100.0
var radius: int = 0
var ring_width: int = 0
var key: String = ""
var _region_known := false

var texture: Texture2D:
	get:
		if _texture == null and tex_path != "":
			_texture = load(tex_path)
			if _texture != null and not _region_known:
				region = Rect2(Vector2.ZERO, _texture.get_size())
				_region_known = true
		return _texture
	set(v):
		_texture = v

var rect: Rect2:
	get:
		var r := get_region()
		return Rect2(0, 0, r.size.x, r.size.y)

func get_region() -> Rect2:
	if kind == Kind.TEX:
		if not _region_known:
			var _t = texture
		if has_meta("flip_y"):
			resolve_region_y()
	return region

func has_border() -> bool:
	return border != Vector4.ZERO

static func from_texture(tex: Texture2D, n: String = "") -> USprite:
	var s := USprite.new()
	s._texture = tex
	s.name = n
	if tex != null:
		s.region = Rect2(Vector2.ZERO, tex.get_size())
		s._region_known = true
	return s

static func from_meta(k: String, m: Dictionary) -> USprite:
	var s := USprite.new()
	s.key = k
	s.tex_path = m.get("tex", "")
	s.name = m.get("name", "")
	s.pixelsPerUnit = float(m.get("ppu", 100))
	var b = m.get("border", [0, 0, 0, 0])
	s.border = Vector4(b[0], b[1], b[2], b[3])
	if m.has("rect"):
		var r = m["rect"]
		s._region_known = true
		s.region = Rect2(r[0], r[1], r[2], r[3])
		s.set_meta("flip_y", true)
	return s

func resolve_region_y() -> void:
	if has_meta("flip_y") and texture != null:
		region.position.y = texture.get_height() - region.position.y - region.size.y
		remove_meta("flip_y")
