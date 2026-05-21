class_name PinDownGame
extends Node2D

enum State { PLAYING, DEAD, TRANSITION }

@onready var ball: RigidBody2D = $Ball
@onready var camera: PinCamera = $Camera2D
@onready var level_generator: LevelGenerator = $LevelGenerator
@onready var audio: AudioManager = $AudioManager
@onready var status_label: Label = $UI/StatusLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var depth_label: Label = $UI/DepthLabel
@onready var overlay: PanelContainer = $UI/Overlay
@onready var overlay_label: Label = $UI/Overlay/VBox/Message

var state: State = State.PLAYING
var level_index: int = 1
var _exit_connected: bool = false


func _ready() -> void:
	_setup_generator()
	camera.set_target(ball)
	ball.died.connect(_on_ball_died)
	ball.reached_exit.connect(_on_ball_reached_exit)
	ball.bounced.connect(audio.play_impact)
	_start_level(false)
	overlay.hide()


func _process(_delta: float) -> void:
	if state != State.PLAYING:
		return
	var bounds := level_generator.get_level_bounds()
	var span := maxf(bounds.y - bounds.x, 1.0)
	var progress := clampf((ball.global_position.y - bounds.x) / span, 0.0, 1.0)
	depth_label.text = "Depth: %d%%" % int(progress * 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and state != State.PLAYING:
		_start_level(false)


func _setup_generator() -> void:
	level_generator.setup($LevelRoot, $Walls, $LaneVisuals)
	level_generator.spawn_chunk_scene = preload("res://scenes/chunks/chunk_spawn.tscn")
	level_generator.exit_chunk_scene = preload("res://scenes/chunks/level_exit.tscn")
	level_generator.chunk_pool = [
		load("res://resources/chunks/chunk_easy.tres") as ChunkDefinition,
		load("res://resources/chunks/chunk_medium.tres") as ChunkDefinition,
		load("res://resources/chunks/chunk_hard.tres") as ChunkDefinition,
	]


func _start_level(advance: bool) -> void:
	if advance:
		level_index += 1
	state = State.PLAYING
	overlay.hide()
	level_generator.build_level()
	_connect_exit()
	_connect_flipper_audio()
	ball.reset_at(level_generator.get_spawn_position())
	var bounds := level_generator.get_level_bounds()
	camera.set_level_bounds(bounds.x, bounds.y)
	camera.snap_to_target()
	_update_hud()


func _connect_exit() -> void:
	var exit_area := level_generator.exit_area
	if exit_area == null:
		return
	if not exit_area.body_entered.is_connected(_on_exit_zone_entered):
		exit_area.body_entered.connect(_on_exit_zone_entered)


func _connect_flipper_audio() -> void:
	for node in $LevelRoot.find_children("*"):
		if node.is_in_group("player_flippers") and node.has_signal("flipper_hit"):
			if not node.flipper_hit.is_connected(audio.play_flipper):
				node.flipper_hit.connect(audio.play_flipper)


func _on_ball_died() -> void:
	if state != State.PLAYING:
		return
	state = State.DEAD
	audio.play_death()
	camera.add_shake(10.0)
	_show_overlay("You died — press R to retry level %d" % level_index)


func _on_exit_zone_entered(body: Node2D) -> void:
	if state != State.PLAYING:
		return
	if body.is_in_group("ball"):
		ball.reached_exit.emit()


func _on_ball_reached_exit() -> void:
	if state != State.PLAYING:
		return
	state = State.TRANSITION
	audio.play_complete()
	_show_overlay("Level %d complete!" % level_index)
	await get_tree().create_timer(0.6).timeout
	if state == State.TRANSITION:
		_start_level(true)


func _show_overlay(text: String) -> void:
	overlay_label.text = text
	overlay.show()


func _update_hud() -> void:
	status_label.text = "Pin Down — Level %d  |  Hold Space/Z/Click: flippers" % level_index
	hint_label.text = "Descend to the gold EXIT gate. Avoid red spikes."
