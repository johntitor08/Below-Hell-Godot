extends Node

signal status_changed(text: String)
signal auth_done(ok: bool, message: String)
signal match_found(info: Dictionary)
signal leaderboard_received(data: Dictionary)
signal opponent_left
signal remote_input(arr: Array)
signal remote_state(st: Dictionary)
signal remote_event(ev: Dictionary)
signal connection_changed(online: bool)

const OFFICIAL_SERVER := "malls-correctly.tun.ply.gg:30451"
const WEB_ADDRESS_URL := "https://raw.githubusercontent.com/johntitor08/Below-Hell-Godot/sunucu/adres.json"
const DEFAULT_PORT := 7788
const SALT := "belowhell-v1"

var is_server := false
var connected := false
var username := ""
var stats := {}
var match_info := {}
var _peer: MultiplayerPeer
var _connecting := false

var _db_path := "user://server_db.json"
var _db := {"users": {}, "times": {}}
var _sessions := {}
var _queue: Array = []
var _matches := {}
var _next_match := 1
var _dirty := false
var _save_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.has("--server"):
		var port := DEFAULT_PORT
		for a in args:
			if a.begins_with("--port="):
				port = int(a.substr(7))
		_start_server(port)

func _notification(what: int) -> void:
	if is_server and (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE) and _dirty:
		_save_db()

func _exit_tree() -> void:
	if is_server and _dirty:
		_save_db()

func _process(delta: float) -> void:
	if is_server and FileAccess.file_exists("user://kapat"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kapat"))
		_save_db()
		print("[sunucu] kapat isteği: kaydedildi, çıkılıyor")
		get_tree().quit()
		return
	if is_server and _dirty:
		_save_t -= delta
		if _save_t <= 0.0:
			_save_db()

func host_address() -> String:
	var s := str(Game.settings.get("server", ""))
	return s if s != "" else OFFICIAL_SERVER

func connect_to_server() -> void:
	if connected or _connecting:
		return
	var addr := host_address()
	if OS.has_feature("web") and not (addr.begins_with("ws://") or addr.begins_with("wss://")):
		_connecting = true
		status_changed.emit("…")
		var url := await _fetch_web_address()
		_connecting = false
		if url == "":
			status_changed.emit(Game.t("offline"))
			connection_changed.emit(false)
			return
		addr = url
	if addr.begins_with("ws://") or addr.begins_with("wss://"):
		var w := WebSocketMultiplayerPeer.new()
		w.inbound_buffer_size = 1 << 20
		w.outbound_buffer_size = 1 << 20
		if w.create_client(addr) != OK:
			status_changed.emit(Game.t("offline"))
			connection_changed.emit(false)
			return
		_begin(w)
		return
	var host := addr
	var port := DEFAULT_PORT
	var i := addr.rfind(":")
	if i > 0:
		host = addr.substr(0, i)
		port = int(addr.substr(i + 1))
	if not host.is_valid_ip_address():
		var v4 := IP.resolve_hostname(host, IP.TYPE_IPV4)
		if v4 != "":
			host = v4
	var e := ENetMultiplayerPeer.new()
	if e.create_client(host, port) != OK:
		status_changed.emit(Game.t("offline"))
		connection_changed.emit(false)
		return
	e.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	_begin(e)

func _begin(p: MultiplayerPeer) -> void:
	_peer = p
	_connecting = true
	multiplayer.multiplayer_peer = p
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.server_disconnected.connect(_on_lost)
	status_changed.emit("…")
	get_tree().create_timer(8.0).timeout.connect(_connect_timeout)

func _fetch_web_address() -> String:
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request(WEB_ADDRESS_URL + "?t=" + str(Time.get_unix_time_from_system()))
	if err != OK:
		req.queue_free()
		return ""
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[1]) != 200:
		return ""
	var v = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if v is Dictionary:
		return str(v.get("wss", ""))
	return ""

func _connect_timeout() -> void:
	if _connecting and not connected:
		_on_failed()

func _on_connected() -> void:
	_connecting = false
	connected = true
	status_changed.emit("")
	connection_changed.emit(true)

func _on_failed() -> void:
	_connecting = false
	connected = false
	multiplayer.multiplayer_peer = null
	status_changed.emit(Game.t("offline"))
	connection_changed.emit(false)

