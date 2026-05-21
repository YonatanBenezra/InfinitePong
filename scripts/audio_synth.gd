extends Object
class_name AudioSynth
## Procedural sound generator. We have no asset pipeline yet, so we
## synthesize short PCM blips at runtime and feed them to AudioStreamPlayers.
## Output is 16-bit mono WAV at 22050 Hz — small, instant, no import step.

const SR: int = 22050


static func _pack(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := clampf(samples[i], -1.0, 1.0)
		var s16 := int(s * 32767.0)
		if s16 < 0:
			s16 += 65536
		data[i * 2] = s16 & 0xff
		data[i * 2 + 1] = (s16 >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SR
	stream.stereo = false
	stream.data = data
	return stream


static func flip_sound() -> AudioStreamWAV:
	# Short upward chirp — feels like a quick pinball click.
	var dur := 0.085
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var freq := lerpf(420.0, 880.0, u)
		var env := pow(1.0 - u, 0.4) * (1.0 - exp(-u * 60.0))
		var saw := fmod(t * freq, 1.0) * 2.0 - 1.0
		var sine := sin(t * freq * TAU)
		s[i] = (saw * 0.35 + sine * 0.65) * env * 0.45
	return _pack(s)


static func hit_sound() -> AudioStreamWAV:
	# Low thud + noise burst — punchy ball impact.
	var dur := 0.10
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var env := pow(1.0 - u, 1.8)
		var noise := rng.randf() * 2.0 - 1.0
		var thud := sin(t * lerpf(180.0, 90.0, u) * TAU)
		s[i] = (noise * 0.35 + thud * 0.70) * env * 0.55
	return _pack(s)


static func death_sound() -> AudioStreamWAV:
	# Descending square-wave wail.
	var dur := 0.55
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var freq := lerpf(520.0, 90.0, pow(u, 0.6))
		var env := pow(1.0 - u, 0.7) * (1.0 - exp(-u * 30.0))
		var square := signf(sin(t * freq * TAU))
		var sine := sin(t * freq * TAU)
		s[i] = (square * 0.4 + sine * 0.6) * env * 0.35
	return _pack(s)


static func win_sound() -> AudioStreamWAV:
	# Triumphant arpeggio C5 -> E5 -> G5 -> C6.
	var notes := [523.25, 659.25, 783.99, 1046.50]
	var per_note := 0.13
	var dur: float = per_note * float(notes.size())
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		var idx := int(t / per_note)
		idx = clampi(idx, 0, notes.size() - 1)
		var freq: float = notes[idx]
		var nt := fmod(t, per_note) / per_note
		var note_env := pow(1.0 - nt, 0.5) * (1.0 - exp(-nt * 60.0))
		var overall := pow(1.0 - t / dur, 0.25)
		var sine := sin(t * freq * TAU)
		var third := sin(t * freq * 1.5 * TAU) * 0.3
		s[i] = (sine + third) * note_env * overall * 0.32
	return _pack(s)
