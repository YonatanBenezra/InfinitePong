extends Object
class_name MusicSynth
## Procedural music generator. No asset pipeline yet, so menu and gameplay
## tracks are synthesised at boot as seamless looping AudioStreamWAVs:
## a soft pad, a pulsing bass, and an arpeggio over a chord progression.
## A short head/tail crossfade removes the loop-point click.

const SR := 22050
const XF := 1600   ## loop crossfade length in samples

# Chord = [root, third, fifth] frequencies (Hz).
const AM := [220.0, 261.63, 329.63]
const F  := [174.61, 220.0, 261.63]
const C  := [261.63, 329.63, 392.0]
const G  := [196.0, 246.94, 293.66]
const E  := [164.81, 207.65, 246.94]
const DM := [146.83, 220.0, 293.66]


static func _pack(samples: PackedFloat32Array, loop_end: int) -> AudioStreamWAV:
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
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_end
	stream.data = data
	return stream


## Renders a looping track from a chord progression.
## opts: bar (sec/chord), arp (per-bar note count), pad/bass/arp_gain,
## bright (saw vs sine mix), octave (arp octave shift).
static func build(chords: Array, opts: Dictionary) -> AudioStreamWAV:
	var bar: float = float(opts.get("bar", 2.0))
	var arp_n: int = int(opts.get("arp", 8))
	var pad_g: float = float(opts.get("pad_gain", 0.30))
	var bass_g: float = float(opts.get("bass_gain", 0.42))
	var arp_g: float = float(opts.get("arp_gain", 0.34))
	var bright: float = float(opts.get("bright", 0.5))
	var oct: float = float(opts.get("octave", 2.0))
	var loop_n := int(bar * chords.size() * SR)
	var n := loop_n + XF
	var buf := PackedFloat32Array()
	buf.resize(n)
	var step_dur := bar / float(arp_n)
	for i in n:
		var t := float(i) / SR
		var ci := int(t / bar) % chords.size()
		var chord: Array = chords[ci]
		var local := fmod(t, bar)
		var s := 0.0
		# Sustained pad — gentle attack at the start of each bar.
		var pad_env: float = clampf(local * 3.0, 0.0, 1.0) * clampf((bar - local) * 4.0, 0.0, 1.0)
		for f in chord:
			s += sin(t * float(f) * TAU) * pad_g / float(chord.size()) * pad_env
		# Bass — root an octave down, soft pluck twice per bar.
		var beat := fmod(local, bar * 0.5)
		var be: float = pow(1.0 - clampf(beat / (bar * 0.5), 0.0, 1.0), 1.6)
		var root: float = float(chord[0]) * 0.5
		s += sin(t * root * TAU) * bass_g * be
		# Arpeggio — climbs the chord, octave shifts every cycle.
		var step := int(local / step_dur)
		var note: float = float(chord[step % chord.size()]) * oct
		if (step / chord.size()) % 2 == 1:
			note *= 1.5
		var into := fmod(local, step_dur) / step_dur
		var ne: float = pow(1.0 - into, 1.8) * (1.0 - exp(-into * 40.0))
		var saw: float = fmod(t * note, 1.0) * 2.0 - 1.0
		var sine: float = sin(t * note * TAU)
		s += lerpf(sine, saw, bright) * ne * arp_g
		buf[i] = s
	# Soft-clip then crossfade the rendered tail back over the head.
	for i in n:
		buf[i] = _soft(buf[i])
	var out := PackedFloat32Array()
	out.resize(loop_n)
	for i in loop_n:
		out[i] = buf[i]
	for i in XF:
		var w := float(i) / float(XF)
		out[i] = buf[i] * w + buf[loop_n + i] * (1.0 - w)
	return _pack(out, loop_n)


static func _soft(x: float) -> float:
	return clampf(x - (x * x * x) / 3.0, -1.0, 1.0)
