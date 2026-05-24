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


static func hazard_sound() -> AudioStreamWAV:
	# Sharp, metallic stinger for spike contact — distinct from the longer
	# death wail and the soft ball-impact thud. Short and bright.
	var dur := 0.13
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var env := pow(1.0 - u, 1.2) * (1.0 - exp(-u * 90.0))
		var clang := sin(t * lerpf(1850.0, 760.0, u) * TAU)
		var harm := sin(t * lerpf(2620.0, 1280.0, u) * TAU) * 0.5
		var grit := (rng.randf() * 2.0 - 1.0) * 0.18
		s[i] = (clang * 0.55 + harm * 0.3 + grit) * env * 0.5
	return _pack(s)


static func ricochet_sound() -> AudioStreamWAV:
	# Brief upward zing for high-energy wall ricochets — telegraphs that
	# the ball just kept a lot of momentum off a surface.
	var dur := 0.075
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var freq := lerpf(1100.0, 2600.0, pow(u, 0.7))
		var env := pow(1.0 - u, 0.9) * (1.0 - exp(-u * 120.0))
		var sine := sin(t * freq * TAU)
		var detune := sin(t * freq * 1.01 * TAU) * 0.4
		s[i] = (sine + detune) * env * 0.4
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


static func ui_hover_sound() -> AudioStreamWAV:
	# Soft, short, high tick for menu hover/focus.
	var dur := 0.045
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var env := pow(1.0 - u, 1.4) * (1.0 - exp(-u * 120.0))
		var sine := sin(t * 1320.0 * TAU)
		s[i] = sine * env * 0.22
	return _pack(s)


static func ui_click_sound() -> AudioStreamWAV:
	# Crisp confirming click for menu button presses.
	var dur := 0.10
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var freq := lerpf(660.0, 990.0, pow(u, 0.5))
		var env := pow(1.0 - u, 1.1) * (1.0 - exp(-u * 90.0))
		var sine := sin(t * freq * TAU)
		var sub := sin(t * freq * 0.5 * TAU) * 0.4
		s[i] = (sine + sub) * env * 0.30
	return _pack(s)


static func ui_back_sound() -> AudioStreamWAV:
	# Descending tick for back / cancel.
	var dur := 0.09
	var n := int(dur * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(SR)
		var u := t / dur
		var freq := lerpf(720.0, 420.0, pow(u, 0.6))
		var env := pow(1.0 - u, 1.2) * (1.0 - exp(-u * 100.0))
		s[i] = sin(t * freq * TAU) * env * 0.26
	return _pack(s)
