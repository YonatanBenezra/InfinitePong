extends Camera2D
## Follows the ball on Y only; X stays pinned to the arena center.
##
## A small forward lead biases the camera slightly toward where the ball
## is heading so upcoming hazards become visible before they hit. Uses
## frame-rate-independent exponential smoothing so the follow feels stable
## even when the ball briefly tunnels at high speed.

@export var target_path: NodePath
@export var arena_center_x: float = 320.0
@export var smoothing_speed: float = 12.0
@export var look_ahead: float = 0.22
@export var max_look_ahead_px: float = 140.0
@export var max_catchup_distance: float = 320.0

var _target: Node2D
var _lead_smoothed: float = 0.0
var _shake_amount: float = 0.0
var _shake_decay: float = 7.0


func _ready() -> void:
	if target_path:
		_target = get_node_or_null(target_path) as Node2D


func set_target(node: Node2D) -> void:
	_target = node
	if is_instance_valid(_target):
		global_position = Vector2(arena_center_x, _target.global_position.y)
		_lead_smoothed = 0.0


func add_shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var vy := 0.0
	if _target is RigidBody2D:
		vy = (_target as RigidBody2D).linear_velocity.y
	var lead_target := clampf(vy * look_ahead, -max_look_ahead_px * 0.5, max_look_ahead_px)
	_lead_smoothed = lerpf(_lead_smoothed, lead_target, clampf(smoothing_speed * 0.4 * delta, 0.0, 1.0))
	var desired := Vector2(arena_center_x, _target.global_position.y + _lead_smoothed)
	# Cap catch-up so a teleporting ball does not snap the camera violently.
	var dy := desired.y - global_position.y
	if absf(dy) > max_catchup_distance:
		desired.y = global_position.y + signf(dy) * max_catchup_distance
	var t := 1.0 - exp(-smoothing_speed * delta)
	global_position = global_position.lerp(desired, t)
	# Decay shake.
	if _shake_amount > 0.01:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amount
		_shake_amount = maxf(_shake_amount - _shake_decay * delta * (1.0 + _shake_amount), 0.0)
	else:
		offset = Vector2.ZERO
