class_name StandardFlipper
extends Node2D

signal flipper_hit

enum RestPose { LOWERED, RAISED }

@export var rest_pose: RestPose = RestPose.LOWERED
@export var rest_degrees: float = 25.0
@export var active_degrees: float = -35.0
@export var rotate_speed: float = 16.0
@export var impulse_strength: float = 620.0

@onready var arm: AnimatableBody2D = $Arm
@onready var tip_area: Area2D = $Arm/TipArea

var _prev_rotation: float = 0.0
var _flipper_pressed: bool = false


func _ready() -> void:
	arm.add_to_group("flipper_body")
	tip_area.body_entered.connect(_on_contact)
	_apply_angle(_rest_angle())
	_prev_rotation = arm.rotation


func _physics_process(delta: float) -> void:
	_flipper_pressed = Input.is_action_pressed("flipper")
	var target := _active_angle() if _flipper_pressed else _rest_angle()
	arm.rotation = lerp_angle(arm.rotation, deg_to_rad(target), rotate_speed * delta)
	var spin_rate := absf(arm.rotation - _prev_rotation) / maxf(delta, 0.001)
	_prev_rotation = arm.rotation
	if _flipper_pressed and spin_rate > 0.5:
		_try_hit_nearby_balls(spin_rate)


func _rest_angle() -> float:
	return rest_degrees if rest_pose == RestPose.LOWERED else active_degrees


func _active_angle() -> float:
	return active_degrees if rest_pose == RestPose.LOWERED else rest_degrees


func _apply_angle(deg: float) -> void:
	arm.rotation_degrees = deg


func _on_contact(body: Node2D) -> void:
	if not _flipper_pressed:
		return
	_apply_hit(body as RigidBody2D, 1.0)


func _try_hit_nearby_balls(spin_rate: float) -> void:
	for node in get_tree().get_nodes_in_group("ball"):
		if node is RigidBody2D:
			var ball := node as RigidBody2D
			if ball.global_position.distance_to(arm.global_position) < 100.0:
				_apply_hit(ball, clampf(spin_rate * 0.35, 0.6, 1.4))


func _apply_hit(ball: RigidBody2D, power_scale: float) -> void:
	if ball == null or not ball.is_in_group("ball"):
		return
	var dir := Vector2.UP.rotated(arm.global_rotation)
	var spin_boost := absf(arm.rotation - _prev_rotation) * 120.0
	ball.apply_central_impulse(dir * impulse_strength * power_scale + dir * spin_boost)
	flipper_hit.emit()
