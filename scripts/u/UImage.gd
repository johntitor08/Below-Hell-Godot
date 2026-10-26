@tool
class_name UImage
extends Control

enum Type { SIMPLE, SLICED, TILED, FILLED }

var blob: Dictionary = {}
var has_graphic := false
var is_raw := false
var _sprite: USprite
var _color := Color.WHITE
var _enabled := true
var type := 0
var preserveAspect := false
var fillCenter := true
var fillMethod := 4
var fillOrigin := 0
var fillClockwise := true
var _fillAmount := 1.0
var ppum := 1.0
var raycastTarget := true
var raycastPadding := Vector4.ZERO
var uvRect := Rect2(0, 0, 1, 1)
var tint := Color.WHITE
var cr_alpha := 1.0
var show_graphic := true
var shape_poly := PackedVector2Array()
var shape_color := Color(1, 1, 1, 0)
var has_shape := false
var _tint_tween: Tween
var _ready_done := false

var sprite: USprite:
	get:
		return _sprite
	set(v):
		_sprite = v
		queue_redraw()
		ES.mark_layout_dirty()

var overrideSprite: USprite:
	get:
		return _sprite
	set(v):
		sprite = v

var texture: USprite:
	get:
		return _sprite
	set(v):
		sprite = v

var color: Color:
	get:
		return _color
	set(v):
		_color = v
		queue_redraw()

var enabled: bool:
	get:
		return _enabled
	set(v):
		_enabled = v
		queue_redraw()

var fillAmount: float:
	get:
		return _fillAmount
	set(v):
		_fillAmount = clampf(v, 0.0, 1.0)
		queue_redraw()

var gameObject:
	get:
		return self

var transform:
	get:
		return self

var rectTransform:
	get:
		return self

var activeSelf: bool:
	get:
		return visible

var activeInHierarchy: bool:
	get:
		return U.activeInHierarchy(self)

var anchoredPosition: Vector2:
	get:
		return RT.anchored_position(self)
	set(v):
		RT.set_anchored_position(self, v)

var sizeDelta: Vector2:
	get:
		return RT.size_delta(self)
	set(v):
		RT.set_size_delta(self, v)

var anchorMin: Vector2:
	get:
		return RT.anchor_min(self)
	set(v):
		RT.set_anchor_min(self, v)

var anchorMax: Vector2:
	get:
		return RT.anchor_max(self)
	set(v):
		RT.set_anchor_max(self, v)

var pivot: Vector2:
	get:
		return RT.pivot(self)
	set(v):
		RT.set_pivot(self, v)

var offsetMin: Vector2:
	get:
		return RT.offset_min(self)
	set(v):
		RT.set_offset_min(self, v)

var offsetMax: Vector2:
	get:
		return RT.offset_max(self)
	set(v):
		RT.set_offset_max(self, v)

var localScale:
	get:
		return RT.local_scale(self)
	set(v):
		RT.set_local_scale(self, v)

var rect: Rect2:
	get:
		return RT.rect(self)

var u_name: String:
	get:
		return get_meta("u_name", name)
	set(v):
		set_meta("u_name", v)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	if _ready_done:
		return
	_ready_done = true
	parse_blob()

