extends Node2D
## Main gameplay controller: procedural build, ball spawn, run lifecycle,
## results, pause, theming and feel.
##
## Flow is driven by an explicit state machine (PLAYING / RESULTS / PAUSED)
## so restart can never soft-lock: the Retry button and the R key both route
## through the same _restart_level() regardless of state.

enum State { PLAYING, RESULTS, PAUSED }

@export var ball_scene: PackedScene
@export var chunk_generator_path: NodePath = NodePath("ChunkGenerator")
@export var ball_fall_grace_y: float = 600.0
@export var spawn_invuln_seconds: float = 0.35
## Several flippers in a chunk fire on one key press; this gates both the
## flipper cue and the flipper counter so one press counts once.
@export var flipper_sfx_cooldown: float = 0.09

@onready var _world: Node2D = $World
@onready var _camera: Camera2D = $Camera2D
@onready var _canvas: CanvasLayer = $CanvasLayer
@onready var _vignette: ColorRect = $CanvasLayer/Vignette
@onready var _sfx_flip: AudioStreamPlayer = $SfxFlip
@onready var _sfx_hit: AudioStreamPlayer = $SfxHit
@onready var _sfx_death: AudioStreamPlayer = $SfxDeath
@onready var _sfx_win: AudioStreamPlayer = $SfxWin
@onready var _sfx_hazard: AudioStreamPlayer = $SfxHazard
@onready var _sfx_ricochet: AudioStreamPlayer = $SfxRicochet

var _ball: RigidBody2D
var _generator: ChunkGenerator
var _rng := RandomNumberGenerator.new()
var _state: State = State.PLAYING
var _level_top_y: float = 0.0
var _level_bottom_y: float = 0.0
var _invuln_until: float = 0.0
var _best_depth_pct: float = 0.0
var _last_flip_sfx: float = -1.0
var _level_index: int = 1
var _level_seed: int = 0
var _world_def: Dictionary = {}
var _bg: Node2D
var _results: Control
var _pause_menu: Control
var _results_primary: Callable

# HUD nodes (built procedurally).
var _hud_world: Label
var _hud_level: Label
var _hud_track: Panel
var _hud_depth_fill: ColorRect
var _hud_depth_label: Label
var _hud_time: Label
var _hud_deaths: Label
var _fps_label: Label
var _banner: Label
var _hint: Label

# --- Per-run metrics ---
var _run_time: float = 0.0
var _run_flippers: int = 0
var _run_distance: float = 0.0
var _deaths_this_level: int = 0
var _prev_ball_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_level_seed = randi()
	var payload := SceneRouter.take_payload()
	_level_index = maxi(int(payload.get("start_level", 1)), 1)
	_generator = get_node(chunk_generator_path) as ChunkGenerator

	GameEvents.player_died.connect(_on_player_died)
	GameEvents.level_completed.connect(_on_level_completed)
	GameEvents.ball_hit.connect(_on_ball_hit)
	GameEvents.ball_ricochet.connect(_on_ball_ricochet)
	GameEvents.flipper_fired.connect(_on_flipper_fired)
	GameEvents.hazard_hit.connect(_on_hazard_hit)

	if _vignette:
		_vignette.modulate = Color(1, 1, 1, 0)
	_setup_background()
	_setup_audio()
	_setup_hud()
	_spawn_ball_if_needed()
	_regenerate_level(false)
	MusicManager.play_gameplay(_level_index)


func _setup_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	_bg = Node2D.new()
	_bg.set_script(load("res://scripts/ui/game_background.gd"))
	layer.add_child(_bg)


func _setup_audio() -> void:
	var have_sfx := AudioServer.get_bus_index("Sfx") >= 0
	for entry in [
		[_sfx_flip, AudioSynth.flip_sound(), -6.0],
		[_sfx_hit, AudioSynth.hit_sound(), -10.0],
		[_sfx_death, AudioSynth.death_sound(), -4.0],
		[_sfx_win, AudioSynth.win_sound(), -2.0],
		[_sfx_hazard, AudioSynth.hazard_sound(), -5.0],
		[_sfx_ricochet, AudioSynth.ricochet_sound(), -8.0],
	]:
		var player: AudioStreamPlayer = entry[0]
		if player:
			player.stream = entry[1]
			player.volume_db = entry[2]
			if have_sfx:
				player.bus = "Sfx"


# --- HUD ------------------------------------------------------------------

