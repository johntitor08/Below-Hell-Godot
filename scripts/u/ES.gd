@tool
extends Node

const DRAG_THRESHOLD := 10.0

var ev := UPointerEvent.new()
var _last_pos := Vector2(-1, -1)
var _layout_dirty := true
var currentSelectedGameObject = null
var _hover_go = null
var enabled := true
var _press_started := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_priority = -900
	process_mode = Node.PROCESS_MODE_ALWAYS
	var late := Node.new()
	late.name = "LatePass"
	late.process_priority = 1000
	late.process_mode = Node.PROCESS_MODE_ALWAYS
	late.set_script(load("res://scripts/u/ESLate.gd"))
	add_child(late)

func reset() -> void:
	ev = UPointerEvent.new()
	_hover_go = null
	currentSelectedGameObject = null
	_layout_dirty = true

func mark_layout_dirty() -> void:
	_layout_dirty = true
	if Engine.is_editor_hint():
		return

var mouse_override := Vector2(-1, -1)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled or U.scene_root() == null:
		return
	if _layout_dirty:
		rebuild_layout()
	var vp := get_viewport()
	var gp := mouse_override if mouse_override.x >= 0.0 else vp.get_mouse_position()
	var upos := U.to_unity_screen(gp)
	ev.delta = upos - ev.position if _last_pos.x >= 0 else Vector2.ZERO
	ev.position = upos
	_last_pos = gp
	var hit = raycast(gp)
	ev.pointerCurrentRaycast = {"gameObject": hit}
	_handle_enter_exit(hit)
	if U.GetMouseButtonDown(0):
		_press(hit)
	_process_drag(hit)
	if U.GetMouseButtonUp(0):
		_release(hit)
	var s := U.consume_scroll()
	if s != 0.0 and hit != null:
		ev.scrollDelta = Vector2(0, s)
		execute_hierarchy(hit, "OnScroll", ev)
		ev.scrollDelta = Vector2.ZERO

func _press(hit) -> void:
	ev.eligibleForClick = true
	ev.delta = Vector2.ZERO
	ev.dragging = false
	ev.useDragThreshold = true
	ev.pressPosition = ev.position
	ev.pointerPressRaycast = {"gameObject": hit}
	ev.used = false
	if hit != currentSelectedGameObject:
		set_selected(null)
	var new_press = execute_hierarchy(hit, "OnPointerDown", ev)
	var click_handler = get_event_handler(hit, "OnPointerClick")
	if new_press == null:
		new_press = click_handler
	var t := U.unscaledTime
	if new_press != null and new_press == ev.lastPress:
		if t - ev.clickTime < 0.3:
			ev.clickCount += 1
		else:
			ev.clickCount = 1
	else:
		ev.clickCount = 1
	ev.clickTime = t
	ev.pointerPress = new_press
	ev.rawPointerPress = hit
	ev.pointerClick = click_handler
	ev.pointerDrag = get_event_handler(hit, "OnDrag")
	if ev.pointerDrag != null:
		execute(ev.pointerDrag, "OnInitializePotentialDrag", ev)
	_press_started = true

func _process_drag(_hit) -> void:
	if not _press_started or ev.pointerDrag == null or not is_instance_valid(ev.pointerDrag):
		return
	if not U.GetMouseButton(0) and not U.GetMouseButtonUp(0):
		return
	if not ev.dragging:
		if not ev.useDragThreshold or (ev.pressPosition - ev.position).length() >= DRAG_THRESHOLD:
			execute(ev.pointerDrag, "OnBeginDrag", ev)
			ev.dragging = true
	if ev.dragging and ev.delta != Vector2.ZERO:
		if ev.pointerPress != ev.pointerDrag and ev.pointerPress != null:
			execute(ev.pointerPress, "OnPointerUp", ev)
			ev.eligibleForClick = false
			ev.pointerPress = null
			ev.rawPointerPress = null
		execute(ev.pointerDrag, "OnDrag", ev)

