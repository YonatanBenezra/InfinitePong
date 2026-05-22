extends AnimatableBody2D
## Flat flipper: translates as a rigid plate between rest and active offset.
##
## Two modes (GDD: hold-to-activate, with two starting positions):
##  - Default pop (active_offset.y < 0): plate rests low, pops up when held.
##  - Inverted drop (active_offset.y > 0): plate rests high (often blocking
##    the path), drops down when held so the ball can pass.
##
## Reliability (the flat flipper is the one testers saw the ball pass
## through, so this is deliberately conservative):
##  - sync_to_physics = true so the moving plate transfers real momentum to
##    the ball through the physics solver instead of teleporting past it.
##  - move_speed is kept low enough that, at the project's 120 Hz physics
##    tick, the plate travels less than a ball diameter per step. That
##    guarantees the ball always overlaps the plate for at least one solver
##    step, so it can never be swept through.
##  - The assist kick only ever pushes the ball AWAY from the plate, along
##    the side the ball is already on — it can never shove the ball through
##    the plate to the far side.

## Plate travel ~10.8 px/step at 120 Hz — comfortably under the ball's
## ~13 px diameter, so the plate cannot tunnel a slow ball.
@export var move_speed: float = 1300.0
@export var active_offset: Vector2 = Vector2(0, -90)
@export var kick_impulse: float = 600.0
@export var contact_radius: float = 110.0

## Ball is still treated as "on the leading face" up to this far behind the
## plate surface, so a ball resting right on the plate still gets launched.
const SURFACE_TOLERANCE := 12.0

var _rest_local: Vector2
var _was_active: bool = false
var _kicked_this_press: bool = false


func _ready() -> void:
	add_to_group("player_flippers")
	# sync_to_physics lets the plate push the RigidBody ball reliably.
	sync_to_physics = true
	_rest_local = position


func _physics_process(delta: float) -> void:
	var active := Input.is_action_pressed("flipper")
	if active and not _was_active:
		GameEvents.flipper_fired.emit()
		_kicked_this_press = false
	if not active:
		_kicked_this_press = false
	_was_active = active

	var target := _rest_local + active_offset if active else _rest_local
	# Assist kick: any frame during the stroke where the ball is in contact,
	# fired at most once per press.
	if active and not _kicked_this_press and not position.is_equal_approx(target):
		if _try_kick_overlapping_ball():
			_kicked_this_press = true
	position = position.move_toward(target, move_speed * delta)


func _try_kick_overlapping_ball() -> bool:
	var balls := get_tree().get_nodes_in_group("ball")
	if balls.is_empty():
		return false
	var ball := balls[0] as RigidBody2D
	if ball == null:
		return false
	var to_ball := ball.global_position - global_position
	if to_ball.length() > contact_radius:
		return false
	var travel_dir := active_offset.normalized()
	if travel_dir == Vector2.ZERO:
		travel_dir = Vector2.UP
	# Only kick a ball on the LEADING face of the plate (the side it travels
	# toward). A ball behind the plate is left to the physics solver — never
	# kicked, so the assist can never push the ball through the plate.
	if to_ball.dot(travel_dir) < -SURFACE_TOLERANCE:
		return false
	ball.linear_velocity += travel_dir * kick_impulse
	return true
