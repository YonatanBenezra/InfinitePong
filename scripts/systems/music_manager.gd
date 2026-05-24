extends Node
## Autoload: background music with crossfades and difficulty-driven intensity.
##
## Two synthesised loops (menu, gameplay) sit on the "Music" bus. Switching
## context crossfades between two players so there is never a hard cut.
## During gameplay, intensity (0..1, from Worlds) lifts the gameplay loop's
## volume and tempo so deeper levels feel more urgent.

var _menu_stream: AudioStreamWAV
var _game_stream: AudioStreamWAV
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _mode: String = "none"          ## "menu" | "game" | "none"
var _intensity: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _make_player()
	_b = _make_player()
	_active = _a
	call_deferred("_synthesize")


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	p.volume_db = -60.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _synthesize() -> void:
	_menu_stream = MusicSynth.build(
		[MusicSynth.AM, MusicSynth.F, MusicSynth.C, MusicSynth.G],
		{"bar": 2.4, "arp": 8, "bright": 0.22, "pad_gain": 0.34,
		 "bass_gain": 0.34, "arp_gain": 0.28, "octave": 2.0})
	_game_stream = MusicSynth.build(
		[MusicSynth.AM, MusicSynth.F, MusicSynth.C, MusicSynth.E],
		{"bar": 1.6, "arp": 16, "bright": 0.6, "pad_gain": 0.24,
		 "bass_gain": 0.46, "arp_gain": 0.34, "octave": 2.0})
	if _mode == "menu":
		play_menu()
	elif _mode == "game":
		_start_game()


func play_menu() -> void:
	_mode = "menu"
	if _menu_stream == null:
		return
	_crossfade_to(_menu_stream, -6.0, 1.0)


func play_gameplay(level: int = 1) -> void:
	_mode = "game"
	_intensity = Worlds.music_intensity_for_level(level)
	if _game_stream == null:
		return
	_start_game()


func _start_game() -> void:
	var target := lerpf(-9.0, -3.0, _intensity)
	_crossfade_to(_game_stream, target, lerpf(1.0, 1.09, _intensity))


## Updates intensity mid-session (e.g. on level advance) without a restart.
func set_level(level: int) -> void:
	if _mode != "game":
		return
	_intensity = Worlds.music_intensity_for_level(level)
	var target := lerpf(-9.0, -3.0, _intensity)
	create_tween().tween_property(_active, "volume_db", target, 0.8)
	create_tween().tween_property(_active, "pitch_scale", lerpf(1.0, 1.09, _intensity), 0.8)


func stop() -> void:
	_mode = "none"
	for p in [_a, _b]:
		create_tween().tween_property(p, "volume_db", -60.0, 0.6)


## Swaps the inactive player onto `stream` and crossfades the pair.
func _crossfade_to(stream: AudioStreamWAV, target_db: float, pitch: float) -> void:
	var incoming: AudioStreamPlayer = _b if _active == _a else _a
	var outgoing := _active
	incoming.stream = stream
	incoming.pitch_scale = pitch
	incoming.volume_db = -60.0
	incoming.play()
	create_tween().tween_property(incoming, "volume_db", target_db, 1.1)
	if outgoing.playing:
		var t := create_tween()
		t.tween_property(outgoing, "volume_db", -60.0, 1.1)
		t.tween_callback(outgoing.stop)
	_active = incoming
