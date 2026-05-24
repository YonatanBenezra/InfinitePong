extends AnimatableBody2D
## Classic pinball flipper: rotates around its origin (the pivot).
##
## Two modes (designer-facing):
##  - Default (upward swing):    rest_angle_deg > active_angle_deg.
##    Bar hangs down, pressing swings it up. This is the classic flipper.
##  - Inverted (downward swing): rest_angle_deg < active_angle_deg.
##    Bar starts raised (often blocking the path), pressing drops it.
##
## The kick direction follows the actual swing automatically — no need to
## reconfigure it for the inverted case. For a right-side flipper, set
## `mirror = true` so the swing mirrors in world space while still using
## the same angle conventions.
##
## Reliability:
##  - sync_to_physics = true so the moving bar transfers real momentum to
##    the ball through the physics solver every step instead of teleporting
##    through a fast-moving ball.
##  - The assist kick fires once per press at ANY point during the swing,
##    so a ball that arrives mid-swing is still launched — not only a ball
##    that happened to be touching on the exact press frame.

@export_group("Geometry")
## Rest rotation in degrees (the angle when the flipper is NOT held).
## For a default left-side flipper this is positive (bar hangs down-right).
@export_range(-180.0, 180.0, 1.0) var rest_angle_deg: float = 30.0
## Active rotation in degrees (the angle when the flipper IS held).
## For a default left-side flipper this is negative (bar swings up).
@export_range(-180.0, 180.0, 1.0) var active_angle_deg: float = -52.0
## Length of the bar in pixels. Used by the assist kick to find the
## leverage point and to know where the bar tip is.
@export_range(20.0, 240.0, 2.0) var bar_length: float = 96.0
## Mirror the swing for a right-side flipper. Both rest and active angles
## get negated, so you can keep using the same conventions on both sides.
@export var mirror: bool = false

@export_group("Motion")
## Swing speed in degrees per second.
@export_range(120.0, 2400.0, 30.0) var flick_speed_deg: float = 900.0

@export_group("Kick")
## Velocity bonus added to the ball when the bar kicks it.
@export_range(100.0, 2000.0, 20.0) var kick_impulse: float = 640.0
## How close the ball has to be to the bar (in pixels) to receive the
## assist kick.
@export_range(16.0, 96.0, 2.0) var contact_radius: float = 44.0

var _was_active: bool = false
var _kicked_this_press: bool = false


func _ready() -> void:
	add_to_group("player_flippers")
	# sync_to_physics lets the bar push the RigidBody ball reliably.
	sync_to_physics = true
	rotation_degrees = _eff_rest()


func _eff_rest() -> float:
	return -rest_angle_deg if mirror else rest_angle_deg


func _eff_active() -> float:
	return -active_angle_deg if mirror else active_angle_deg


func _physics_process(delta: float) -> void:
	var active := Input.is_action_pressed("flipper")
	if active and not _was_active:
		GameEvents.flipper_fired.emit()
		_kicked_this_press = false
	if not active:
		_kicked_this_press = false
	_was_active = active

	var target_deg := _eff_active() if active else _eff_rest()
	# Assist kick: any frame during the swing where the ball is in contact,
	# fired at most once per press.
	if active and not _kicked_this_press and not is_equal_approx(rotation_degrees, target_deg):
		if _try_kick_overlapping_ball():
			_kicked_this_press = true
	rotation_degrees = move_toward(rotation_degrees, target_deg, flick_speed_deg * delta)


func _try_kick_overlapping_ball() -> bool:
	var balls := get_tree().get_nodes_in_group("ball")
	if balls.is_empty():
		return false
	var ball := balls[0] as RigidBody2D
	if ball == null:
		return false
	var bar_origin := global_position
	var bar_dir := Vector2.RIGHT.rotated(global_rotation)
	var to_ball := ball.global_position - bar_origin
	var along := clampf(to_ball.dot(bar_dir), 0.0, bar_length)
	var closest := bar_origin + bar_dir * along
	var offset := ball.global_position - closest
	var dist := offset.length()
	if dist > contact_radius:
		return false
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
	# Safety: only clamp the downward (positive Y) component for default
	# upward-swinging flippers — for inverted flippers, swinging downward
	# IS the intent, so let the kick follow the swing direction freely.
	var swings_upward := swing_sign < 0.0
	if swings_upward and kick_dir.y > 0.35:
		kick_dir.y = 0.35
		kick_dir = kick_dir.normalized()
	# Tip of the bar has more leverage than the base.
	var leverage := lerpf(0.55, 1.0, along / bar_length)
	ball.linear_velocity += kick_dir * kick_impulse * leverage
	return true
