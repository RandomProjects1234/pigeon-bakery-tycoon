extends Node
## Sound bank. Every sound is a WAV synthesised by tools/gen_audio.py.
## Registered as the "Sfx" autoload.

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _idx := 0
var _music: AudioStreamPlayer
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.volume_db = -9.0


func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var path := "res://assets/sfx/%s.wav" % sound
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
		if sound.ends_with("_loop") and st is AudioStreamWAV:
			var w := st as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	_cache[sound] = st
	return st


## Fire-and-forget. `min_gap` stops the same sound machine-gunning.
func play(sound: String, vol_db := 0.0, pitch := 1.0, min_gap := 0.03) -> void:
	if not bool(Game.settings.get("sfx", true)):
		return
	if Game.test_mode() and DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sound, -1.0)) < min_gap:
		return
	_last_play[sound] = now
	var st := stream(sound)
	if st == null:
		return
	var p := _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.2, 4.0)
	p.play()


func play_rand(sound: String, vol_db := 0.0, spread := 0.08) -> void:
	play(sound, vol_db, randf_range(1.0 - spread, 1.0 + spread))


func coo(vol_db := -6.0) -> void:
	play("coo%d" % randi_range(1, 3), vol_db, randf_range(0.85, 1.2), 0.25)


func set_music(on: bool) -> void:
	if on:
		if not _music.playing:
			_music.stream = stream("music_loop")
			_music.play()
	else:
		_music.stop()


func refresh_music() -> void:
	set_music(bool(Game.settings.get("music", true)) and not Game.test_mode())
