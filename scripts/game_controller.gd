extends Node2D
## Main controller: procedural build, ball spawn, death/win/restart, pause.
##
## Responsibilities:
##  - Owns the ball + camera + UI labels.
##  - Asks the ChunkGenerator to build a fresh level on demand.
##  - Routes GameEvents (player_died, level_completed, ball_hit,
##    flipper_fired) into audio, camera shake, and UI feedback.
##  - Handles global input: R restart, ESC pause.

@export var ball_scene: PackedScene
@export var chunk_generator_path: NodePath = NodePath("ChunkGenerator")
@export var death_restart_delay: float = 0.7
@export var win_restart_delay: float = 1.2
@export var ball_fall_grace_y: float = 600.0
@export var spawn_invuln_seconds: float = 0.35

@onready var _world: Node2D = $World
@onready var _camera: Camera2D = $Camera2D
@onready var _status: Label = $CanvasLayer/StatusLabel
@onready var _title: Label = $CanvasLayer/TitleLabel
@onready var _center: Label = $CanvasLayer/CenterMessage
@onready var _pause_label: Label = $CanvasLayer/PauseLabel
@onready var _vignette: ColorRect = $CanvasLayer/Vignette
@onready var _depth_label: Label = $CanvasLayer/DepthLabel
@onready var _depth_bar_bg: ColorRect = $CanvasLayer/DepthBarBg
@onready var _depth_bar_fill: ColorRect = $CanvasLayer/DepthBarFill
@onready var _sfx_flip: AudioStreamPlayer = $SfxFlip
@onready var _sfx_hit: AudioStreamPlayer = $SfxHit
@onready var _sfx_death: AudioStreamPlayer = $SfxDeath
@onready var _sfx_win: AudioStreamPlayer = $SfxWin

var _ball: RigidBody2D
var _generator: ChunkGenerator
var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _level_top_y: float = 0.0
var _level_bottom_y: float = 0.0
var _invuln_until: float = 0.0
var _run_count: int = 0
var _death_count: int = 0
var _best_depth_pct: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_generator = get_node(chunk_generator_path) as ChunkGenerator
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.level_completed.connect(_on_level_completed)
	GameEvents.ball_hit.connect(_on_ball_hit)
	GameEvents.flipper_fired.connect(_on_flipper_fired)
	_pause_label.visible = false
	_center.visible = false
	if _vignette:
		_vignette.modulate = Color(1, 1, 1, 0)
	_title.text = "PIN DOWN"
	_status.text = "[Space] / [LMB] Flippers   [R] Restart   [Esc] Pause"
	_setup_audio()
	_spawn_ball_if_needed()
	_regenerate_level()


func _setup_audio() -> void:
	# We synthesize placeholder PCM in-engine so the prototype is audible
	# without an asset pipeline. Volumes are tuned so hits don't overpower.
	if _sfx_flip:
		_sfx_flip.stream = AudioSynth.flip_sound()
		_sfx_flip.volume_db = -6.0
	if _sfx_hit:
		_sfx_hit.stream = AudioSynth.hit_sound()
		_sfx_hit.volume_db = -10.0
	if _sfx_death:
		_sfx_death.stream = AudioSynth.death_sound()
		_sfx_death.volume_db = -4.0
	if _sfx_win:
		_sfx_win.stream = AudioSynth.win_sound()
		_sfx_win.volume_db = -2.0


func _process(delta: float) -> void:
	# Fade the vignette overlay back to clear over time.
	if _vignette and _vignette.modulate.a > 0.0:
		var a := maxf(_vignette.modulate.a - delta * 1.6, 0.0)
		_vignette.modulate.a = a
	_update_depth_ui()
	# Safety net: if the ball somehow falls past the level bottom, treat as death.
	if get_tree().paused or _busy:
		return
	if is_instance_valid(_ball):
		if _ball.global_position.y > _level_bottom_y + ball_fall_grace_y:
			GameEvents.player_died.emit()


