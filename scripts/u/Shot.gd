extends Node

var _args := {}
var _frames := 0
var _target := 0
var _out := ""
var _steps: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not _args.has("shot"):
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = str(_args["shot"])
	_target = int(_args.get("frames", "90"))
	if _args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(str(_args["scene"]))
	if _args.has("eval"):
		_steps = str(_args["eval"]).split(";")

func _process(_d: float) -> void:
	_frames += 1
	for ck in str(_args.get("clicks", "")).split(",", false):
		var parts := ck.split(":")
		if parts.size() == 3 and int(parts[0]) == _frames:
			_click(Vector2(float(parts[1]), float(parts[2])))
	for dr in str(_args.get("drags", "")).split(",", false):
		var q := dr.split(":")
		if q.size() == 5 and int(q[0]) == _frames:
			_drag(Vector2(float(q[1]), float(q[2])), Vector2(float(q[3]), float(q[4])))
	for st in str(_args.get("steps", "")).split(";", false):
		var at := st.find("@")
		if at > 0 and int(st.substr(0, at)) == _frames:
			_run(st.substr(at + 1))
	if _frames == 20 and not _steps.is_empty():
		for s in _steps:
			_run(s)
	if _frames >= _target:
		if _args.has("dump"):
			_dump(get_tree().current_scene)
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("SHOT ", _out)
		get_tree().quit()

func _run(s: String) -> void:
	var e := Expression.new()
	if e.parse(s, ["U", "ES", "DB", "root"]) != OK:
		push_error("eval parse: " + s)
		return
	var r = e.execute([U, ES, DB, get_tree().current_scene], self)
	if e.has_execute_failed():
		push_error("eval failed: " + s + " -> " + e.get_error_text())
	else:
		print("EVAL ", s, " => ", r)

func cls(n: String):
	for g in ProjectSettings.get_global_class_list():
		if g["class"] == n:
			return load(g["path"])
	return null

func inst(n: String):
	var c = cls(n)
	return c.Instance if c != null else null

func _dump(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is UImage and c.size.x >= 1000 and c.size.y >= 600:
			var col: Color = c.color
			print("DUMP ", c.get_path(), " col=", col, " mod=", c.modulate, " spr=", c.sprite.name if c.sprite != null else "-")
		if c is CanvasLayer:
			print("LAYER ", c.get_path(), " layer=", c.layer)
		_dump(c)

func _click(p: Vector2) -> void:
	var sp: Vector2 = get_tree().root.get_final_transform() * p
	ES.mouse_override = p
	await get_tree().process_frame
	var mm := InputEventMouseMotion.new()
	mm.position = sp
	mm.global_position = sp
	Input.parse_input_event(mm)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = sp
	d.global_position = sp
	Input.parse_input_event(d)
	await get_tree().process_frame
	await get_tree().process_frame
	var u := d.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	var h = ES.raycast(p)
	print("CLICK ", p, " hit=", h.get_path() if h != null else null)

func _mouse_btn(pressed: bool) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = pressed
	Input.parse_input_event(d)

func _drag(a: Vector2, b: Vector2) -> void:
	ES.mouse_override = a
	await get_tree().process_frame
	_mouse_btn(true)
	for i in 31:
		await get_tree().process_frame
		ES.mouse_override = a.lerp(b, i / 30.0)
	await get_tree().process_frame
	_mouse_btn(false)
	print("DRAG ", a, " -> ", b)