func parse_blob() -> void:
	var raw = get_meta("u", "")
	if raw is String and raw != "":
		var p = JSON.parse_string(raw)
		if p is Dictionary:
			blob = p
	if blob.has("name"):
		set_meta("u_name", blob["name"])
	var tag := str(blob.get("tag", "Untagged"))
	if tag != "Untagged" and not Engine.is_editor_hint():
		add_to_group("go_tag_" + tag)
	var pv = get_meta("pivot", [0.5, 0.5])
	pivot_offset_ratio = Vector2(pv[0], 1.0 - pv[1])
	var im = blob.get("image")
	if im is Dictionary:
		has_graphic = true
		_enabled = bool(im.get("enabled", true))
		var c = im.get("color", [1, 1, 1, 1])
		_color = Color(c[0], c[1], c[2], c[3])
		raycastTarget = bool(im.get("raycastTarget", true))
		if im.get("raw", false):
			is_raw = true
			if im.get("texture") != null:
				_sprite = DB.sprite(str(im["texture"]))
			var uv = im.get("uvRect")
			if uv is Dictionary:
				uvRect = Rect2(uv.get("x", 0), uv.get("y", 0), uv.get("width", 1), uv.get("height", 1))
		else:
			var sp = im.get("sprite")
			if sp is Dictionary and sp.has("$spr"):
				_sprite = DB.sprite(str(sp["$spr"]))
			type = int(im.get("type", 0))
			preserveAspect = bool(im.get("preserveAspect", false))
			fillCenter = bool(im.get("fillCenter", true))
			fillMethod = int(im.get("fillMethod", 4))
			fillOrigin = int(im.get("fillOrigin", 0))
			fillClockwise = bool(im.get("fillClockwise", true))
			_fillAmount = float(im.get("fillAmount", 1.0))
			ppum = float(im.get("ppum", 1.0))
			var rp = im.get("raycastPadding", [0, 0, 0, 0])
			raycastPadding = Vector4(rp[0], rp[1], rp[2], rp[3])
	var sh = blob.get("shape")
	if sh is Dictionary and sh.has("poly"):
		has_shape = true
		for p in sh["poly"]:
			shape_poly.append(Vector2(p[0], p[1]))
		var sc = sh.get("color", [1, 1, 1, 0])
		shape_color = Color(sc[0], sc[1], sc[2], sc[3])
	var cv = blob.get("canvas")
	if cv is Dictionary and cv.get("override", false) and get_parent() is Control:
		z_index = clampi(int(cv.get("order", 0)), -100, 100)
	queue_redraw()

func SetActive(v: bool) -> void:
	U.SetActive(self, v)

func CompareTag(t: String) -> bool:
	return str(blob.get("tag", "Untagged")) == t

func SetNativeSize() -> void:
	if _sprite == null:
		return
	var r := _sprite.get_region()
	var k := 100.0 / maxf(0.001, _sprite.pixelsPerUnit)
	sizeDelta = r.size * k

func SetAsLastSibling() -> void:
	U.SetAsLastSibling(self)

func SetAsFirstSibling() -> void:
	U.SetAsFirstSibling(self)

func SetAlpha(a: float) -> void:
	cr_alpha = a
	queue_redraw()

func GetAlpha() -> float:
	return cr_alpha

func CrossFadeColor(target: Color, duration: float, _ignore_ts := true, use_alpha := true) -> void:
	if _tint_tween != null:
		_tint_tween.kill()
	var t := Color(target.r, target.g, target.b, target.a if use_alpha else tint.a)
	if duration <= 0.0 or not is_inside_tree():
		tint = t
		queue_redraw()
		return
	_tint_tween = create_tween()
	_tint_tween.set_ignore_time_scale(true)
	_tint_tween.tween_method(func(c): tint = c; queue_redraw(), tint, t, duration)

func CrossFadeAlpha(a: float, duration: float, _ignore_ts := true) -> void:
	CrossFadeColor(Color(tint.r, tint.g, tint.b, a), duration)

func pivot_px() -> Vector2:
	var p := RT.pivot(self)
	return Vector2(p.x * size.x, (1.0 - p.y) * size.y)

func godot_poly() -> PackedVector2Array:
	var out := PackedVector2Array()
	var pp := pivot_px()
	for p in shape_poly:
		out.append(Vector2(pp.x + p.x, pp.y - p.y))
	return out

func hit_local(lp: Vector2) -> bool:
	if has_shape:
		var poly := godot_poly()
		return poly.size() >= 3 and Geometry2D.is_point_in_polygon(lp, poly)
	var r := Rect2(Vector2(raycastPadding.x, raycastPadding.w), size - Vector2(raycastPadding.x + raycastPadding.z, raycastPadding.y + raycastPadding.w))
	return r.has_point(lp)

func is_raycast_target() -> bool:
	if has_shape:
		return true
	return has_graphic and _enabled and raycastTarget

func draw_color() -> Color:
	var c := _color * tint
	c.a *= cr_alpha
	return c

