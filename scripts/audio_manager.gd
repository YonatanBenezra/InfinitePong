class_name AudioManager
extends Node

@onready var flipper_player: AudioStreamPlayer = $FlipperPlayer
@onready var impact_player: AudioStreamPlayer = $ImpactPlayer
@onready var death_player: AudioStreamPlayer = $DeathPlayer
@onready var complete_player: AudioStreamPlayer = $CompletePlayer

var _impact_ready: bool = true


func _ready() -> void:
	flipper_player.stream = _make_tone(440.0, 0.06)
	impact_player.stream = _make_tone(220.0, 0.05)
	death_player.stream = _make_tone(110.0, 0.2)
	complete_player.stream = _make_tone(660.0, 0.15)


func play_flipper() -> void:
	_play(flipper_player)


func play_impact() -> void:
	if not _impact_ready:
		return
	_impact_ready = false
	_play(impact_player)
	get_tree().create_timer(0.07).timeout.connect(func(): _impact_ready = true)


func play_death() -> void:
	_play(death_player)


func play_complete() -> void:
	_play(complete_player)


func _play(player: AudioStreamPlayer) -> void:
	player.stop()
	player.play()


func _make_tone(freq: float, duration: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var env := 1.0 - (float(i) / float(sample_count))
		var sample := int(clampf(sin(TAU * freq * t) * 32767.0 * env, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
