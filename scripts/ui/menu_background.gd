extends Node2D
## Premium animated background shared by every menu screen.
##
## A synthwave neon grid recedes to a glowing horizon while a soft starfield
## drifts above it — clean, intentional motion, fully themed to the current
## world. No random shapes: it supports foreground readability rather than
## competing with it. game_background.gd extends this at a lower intensity.

const H_RATIO := 0.58          ## horizon as a fraction of viewport height
const GRID_COLS := 8           ## vertical lines each side of centre
const GRID_ROWS := 16          ## receding horizontal lines
const SCROLL_SPEED := 0.10     ## grid rows advanced per second
const STAR_COUNT := 70

@export var intensity: float = 1.0

var _w: float = 640.0
var _h: float = 720.0
var _theme: Dictionary = {}
var _stars: Array[Dictionary] = []
var _scroll: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	var vp := get_viewport_rect().size
	_w = vp.x
	_h = vp.y
	if _theme.is_empty():
		_theme = Worlds.world(Profile.highest_world_unlocked)
	var horizon := _h * H_RATIO
	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(randf_range(0.0, _w), randf_range(0.0, horizon)),
			"r": randf_range(0.6, 2.0),
			"speed": randf_range(2.0, 9.0),
			"phase": randf() * TAU,
			"depth": randf(),
		})
	set_process(true)


func apply_world(world: Dictionary) -> void:
	_theme = world
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_scroll = fmod(_scroll + SCROLL_SPEED * delta, 1.0)
	var horizon := _h * H_RATIO
	for s in _stars:
		var p: Vector2 = s["pos"]
		p.y += float(s["speed"]) * delta * 0.5
		if p.y > horizon:
			p = Vector2(randf_range(0.0, _w), 0.0)
		s["pos"] = p
	queue_redraw()


func _draw() -> void:
	var top: Color = _theme.get("bg_top", UITheme.BG_TOP)
	var bot: Color = _theme.get("bg_bottom", UITheme.BG_BOTTOM)
	var accent: Color = _theme.get("accent", UITheme.accent)
	var horizon := _h * H_RATIO
	var vp := Vector2(_w * 0.5, horizon)

	# --- Sky gradient ---
	var bands := 32
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0.0, _h * float(i) / bands, _w, _h / bands + 2.0),
			top.lerp(bot, t))

	# --- Starfield (above horizon) ---
	for s in _stars:
		var tw: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * 2.2 + float(s["phase"])))
		var a: float = (0.25 + 0.55 * float(s["depth"])) * tw * intensity
		draw_circle(s["pos"], float(s["r"]), Color(0.92, 0.95, 1.0, a))

	# --- Horizon bloom ---
	var glow_steps := 9
	for i in glow_steps:
		var gt := float(i) / float(glow_steps)
		var gr := lerpf(150.0, 30.0, gt)
		draw_circle(vp, gr, Color(accent.r, accent.g, accent.b, 0.05 * intensity))
	draw_line(Vector2(0, horizon), Vector2(_w, horizon),
		Color(accent.r, accent.g, accent.b, 0.55 * intensity), 2.0, true)

	# --- Receding grid (below horizon) ---
	var floor_h := _h - horizon
	# Vertical lines fan out from the vanishing point.
	for c in range(-GRID_COLS, GRID_COLS + 1):
		var spread := _w * 1.9 / float(GRID_COLS * 2)
		var bottom := Vector2(_w * 0.5 + c * spread, _h)
		var fade := 1.0 - absf(float(c)) / float(GRID_COLS + 1)
		draw_line(vp, bottom,
			Color(accent.r, accent.g, accent.b, 0.10 + 0.22 * fade * intensity),
			1.5, true)
	# Horizontal lines scroll toward the viewer with perspective spacing.
	for r in GRID_ROWS:
		var d := fmod(float(r) / GRID_ROWS + _scroll, 1.0)
		var y := horizon + floor_h * pow(d, 2.4)
		var a := pow(d, 0.6) * 0.40 * intensity
		draw_line(Vector2(0, y), Vector2(_w, y),
			Color(accent.r, accent.g, accent.b, a), 1.0 + d * 1.6, true)
