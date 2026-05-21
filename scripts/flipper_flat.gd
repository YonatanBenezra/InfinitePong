<<<<<<< HEAD
extends AnimatableBody2D
## Flat flipper: translates as a rigid plate between rest and active offset.
##
## active_offset = the displacement applied when the flipper is pressed.
## A negative Y means an upward pop (the normal case). Positive Y would
## slam the plate downward, which is rejected — the kick impulse is always
## clamped to be non-downward so pressing flip never launches the ball
## straight into the floor.
##
## On the press edge, applies an instantaneous impulse to any ball within
## contact range, in the active_offset direction.

@export var active_offset: Vector2 = Vector2(0, -90)
@export var move_speed: float = 3000.0
@export var kick_impulse: float = 820.0
@export var contact_radius: float = 100.0

var _rest_local: Vector2
var _was_active: bool = false


func _ready() -> void:
	add_to_group("player_flippers")
	sync_to_physics = false
	_rest_local = position


func _physics_process(delta: float) -> void:
	var active := Input.is_action_pressed("flipper")
	if active and not _was_active:
		GameEvents.flipper_fired.emit()
		_apply_kick_to_overlapping_ball()
	_was_active = active
	var target := _rest_local + active_offset if active else _rest_local
	position = position.move_toward(target, move_speed * delta)


func _apply_kick_to_overlapping_ball() -> void:
	var balls := get_tree().get_nodes_in_group("ball")
	if balls.is_empty():
		return
	var ball := balls[0] as RigidBody2D
	if ball == null:
		return
	if ball.global_position.distance_to(global_position) > contact_radius:
		return
	var dir := active_offset.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	# Safety: a flat flipper press must never push the ball downward into
	# the floor. If the configured offset is downward, kick in the direction
	# the ball is already going relative to the plate (most likely upward
	# off the plate's contact).
	if dir.y > 0.0:
		var to_ball := (ball.global_position - global_position)
		if to_ball.length() > 0.001:
			dir = to_ball.normalized()
		else:
			dir = Vector2.UP
		# Final clamp: even a near-horizontal kick is fine, but no pure-down.
		dir.y = minf(dir.y, 0.0)
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		dir = dir.normalized()
	ball.linear_velocity += dir * kick_impulse
=======
class_name FlatFlipper
extends Node2D

signal flipper_hit

enum RestPose { LOWERED, RAISED }

@export var rest_pose: RestPose = RestPose.RAISED
@export var lowered_offset := Vector2(0, 28)
@export var raised_offset := Vector2(0, -8)
@export var move_speed: float = 20.0
@export var push_strength: float = 560.0

@onready var platform: AnimatableBody2D = $Platform
@onready var push_area: Area2D = $Platform/PushArea

var _rest_local: Vector2
var _active_local: Vector2
var _prev_position: Vector2


func _ready() -> void:
	platform.add_to_group("flipper_body")
	_rest_local = lowered_offset if rest_pose == RestPose.LOWERED else raised_offset
	_active_local = raised_offset if rest_pose == RestPose.LOWERED else lowered_offset
	platform.position = _rest_local
	_prev_position = platform.position
	push_area.body_entered.connect(_on_push_body_entered)


func _physics_process(delta: float) -> void:
	var target := _active_local if Input.is_action_pressed("flipper") else _rest_local
	platform.position = platform.position.lerp(target, move_speed * delta)
	var move_delta := (platform.position - _prev_position).length() / maxf(delta, 0.001)
	_prev_position = platform.position
	if Input.is_action_pressed("flipper") and move_delta > 40.0:
		_try_hit_nearby_balls(move_delta)


func _on_push_body_entered(body: Node2D) -> void:
	if not Input.is_action_pressed("flipper"):
		return
	_apply_hit(body as RigidBody2D, 1.0)


func _try_hit_nearby_balls(move_rate: float) -> void:
	for node in get_tree().get_nodes_in_group("ball"):
		if node is RigidBody2D:
			var ball := node as RigidBody2D
			if ball.global_position.distance_to(platform.global_position) < 90.0:
				_apply_hit(ball, clampf(move_rate * 0.02, 0.7, 1.5))


func _apply_hit(ball: RigidBody2D, power_scale: float) -> void:
	if ball == null or not ball.is_in_group("ball"):
		return
	var push_dir := Vector2.UP if _active_local.y < _rest_local.y else Vector2.DOWN
	if rest_pose == RestPose.RAISED and Input.is_action_pressed("flipper"):
		push_dir = Vector2.DOWN
	ball.apply_central_impulse(push_dir * push_strength * power_scale)
	flipper_hit.emit()
>>>>>>> 3baf8dd182d1f8559ff606cfad718104a3199c39