func _on_lost() -> void:
	connected = false
	username = ""
	multiplayer.multiplayer_peer = null
	status_changed.emit(Game.t("offline"))
	connection_changed.emit(false)
	if not match_info.is_empty():
		match_info = {}
		opponent_left.emit()

func disconnect_from_server() -> void:
	if _peer != null:
		_peer.close()
	multiplayer.multiplayer_peer = null
	connected = false
	username = ""

static func hash_password(user: String, password: String) -> String:
	return ("%s:%s:%s" % [user.to_lower(), password, SALT]).sha256_text()

func register(user: String, password: String) -> void:
	_srv_register.rpc_id(1, user, hash_password(user, password))

func login(user: String, password: String) -> void:
	_srv_login.rpc_id(1, user, hash_password(user, password))

func find_match(form: String) -> void:
	_srv_queue.rpc_id(1, form)

func cancel_match() -> void:
	if connected:
		_srv_unqueue.rpc_id(1)

func request_leaderboard() -> void:
	if connected:
		_srv_leaderboard.rpc_id(1)

func submit_time(level: int, t: float) -> void:
	if connected and username != "":
		_srv_time.rpc_id(1, level, t)

func send_input(arr: Array) -> void:
	if connected and not match_info.is_empty():
		_srv_relay_input.rpc_id(1, arr)

func send_state(st: Dictionary) -> void:
	if connected and not match_info.is_empty():
		_srv_relay_state.rpc_id(1, st)

func send_event(ev: Dictionary) -> void:
	if connected and not match_info.is_empty():
		_srv_relay_event.rpc_id(1, ev)

func report_result(winner_slot: int) -> void:
	if connected and not match_info.is_empty() and int(match_info.get("slot", 0)) == 0:
		_srv_result.rpc_id(1, winner_slot)

func leave_match() -> void:
	if connected and not match_info.is_empty():
		_srv_leave.rpc_id(1)
	match_info = {}

func name_of(slot: int) -> String:
	var names: Array = match_info.get("names", ["P1", "P2"])
	return str(names[slot]) if slot < names.size() else "P%d" % (slot + 1)

func my_slot() -> int:
	return int(match_info.get("slot", 0))

@rpc("authority", "call_remote", "reliable")
func _cl_auth(ok: bool, message: String, user: String, st: Dictionary) -> void:
	if ok:
		username = user
		stats = st
	auth_done.emit(ok, message)

@rpc("authority", "call_remote", "reliable")
func _cl_match(info: Dictionary) -> void:
	match_info = info
	match_found.emit(info)

@rpc("authority", "call_remote", "reliable")
func _cl_leaderboard(data: Dictionary) -> void:
	leaderboard_received.emit(data)

@rpc("authority", "call_remote", "reliable")
func _cl_opponent_left() -> void:
	match_info = {}
	opponent_left.emit()

@rpc("authority", "call_remote", "unreliable_ordered")
func _cl_input(arr: Array) -> void:
	remote_input.emit(arr)

@rpc("authority", "call_remote", "unreliable_ordered")
func _cl_state(st: Dictionary) -> void:
	remote_state.emit(st)

@rpc("authority", "call_remote", "reliable")
func _cl_event(ev: Dictionary) -> void:
	remote_event.emit(ev)

@rpc("authority", "call_remote", "reliable")
func _cl_stats(st: Dictionary) -> void:
	stats = st

func _start_server(port: int) -> void:
	is_server = true
	_load_db()
	var e := ENetMultiplayerPeer.new()
	var err := e.create_server(port, 256)
	if err != OK:
		printerr("[sunucu] port %d açılamadı: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	e.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	var ws_port := port + 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ws-port="):
			ws_port = int(a.substr(10))
	_peer = e
	if ws_port > 0:
		var w := WebSocketMultiplayerPeer.new()
		w.inbound_buffer_size = 1 << 20
		w.outbound_buffer_size = 1 << 20
		if w.create_server(ws_port) == OK:
			var dual := DualPeer.new()
			dual.setup(e, w)
			_peer = dual
			print("[sunucu] tarayıcı oyuncuları için WebSocket: %d (TCP)" % ws_port)
		else:
			print("[sunucu] UYARI: WebSocket portu %d açılamadı, yalnızca UDP" % ws_port)
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_disconnected.connect(_on_peer_left)
	print("[sunucu] Below Hell sunucusu %d portunda dinliyor" % port)
	get_tree().change_scene_to_file.call_deferred("res://game/net/server_root.tscn")

