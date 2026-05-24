extends Object
class_name BallSkinRenderer
## Stateless renderer for ball skins. Both the in-game ball and the menu
## previews call paint(), so a skin looks identical everywhere. Everything
## is drawn centred on the canvas origin; callers position the origin.
##
## paint(canvas, skin, radius, time, rotation)

const O := Vector2.ZERO


static func paint(c: CanvasItem, skin: Dictionary, r: float, t: float, rot: float = 0.0) -> void:
	var core: Color = skin.get("core", Color.WHITE)
	var shell: Color = skin.get("shell", Color(0.5, 0.5, 0.6))
	var glow: Color = skin.get("glow", Color.WHITE)
	var accent: Color = skin.get("accent", Color.WHITE)
	match String(skin.get("style", "solid")):
		"glow": _glow(c, core, shell, glow, accent, r, t)
		"pulse": _pulse(c, core, shell, glow, accent, r, t)
		"crystal": _crystal(c, core, shell, glow, accent, r, t)
		"core": _core(c, core, shell, glow, accent, r, t)
		"cosmic": _cosmic(c, core, shell, glow, accent, r, t, rot)
		"spark": _spark(c, core, shell, glow, accent, r, t)
		"lightning": _lightning(c, core, shell, glow, accent, r, t)
		"halo": _halo(c, core, shell, glow, accent, r, t, rot)
		"retro": _retro(c, core, shell, glow, accent, r, t)
		"gold": _gold(c, core, shell, glow, accent, r, t)
		_: _solid(c, core, shell, glow, accent, r, t)


# --- shared bits ----------------------------------------------------------

static func _aura(c: CanvasItem, glow: Color, r: float, mul: float, alpha: float) -> void:
	var layers := 4
	for i in layers:
		var f := float(i) / float(layers)
		c.draw_circle(O, r * lerpf(mul, 1.0, f),
			Color(glow.r, glow.g, glow.b, alpha * (1.0 - f)))


static func _orb(c: CanvasItem, core: Color, shell: Color, r: float) -> void:
	c.draw_circle(O, r, core)
	c.draw_arc(O, r - 1.0, 0.0, TAU, 36, shell, 2.6, true)


static func _shine(c: CanvasItem, r: float) -> void:
	c.draw_circle(Vector2(-r * 0.30, -r * 0.34), r * 0.30, Color(1, 1, 1, 0.5))


# --- styles ---------------------------------------------------------------

static func _solid(c: CanvasItem, core: Color, shell: Color, glow: Color, _a: Color, r: float, _t: float) -> void:
	_aura(c, glow, r, 1.55, 0.16)
	_orb(c, core, shell, r)
	_shine(c, r)


static func _glow(c: CanvasItem, core: Color, shell: Color, glow: Color, _a: Color, r: float, t: float) -> void:
	var p := 0.5 + 0.5 * sin(t * 3.0)
	_aura(c, glow, r, 1.7 + 0.7 * p, 0.34)
	_orb(c, core, shell, r)
	_shine(c, r)


static func _pulse(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float) -> void:
	var p := 0.5 + 0.5 * sin(t * 4.5)
	_aura(c, glow, r, 1.6 + 0.6 * p, 0.32)
	c.draw_circle(O, r, core.lerp(accent, p))
	c.draw_arc(O, r - 1.0, 0.0, TAU, 36, accent, 2.6, true)
	_shine(c, r)


static func _crystal(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float) -> void:
	_aura(c, glow, r, 1.6, 0.22)
	var pts := PackedVector2Array()
	var sides := 6
	for i in sides:
		var a := t * 0.4 + TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, core)
	for i in sides:
		c.draw_line(O, pts[i], Color(shell.r, shell.g, shell.b, 0.7), 1.6, true)
	# A bright facet that sweeps around.
	var fi := int(t * 1.3) % sides
	c.draw_colored_polygon(PackedVector2Array([O, pts[fi], pts[(fi + 1) % sides]]),
		Color(accent.r, accent.g, accent.b, 0.55))
	for i in sides:
		c.draw_line(pts[i], pts[(i + 1) % sides], accent, 2.2, true)


static func _core(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float) -> void:
	var p := 0.5 + 0.5 * sin(t * 5.0)
	_aura(c, glow, r, 1.9 + 0.5 * p, 0.34)
	c.draw_circle(O, r, Color(shell.r, shell.g, shell.b, 0.85))
	c.draw_circle(O, r * 0.72, core)
	c.draw_circle(O, r * (0.34 + 0.12 * p), Color(1, 1, 1, 0.92).lerp(accent, 0.4))
	c.draw_arc(O, r - 1.0, 0.0, TAU, 36, accent, 2.0, true)


