class_name UInputField
extends USelectable

var textComponent
var placeholder
var textViewport
var characterLimit := 0
var contentType := 0
var lineType := 0
var readOnly := false
var onValueChanged := UEvent.new()
var onEndEdit := UEvent.new()
var onSubmit := UEvent.new()
var onSelect := UEvent.new()
var onDeselect := UEvent.new()
var edit: LineEdit
var _text := ""
var _suppress := false

var text: String:
	get:
		return edit.text if edit != null else _text
	set(v):
		_text = "" if v == null else str(v)
		if edit != null and edit.text != _text:
			_suppress = true
			edit.text = _text
			_suppress = false
		onValueChanged.Invoke(_text)
		_sync_placeholder()

var isFocused: bool:
	get:
		return edit != null and edit.has_focus()

func _selectable_injected(root: Node) -> void:
	textComponent = DB.conv(u.get("m_TextComponent"), root)
	placeholder = DB.conv(u.get("m_Placeholder"), root)
	textViewport = DB.conv(u.get("m_TextViewport"), root)
	characterLimit = int(u.get("m_CharacterLimit", 0))
	contentType = int(u.get("m_ContentType", 0))
	lineType = int(u.get("m_LineType", 0))
	readOnly = int(u.get("m_ReadOnly", 0)) != 0
	_text = str(u.get("m_Text", "")) if u.get("m_Text") != null else ""
	for pair in [["m_OnValueChanged", "onValueChanged"], ["m_OnEndEdit", "onEndEdit"], ["m_OnSubmit", "onSubmit"], ["m_OnSelect", "onSelect"], ["m_OnDeselect", "onDeselect"]]:
		var e = DB.conv(u.get(pair[0]), root)
		if e is UEvent:
			set(pair[1], e)

func Awake() -> void:
	_build()

func _build() -> void:
	if edit != null:
		return
	var host: Control = textViewport if textViewport is Control else gameObject
	edit = LineEdit.new()
	edit.name = "_edit"
	edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit.flat = true
	edit.context_menu_enabled = false
	for s in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	if textComponent is UText:
		edit.add_theme_font_override("font", textComponent.font)
		edit.add_theme_font_size_override("font_size", int(textComponent._fontSize))
		edit.add_theme_color_override("font_color", textComponent.color)
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER if textComponent._halign == UText.H_CENTER else (HORIZONTAL_ALIGNMENT_RIGHT if textComponent._halign == UText.H_RIGHT else HORIZONTAL_ALIGNMENT_LEFT)
		textComponent.enabled = false
	if placeholder is UText:
		edit.placeholder_text = placeholder.text
		edit.add_theme_color_override("font_placeholder_color", placeholder.color)
		placeholder.enabled = false
	if characterLimit > 0:
		edit.max_length = characterLimit
	edit.secret = contentType == 7
	edit.editable = not readOnly and _interactable
	edit.text = _text
	host.add_child(edit, false, Node.INTERNAL_MODE_BACK)
	edit.text_changed.connect(_on_changed)
	edit.text_submitted.connect(_on_submitted)
	edit.focus_exited.connect(_on_focus_lost)
	edit.focus_entered.connect(func(): onSelect.Invoke(edit.text))

func _sync_placeholder() -> void:
	pass

func _on_changed(t: String) -> void:
	_text = t
	if not _suppress:
		onValueChanged.Invoke(t)

func _on_submitted(t: String) -> void:
	onSubmit.Invoke(t)
	onEndEdit.Invoke(t)

func _on_focus_lost() -> void:
	onEndEdit.Invoke(edit.text)
	onDeselect.Invoke(edit.text)

func SetTextWithoutNotify(t: String) -> void:
	_text = t
	if edit != null:
		_suppress = true
		edit.text = t
		_suppress = false

func ActivateInputField() -> void:
	if edit != null:
		edit.grab_focus.call_deferred()
		edit.caret_column = edit.text.length()

func DeactivateInputField(_restore := false) -> void:
	if edit != null and edit.has_focus():
		edit.release_focus()

func Select() -> void:
	ActivateInputField()

func OnPointerClick(_e) -> void:
	if IsInteractable():
		ActivateInputField()

func OnEnable() -> void:
	super.OnEnable()
	_build()
	edit.editable = not readOnly and IsInteractable()

func OnDisable() -> void:
	super.OnDisable()
	DeactivateInputField()
