extends Node2D
## Calm, static in-game background: just a world-themed vertical gradient,
## intentionally quiet so the level geometry and ball are always the clear
## focus. No grid, no motion — nothing competes with gameplay.

var _w: float = 640.0
var _h: float = 720.0
var _theme: Dictionary = {}


func _ready() -> void:
	var vp := get_viewport_rect().size
	_w = vp.x
	_h = vp.y
	if _theme.is_empty():
		_theme = Worlds.world(Profile.highest_world_unlocked)
	queue_redraw()


func apply_world(world: Dictionary) -> void:
	_theme = world
	queue_redraw()


func _draw() -> void:
	# Darkened world gradient — keeps the neon level geometry popping.
	var top: Color = _theme.get("bg_top", UITheme.BG_TOP)
	var bot: Color = _theme.get("bg_bottom", UITheme.BG_BOTTOM)
	top = top.darkened(0.30)
	bot = bot.darkened(0.45)
	var bands := 40
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0.0, _h * float(i) / bands, _w, _h / bands + 2.0),
			top.lerp(bot, t))
