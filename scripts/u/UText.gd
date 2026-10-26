@tool
class_name UText
extends Control

const H_LEFT := 1
const H_CENTER := 2
const H_RIGHT := 4
const H_JUSTIFIED := 8
const H_FLUSH := 16
const H_GEOMETRY := 32
const V_TOP := 256
const V_MIDDLE := 512
const V_BOTTOM := 1024

var blob: Dictionary = {}
var label: RichTextLabel
var _text := ""
var _color := Color.WHITE
var _font: Font
var _font_info = null
var _fontSize := 36.0
var _autoSize := false
var fontSizeMin := 18.0
var fontSizeMax := 72.0
var _style := 0
var _halign := 1
var _valign := 256
var _wrap := true
var _overflow := 0
var _margin := Vector4.ZERO
var _lineSpacing := 0.0
var _charSpacing := 0.0
var raycastTarget := true
var raycastPadding := Vector4.ZERO
var _enabled := true
var richText := true
var tint := Color.WHITE
var cr_alpha := 1.0
var _applied_size := 0.0
var _dirty := true
var _ready_done := false
var _vis_chars := -1
var _font_cache: Dictionary = {}
var pageToDisplay := 1
var _plain_cache := ""

var text: String:
	get:
		return _text
	set(v):
		v = "" if v == null else str(v)
		if v == _text:
			return
		_text = v
		_mark()

var color: Color:
	get:
		return _color
	set(v):
		_color = v
		_apply_color()

var alpha: float:
	get:
		return _color.a
	set(v):
		_color.a = v
		_apply_color()

var fontSize: float:
	get:
		return _applied_size if _autoSize and _applied_size > 0 else _fontSize
	set(v):
		_fontSize = v
		_mark()

var enableAutoSizing: bool:
	get:
		return _autoSize
	set(v):
		_autoSize = v
		_mark()

var font: Font:
	get:
		return _font
	set(v):
		_font = v
		_font_cache.clear()
		_mark()

var fontStyle: int:
	get:
		return _style
	set(v):
		_style = v
		_mark()

var alignment: int:
	get:
		return _halign | _valign
	set(v):
		var h := v & 0xFF
		var vv := v & 0xFF00
		if h != 0:
			_halign = h
		if vv != 0:
			_valign = vv
		_mark()

var horizontalAlignment: int:
	get:
		return _halign
	set(v):
		_halign = v
		_mark()

var verticalAlignment: int:
	get:
		return _valign
	set(v):
		_valign = v
		_mark()

var enableWordWrapping: bool:
	get:
		return _wrap
	set(v):
		_wrap = v
		_mark()

var textWrappingMode: int:
	get:
		return 1 if _wrap else 0
	set(v):
		_wrap = v != 0
		_mark()

var overflowMode: int:
	get:
		return _overflow
	set(v):
		_overflow = v
		_mark()

var margin: Vector4:
	get:
		return _margin
	set(v):
		_margin = v
		_mark()

var lineSpacing: float:
	get:
		return _lineSpacing
	set(v):
		_lineSpacing = v
		_mark()

var characterSpacing: float:
	get:
		return _charSpacing
	set(v):
		_charSpacing = v
		_mark()

var enabled: bool:
	get:
		return _enabled
	set(v):
		_enabled = v
		if label:
			label.visible = v
		ES.mark_layout_dirty()

var maxVisibleCharacters: int:
	get:
		return _vis_chars if _vis_chars >= 0 else 99999
	set(v):
		_vis_chars = v
		if label:
			label.visible_characters = v if v < 99999 else -1

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

var preferredWidth: float:
	get:
		return GetPreferredValues(_text, 1e6, 0).x