func _draw() -> void:
	if has_shape and shape_color.a > 0.001:
		var poly := godot_poly()
		if poly.size() >= 3 and Geometry2D.triangulate_polygon(poly).size() > 0:
			draw_colored_polygon(poly, shape_color)
	if not has_graphic or not _enabled or not show_graphic:
		return
	var c := draw_color()
	if c.a <= 0.0005:
		return
	var full := Rect2(Vector2.ZERO, size)
	if _sprite == null:
		draw_rect(full, c)
		return
	match _sprite.kind:
		USprite.Kind.ROUNDED:
			_draw_flat(full, c, _sprite.radius, 0, type == Type.SLICED)
			return
		USprite.Kind.RING:
			_draw_flat(full, c, _sprite.radius, _sprite.ring_width, type == Type.SLICED)
			return
		USprite.Kind.SOLID:
			draw_rect(full, c)
			return
		USprite.Kind.CIRCLE:
			_draw_circle_img(full, c)
			return
		USprite.Kind.BOTTOM_FADE:
			_draw_bottom_fade(full, c)
			return
	var tex := _sprite.texture
	if tex == null:
		return
	if is_raw:
		var ts := tex.get_size()
		var src := Rect2(uvRect.position.x * ts.x, (1.0 - uvRect.position.y - uvRect.size.y) * ts.y, uvRect.size.x * ts.x, uvRect.size.y * ts.y)
		draw_texture_rect_region(tex, full, src, c)
		return
	var region := _sprite.get_region()
	match type:
		Type.SLICED:
			if _sprite.has_border():
				_draw_sliced(tex, region, full, c)
			else:
				draw_texture_rect_region(tex, _aspect_rect(full, region.size), region, c)
		Type.TILED:
			draw_texture_rect_region(tex, full, region, c)
		Type.FILLED:
			_draw_filled(tex, region, _aspect_rect(full, region.size), c)
		_:
			draw_texture_rect_region(tex, _aspect_rect(full, region.size), region, c)

func _aspect_rect(full: Rect2, tex_size: Vector2) -> Rect2:
	if not preserveAspect or tex_size.y <= 0 or full.size.y <= 0:
		return full
	var ra := tex_size.x / tex_size.y
	var rr := full.size.x / full.size.y
	var p := RT.pivot(self)
	var r := full
	if ra > rr:
		var h := full.size.x / ra
		r.position.y += (full.size.y - h) * (1.0 - p.y)
		r.size.y = h
	else:
		var w := full.size.y * ra
		r.position.x += (full.size.x - w) * p.x
		r.size.x = w
	return r

func _border_scale() -> float:
	return 1.0 / maxf(0.0001, (_sprite.pixelsPerUnit / 100.0) * ppum)

func _draw_flat(full: Rect2, c: Color, radius: int, ring: int, scaled: bool) -> void:
	var k := 1.0 / maxf(0.0001, ppum) if scaled else 1.0
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	var r: float = radius * k
	var lim := minf(full.size.x, full.size.y) * 0.5
	r = min(r, lim)
	sb.set_corner_radius_all(int(round(r)))
	sb.corner_detail = 12
	if ring > 0:
		sb.draw_center = false
		sb.set_border_width_all(max(1, int(round(ring * k))))
		sb.border_color = c
	else:
		sb.bg_color = c
	if not fillCenter and ring == 0:
		return
	draw_style_box(sb, full)

var _circle_tex: Texture2D
var _fade_tex: Texture2D

func _draw_circle_img(full: Rect2, c: Color) -> void:
	var r := _aspect_rect(full, Vector2(1, 1)) if preserveAspect else full
	var center := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.5
	if absf(r.size.x - r.size.y) < 0.5:
		draw_circle(center, rad, c, true, -1.0, true)
	else:
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(center + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5))
		draw_colored_polygon(pts, c)

func _draw_bottom_fade(full: Rect2, c: Color) -> void:
	if _fade_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 1))
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		gt.width = 4
		gt.height = 128
		_fade_tex = gt
	draw_texture_rect(_fade_tex, full, false, c)