func _setup_hud() -> void:
	var bar := PanelContainer.new()
	bar.anchor_right = 1.0
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.04, 0.05, 0.09, 0.82)
	bar_style.border_width_bottom = 2
	bar_style.border_color = Color(1, 1, 1, 0.08)
	bar_style.content_margin_left = 16
	bar_style.content_margin_right = 16
	bar_style.content_margin_top = 8
	bar_style.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)

	# Left: world + level.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.custom_minimum_size = Vector2(120, 0)
	row.add_child(left)
	_hud_world = _hud_label("", 11, UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_level = _hud_label("", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(_hud_world)
	left.add_child(_hud_level)

	# Centre: depth bar.
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 3)
	row.add_child(center)
	_hud_depth_label = _hud_label("DEPTH 0%", 12, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_hud_depth_label)
	_hud_track = Panel.new()
	_hud_track.custom_minimum_size = Vector2(0, 10)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0, 0, 0, 0.5)
	track_style.set_corner_radius_all(5)
	_hud_track.add_theme_stylebox_override("panel", track_style)
	center.add_child(_hud_track)
	_hud_depth_fill = ColorRect.new()
	_hud_depth_fill.anchor_bottom = 1.0
	_hud_depth_fill.offset_left = 1.0
	_hud_depth_fill.offset_top = 1.0
	_hud_depth_fill.offset_bottom = -1.0
	_hud_depth_fill.color = UITheme.accent
	_hud_track.add_child(_hud_depth_fill)

	# Right: time + deaths.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.custom_minimum_size = Vector2(120, 0)
	row.add_child(right)
	_hud_time = _hud_label("0:00", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_deaths = _hud_label("DEATHS 0", 11, UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_hud_time)
	right.add_child(_hud_deaths)

	# FPS readout.
	_fps_label = _hud_label("", 12, Color(0.55, 0.9, 0.65), HORIZONTAL_ALIGNMENT_LEFT)
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_left = 8
	_fps_label.offset_top = -22
	_fps_label.offset_bottom = -4
	_fps_label.visible = GameSettings.show_fps
	_canvas.add_child(_fps_label)

	# Centre level banner (fades on each level start).
	_banner = UITheme.make_title("", 40)
	_banner.anchor_right = 1.0
	_banner.anchor_bottom = 0.5
	_banner.offset_top = 150
	_banner.modulate.a = 0.0
	_canvas.add_child(_banner)

	# Controls hint along the bottom — fades out after each level start.
	_hint = _hud_label(
		"Hold  SPACE / CLICK  Flippers      R  Retry      ESC  Pause",
		13, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -42
	_hint.offset_bottom = -16
	_hint.modulate.a = 0.0
	_canvas.add_child(_hint)


func _hud_label(text: String, size: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	return l


func _process(delta: float) -> void:
	if _vignette and _vignette.modulate.a > 0.0:
		_vignette.modulate.a = maxf(_vignette.modulate.a - delta * 1.6, 0.0)
	if _fps_label and _fps_label.visible:
		_fps_label.text = "%d FPS" % int(Engine.get_frames_per_second())
	_update_hud()
	if _state != State.PLAYING or get_tree().paused:
		return
	_run_time += delta
	if is_instance_valid(_ball):
		_run_distance += _ball.global_position.distance_to(_prev_ball_pos)
		_prev_ball_pos = _ball.global_position
		if _ball.global_position.y > _level_bottom_y + ball_fall_grace_y:
			GameEvents.player_died.emit()


func _update_hud() -> void:
	if _hud_depth_fill == null:
		return
	var pct := 0.0
	if is_instance_valid(_ball) and _level_bottom_y > _level_top_y:
		pct = clampf((_ball.global_position.y - _level_top_y) /
			(_level_bottom_y - _level_top_y), 0.0, 1.0)
	_best_depth_pct = maxf(_best_depth_pct, pct)
	var track_w: float = _hud_track.size.x - 2.0
	_hud_depth_fill.size.x = maxf(track_w * pct, 0.0)
	var accent: Color = _world_def.get("accent", UITheme.accent)
	_hud_depth_fill.color = accent
	_hud_depth_label.text = "DEPTH %d%%" % int(pct * 100.0)
	_hud_time.text = _format_time(_run_time)
	_hud_deaths.text = "DEATHS %d" % _deaths_this_level


func _format_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


# --- Input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match _state:
			State.PLAYING:
				_open_pause()
			State.PAUSED:
				_close_pause()
			State.RESULTS:
				_go_to_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart"):
		match _state:
			State.PLAYING:
				_restart_level()
			State.RESULTS:
				if _results_primary.is_valid():
					_results_primary.call()
		get_viewport().set_input_as_handled()


# --- Pause ---------------------------------------------------------------

func _open_pause() -> void:
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	get_tree().paused = true
	_pause_menu = Control.new()
	_pause_menu.set_script(load("res://scripts/ui/pause_menu.gd"))
	_canvas.add_child(_pause_menu)
	_pause_menu.call("setup",
		Callable(self, "_close_pause"),
		Callable(self, "_pause_restart"),
		Callable(self, "_go_to_menu"))


func _close_pause() -> void:
	get_tree().paused = false
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
		_pause_menu = null
	if _state == State.PAUSED:
		_state = State.PLAYING


func _pause_restart() -> void:
	_close_pause()
	_restart_level()


func _go_to_menu() -> void:
	get_tree().paused = false
	MusicManager.play_menu()
	SceneRouter.goto(SceneRouter.MENU)


# --- Level lifecycle -----------------------------------------------------

func _spawn_ball_if_needed() -> void:
	if is_instance_valid(_ball):
		return
	if ball_scene == null:
		push_error("GameController: assign ball_scene PackedScene")
		return
	_ball = ball_scene.instantiate() as RigidBody2D
	_ball.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_ball)
	if _camera and _camera.has_method("set_target"):
		_camera.call("set_target", _ball)


## Single, authoritative restart entry point. advance=false rebuilds the
## same level (same seed); advance=true rerolls a harder one.
func _regenerate_level(advance: bool) -> void:
	# Tear down any overlays so we can never resume into a stale UI.
	if is_instance_valid(_results):
		_results.queue_free()
		_results = null
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
		_pause_menu = null
	get_tree().paused = false
	_state = State.PLAYING

	if advance:
		_level_index += 1
		_level_seed = randi()
		_deaths_this_level = 0
	_run_time = 0.0
	_run_flippers = 0
	_run_distance = 0.0
	_best_depth_pct = 0.0

	_apply_world_theme()

	if _generator:
		_rng.seed = _level_seed
		var info: Dictionary = _generator.build_level(_world, _rng, _level_index)
		var spawn: Vector2 = info.get("spawn_global", Vector2(0, 80))
		_level_bottom_y = float(info.get("bottom_y", 4000.0))
		_level_top_y = spawn.y
		_spawn_ball_if_needed()
		if is_instance_valid(_ball):
			_ball.visible = true
			_ball.freeze = false
			_apply_ball_skin()
			_ball.reset_ball(spawn)
			_prev_ball_pos = spawn
		for chunk_name in info.get("sequence", PackedStringArray()):
			GameEvents.chunk_discovered.emit(String(chunk_name))

	if _camera and _camera.has_method("set_target") and is_instance_valid(_ball):
		_camera.call("set_target", _ball)
	_invuln_until = Time.get_ticks_msec() / 1000.0 + spawn_invuln_seconds

	_hud_world.text = "WORLD %d" % Worlds.world_index_for_level(_level_index)
	_hud_level.text = "LEVEL %d" % _level_index
	_show_banner()
	_show_controls_hint()

	GameEvents.run_started.emit(_level_index)
	MusicManager.set_level(_level_index)


## Restarts the current level (Retry button / R key / pause-restart).
func _restart_level() -> void:
	_regenerate_level(false)


func _next_level() -> void:
	_regenerate_level(true)


func _show_banner() -> void:
	if _banner == null:
		return
	_banner.text = "%s\nLEVEL %d" % [_world_def.get("name", ""), _level_index]
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.9, 0.9)
	_banner.pivot_offset = _banner.size * 0.5
	var t := _banner.create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(_banner, "modulate:a", 0.0, 0.5)


## Shows the controls reminder for the opening levels, then fades it out.
func _show_controls_hint() -> void:
	if _hint == null:
		return
	if _level_index > 3:
		_hint.modulate.a = 0.0
		return
	_hint.modulate.a = 1.0
	var t := _hint.create_tween()
	t.tween_interval(2.8)
	t.tween_property(_hint, "modulate:a", 0.0, 0.7)


func _apply_world_theme() -> void:
	_world_def = Worlds.world_for_level(_level_index)
	WorldPainter.apply_world(_world_def)
	UITheme.set_world(Worlds.world_index_for_level(_level_index))
	if _bg and _bg.has_method("apply_world"):
		_bg.call("apply_world", _world_def)
	GameEvents.world_changed.emit(Worlds.world_index_for_level(_level_index))


## Applies the player's equipped ball skin to the live ball. The skin fully
## defines the ball's look — the world only themes the level and background.
func _apply_ball_skin() -> void:
	if is_instance_valid(_ball):
		_ball.call("apply_skin", BallSkins.equipped_skin())


func _is_invuln() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _invuln_until


# --- Run end -------------------------------------------------------------

func _build_result(outcome: String) -> Dictionary:
	var win := outcome == "win"
	var depth := 1.0 if win else _best_depth_pct
	var score := 0
	if win:
		score = _level_index * 1000
		score += int(maxf(0.0, 75.0 - _run_time) * 22.0)
		score += _run_flippers * 5
		if _deaths_this_level == 0:
			score += 1500
	else:
		score = _level_index * 120 + int(depth * 450.0)
	return {
		"outcome": outcome,
		"level": _level_index,
		"world": Worlds.world_index_for_level(_level_index),
		"depth_pct": depth,
		"time": _run_time,
		"flippers": _run_flippers,
		"distance": _run_distance,
		"deaths_this_level": _deaths_this_level,
		"no_death": win and _deaths_this_level == 0,
		"score": score,
	}


func _on_player_died() -> void:
	if _state != State.PLAYING:
		return
	if _is_invuln():
		return
	_state = State.RESULTS
	_deaths_this_level += 1
	_play_sfx(_sfx_death)
	_shake(18.0)
	_flash(Color(0.85, 0.1, 0.15, 0.55))
	if is_instance_valid(_ball):
		VFX.explode(self, _ball.global_position, _world_def.get("hazard", Color(1, 0.3, 0.4)))
		_ball.visible = false
		_ball.freeze = true
	var result := _build_result("death")
	GameEvents.run_ended.emit(result)
	_show_results(result)


func _on_level_completed() -> void:
	if _state != State.PLAYING:
		return
	_state = State.RESULTS
	_play_sfx(_sfx_win)
	_shake(10.0)
	_flash(Color(0.25, 0.95, 0.4, 0.45))
	if is_instance_valid(_ball):
		VFX.burst(self, _ball.global_position, _world_def.get("accent", Color(1, 1, 1)), 36, 300.0, 0.8)
		_ball.freeze = true
	var result := _build_result("win")
	GameEvents.run_ended.emit(result)
	_show_results(result)


func _show_results(result: Dictionary) -> void:
	var win := String(result.get("outcome", "")) == "win"
	_results_primary = Callable(self, "_next_level") if win else Callable(self, "_restart_level")
	_results = Control.new()
	_results.set_script(load("res://scripts/ui/results_overlay.gd"))
	_canvas.add_child(_results)
	_results.call("setup", result, _results_primary, Callable(self, "_go_to_menu"))


# --- Feedback ------------------------------------------------------------

func _on_ball_hit(speed: float) -> void:
	if speed < 220.0:
		return
	_play_sfx(_sfx_hit)
	_shake(clampf((speed - 220.0) / 1400.0, 0.0, 1.0) * 6.0)
	if speed > 600.0 and is_instance_valid(_ball):
		VFX.burst(self, _ball.global_position,
			_world_def.get("wall_trim", Color(1, 1, 1)), 6, 130.0, 0.35)


func _on_ball_ricochet(speed: float) -> void:
	_play_sfx(_sfx_ricochet)
	_shake(clampf((speed - 900.0) / 300.0, 0.0, 1.0) * 8.0 + 2.0)
	if is_instance_valid(_ball):
		VFX.burst(self, _ball.global_position,
			_world_def.get("accent", Color(1, 1, 1)), 12, 220.0, 0.45)


func _on_hazard_hit() -> void:
	_play_sfx(_sfx_hazard)


func _on_flipper_fired() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_flip_sfx < flipper_sfx_cooldown:
		return
	_last_flip_sfx = now
	_run_flippers += 1
	_play_sfx(_sfx_flip)
	_shake(2.0)


func _shake(amount: float) -> void:
	if _camera and _camera.has_method("add_shake"):
		_camera.call("add_shake", GameSettings.shake_amount(amount))


func _flash(color: Color) -> void:
	if _vignette == null or not GameSettings.screen_flash:
		return
	_vignette.color = Color(color.r, color.g, color.b, 1.0)
	_vignette.modulate = color


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()
