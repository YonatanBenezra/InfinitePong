extends Node2D
## Main gameplay controller: procedural build, ball spawn, run lifecycle,
## results, pause, theming and feel.
##
## Flow is driven by an explicit state machine (PLAYING / RESULTS / PAUSED)
## so restart can never soft-lock: the Retry button and the R key both route
## through the same _restart_level() regardless of state.

enum State { PLAYING, RESULTS, PAUSED }

## Health the player starts a run with. Each lethal hit costs 1; while any
## remains the ball respawns at the top of the current level and the run
## continues. At 0 the player dies: the run ends, run progress is wiped and
## the player is sent back to the menu. The "Heal +2" upgrade tops it back up.
const STARTING_HEALTH := 5

@export var ball_scene: PackedScene
@export var chunk_generator_path: NodePath = NodePath("ChunkGenerator")
@export var ball_fall_grace_y: float = 600.0
@export var spawn_invuln_seconds: float = 0.35
## Several flippers in a chunk fire on one key press; this gates both the
## flipper cue and the flipper counter so one press counts once.
@export var flipper_sfx_cooldown: float = 0.09

@export_group("Shooting")
## Max ammo. Bullets cost 1 each; the magazine refills `reload_amount` on
## each qualifying ball collision, gated by `reload_cooldown`.
@export_range(1, 30, 1) var max_ammo: int = 5
## Bullets restored per qualifying collision. Stays at 1 by default so the
## player reloads one shot per bounce.
@export_range(1, 10, 1) var reload_amount: int = 1
## Minimum seconds between collision-driven reload ticks. Stops one long
## bounce (or a rapid flurry of contacts) from refilling the whole magazine
## at once, and drives the on-screen reload-readiness bar.
@export_range(0.05, 5.0, 0.05) var reload_cooldown: float = 0.45
## Velocity (px/s) applied to the ball in the OPPOSITE direction of each
## shot. Raise for a stronger movement boost; lower for a gentler kick.
@export_range(0.0, 1200.0, 10.0) var recoil_strength: float = 150.0
## Bullet scene spawned per shot. Defaults to res://scenes/projectiles/bullet.tscn.
@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")

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
var _lives: int = STARTING_HEALTH
var _ammo: int = 5
## Global spawn point of the current level, kept so a non-lethal hit can
## respawn the ball at the top without rebuilding the level.
var _spawn_global: Vector2 = Vector2(0, 80)

# --- Run upgrades -----------------------------------------------------------
# Modifiers chosen from the post-level upgrade draft. They accumulate across
# levels for the whole run and reset on death (a death returns to the menu,
# which reloads this scene fresh, so defaults are restored automatically;
# _reset_run_progress() also restores them for the in-scene Retry path).
var _shot_size_mult: float = 1.0
var _shot_damage: int = 1
var _speed_mult: float = 1.0
## Score accumulated across every level cleared this run. Shown as the run's
## "current score" on the game-over card and compared against the high score.
var _run_score: int = 0
# Base values captured at _ready so _reset_run_progress() can restore the
# tunables that upgrades mutate in place.
var _base_max_ammo: int = 5
var _base_reload_cooldown: float = 0.45
var _base_recoil_strength: float = 150.0
var _base_ball_speed: float = 750.0
## Seconds left on the reload gate. A qualifying ball collision refills one
## ammo and re-arms this to `reload_cooldown`; it counts back down to 0,
## during which further collisions don't reload. Also drives the HUD bar.
var _reload_cooldown_left: float = 0.0
var _sfx_shoot: AudioStreamPlayer
var _sfx_empty: AudioStreamPlayer
var _sfx_bullet_hit: AudioStreamPlayer
var _world_def: Dictionary = {}
var _bg: Node2D
var _results: Control
var _pause_menu: Control
var _results_primary: Callable