var preferredHeight: float:
	get:
		return GetPreferredValues(_text, size.x, 0).y

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	if _ready_done:
		return
	_ready_done = true
	for old in get_children(true):
		if old is RichTextLabel and old.name == "_label":
			old.free()
	label = RichTextLabel.new()
	label.name = "_label"
	label.bbcode_enabled = true
	label.scroll_active = false
	label.fit_content = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_contents = false
	label.selection_enabled = false
	label.shortcut_keys_enabled = false
	label.context_menu_enabled = false
	label.threaded = false
	add_child(label, false, Node.INTERNAL_MODE_FRONT)
	parse_blob()
	resized.connect(_mark)
	_render()

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
	var t = blob.get("text")
	if not (t is Dictionary):
		return
	_text = str(t.get("text", ""))
	var c = t.get("color", [1, 1, 1, 1])
	_color = Color(c[0], c[1], c[2], c[3])
	_fontSize = float(t.get("fontSize", 36))
	_autoSize = bool(t.get("autoSize", false))
	fontSizeMin = float(t.get("minSize", 18))
	fontSizeMax = float(t.get("maxSize", 72))
	_style = int(t.get("style", 0))
	if t.has("align") and t["align"] is Dictionary:
		_halign = int(t["align"].get("halign", 1))
		_valign = int(t["align"].get("valign", 256))
	else:
		_halign = int(t.get("halign", 1))
		_valign = int(t.get("valign", 256))
	_wrap = bool(t.get("wrap", true))
	_overflow = int(t.get("overflow", 0))
	var m = t.get("margin", [0, 0, 0, 0])
	_margin = Vector4(m[0], m[1], m[2], m[3])
	_lineSpacing = float(t.get("lineSpacing", 0))
	_charSpacing = float(t.get("charSpacing", 0))
	raycastTarget = bool(t.get("raycastTarget", true))
	_enabled = bool(t.get("enabled", true))
	richText = bool(t.get("rich", true))
	_font_info = t.get("font")
	if _font_info != null:
		_font = DB.font(_font_info)
	if _font == null:
		_font = ThemeDB.fallback_font
	label.visible = _enabled

func SetActive(v: bool) -> void:
	U.SetActive(self, v)

func CompareTag(t: String) -> bool:
	return str(blob.get("tag", "Untagged")) == t

func SetText(s: String) -> void:
	text = s

func SetAlpha(a: float) -> void:
	cr_alpha = a
	_apply_color()

func GetAlpha() -> float:
	return cr_alpha

func CrossFadeColor(target: Color, duration: float, _ignore_ts := true, use_alpha := true) -> void:
	var t := Color(target.r, target.g, target.b, target.a if use_alpha else tint.a)
	if duration <= 0.0 or not is_inside_tree():
		tint = t
		_apply_color()
		return
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(func(cc): tint = cc; _apply_color(), tint, t, duration)

func CrossFadeAlpha(a: float, duration: float, ignore_ts := true) -> void:
	CrossFadeColor(Color(tint.r, tint.g, tint.b, a), duration, ignore_ts)

func ForceMeshUpdate() -> void:
	if _dirty:
		_render()

func is_raycast_target() -> bool:
	return _enabled and raycastTarget

