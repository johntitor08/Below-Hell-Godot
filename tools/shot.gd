extends Node

var _args := {}
var _frames := 0
var _target := 0
var _out := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not _args.has("shot") and not _args.has("frames"):
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = str(_args.get("shot", ""))
	_target = int(_args.get("frames", "90"))
	if _args.has("level"):
		Game.set_meta("level_index", int(_args["level"]))
	if _args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(str(_args["scene"]))

func _process(_d: float) -> void:
	_frames += 1
	for ck in str(_args.get("clicks", "")).split(",", false):
		var p := ck.split(":")
		if p.size() == 3 and int(p[0]) == _frames:
			_click(Vector2(float(p[1]), float(p[2])))
	for h in str(_args.get("hold", "")).split(",", false):
		var p := h.split(":")
		if p.size() >= 3:
			var f0 := int(p[0])
			var f1 := f0 + int(p[2])
			if _frames == f0:
				Input.action_press(p[1])
			elif _frames == f1:
				Input.action_release(p[1])
	for st in str(_args.get("steps", "")).split(";", false):
		var at := st.find("@")
		if at > 0 and int(st.substr(0, at)) == _frames:
			_run(st.substr(at + 1))
	if _frames >= _target:
		if _out != "":
			var img := get_viewport().get_texture().get_image()
			img.save_png(_out)
			print("SHOT ", _out)
		get_tree().quit()

func _click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	get_viewport().push_input(m)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = p
	d.global_position = p
	get_viewport().push_input(d)
	await get_tree().process_frame
	var u := d.duplicate()
	u.pressed = false
	get_viewport().push_input(u)
	print("CLICK ", p)

func _run(s: String) -> void:
	var e := Expression.new()
	if e.parse(s, ["root", "Game", "Creatures", "Fx"]) != OK:
		push_error("eval parse: " + s)
		return
	var r = e.execute([get_tree().current_scene, Game, Creatures, Fx], self)
	if e.has_execute_failed():
		push_error("eval failed: " + s + " -> " + e.get_error_text())
	else:
		print("EVAL ", s, " => ", r)

func node(path: String):
	return get_tree().current_scene.get_node_or_null(path)

func group(g: String):
	return get_tree().get_first_node_in_group(g)
