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
