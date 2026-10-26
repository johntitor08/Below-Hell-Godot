extends Node

const SFX := {
	"click": "res://assets/sfx/Click.wav", "hover": "res://assets/sfx/ButtonHover.wav", "press": "res://assets/sfx/ButtonPress.wav",
	"bonus": "res://assets/sfx/Bonus.wav", "hit": "res://assets/sfx/Hit.wav", "explosion": "res://assets/sfx/Explosion.wav",
	"death": "res://assets/sfx/DeathVoice.wav", "grunt1": "res://assets/sfx/GruntVoice01.wav", "grunt2": "res://assets/sfx/GruntVoice02.wav",
	"land": "res://assets/sfx/LandingFootsteps.wav", "countdown": "res://assets/sfx/RespawnCountdown.wav", "shot": "res://assets/sfx/Shot.wav",
	"spawn": "res://assets/sfx/Spawn.wav", "whoosh": "res://assets/sfx/Whoosh.wav", "gameover": "res://assets/sfx/GameOver.wav",
}
const MUSIC := {
	"menu": "res://assets/music/under the rainbow.ogg", "level": "res://assets/music/up_and_right.ogg",
	"level2": "res://assets/music/hurry_up_and_run.mp3", "arena": "res://assets/music/Maniac.ogg", "boss": "res://assets/music/Hurt_and_heart.ogg",
}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music_a = _make_music()
	_music_b = _make_music()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

func _make_music() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p

func set_volumes(master: float, music: float, sfx: float) -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)

func _set_bus(n: String, v: float) -> void:
	var i := AudioServer.get_bus_index(n)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

func music(key: String, fade := 1.0) -> void:
	if key == _current:
		return
	_current = key
	var path: String = MUSIC.get(key, "")
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if path != "":
		var st := _stream(path)
		if st is AudioStreamOggVorbis or st is AudioStreamMP3:
			st.loop = true
		_music_a.stream = st
		_music_a.volume_db = -40.0
		_music_a.play()
		_tween.tween_property(_music_a, "volume_db", 0.0, fade)
	_tween.tween_property(_music_b, "volume_db", -40.0, fade)
	_tween.chain().tween_callback(_music_b.stop)

func play(key: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	var path: String = SFX.get(key, key)
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[0]
	p.stream = _stream(path)
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