# HUD nodes (built procedurally).
var _hud_level: Label
var _hud_track: Panel
var _hud_depth_fill: ColorRect
var _hud_depth_label: Label
var _hud_time: Label
var _hud_health: Label
var _hud_ammo: Label
var _hud_reload_track: Panel
var _hud_reload_fill: ColorRect
var _fps_label: Label
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
	# Snapshot the stock tunables BEFORE any saved-run values overwrite them,
	# so a reset can always restore the true base loadout.
	_base_max_ammo = max_ammo
	_base_reload_cooldown = reload_cooldown
	_base_recoil_strength = recoil_strength
	# Resume a saved run only when the menu asked to Continue and one exists;
	# otherwise this is a brand-new run, which abandons any stale saved run.
	var mode := String(payload.get("mode", "play"))
	if mode == "continue" and Profile.has_active_run():
		_restore_run(Profile.active_run)
	else:
		_level_index = maxi(int(payload.get("start_level", 1)), 1)
		_lives = STARTING_HEALTH
		Profile.clear_active_run()
	_ammo = max_ammo
	_reload_cooldown_left = 0.0
	_generator = get_node(chunk_generator_path) as ChunkGenerator

	GameEvents.player_died.connect(_on_player_died)
	GameEvents.level_completed.connect(_on_level_completed)
	GameEvents.ball_hit.connect(_on_ball_hit)
	GameEvents.ball_ricochet.connect(_on_ball_ricochet)
	GameEvents.bullet_hit_hazard.connect(_on_bullet_hit_hazard)
	GameEvents.ball_hit_flipper.connect(_on_ball_hit_flipper)
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
	# Shoot / empty / bullet-hit aren't placed in the scene file; create
	# them here so the gameplay scene stays minimal.
	_sfx_shoot = _add_sfx_player()
	_sfx_empty = _add_sfx_player()
	_sfx_bullet_hit = _add_sfx_player()
	var have_sfx := AudioServer.get_bus_index("Sfx") >= 0
	for entry in [
		[_sfx_flip, AudioSynth.flip_sound(), -6.0],
		[_sfx_hit, AudioSynth.hit_sound(), -10.0],
		[_sfx_death, AudioSynth.death_sound(), -4.0],
		[_sfx_win, AudioSynth.win_sound(), -2.0],
		[_sfx_hazard, AudioSynth.hazard_sound(), -5.0],
		[_sfx_ricochet, AudioSynth.ricochet_sound(), -8.0],
		[_sfx_shoot, AudioSynth.shoot_sound(), -8.0],
		[_sfx_empty, AudioSynth.empty_ammo_sound(), -10.0],
		[_sfx_bullet_hit, AudioSynth.bullet_hit_sound(), -7.0],
	]:
		var player: AudioStreamPlayer = entry[0]
		if player:
			player.stream = entry[1]
			player.volume_db = entry[2]
			if have_sfx:
				player.bus = "Sfx"


