extends AnimatableBody2D
## Standard pinball flipper: rotates around its origin (the pivot).
##
## Convention (matches real pinball):
##  - At rest, bar hangs DOWN from pivot (rest_angle_deg > 0 = tilted below
##    the local horizontal).
##  - When pressed, bar swings UP (active_angle_deg < 0 = tilted above
##    the local horizontal).
##  - For a right-side flipper, set mirror=true so the bar swings in the
##    opposite world direction while still appearing to flick upward.
##
## - flick_speed_deg controls how fast the bar moves between rest/active.
## - On the press edge, applies a single impulse to any ball touching the
##   bar so the flick feels like a real kick beyond pure kinematic motion.

@export var rest_angle_deg: float = 30.0
@export var active_angle_deg: float = -52.0
@export var flick_speed_deg: float = 2800.0
@export var kick_impulse: float = 760.0
@export var contact_radius: float = 34.0
@export var bar_length: float = 96.0
@export var mirror: bool = false

var _was_active: bool = false


func _ready() -> void:
	add_to_group("player_flippers")
	sync_to_physics = false
	rotation_degrees = _eff_rest()


func _eff_rest() -> float:
	return -rest_angle_deg if mirror else rest_angle_deg


func _eff_active() -> float:
	return -active_angle_deg if mirror else active_angle_deg


func _physics_process(delta: float) -> void:
	var active := Input.is_action_pressed("flipper")
	if active and not _was_active:
		GameEvents.flipper_fired.emit()
		_apply_kick_to_overlapping_ball()
	_was_active = active
	var target_deg := _eff_active() if active else _eff_rest()
	rotation_degrees = move_toward(rotation_degrees, target_deg, flick_speed_deg * delta)


func _apply_kick_to_overlapping_ball() -> void:
	var balls := get_tree().get_nodes_in_group("ball")
	if balls.is_empty():
		return
	var ball := balls[0] as RigidBody2D
	if ball == null:
		return
	var bar_origin := global_position
	var bar_dir := Vector2.RIGHT.rotated(global_rotation)
	var to_ball := ball.global_position - bar_origin
	var along := clampf(to_ball.dot(bar_dir), 0.0, bar_length)
	var closest := bar_origin + bar_dir * along
	var offset := ball.global_position - closest
	var dist := offset.length()
	if dist > contact_radius:
		return
	# Direction of the bar tip's motion during the upward swing.
	var swing_sign := signf(_eff_active() - _eff_rest())
	if swing_sign == 0.0:
		swing_sign = -1.0
	var swing_normal := bar_dir.rotated(PI * 0.5 * swing_sign)
	# Prefer kicking the ball AWAY from the bar surface (in the half-plane
	# the ball is on), but bias toward the swing direction. This protects
	# against pushing a ball INTO the bar when it's barely overlapping.
	var away_dir: Vector2 = offset.normalized() if dist > 0.001 else swing_normal
	var kick_dir := (away_dir + swing_normal).normalized()
	# Safety: a flipper should never push the ball straight down. Cap the
	# downward (positive Y) component so even degenerate geometry stays sane.
	if kick_dir.y > 0.35:
		kick_dir.y = 0.35
		kick_dir = kick_dir.normalized()
	# Tip of the bar has more leverage than the base.
	var leverage := lerpf(0.55, 1.0, along / bar_length)
	ball.linear_velocity += kick_dir * kick_impulse * leverage
