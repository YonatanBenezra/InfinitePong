extends Node
## Autoload: single entry point for all screen changes, with a fade wipe.
##
## Every screen calls SceneRouter.goto(SceneRouter.MENU) etc. The router
## owns a top-most CanvasLayer fade rect so transitions are consistent and
## never flicker. It also carries a small `payload` dictionary so one
## screen can hand context to the next (e.g. Level Select -> game).

const BOOT := "res://scenes/ui/splash.tscn"
const MENU := "res://scenes/ui/main_menu.tscn"
const GAME := "res://scenes/main.tscn"
const LEVEL_SELECT := "res://scenes/ui/level_select.tscn"
const RESULTS := "res://scenes/ui/results.tscn"
const SETTINGS := "res://scenes/ui/settings.tscn"
const STATS := "res://scenes/ui/stats.tscn"
const BALL_SKINS := "res://scenes/ui/ball_skins.tscn"
const ACHIEVEMENTS := "res://scenes/ui/achievements.tscn"

const FADE_TIME := 0.32

## Context passed from the previous screen to the next. Read once, then the
## receiving screen may clear it. Example keys: "start_level", "result".
var payload: Dictionary = {}

var _fade: ColorRect
var _layer: CanvasLayer
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.06, 1.0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_layer.add_child(_fade)


## Fade out, swap scene, fade back in. Safe to call from any screen.
func goto(scene_path: String, with_payload: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	payload = with_payload
	get_tree().paused = false
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await t.finished
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: failed to load %s (err %d)" % [scene_path, err])
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await t2.finished
	_busy = false


func take_payload() -> Dictionary:
	var p := payload
	payload = {}
	return p
