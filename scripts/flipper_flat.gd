extends AnimatableBody2D
## Flat flipper: translates as a rigid plate between rest and active offset.
##
## Two modes (GDD: hold-to-activate, with two starting positions):
##  - Default pop (active_offset.y < 0): plate rests low, pops up when held.
##  - Inverted drop (active_offset.y > 0): plate rests high (often blocking
##    the path), drops down when held so the ball can pass.
##
## The kick impulse follows the configured active_offset direction in both
## modes, so an inverted plate gently pushes the ball downward through the
## opening rather than fighting the player's intent.

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
	ball.linear_velocity += dir * kick_impulse