static func _cosmic(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float, rot: float) -> void:
	_aura(c, glow, r, 1.7, 0.26)
	c.draw_circle(O, r, core)
	# Spiral arms.
	for arm in 2:
		var pts := PackedVector2Array()
		for k in 14:
			var f := float(k) / 13.0
			var a := rot * 1.4 + arm * PI + f * 3.0
			pts.append(Vector2(cos(a), sin(a)) * (r * 0.92 * f))
		c.draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.7), 2.0, true)
	# Stars.
	for i in 7:
		var sa := rot * 0.6 + i * 2.39996
		var sr := r * (0.2 + 0.66 * fmod(float(i) * 0.37, 1.0))
		var tw := 0.5 + 0.5 * sin(t * 3.0 + float(i))
		c.draw_circle(Vector2(cos(sa), sin(sa)) * sr, 1.3 + tw * 1.0,
			Color(1, 1, 1, 0.5 + 0.4 * tw))
	c.draw_arc(O, r - 1.0, 0.0, TAU, 36, shell, 2.4, true)


static func _spark(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float) -> void:
	_aura(c, glow, r, 1.8, 0.30)
	for i in 5:
		var a := t * 2.2 + TAU * float(i) / 5.0
		var pos := Vector2(cos(a), sin(a)) * r * 1.55
		c.draw_circle(pos, r * 0.20, Color(glow.r, glow.g, glow.b, 0.4))
		c.draw_circle(pos, r * 0.11, accent)
	_orb(c, core, shell, r)
	_shine(c, r)


static func _lightning(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float) -> void:
	_aura(c, glow, r, 1.55, 0.24)
	_orb(c, core, shell, r)
	for i in 4:
		if sin(t * 9.0 + float(i) * 1.7) < 0.15:
			continue
		var base := TAU * float(i) / 4.0 + sin(t * 2.0 + i) * 0.4
		var pts := PackedVector2Array()
		for k in 4:
			var f := float(k) / 3.0
			var off := 0.0 if k == 0 or k == 3 else sin(t * 30.0 + k * 5.0 + i) * r * 0.4
			var dir := Vector2(cos(base), sin(base))
			var perp := Vector2(-dir.y, dir.x)
			pts.append(dir * (r * 0.4 + f * r * 1.7) + perp * off)
		c.draw_polyline(pts, accent, 2.2, true)
	_shine(c, r)


static func _halo(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float, rot: float) -> void:
	_aura(c, glow, r, 1.7, 0.26)
	# Tilted ring behind.
	var ring := PackedVector2Array()
	for k in 40:
		var a := rot + TAU * float(k) / 40.0
		ring.append(Vector2(cos(a) * r * 1.95, sin(a) * r * 0.66))
	ring.append(ring[0])
	c.draw_polyline(ring, Color(accent.r, accent.g, accent.b, 0.85), 2.6, true)
	_orb(c, core, shell, r)
	_shine(c, r)
	# Sparkle on the ring.
	var sa := rot * 2.0
	c.draw_circle(Vector2(cos(sa) * r * 1.95, sin(sa) * r * 0.66), 2.6 + sin(t * 6.0), Color(1, 1, 1, 0.9))


static func _retro(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float) -> void:
	_aura(c, glow, r, 1.4, 0.16)
	# Chunky octagon body.
	var oct := PackedVector2Array()
	for i in 8:
		var a := PI / 8.0 + TAU * float(i) / 8.0
		oct.append(Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(oct, core)
	# Lower half tint.
	c.draw_colored_polygon(PackedVector2Array([
		oct[5], oct[6], oct[7], oct[0]]), shell)
	# Pixel highlights.
	var px := r * 0.34
	c.draw_rect(Rect2(-r * 0.55, -r * 0.55, px, px), accent)
	c.draw_rect(Rect2(r * 0.2, -r * 0.18, px * 0.7, px * 0.7), Color(1, 1, 1, 0.8))
	for i in 8:
		c.draw_line(oct[i], oct[(i + 1) % 8], Color(0.05, 0.05, 0.09), 2.4, true)


static func _gold(c: CanvasItem, core: Color, shell: Color, glow: Color, accent: Color, r: float, t: float) -> void:
	_aura(c, glow, r, 1.7, 0.28)
	c.draw_circle(O, r, core)
	# Bottom metallic shading.
	c.draw_circle(Vector2(0, r * 0.4), r * 0.8, Color(shell.r, shell.g, shell.b, 0.5))
	c.draw_circle(O, r * 0.96, Color(core.r, core.g, core.b, 0.0))
	# Moving shine streak.
	var sx := sin(t * 1.6) * r * 0.4
	c.draw_circle(Vector2(sx - r * 0.2, -r * 0.32), r * 0.26, Color(1, 1, 1, 0.7))
	c.draw_arc(O, r - 1.0, 0.0, TAU, 40, accent, 3.0, true)