func _draw_sliced(tex: Texture2D, region: Rect2, full: Rect2, c: Color) -> void:
	var k := _border_scale()
	var b := _sprite.border
	var l := b.x
	var bo := b.y
	var r := b.z
	var t := b.w
	var dl := l * k
	var dr := r * k
	var dt := t * k
	var db := bo * k
	if dl + dr > full.size.x and dl + dr > 0:
		var s := full.size.x / (dl + dr)
		dl *= s
		dr *= s
	if dt + db > full.size.y and dt + db > 0:
		var s2 := full.size.y / (dt + db)
		dt *= s2
		db *= s2
	var sx := [region.position.x, region.position.x + l, region.end.x - r, region.end.x]
	var sy := [region.position.y, region.position.y + t, region.end.y - bo, region.end.y]
	var dx := [full.position.x, full.position.x + dl, full.end.x - dr, full.end.x]
	var dy := [full.position.y, full.position.y + dt, full.end.y - db, full.end.y]
	for yi in 3:
		for xi in 3:
			if xi == 1 and yi == 1 and not fillCenter:
				continue
			var src := Rect2(sx[xi], sy[yi], sx[xi + 1] - sx[xi], sy[yi + 1] - sy[yi])
			var dst := Rect2(dx[xi], dy[yi], dx[xi + 1] - dx[xi], dy[yi + 1] - dy[yi])
			if src.size.x <= 0 or src.size.y <= 0 or dst.size.x <= 0 or dst.size.y <= 0:
				continue
			draw_texture_rect_region(tex, dst, src, c)

func _draw_filled(tex: Texture2D, region: Rect2, dst: Rect2, c: Color) -> void:
	var f := _fillAmount
	if f <= 0.0:
		return
	if f >= 1.0:
		draw_texture_rect_region(tex, dst, region, c)
		return
	match fillMethod:
		0:
			var w := dst.size.x * f
			var sw := region.size.x * f
			if fillOrigin == 0:
				draw_texture_rect_region(tex, Rect2(dst.position, Vector2(w, dst.size.y)), Rect2(region.position, Vector2(sw, region.size.y)), c)
			else:
				draw_texture_rect_region(tex, Rect2(dst.end.x - w, dst.position.y, w, dst.size.y), Rect2(region.end.x - sw, region.position.y, sw, region.size.y), c)
		1:
			var h := dst.size.y * f
			var sh := region.size.y * f
			if fillOrigin == 0:
				draw_texture_rect_region(tex, Rect2(dst.position.x, dst.end.y - h, dst.size.x, h), Rect2(region.position.x, region.end.y - sh, region.size.x, sh), c)
			else:
				draw_texture_rect_region(tex, Rect2(dst.position, Vector2(dst.size.x, h)), Rect2(region.position, Vector2(region.size.x, sh)), c)
		_:
			_draw_radial(tex, region, dst, c, f)

func _draw_radial(tex: Texture2D, region: Rect2, dst: Rect2, c: Color, f: float) -> void:
	var span := TAU
	if fillMethod == 2:
		span = PI * 0.5
	elif fillMethod == 3:
		span = PI
	var center := dst.get_center()
	var start_angle := 0.0
	if fillMethod == 4:
		start_angle = [PI * 0.5, 0.0, -PI * 0.5, PI][clampi(fillOrigin, 0, 3)]
	elif fillMethod == 3:
		start_angle = [PI, PI * 0.5, 0.0, -PI * 0.5][clampi(fillOrigin, 0, 3)]
		center = [Vector2(dst.get_center().x, dst.end.y), Vector2(dst.position.x, dst.get_center().y), Vector2(dst.get_center().x, dst.position.y), Vector2(dst.end.x, dst.get_center().y)][clampi(fillOrigin, 0, 3)]
	else:
		var corners := [Vector2(dst.position.x, dst.end.y), Vector2(dst.position.x, dst.position.y), Vector2(dst.end.x, dst.position.y), dst.end]
		center = corners[clampi(fillOrigin, 0, 3)]
		start_angle = [-PI * 0.5, 0.0, PI * 0.5, PI][clampi(fillOrigin, 0, 3)]
	var dir := 1.0 if fillClockwise else -1.0
	var sweep := span * f
	var rad := dst.size.length() * 2.0
	var pts := PackedVector2Array([center])
	var steps := maxi(3, int(48 * f))
	for i in steps + 1:
		var a := start_angle + dir * sweep * float(i) / float(steps)
		pts.append(center + Vector2(sin(a), -cos(a)) * rad)
	var clip := PackedVector2Array([dst.position, Vector2(dst.end.x, dst.position.y), dst.end, Vector2(dst.position.x, dst.end.y)])
	var inter := Geometry2D.intersect_polygons(pts, clip)
	var ts := tex.get_size()
	for poly in inter:
		var uvs := PackedVector2Array()
		for p in poly:
			var t := (p - dst.position) / dst.size
			uvs.append((region.position + t * region.size) / ts)
		draw_colored_polygon(poly, c, uvs, tex)
