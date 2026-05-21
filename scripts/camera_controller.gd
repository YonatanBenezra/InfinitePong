class_name PinCamera
extends Camera2D

@export var follow_speed: float = 7.0
@export var viewport_center_x: float = 576.0
@export var look_ahead_y: float = 80.0

var target: Node2D
var min_y: float = 0.0
var max_y: float = 10000.0
var _snap_next: bool = false


func set_target(node: Node2D) -> void:
	target = node


func set_level_bounds(top_y: float, bottom_y: float) -> void:
	min_y = top_y
	max_y = bottom_y


func snap_to_target() -> void:
	_snap_next = true


func add_shake(amount: float = 8.0) -> void:
	offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	var tween := create_tween()
	tween.tween_property(self, "offset", Vector2.ZERO, 0.25)


func _physics_process(delta: float) -> void:
	if not target:
		return
	var look_y := clampf(target.global_position.y + look_ahead_y, min_y, max_y)
	var desired := Vector2(viewport_center_x, look_y)
	if _snap_next:
		global_position = desired
		_snap_next = false
	else:
		global_position = global_position.lerp(desired, follow_speed * delta)