func _update_depth_ui() -> void:
	if _depth_label == null or _depth_bar_fill == null or _depth_bar_bg == null:
		return
	var pct := 0.0
	if is_instance_valid(_ball) and _level_bottom_y > _level_top_y:
		var travelled: float = _ball.global_position.y - _level_top_y
		var total: float = _level_bottom_y - _level_top_y
		pct = clampf(travelled / total, 0.0, 1.0)
	_best_depth_pct = maxf(_best_depth_pct, pct)
	_depth_label.text = "DEPTH %d%%   RUN %d   DEATHS %d" % [int(pct * 100.0), _run_count, _death_count]
	var bar_width := _depth_bar_bg.size.x
	_depth_bar_fill.size.x = bar_width * pct
	# Color shifts warm-to-cool as the player descends.
	var color := Color(0.95, 0.78, 0.25).lerp(Color(0.4, 0.95, 0.5), pct)
	_depth_bar_fill.color = Color(color.r, color.g, color.b, 0.95)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart") and not get_tree().paused:
		_force_restart()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	_pause_label.visible = tree.paused


func _force_restart() -> void:
	if _busy:
		return
	_busy = true
	_center.text = "RESTART"
	_center.visible = true
	await get_tree().create_timer(0.12).timeout
	_regenerate_level()


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


func _regenerate_level() -> void:
	_busy = false
	_center.visible = false
	_run_count += 1
	_best_depth_pct = 0.0
	if _generator:
		var info: Dictionary = _generator.build_level(_world, _rng, _run_count)
		var spawn: Vector2 = info.get("spawn_global", Vector2(320, 80))
		_level_bottom_y = float(info.get("bottom_y", 4000.0))
		_level_top_y = spawn.y
		_spawn_ball_if_needed()
		if is_instance_valid(_ball):
			_ball.reset_ball(spawn)
	if _camera and _camera.has_method("set_target") and is_instance_valid(_ball):
		_camera.call("set_target", _ball)
	_invuln_until = Time.get_ticks_msec() / 1000.0 + spawn_invuln_seconds


func _is_invuln() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _invuln_until


func _on_player_died() -> void:
	if _busy:
		return
	# Ignore deaths during the spawn invulnerability window so the ball
	# can't die from spawning on/near a hazard.
	if _is_invuln():
		return
	_busy = true
	_death_count += 1
	_play_sfx(_sfx_death)
	_shake(18.0)
	_flash(Color(0.85, 0.1, 0.15, 0.55))
	_center.text = "YOU DIED\nDepth: %d%%\n[R] Restart" % int(_best_depth_pct * 100.0)
	_center.visible = true
	await get_tree().create_timer(death_restart_delay).timeout
	if _busy:
		_regenerate_level()


func _on_level_completed() -> void:
	if _busy:
		return
	_busy = true
	_play_sfx(_sfx_win)
	_shake(10.0)
	_flash(Color(0.25, 0.95, 0.4, 0.45))
	_center.text = "EXIT REACHED!\nNew layout incoming…"
	_center.visible = true
	await get_tree().create_timer(win_restart_delay).timeout
	if _busy:
		_regenerate_level()


func _on_ball_hit(speed: float) -> void:
	# Only play hit sfx for meaningful impacts to avoid spam on micro-contacts.
	if speed < 220.0:
		return
	_play_sfx(_sfx_hit)
	# Shake scales with impact intensity.
	var s := clampf((speed - 220.0) / 1400.0, 0.0, 1.0) * 6.0
	_shake(s)


func _on_flipper_fired() -> void:
	_play_sfx(_sfx_flip)
	_shake(2.0)


func _shake(amount: float) -> void:
	if _camera and _camera.has_method("add_shake"):
		_camera.call("add_shake", amount)


func _flash(color: Color) -> void:
	if _vignette == null:
		return
	_vignette.color = Color(color.r, color.g, color.b, 1.0)
	_vignette.modulate = color


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()