func _release(hit) -> void:
	if not _press_started:
		return
	_press_started = false
	if ev.pointerPress != null and is_instance_valid(ev.pointerPress):
		execute(ev.pointerPress, "OnPointerUp", ev)
	var click_handler = get_event_handler(hit, "OnPointerClick")
	if ev.pointerPress != null and is_instance_valid(ev.pointerPress) and ev.pointerClick == click_handler and ev.eligibleForClick:
		execute(ev.pointerClick, "OnPointerClick", ev)
	elif ev.dragging and hit != null:
		execute_hierarchy(hit, "OnDrop", ev)
	ev.eligibleForClick = false
	ev.lastPress = ev.pointerPress
	ev.pointerPress = null
	ev.rawPointerPress = null
	if ev.pointerDrag != null and is_instance_valid(ev.pointerDrag) and ev.dragging:
		execute(ev.pointerDrag, "OnEndDrag", ev)
	ev.dragging = false
	ev.pointerDrag = null

func _chain(go) -> Array:
	var a := []
	while go != null and is_instance_valid(go):
		a.append(go)
		go = _parent_go(go)
	return a

func _parent_go(go):
	var p = go.get_parent()
	while p != null:
		if p is CanvasItem and p.has_meta("u"):
			return p
		if p is CanvasLayer:
			p = p.get_parent()
			continue
		return null
	return null

func _handle_enter_exit(hit) -> void:
	if hit == _hover_go:
		return
	var old_chain := []
	for h in ev.hovered:
		if is_instance_valid(h):
			old_chain.append(h)
	var new_chain := _chain(hit) if hit != null else []
	var common = null
	for n in new_chain:
		if old_chain.has(n):
			common = n
			break
	for h in old_chain:
		if h == common:
			break
		execute(h, "OnPointerExit", ev)
	var to_enter := []
	for n in new_chain:
		if n == common:
			break
		to_enter.append(n)
	to_enter.reverse()
	ev.pointerEnter = hit
	ev.hovered = new_chain
	_hover_go = hit
	for n in to_enter:
		execute(n, "OnPointerEnter", ev)

func handlers(go, method: String) -> Array:
	var a := []
	if go == null or not is_instance_valid(go):
		return a
	for c in go.get_children():
		if c is Mono and c._active and c.has_method(method):
			a.append(c)
	return a

func execute(go, method: String, data) -> bool:
	var hs := handlers(go, method)
	var live := []
	for h in hs:
		if is_instance_valid(h) and h._active:
			live.append(h)
	for h in live:
		if is_instance_valid(h):
			h.call(method, data)
	return not hs.is_empty()

func get_event_handler(go, method: String):
	while go != null and is_instance_valid(go):
		if not handlers(go, method).is_empty():
			return go
		go = _parent_go(go)
	return null

func execute_hierarchy(go, method: String, data):
	var h = get_event_handler(go, method)
	if h != null:
		execute(h, method, data)
	return h

func set_selected(go) -> void:
	if go == currentSelectedGameObject:
		return
	var old = currentSelectedGameObject
	currentSelectedGameObject = go
	if old != null and is_instance_valid(old):
		execute(old, "OnDeselect", ev)
	if go != null and is_instance_valid(go):
		execute(go, "OnSelect", ev)

func SetSelectedGameObject(go) -> void:
	set_selected(U.go_of(go))

func IsPointerOverGameObject() -> bool:
	return _hover_go != null

func layers() -> Array:
	var root := U.scene_root()
	var out := []
	if root == null:
		return out
	_collect_layers(root, out)
	return out