func _add_sfx_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


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

	# Left: level + ammo.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.custom_minimum_size = Vector2(120, 0)
	row.add_child(left)
	_hud_level = _hud_label("", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_ammo = _hud_label("AMMO %d / %d" % [_ammo, max_ammo], 11,
		UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(_hud_level)
	left.add_child(_hud_ammo)
	# Reload progress bar — a thin track beneath the ammo readout that fills
	# while the magazine recharges, then hides once it is full.
	_hud_reload_track = Panel.new()
	_hud_reload_track.custom_minimum_size = Vector2(110, 6)
	var reload_track_style := StyleBoxFlat.new()
	reload_track_style.bg_color = Color(0, 0, 0, 0.5)
	reload_track_style.set_corner_radius_all(3)
	_hud_reload_track.add_theme_stylebox_override("panel", reload_track_style)
	left.add_child(_hud_reload_track)
	_hud_reload_fill = ColorRect.new()
	_hud_reload_fill.anchor_bottom = 1.0
	_hud_reload_fill.offset_left = 1.0
	_hud_reload_fill.offset_top = 1.0
	_hud_reload_fill.offset_bottom = -1.0
	_hud_reload_fill.color = Color(1.0, 0.82, 0.4)
	_hud_reload_track.add_child(_hud_reload_fill)

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
	# Health readout. A single heart + count so it scales cleanly when the
	# "Heal +2" upgrade pushes health above the starting value.
	_hud_health = _hud_label("♥ %d" % _lives, 18, UITheme.DANGER, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_hud_time)
	right.add_child(_hud_health)

	# FPS readout.
	_fps_label = _hud_label("", 12, Color(0.55, 0.9, 0.65), HORIZONTAL_ALIGNMENT_LEFT)
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_left = 8
	_fps_label.offset_top = -22
	_fps_label.offset_bottom = -4
	_fps_label.visible = GameSettings.show_fps
	_canvas.add_child(_fps_label)

	# Controls hint along the bottom — fades out after each level start.
	_hint = _hud_label(
		"Hold  SPACE  Flipper      LMB  Shoot      R  Retry      ESC  Pause",
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
	if _reload_cooldown_left > 0.0:
		_reload_cooldown_left = maxf(_reload_cooldown_left - delta, 0.0)
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
	if _hud_health != null:
		_hud_health.text = "♥ %d" % maxi(_lives, 0)
	if _hud_ammo != null:
		_hud_ammo.text = "AMMO %d / %d" % [_ammo, max_ammo]
		_hud_ammo.add_theme_color_override("font_color",
			UITheme.DANGER if _ammo == 0 else UITheme.TEXT_FAINT)
	if _hud_reload_track != null:
		# Shown only while the magazine isn't full. The fill is the reload
		# cooldown recovering: it empties when a bounce refills a shot, then
		# fills back to full = "ready to reload on the next bounce".
		var reloading := _ammo < max_ammo
		_hud_reload_track.visible = reloading
		if reloading and _hud_reload_fill != null:
			var ready := 1.0 - _reload_cooldown_left / maxf(reload_cooldown, 0.01)
			var reload_w: float = _hud_reload_track.size.x - 2.0
			_hud_reload_fill.size.x = maxf(reload_w * clampf(ready, 0.0, 1.0), 0.0)


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
		return
	if event.is_action_pressed("shoot") and _state == State.PLAYING:
		_try_shoot()


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
	# Remember the ball's stock top speed so the "Speed x1.1" upgrade can scale
	# from a stable baseline and a run reset can restore it.
	_base_ball_speed = float(_ball.get("max_speed"))
	# Re-apply any speed already banked this run (the ball is reused across
	# levels, but if it was ever rebuilt this keeps the upgrade in effect).
	_ball.set("max_speed", _base_ball_speed * _speed_mult)
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
	# Every level start (advance OR retry) tops the magazine off so the
	# player isn't dropped into a new layout already empty.
	_ammo = max_ammo
	_reload_cooldown_left = 0.0

	_apply_world_theme()

	if _generator:
		_rng.seed = _level_seed
		var info: Dictionary = _generator.build_level(_world, _rng, _level_index)
		var spawn: Vector2 = info.get("spawn_global", Vector2(0, 80))
		_spawn_global = spawn
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

	_hud_level.text = "LEVEL %d" % _level_index
	_show_controls_hint()

	GameEvents.run_started.emit(_level_index)
	MusicManager.set_level(_level_index)
	# Checkpoint the run as the Continue resume point now that the level (and
	# any upgrades applied before advancing) is live.
	_save_run_checkpoint()


## Restarts the run from the BEGINNING (R key / pause-restart). A restart is a
## brand-new run: level progression AND run upgrades/health/score are wiped, so
## the player always returns to level 1 with a fresh layout and base loadout.
func _restart_level() -> void:
	_level_index = 1
	_level_seed = randi()
	_deaths_this_level = 0
	_reset_run_progress()
	_regenerate_level(false)


## Restores every run-based modifier to its base value: health, the upgrade
## tunables and the accumulated run score. Called when a fresh run begins.
func _reset_run_progress() -> void:
	_lives = STARTING_HEALTH
	_run_score = 0
	_shot_size_mult = 1.0
	_shot_damage = 1
	_speed_mult = 1.0
	max_ammo = _base_max_ammo
	reload_cooldown = _base_reload_cooldown
	recoil_strength = _base_recoil_strength
	if is_instance_valid(_ball):
		_ball.set("max_speed", _base_ball_speed)


# --- Saved run (Continue) ------------------------------------------------
# The whole run is checkpointed to Profile at the start of every level, so the
# player can quit and Continue from there. It is cleared on death and when a
# new run begins, so the menu only offers Continue while a run is genuinely in
# progress — never a stale level number after a wipe.

## Serialises the live run state into a plain dict for Profile.
func _snapshot_run() -> Dictionary:
	return {
		"level": _level_index,
		"health": _lives,
		"max_ammo": max_ammo,
		"shot_size_mult": _shot_size_mult,
		"shot_damage": _shot_damage,
		"speed_mult": _speed_mult,
		"reload_cooldown": reload_cooldown,
		"recoil_strength": recoil_strength,
		"run_score": _run_score,
	}


## Loads a saved run snapshot back into the live run state. Base tunables must
## already be captured (see _ready) so a later reset still restores stock.
func _restore_run(state: Dictionary) -> void:
	_level_index = maxi(int(state.get("level", 1)), 1)
	_lives = maxi(int(state.get("health", STARTING_HEALTH)), 1)
	max_ammo = maxi(int(state.get("max_ammo", _base_max_ammo)), 1)
	_shot_size_mult = float(state.get("shot_size_mult", 1.0))
	_shot_damage = maxi(int(state.get("shot_damage", 1)), 1)
	_speed_mult = float(state.get("speed_mult", 1.0))
	reload_cooldown = float(state.get("reload_cooldown", _base_reload_cooldown))
	recoil_strength = float(state.get("recoil_strength", _base_recoil_strength))
	_run_score = int(state.get("run_score", 0))


## Persists the current run as the resume point.
func _save_run_checkpoint() -> void:
	Profile.save_active_run(_snapshot_run())


func _next_level() -> void:
	_regenerate_level(true)


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
		"lives": _lives,
		"no_death": win and _deaths_this_level == 0,
		"score": score,
	}


func _on_player_died() -> void:
	if _state != State.PLAYING:
		return
	if _is_invuln():
		return
	_deaths_this_level += 1
	_lives = maxi(_lives - 1, 0)
	_play_sfx(_sfx_death)
	_flash(Color(0.85, 0.1, 0.15, 0.55))
	if _lives > 0:
		# Non-lethal: spend a health point, then drop the ball back in at the
		# top of the current level so the run keeps going with its upgrades.
		_shake(8.0)
		if is_instance_valid(_ball):
			VFX.burst(self, _ball.global_position,
				_world_def.get("hazard", Color(1, 0.3, 0.4)), 14, 200.0, 0.45)
		_respawn_ball()
		return
	# Out of health — the run is over. Drop the saved run so the menu stops
	# offering Continue, then report the final run score and the high score.
	_state = State.RESULTS
	Profile.clear_active_run()
	if is_instance_valid(_ball):
		VFX.explode(self, _ball.global_position, _world_def.get("hazard", Color(1, 0.3, 0.4)))
		_ball.visible = false
		_ball.freeze = true
	var result := _build_result("game_over")
	var prior_best := int(Profile.stats.get("best_score", 0))
	var run_total := _run_score + int(result.get("score", 0))
	result["score"] = run_total
	result["run_score"] = run_total
	result["high_score"] = maxi(prior_best, run_total)
	result["new_best"] = run_total > prior_best
	# Profile reads result.score to update the persisted best_score.
	GameEvents.run_ended.emit(result)
	_show_game_over(result)


func _on_level_completed() -> void:
	if _state != State.PLAYING:
		return
	_state = State.RESULTS
	_play_sfx(_sfx_win)
	_flash(Color(0.25, 0.95, 0.4, 0.45))
	if is_instance_valid(_ball):
		VFX.burst(self, _ball.global_position, _world_def.get("accent", Color(1, 1, 1)), 36, 300.0, 0.8)
		_ball.freeze = true
	var result := _build_result("win")
	# Bank the cleared level's score into the running total for this run.
	_run_score += int(result.get("score", 0))
	GameEvents.run_ended.emit(result)
	# Every cleared level offers an upgrade draft before advancing.
	_show_upgrade_select(result)


## Drops the ball back at the top of the current level after a non-lethal hit,
## without rebuilding the level. Re-arms spawn invulnerability so the same
## hazard can't immediately re-trigger the death.
func _respawn_ball() -> void:
	if is_instance_valid(_ball):
		_ball.visible = true
		_ball.freeze = false
		_ball.reset_ball(_spawn_global)
		_prev_ball_pos = _spawn_global
	_invuln_until = Time.get_ticks_msec() / 1000.0 + spawn_invuln_seconds


# --- Upgrade draft -------------------------------------------------------

## Presents the three-card upgrade draft over the cleared level.
func _show_upgrade_select(result: Dictionary) -> void:
	# No keyboard "primary" during a draft — the player must pick a card.
	_results_primary = Callable()
	var choices := Upgrades.roll(3)
	_results = Control.new()
	_results.set_script(load("res://scripts/ui/upgrade_select.gd"))
	_canvas.add_child(_results)
	_results.call("setup", result, choices, Callable(self, "_on_upgrade_chosen"))


## Applies the drafted upgrade for the rest of the run, then advances.
func _on_upgrade_chosen(upgrade: Dictionary) -> void:
	_apply_upgrade(String(upgrade.get("id", "")))
	_next_level()


## Maps an upgrade id onto the live run state. Multipliers stack across picks.
func _apply_upgrade(id: String) -> void:
	match id:
		"heal":
			_lives += 2
		"max_ammo":
			max_ammo += 1
			_ammo = mini(_ammo + 1, max_ammo)
		"speed":
			_speed_mult *= 1.1
			if is_instance_valid(_ball):
				_ball.set("max_speed", _base_ball_speed * _speed_mult)
		"reload":
			# Faster reload = shorter cooldown. Floor it so it can't hit zero.
			reload_cooldown = maxf(reload_cooldown / 1.1, 0.05)
		"shot_size":
			_shot_size_mult *= 1.1
		"recoil":
			recoil_strength *= 1.1
		"shot_damage":
			_shot_damage += 1
		_:
			push_warning("GameController: unknown upgrade id '%s'" % id)


## Shows the game-over card with the run's final score and the high score,
## then routes the player back to the main menu.
func _show_game_over(result: Dictionary) -> void:
	_results_primary = Callable(self, "_go_to_menu")
	_results = Control.new()
	_results.set_script(load("res://scripts/ui/results_overlay.gd"))
	_canvas.add_child(_results)
	_results.call("setup", result, _results_primary, Callable(self, "_go_to_menu"))


# --- Feedback ------------------------------------------------------------

func _on_ball_hit(speed: float) -> void:
	# Any ball contact drip-feeds the magazine back up (1 per reload_cooldown).
	_try_reload_from_contact()
	if speed < 220.0:
		return
	_play_sfx(_sfx_hit)
	# Small shake on a real bounce off a surface (the speed gate above keeps
	# tiny rolls and brushes from triggering it).
	_shake(3.0)
	if speed > 600.0 and is_instance_valid(_ball):
		VFX.burst(self, _ball.global_position,
			_world_def.get("wall_trim", Color(1, 1, 1)), 6, 130.0, 0.35)


## Refills one reload tick per qualifying ball collision. Called from BOTH
## the normal-hit and ricochet paths so any bounce reloads — the old version
## only listened to the normal-hit event, so a fast ricochet (the most common
## contact while moving at speed) never reloaded and the gun felt broken.
func _try_reload_from_contact() -> void:
	if _ammo >= max_ammo:
		return
	if _reload_cooldown_left > 0.0:
		return
	_ammo = mini(_ammo + reload_amount, max_ammo)
	_reload_cooldown_left = reload_cooldown


# --- Shooting -------------------------------------------------------------

func _try_shoot() -> void:
	if not is_instance_valid(_ball):
		return
	# A ball stuck in glue is in "aim and launch" mode — don't let the
	# shoot binding overlap with that interaction.
	if _ball.has_method("is_glue_stuck") and bool(_ball.call("is_glue_stuck")):
		return
	if _ammo <= 0:
		_play_sfx(_sfx_empty)
		return
	var mouse_pos: Vector2 = _ball.get_global_mouse_position()
	var dir: Vector2 = mouse_pos - _ball.global_position
	if dir.length() < 1.0:
		dir = Vector2.DOWN
	dir = dir.normalized()
	_ammo -= 1
	_spawn_bullet(_ball.global_position, dir)
	# Recoil — opposite the shot. Add to current velocity so the boost
	# stacks with the ball's motion instead of replacing it.
	_ball.linear_velocity += -dir * recoil_strength
	_play_sfx(_sfx_shoot)
	# Quick muzzle flash at the ball.
	if is_instance_valid(_ball):
		VFX.burst(self, _ball.global_position + dir * 8.0,
			Color(1.0, 0.9, 0.5), 5, 160.0, 0.22)


func _spawn_bullet(at_global: Vector2, dir: Vector2) -> void:
	if bullet_scene == null:
		push_error("GameController: bullet_scene is null")
		return
	var bullet := bullet_scene.instantiate() as Area2D
	if bullet == null:
		return
	# Apply run upgrades: scale the whole node (visual + collision) for Shot
	# Size, and set the per-bullet damage for Shot Damage.
	bullet.scale = Vector2(_shot_size_mult, _shot_size_mult)
	bullet.set("damage", _shot_damage)
	add_child(bullet)
	bullet.global_position = at_global + dir * 10.0
	if bullet.has_method("setup"):
		bullet.call("setup", dir)


func _on_bullet_hit_hazard(pos: Vector2) -> void:
	_play_sfx(_sfx_bullet_hit)
	VFX.burst(self, pos, Color(1.0, 0.85, 0.45), 8, 180.0, 0.3)


func _on_ball_ricochet(speed: float) -> void:
	# A ricochet is just a fast bounce, so it reloads exactly like a normal
	# hit. This is the path that was missing before, which is why reloading
	# "didn't work all the time" once the ball was moving fast.
	_try_reload_from_contact()
	_play_sfx(_sfx_ricochet)
	# Still a small shake, slightly stronger than a regular hit to match the
	# audio cue.
	_shake(5.0)
	if is_instance_valid(_ball):
		VFX.burst(self, _ball.global_position,
			_world_def.get("accent", Color(1, 1, 1)), 12, 220.0, 0.45)


func _on_ball_hit_flipper() -> void:
	# Big shake — the flipper just kicked the ball with force.
	_shake(12.0)


func _on_hazard_hit() -> void:
	_play_sfx(_sfx_hazard)


func _on_flipper_fired() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_flip_sfx < flipper_sfx_cooldown:
		return
	_last_flip_sfx = now
	_run_flippers += 1
	_play_sfx(_sfx_flip)


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
