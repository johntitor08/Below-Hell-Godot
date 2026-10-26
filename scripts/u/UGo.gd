class_name UGo

static func init(n: Node) -> Dictionary:
	var blob := {}
	var raw = n.get_meta("u", "")
	if raw is String and raw != "":
		var p = JSON.parse_string(raw)
		if p is Dictionary:
			blob = p
	if blob.has("name"):
		n.set_meta("u_name", blob["name"])
	var tag := str(blob.get("tag", "Untagged"))
	n.set_meta("u_tag", tag)
	n.set_meta("u_layer", int(blob.get("layer", 0)))
	if tag != "Untagged" and not Engine.is_editor_hint():
		n.add_to_group("go_tag_" + tag)
	return blob

static func layer_of(n: Node) -> int:
	return int(n.get_meta("u_layer", 0))

static func set_layer(n: Node, l: int) -> void:
	n.set_meta("u_layer", l)
	if n is CollisionObject2D:
		apply_layer(n, l)
	for c in n.get_children():
		if c is Area2D and c.has_meta("trigger_owner"):
			apply_layer(c, l)

static func apply_layer(co: CollisionObject2D, l: int) -> void:
	co.collision_layer = UPhys.layer_bit(l)
	co.collision_mask = UPhys.mask_for(l)

static func tag_of(n: Node) -> String:
	return str(n.get_meta("u_tag", "Untagged"))

static func set_tag(n: Node, t: String) -> void:
	var old := tag_of(n)
	if old != "Untagged":
		n.remove_from_group("go_tag_" + old)
	n.set_meta("u_tag", t)
	if t != "Untagged":
		n.add_to_group("go_tag_" + t)

static func sync_physics_active(co: CollisionObject2D) -> void:
	var on := co.is_visible_in_tree()
	var want := Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if co.process_mode != want:
		co.set_deferred("process_mode", want)

static func trigger_area(body: CollisionObject2D) -> Area2D:
	for c in body.get_children():
		if c is Area2D and c.has_meta("trigger_owner"):
			return c
	var a := UArea.new()
	a.name = "_triggers"
	a.set_meta("trigger_owner", body)
	a.is_internal = true
	body.add_child(a, false, Node.INTERNAL_MODE_FRONT)
	apply_layer(a, layer_of(body))
	return a
