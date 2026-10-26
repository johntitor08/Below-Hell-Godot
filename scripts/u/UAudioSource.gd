class_name UAudioSource
extends Mono

var player: AudioStreamPlayer
var oneshot: AudioStreamPlayer
var _clip: UClip
var _volume := 1.0
var _pitch := 1.0
var loop := false
var playOnAwake := true
var _mute := false
var _paused := false

var clip: UClip:
	get:
		return _clip
	set(v):
		_clip = v
		if player != null:
			player.stream = v.stream if v != null else null

var volume: float:
	get:
		return _volume
	set(v):
		_volume = clampf(v, 0.0, 1.0)
		_apply_volume()

var pitch: float:
	get:
		return _pitch
	set(v):
		_pitch = v
		if player != null:
			player.pitch_scale = maxf(0.01, v)

var mute: bool:
	get:
		return _mute
	set(v):
		_mute = v
		_apply_volume()

var isPlaying: bool:
	get:
		return player != null and player.playing

var time: float:
	get:
		return player.get_playback_position() if player != null and player.playing else 0.0
	set(v):
		if player != null and player.playing:
			player.seek(v)

func _on_injected(root: Node) -> void:
	_clip = DB.conv(u.get("m_audioClip"), root)
	_volume = float(u.get("m_Volume", 1))
	_pitch = float(u.get("m_Pitch", 1))
	loop = int(u.get("Loop", 0)) != 0
	playOnAwake = int(u.get("m_PlayOnAwake", 1)) != 0
	_mute = int(u.get("Mute", 0)) != 0

func _ensure() -> void:
	if player != null:
		return
	player = AudioStreamPlayer.new()
	player.name = "_player"
	add_child(player)
	player.finished.connect(_on_finished)
	oneshot = AudioStreamPlayer.new()
	oneshot.name = "_oneshot"
	oneshot.max_polyphony = 8
	add_child(oneshot)
	player.stream = _clip.stream if _clip != null else null
	player.pitch_scale = maxf(0.01, _pitch)
	_apply_volume()

func _ready() -> void:
	super._ready()
	_ensure()

func Awake() -> void:
	_ensure()

func OnEnable() -> void:
	if playOnAwake and _clip != null:
		Play()

func OnDisable() -> void:
	if player != null:
		player.stop()

func _apply_volume() -> void:
	if player != null:
		player.volume_db = linear_to_db(maxf(0.0001, 0.0 if _mute else _volume))

func _on_finished() -> void:
	if loop and player != null and not _paused:
		player.play()

func Play() -> void:
	_ensure()
	if _clip == null:
		return
	player.stream = _clip.stream
	_paused = false
	player.play()

func Stop() -> void:
	if player != null:
		_paused = false
		player.stop()

func Pause() -> void:
	if player != null:
		_paused = true
		player.stream_paused = true

func UnPause() -> void:
	if player != null:
		_paused = false
		player.stream_paused = false

func PlayOneShot(c: UClip, volume_scale := 1.0) -> void:
	_ensure()
	if c == null or c.stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = c.stream
	p.volume_db = linear_to_db(maxf(0.0001, (0.0 if _mute else _volume) * volume_scale))
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

static func PlayClipAtPoint(c: UClip, _pos = null, vol := 1.0) -> void:
	if c == null or c.stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = c.stream
	p.volume_db = linear_to_db(maxf(0.0001, vol))
	U.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