func _load_db() -> void:
	if FileAccess.file_exists(_db_path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(_db_path))
		if v is Dictionary:
			_db = v
	if not _db.has("users"):
		_db["users"] = {}
	if not _db.has("times"):
		_db["times"] = {}

func _save_db() -> void:
	_dirty = false
	var tmp := _db_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_db))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(_db_path))

func _mark_dirty() -> void:
	_dirty = true
	_save_t = 2.0

func _user_stats(u: String) -> Dictionary:
	var rec: Dictionary = _db.users.get(u.to_lower(), {})
	return {"wins": int(rec.get("wins", 0)), "losses": int(rec.get("losses", 0))}

static func _valid_name(u: String) -> bool:
	if u.length() < 3 or u.length() > 16:
		return false
	for ch in u:
		if not (ch.is_valid_identifier() or ch.is_valid_int() or ch in "ğüşöçıİĞÜŞÖÇ-"):
			return false
	return true

func _stored_hash(salt: String, h: String) -> String:
	var v := salt + h
	for i in 2000:
		v = (salt + v).sha256_text()
	return v

@rpc("any_peer", "call_remote", "reliable")
func _srv_register(user: String, h: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	user = user.strip_edges()
	if not _valid_name(user):
		_cl_auth.rpc_id(id, false, "name", "", {})
		return
	var key := user.to_lower()
	if _db.users.has(key):
		_cl_auth.rpc_id(id, false, "taken", "", {})
		return
	var salt := str(randi()) + str(Time.get_ticks_usec())
	_db.users[key] = {"name": user, "salt": salt, "hash": _stored_hash(salt, h), "wins": 0, "losses": 0, "created": Time.get_datetime_string_from_system()}
	_mark_dirty()
	_sessions[id] = {"user": key}
	print("[sunucu] yeni hesap: ", user)
	_cl_auth.rpc_id(id, true, "", user, _user_stats(key))

@rpc("any_peer", "call_remote", "reliable")
func _srv_login(user: String, h: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	var key := user.strip_edges().to_lower()
	var rec = _db.users.get(key)
	if rec == null or _stored_hash(str(rec.salt), h) != str(rec.hash):
		_cl_auth.rpc_id(id, false, "bad", "", {})
		return
	for sid in _sessions:
		if _sessions[sid].get("user") == key and sid != id:
			_kick_from_queue(sid)
			_sessions.erase(sid)
			break
	_sessions[id] = {"user": key}
	_cl_auth.rpc_id(id, true, "", str(rec.name), _user_stats(key))

@rpc("any_peer", "call_remote", "reliable")
func _srv_queue(form: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _sessions.has(id) or _sessions[id].has("match"):
		return
	if Creatures.get_def(form) == null:
		form = Creatures.fallback().id
	_sessions[id]["form"] = form
	if not _queue.has(id):
		_queue.append(id)
	_try_pair()

@rpc("any_peer", "call_remote", "reliable")
func _srv_unqueue() -> void:
	if is_server:
		_kick_from_queue(multiplayer.get_remote_sender_id())

func _kick_from_queue(id: int) -> void:
	_queue.erase(id)

func _try_pair() -> void:
	while _queue.size() >= 2:
		var a: int = _queue.pop_front()
		var b: int = _queue.pop_front()
		if not _sessions.has(a) or not _sessions.has(b):
			continue
		var mid := _next_match
		_next_match += 1
		var seed_v := randi()
		var names := [str(_db.users[_sessions[a].user].name), str(_db.users[_sessions[b].user].name)]
		var forms := [str(_sessions[a].form), str(_sessions[b].form)]
		_matches[mid] = {"peers": [a, b], "names": names, "done": false}
		_sessions[a]["match"] = mid
		_sessions[b]["match"] = mid
		for slot in 2:
			var pid: int = [a, b][slot]
			_cl_match.rpc_id(pid, {"id": mid, "slot": slot, "seed": seed_v, "forms": forms, "names": names})
		print("[sunucu] maç %d: %s vs %s" % [mid, names[0], names[1]])

func _other(id: int) -> int:
	var s = _sessions.get(id)
	if s == null or not s.has("match"):
		return 0
	var m = _matches.get(s.match)
	if m == null:
		return 0
	return m.peers[1] if m.peers[0] == id else m.peers[0]

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_relay_input(arr: Array) -> void:
	if not is_server:
		return
	var o := _other(multiplayer.get_remote_sender_id())
	if o != 0 and arr.size() <= 16:
		_cl_input.rpc_id(o, arr)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_relay_state(st: Dictionary) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	var o := _other(sender)
	if o != 0 and _is_host(sender):
		_cl_state.rpc_id(o, st)

@rpc("any_peer", "call_remote", "reliable")
func _srv_relay_event(ev: Dictionary) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	var o := _other(sender)
	if o != 0 and _is_host(sender):
		_cl_event.rpc_id(o, ev)

func _is_host(id: int) -> bool:
	var s = _sessions.get(id)
	if s == null or not s.has("match"):
		return false
	var m = _matches.get(s.match)
	return m != null and m.peers[0] == id

@rpc("any_peer", "call_remote", "reliable")
func _srv_result(winner_slot: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _is_host(id):
		return
	var mid: int = _sessions[id].match
	var m: Dictionary = _matches[mid]
	if m.done:
		return
	m.done = true
	winner_slot = clampi(winner_slot, 0, 1)
	for slot in 2:
		var pid: int = m.peers[slot]
		if not _sessions.has(pid):
			continue
		var key: String = _sessions[pid].user
		var rec: Dictionary = _db.users[key]
		if slot == winner_slot:
			rec["wins"] = int(rec.get("wins", 0)) + 1
		else:
			rec["losses"] = int(rec.get("losses", 0)) + 1
		_cl_stats.rpc_id(pid, _user_stats(key))
	_mark_dirty()
	_end_match(mid, false)

@rpc("any_peer", "call_remote", "reliable")
func _srv_leave() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	var s = _sessions.get(id)
	if s != null and s.has("match"):
		_end_match(s.match, true, id)

func _end_match(mid: int, notify: bool, leaver := 0) -> void:
	var m = _matches.get(mid)
	if m == null:
		return
	for pid in m.peers:
		if _sessions.has(pid):
			_sessions[pid].erase("match")
			if notify and pid != leaver:
				_cl_opponent_left.rpc_id(pid)
	_matches.erase(mid)

@rpc("any_peer", "call_remote", "reliable")
func _srv_leaderboard() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	var arena := []
	for k in _db.users:
		var r: Dictionary = _db.users[k]
		if int(r.get("wins", 0)) + int(r.get("losses", 0)) > 0:
			arena.append([str(r.name), int(r.get("wins", 0)), int(r.get("losses", 0))])
	var cmp_a := func(x, y): return x[1] > y[1] or (x[1] == y[1] and x[2] < y[2])
	arena.sort_custom(cmp_a)
	var times := {}
	for lv in _db.times:
		var lst: Array = []
		for k in _db.times[lv]:
			lst.append([str(_db.users.get(k, {}).get("name", k)), float(_db.times[lv][k])])
		var cmp_t := func(x, y): return x[1] < y[1]
		lst.sort_custom(cmp_t)
		times[lv] = lst.slice(0, 10)
	_cl_leaderboard.rpc_id(id, {"arena": arena.slice(0, 10), "times": times})

@rpc("any_peer", "call_remote", "reliable")
func _srv_time(level: int, t: float) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _sessions.has(id) or t < 5.0 or level < 0 or level > 20:
		return
	var key: String = _sessions[id].user
	var lv := str(level)
	if not _db.times.has(lv):
		_db.times[lv] = {}
	var prev = _db.times[lv].get(key)
	if prev == null or t < float(prev):
		_db.times[lv][key] = t
		_mark_dirty()

func _on_peer_left(id: int) -> void:
	_kick_from_queue(id)
	var s = _sessions.get(id)
	if s != null and s.has("match"):
		_end_match(s.match, true, id)
	_sessions.erase(id)
