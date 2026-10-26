class_name UDropdown
extends USelectable

var options: Array = []
var _value := 0
var captionText
var captionImage
var template
var onValueChanged := UEvent.new()
var _popup: PopupMenu

var value: int:
	get:
		return _value
	set(v):
		Set(v, true)

func _selectable_injected(root: Node) -> void:
	captionText = DB.conv(u.get("m_CaptionText"), root)
	captionImage = DB.conv(u.get("m_CaptionImage"), root)
	template = DB.conv(u.get("m_Template"), root)
	_value = int(u.get("m_Value", 0))
	var ol = u.get("m_Options")
	if ol is Dictionary:
		for o in ol.get("m_Options", []):
			options.append({"text": str(o.get("m_Text", "")), "image": DB.conv(o.get("m_Image"), root)})
	var e = DB.conv(u.get("m_OnValueChanged"), root)
	if e is UEvent:
		onValueChanged = e

func Awake() -> void:
	if template is CanvasItem:
		template.visible = false
	RefreshShownValue()

func Set(v: int, notify: bool) -> void:
	var nv := clampi(v, 0, maxi(0, options.size() - 1))
	if nv == _value and options.size() > 0:
		RefreshShownValue()
		return
	_value = nv
	RefreshShownValue()
	if notify:
		onValueChanged.Invoke(_value)

func SetValueWithoutNotify(v: int) -> void:
	Set(v, false)

func RefreshShownValue() -> void:
	if captionText is UText:
		captionText.text = options[_value].text if _value >= 0 and _value < options.size() else ""
	if captionImage is UImage and _value >= 0 and _value < options.size():
		captionImage.sprite = options[_value].image

func ClearOptions() -> void:
	options.clear()
	_value = 0
	RefreshShownValue()

func AddOptions(list: Array) -> void:
	for o in list:
		if o is Dictionary:
			options.append({"text": str(o.get("text", "")), "image": o.get("image")})
		else:
			options.append({"text": str(o), "image": null})
	RefreshShownValue()

func OptionData(t: String, img = null) -> Dictionary:
	return {"text": t, "image": img}

func OnPointerClick(e) -> void:
	if e.button != 0 or not IsInteractable():
		return
	Show()

func Show() -> void:
	Hide()
	_popup = PopupMenu.new()
	_popup.name = "_dropdown_popup"
	var fsize := 28
	var fnt: Font = null
	if captionText is UText:
		fsize = int(captionText.fontSize)
		fnt = captionText.font
	if fnt != null:
		_popup.add_theme_font_override("font", fnt)
	_popup.add_theme_font_size_override("font_size", fsize)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.105, 0.103, 0.133, 0.98)
	bg.border_color = Color(0.784, 0.659, 0.431, 0.75)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(8)
	_popup.add_theme_stylebox_override("panel", bg)
	var hv := StyleBoxFlat.new()
	hv.bg_color = Color(0.263, 0.251, 0.341, 1)
	hv.set_corner_radius_all(6)
	_popup.add_theme_stylebox_override("hover", hv)
	_popup.add_theme_color_override("font_color", Color(0.886, 0.835, 0.733))
	_popup.add_theme_color_override("font_hover_color", Color(0.934, 0.897, 0.824))
	for i in options.size():
		_popup.add_radio_check_item(options[i].text, i)
		_popup.set_item_checked(i, i == _value)
	_popup.id_pressed.connect(func(id): value = id)
	_popup.popup_hide.connect(func(): if is_instance_valid(_popup): _popup.queue_free())
	U.scene_root().add_child(_popup)
	var go: Control = gameObject
	var xf := go.get_global_transform_with_canvas()
	var top_left := xf * Vector2.ZERO
	var bottom := xf * Vector2(0, go.size.y)
	var vp := get_viewport()
	var scale := vp.get_final_transform().get_scale()
	var win_pos := vp.get_final_transform() * bottom
	_popup.min_size = Vector2i(int(go.size.x * scale.x), 0)
	_popup.content_scale_factor = scale.x
	_popup.popup(Rect2i(Vector2i(win_pos) + Vector2i(DisplayServer.window_get_position()) * 0, Vector2i(int(go.size.x * scale.x), 0)))

func Hide() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