func hit_local(lp: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(lp)

func _mark() -> void:
	_dirty = true
	if is_inside_tree():
		_render.call_deferred()
	ES.mark_layout_dirty()

func _apply_color() -> void:
	if label == null:
		return
	label.add_theme_color_override("default_color", Color(_color.r, _color.g, _color.b, 1.0))
	label.self_modulate = Color(tint.r, tint.g, tint.b, _color.a * tint.a * cr_alpha)

func _variant(bold: bool) -> Font:
	var key := ("b" if bold else "n") + ("i" if _style & 2 else "") + str(_charSpacing)
	if _font_cache.has(key):
		return _font_cache[key]
	var fv := FontVariation.new()
	fv.base_font = _font
	if bold:
		fv.variation_embolden = 0.55
	if _style & 2:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_font_cache[key] = fv
	return fv

func _render() -> void:
	if label == null:
		return
	_dirty = false
	var bold := (_style & 1) != 0
	var f := _variant(bold)
	var fb := _variant(true)
	label.add_theme_font_override("normal_font", f)
	label.add_theme_font_override("bold_font", fb)
	label.add_theme_font_override("italics_font", f)
	label.add_theme_font_override("bold_italics_font", fb)
	var src := _text
	if _style & 16:
		src = _upper_keep_tags(src)
	elif _style & 8:
		src = src.to_lower()
	var bb := tmp_to_bbcode(src, richText, _fontSize)
	if _style & 4:
		bb = "[u]" + bb + "[/u]"
	if _style & 64:
		bb = "[s]" + bb + "[/s]"
	var inner := _inner_rect()
	var fsize := _fontSize
	if _autoSize:
		fsize = _fit_size(src, inner.size)
	_applied_size = fsize
	label.add_theme_font_size_override("normal_font_size", int(round(fsize)))
	label.add_theme_font_size_override("bold_font_size", int(round(fsize)))
	label.add_theme_font_size_override("italics_font_size", int(round(fsize)))
	label.add_theme_font_size_override("bold_italics_font_size", int(round(fsize)))
	var ls := _line_gap(fsize)
	label.add_theme_constant_override("line_separation", int(round(ls)))
	if _charSpacing != 0.0:
		var fv: FontVariation = f
		fv.spacing_glyph = int(round(_charSpacing * fsize / 100.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _wrap else TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = _godot_halign()
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	clip_contents = _overflow == 2 or _overflow == 3
	label.text = bb
	label.visible_characters = _vis_chars if _vis_chars >= 0 and _vis_chars < 99999 else -1
	_apply_color()
	if _overflow == 5:
		label.fit_content = false
		label.position = inner.position
		label.size = inner.size
		clip_contents = true
		_apply_page()
	else:
		label.fit_content = true
		_place_label(inner)

func _line_gap(fsize: float) -> float:
	return _lineSpacing * fsize / 100.0

func _inner_rect() -> Rect2:
	return Rect2(_margin.x, _margin.y, maxf(1.0, size.x - _margin.x - _margin.z), maxf(1.0, size.y - _margin.y - _margin.w))

func _godot_halign() -> int:
	match _halign:
		H_CENTER, H_GEOMETRY:
			return HORIZONTAL_ALIGNMENT_CENTER
		H_RIGHT:
			return HORIZONTAL_ALIGNMENT_RIGHT
		H_JUSTIFIED, H_FLUSH:
			return HORIZONTAL_ALIGNMENT_FILL
	return HORIZONTAL_ALIGNMENT_LEFT

func _place_label(inner: Rect2) -> void:
	label.position = inner.position
	label.size = Vector2(inner.size.x, 0)
	label.reset_size()
	label.size = Vector2(inner.size.x, label.size.y)
	var h := label.get_content_height()
	var w := inner.size.x
	if not _wrap:
		var cw := float(label.get_content_width())
		if cw > w:
			w = cw
	label.size = Vector2(w, h)
	var y := inner.position.y
	if _valign == V_MIDDLE or _valign == 2048 or _valign == 4096 or _valign == 8192:
		y = inner.position.y + (inner.size.y - h) * 0.5
	elif _valign == V_BOTTOM:
		y = inner.end.y - h
	var x := inner.position.x
	if w > inner.size.x:
		if _halign == H_CENTER or _halign == H_GEOMETRY:
			x = inner.position.x + (inner.size.x - w) * 0.5
		elif _halign == H_RIGHT:
			x = inner.end.x - w
	label.position = Vector2(x, y)

var pageCount: int:
	get:
		if label == null or _overflow != 5:
			return 1
		var per := maxi(1, label.get_visible_line_count())
		return maxi(1, ceili(float(label.get_line_count()) / per))

func SetPage(p: int) -> void:
	pageToDisplay = p
	_apply_page()

func _apply_page() -> void:
	if label == null:
		return
	var per := maxi(1, label.get_visible_line_count())
	label.scroll_to_line(maxi(0, (pageToDisplay - 1) * per))

func plain_text(s: String = "") -> String:
	var src := _text if s == "" else s
	var re := RegEx.create_from_string("<[^<>]+>")
	return re.sub(src, "", true)

func _measure(plain: String, width: float, fsize: float) -> Vector2:
	var f := _variant((_style & 1) != 0)
	var fs := int(round(fsize))
	var lines := plain.split("\n")
	var total_h := 0.0
	var max_w := 0.0
	var lh := f.get_height(fs)
	var gap := _line_gap(fsize)
	var count := 0
	for ln in lines:
		if ln == "":
			total_h += lh
			count += 1
			continue
		if _wrap and width < 1e5:
			var sz := f.get_multiline_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, width, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
			var n := maxi(1, int(round(sz.y / lh)))
			total_h += sz.y
			count += n
			max_w = max(max_w, min(sz.x, width))
		else:
			var sw := f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			total_h += lh
			count += 1
			max_w = max(max_w, sw)
	total_h += gap * max(0, count - 1)
	return Vector2(max_w, total_h)

func _fit_size(src: String, box: Vector2) -> float:
	var plain := plain_text(src)
	var lo := fontSizeMin
	var hi := fontSizeMax
	if _fits(plain, box, hi):
		return hi
	if not _fits(plain, box, lo):
		return lo
	for i in 10:
		var mid := (lo + hi) * 0.5
		if _fits(plain, box, mid):
			lo = mid
		else:
			hi = mid
		if hi - lo < 0.5:
			break
	return floorf(lo)

func _fits(plain: String, box: Vector2, fsize: float) -> bool:
	var m := _measure(plain, box.x if _wrap else 1e6, fsize)
	if not _wrap and m.x > box.x + 0.5:
		return false
	if _wrap:
		var f := _variant((_style & 1) != 0)
		for word in plain.split(" "):
			if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(fsize))).x > box.x + 0.5:
				return false
	return m.y <= box.y + 0.5

func GetPreferredValues(s = null, w := 0.0, _h := 0.0) -> Vector2:
	var src := _text if s == null else str(s)
	var plain := plain_text(src)
	var fsize := _fontSize if not _autoSize else fontSizeMax
	var width := (w if w > 0.0 else 1e6) - _margin.x - _margin.z
	var m := _measure(plain, maxf(1.0, width), fsize)
	return Vector2(m.x + _margin.x + _margin.z, m.y + _margin.y + _margin.w)

func pref_width() -> float:
	if not _enabled:
		return 0.0
	return GetPreferredValues(_text, 0.0).x

func pref_height(width: float) -> float:
	if not _enabled:
		return 0.0
	return GetPreferredValues(_text, width if width > 0 else size.x).y

static func _upper_keep_tags(s: String) -> String:
	var out := ""
	var in_tag := false
	for ch in s:
		if ch == "<":
			in_tag = true
		elif ch == ">":
			in_tag = false
		out += ch if in_tag else ch.to_upper()
	return out

static var _tag_re: RegEx

static func tmp_to_bbcode(s: String, rich: bool, base_size: float) -> String:
	if _tag_re == null:
		_tag_re = RegEx.create_from_string("<(/?)([a-zA-Z\\-]+)(?:=\\\"?([^>\\\"]*)\\\"?)?\\s*>")
	if not rich:
		return s.replace("[", "[lb]")
	var out := ""
	var pos := 0
	var stack_align := []
	for m in _tag_re.search_all(s):
		out += s.substr(pos, m.get_start() - pos).replace("[", "[lb]")
		pos = m.get_end()
		var closing := m.get_string(1) == "/"
		var tag := m.get_string(2).to_lower()
		var val := m.get_string(3)
		match tag:
			"color":
				if closing:
					out += "[/color]"
				else:
					out += "[color=%s]" % _color_val(val)
			"b", "i", "u", "s":
				out += ("[/%s]" if closing else "[%s]") % tag
			"size":
				if closing:
					out += "[/font_size]"
				else:
					out += "[font_size=%d]" % int(round(_size_val(val, base_size)))
			"br":
				out += "\n"
			"align":
				if closing:
					if not stack_align.is_empty():
						out += "[/%s]" % stack_align.pop_back()
				else:
					var a := "left"
					if val == "center":
						a = "center"
					elif val == "right":
						a = "right"
					stack_align.append(a)
					out += "[%s]" % a
			"sup":
				out += "[/font_size]" if closing else "[font_size=%d]" % int(base_size * 0.6)
			"sub":
				out += "[/font_size]" if closing else "[font_size=%d]" % int(base_size * 0.6)
			_:
				pass
	out += s.substr(pos).replace("[", "[lb]")
	return out

static func _color_val(v: String) -> String:
	v = v.strip_edges()
	if v.begins_with("#"):
		return v
	return v.to_lower()

static func _size_val(v: String, base: float) -> float:
	v = v.strip_edges()
	if v.ends_with("%"):
		return base * float(v.trim_suffix("%")) / 100.0
	if v.ends_with("em"):
		return base * float(v.trim_suffix("em"))
	if v.begins_with("+"):
		return base + float(v.substr(1))
	if v.begins_with("-"):
		return base - float(v.substr(1))
	return float(v)