func _collect_layers(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			out.append(c)
			_collect_layers(c, out)
		elif not (c is CanvasItem) and not (c is Mono):
			_collect_layers(c, out)

func raycast(gp: Vector2):
	_order = 0
	var best = null
	var best_key := []
	var ls := layers()
	var idx := 0
	for L in ls:
		if not L.visible:
			idx += 1
			continue
		var res := []
		for c in L.get_children():
			if c is CanvasItem:
				_ray(c, gp, null, res)
		for r in res:
			var key := [L.layer, 1 if r[0].get("has_shape") else 0, r[1], idx, r[2]]
			if best == null or _key_gt(key, best_key):
				best = r[0]
				best_key = key
		idx += 1
	return best

var _order := 0

func _key_gt(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] > b[i]:
			return true
		if a[i] < b[i]:
			return false
	return false

func _ray(n: CanvasItem, gp: Vector2, clip, res: Array, z := 0) -> void:
	if not n.visible:
		return
	if not n.has_meta("u"):
		return
	_order += 1
	var my_order := _order
	var zz := z
	if n.z_index != 0:
		zz = n.z_index if not n.z_as_relative else z + n.z_index
	var cg = _canvas_group(n)
	if cg != null and not cg.blocksRaycasts_effective():
		return
	var ctl := n as Control
	var local := Vector2.ZERO
	if ctl != null:
		local = ctl.get_global_transform_with_canvas().affine_inverse() * gp
	var child_clip = clip
	if ctl != null and ctl.clip_contents:
		var inside := Rect2(Vector2.ZERO, ctl.size).has_point(local)
		child_clip = inside if clip == null else (clip and inside)
	if ctl != null and n.has_method("is_raycast_target") and n.is_raycast_target():
		if (clip == null or clip) and n.hit_local(local):
			res.append([n, zz, my_order])
	for c in n.get_children():
		if c is CanvasItem:
			_ray(c, gp, child_clip, res, zz)

func _canvas_group(n: Node):
	for c in n.get_children():
		if c is UCanvasGroup:
			return c
	return null

func rebuild_layout() -> void:
	_layout_dirty = false
	for L in layers():
		for c in L.get_children():
			if c is Control:
				_layout_root(c)
	var root := U.scene_root()
	if root != null:
		for c in root.get_children():
			if c is Control:
				_layout_root(c)

func force_layout(go) -> void:
	go = U.go_of(go)
	if go is Control:
		_layout_root(go)

func _layout_root(c: Control) -> void:
	for axis in 2:
		_calc(c, axis)
		_set_layout(c, axis)

func _layout_comps(n: Node) -> Array:
	var g = null
	var f = null
	for c in n.get_children():
		if c is ULayoutGroupBase and c.enabled:
			g = c
		elif c is UContentSizeFitter and c.enabled:
			f = c
	return [g, f]

func _calc(n: Control, axis: int) -> void:
	if not n.visible:
		return
	for c in n.get_children():
		if c is Control and c.has_meta("u"):
			_calc(c, axis)
	var lc := _layout_comps(n)
	if lc[0] != null:
		lc[0].calc_axis(axis)

func _set_layout(n: Control, axis: int) -> void:
	if not n.visible:
		return
	var lc := _layout_comps(n)
	if lc[1] != null:
		lc[1].set_layout(axis)
	if lc[0] != null:
		lc[0].set_axis(axis)
	for c in n.get_children():
		if c is Control and c.has_meta("u"):
			_set_layout(c, axis)

static func layout_props(c: Control, axis: int) -> Array:
	var best := [-1.0, -1.0, -1.0]
	var prio := [-1000000, -1000000, -1000000]
	var elems := []
	if c.has_meta("u") and (c is UImage and c.has_graphic and c.enabled):
		elems.append([0, _image_props(c, axis)])
	if c is UText and c.enabled:
		var pw: float = c.pref_width() if axis == 0 else c.pref_height(c.size.x)
		elems.append([0, [0.0, pw, -1.0]])
	for k in c.get_children():
		if k is ULayoutElement and k.enabled:
			elems.append([k.layoutPriority, k.props(axis)])
		elif k is ULayoutGroupBase and k.enabled:
			elems.append([0, k.totals(axis)])
		elif k is UScrollRect and k.enabled:
			elems.append([-1, [-1.0, -1.0, -1.0]])
	for e in elems:
		var p: int = e[0]
		var v: Array = e[1]
		for i in 3:
			if v[i] < 0:
				continue
			if p > prio[i]:
				prio[i] = p
				best[i] = v[i]
			elif p == prio[i] and v[i] > best[i]:
				best[i] = v[i]
	var mn := maxf(0.0, best[0])
	var pr := maxf(mn, maxf(0.0, best[1]))
	var fl := maxf(0.0, best[2])
	return [mn, pr, fl]

static func _image_props(c: UImage, axis: int) -> Array:
	var sp: USprite = c.sprite
	if sp == null or sp.kind != USprite.Kind.TEX:
		return [0.0, 0.0, -1.0]
	var r := sp.get_region()
	var ppu := (sp.pixelsPerUnit / 100.0)
	if c.type == UImage.Type.SLICED or c.type == UImage.Type.TILED:
		var b := sp.border
		var m := (b.x + b.z) if axis == 0 else (b.y + b.w)
		return [0.0, m / maxf(0.0001, ppu * c.ppum), -1.0]
	return [0.0, (r.size.x if axis == 0 else r.size.y) / maxf(0.0001, ppu), -1.0]

static func ignore_layout(c: Node) -> bool:
	for k in c.get_children():
		if k is ULayoutElement and k.enabled and k.ignoreLayout:
			return true
	return false
