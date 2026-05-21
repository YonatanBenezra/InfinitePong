extends RigidBody2D
## Physics ball: momentum-based movement with stability clamps + trail.
##
## - max_speed: hard cap on velocity magnitude to keep the physics stable.
## - min_speed_when_moving: if the ball is moving but slower than this,
##   it gets a tiny nudge in its current direction to avoid resting.
## - spawn_impulse: initial downward+sideways push so the ball is never
##   stuck on the very first frame.

@export var max_speed: float = 1900.0
@export var min_falling_speed: float = 90.0
@export var min_horizontal_drift: float = 30.0
@export var radius: float = 13.0
@export var ball_color: Color = Color(1.0, 0.97, 0.78)
@export var ball_glow_color: Color = Color(1.0, 0.85, 0.35, 0.5)
@export var outline_color: Color = Color(0.1, 0.12, 0.22)
@export var hit_cooldown: float = 0.05
## Above this speed at the moment of impact, the contact is treated as a
## ricochet (distinct audio cue) rather than a generic thud.
@export var ricochet_speed_threshold: float = 720.0
@export var trail_length: int = 14
@export var trail_color: Color = Color(1.0, 0.9, 0.45, 0.55)
@export var spawn_impulse: Vector2 = Vector2(0, 120)

var _trail_points: Array[Vector2] = []
var _last_hit_time: float = -1.0


func _ready() -> void:
	add_to_group("ball")
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var v := state.linear_velocity
	# Hard speed cap so high-force flippers cannot blow the simulation up.
	var sp := v.length()
	if sp > max_speed:
		state.linear_velocity = v.normalized() * max_speed
		v = state.linear_velocity
	# Anti-rest nudge: if the ball is essentially stationary, give it
	# a small downward kick so gravity has something to amplify and
	# the player is never permanently stuck on a flat ledge.
	if absf(v.y) < min_falling_speed and absf(v.x) < min_horizontal_drift:
		state.linear_velocity.y += min_falling_speed * 6.0 * state.step
		state.linear_velocity.x += (randf() - 0.5) * min_horizontal_drift * 4.0 * state.step


func _process(_delta: float) -> void:
	_trail_points.push_front(global_position)
	if _trail_points.size() > trail_length:
		_trail_points.resize(trail_length)
	queue_redraw()


func reset_ball(at_global: Vector2) -> void:
	# Cleanly reset position + velocity. Freeze briefly so the engine
	# doesn't re-solve old contacts on the next physics frame.
	freeze = true
	global_position = at_global
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_rotation = 0.0
	freeze = false
	# Tiny initial impulse so the ball is in motion immediately.
	linear_velocity = spawn_impulse + Vector2((randf() - 0.5) * 60.0, 0.0)
	_last_hit_time = -1.0
	_trail_points.clear()


func _on_body_entered(_body: Node) -> void:
	# Audio cue for impacts; uses cooldown so successive contacts don't spam.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hit_time < hit_cooldown:
		return
	_last_hit_time = now
	var speed := linear_velocity.length()
	if speed >= ricochet_speed_threshold:
		GameEvents.ball_ricochet.emit(speed)
	else:
		GameEvents.ball_hit.emit(speed)


func _draw() -> void:
	# Trail (oldest = most faded + smallest).
	var n := _trail_points.size()
	for i in range(n - 1, 0, -1):
		var t := float(i) / float(maxi(n - 1, 1))
		var alpha := (1.0 - t) * trail_color.a
		var r := radius * (1.0 - t * 0.85)
		var p := to_local(_trail_points[i])
		var c := Color(trail_color.r, trail_color.g, trail_color.b, alpha)
		draw_circle(p, r, c)
	# Outer glow.
	draw_circle(Vector2.ZERO, radius + 4.0, ball_glow_color)
	# Ball body.
	draw_circle(Vector2.ZERO, radius, ball_color)
	# Outline.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, outline_color, 2.0, true)
