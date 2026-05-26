extends RigidBody2D
## Physics ball: momentum-based movement with stability clamps + trail.
##
## - max_speed: hard cap on velocity magnitude to keep the physics stable.
## - min_speed_when_moving: if the ball is moving but slower than this,
##   it gets a tiny nudge in its current direction to avoid resting.
## - spawn_impulse: initial downward+sideways push so the ball is never
##   stuck on the very first frame.

@export var max_speed: float = 900.0
## Hard cap on spin so a strong glancing hit can't set the ball spinning
## wildly (kept low because the ball is a circle — visible spin is noise).
@export var max_angular_speed: float = 18.0
@export var min_falling_speed: float = 33.75
@export var min_horizontal_drift: float = 22.5
@export var radius: float = 6.5
@export var ball_color: Color = Color(1.0, 0.97, 0.78)
@export var ball_glow_color: Color = Color(1.0, 0.85, 0.35, 0.5)
@export var outline_color: Color = Color(0.1, 0.12, 0.22)
@export var hit_cooldown: float = 0.12
## Above this speed at the moment of impact, the contact is treated as a
## ricochet (distinct audio cue) rather than a generic thud.
@export var ricochet_speed_threshold: float = 675.0
@export var trail_length: int = 14
@export var trail_color: Color = Color(1.0, 0.9, 0.45, 0.55)
@export var spawn_impulse: Vector2 = Vector2(0, 90)

var _trail_points: Array[Vector2] = []
var _last_hit_time: float = -1.0
var _skin: Dictionary = {}
var _skin_time: float = 0.0
## Set by a glue hazard when it captures the ball. While non-null, the
## ball renders an aim trail toward the mouse so the player can pick
## a launch direction.
var _glue_owner: Node = null


func _ready() -> void:
	add_to_group("ball")
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var v := state.linear_velocity
	# Hard speed cap so high-force flippers cannot blow the simulation up.
	# Applied every physics step, so it also clamps the ball right after a
	# strong flipper kick or ricochet.
	var sp := v.length()
	if sp > max_speed:
		state.linear_velocity = v.normalized() * max_speed
		v = state.linear_velocity
	# Clamp spin after strong/glancing hits.
	if absf(state.angular_velocity) > max_angular_speed:
		state.angular_velocity = signf(state.angular_velocity) * max_angular_speed
	# Anti-rest nudge: if the ball is essentially stationary, give it
	# a small downward kick so gravity has something to amplify and
	# the player is never permanently stuck on a flat ledge.
	if absf(v.y) < min_falling_speed and absf(v.x) < min_horizontal_drift:
		state.linear_velocity.y += min_falling_speed * 6.0 * state.step
		state.linear_velocity.x += (randf() - 0.5) * min_horizontal_drift * 4.0 * state.step


func _process(delta: float) -> void:
	_skin_time += delta
	_trail_points.push_front(global_position)
	if _trail_points.size() > trail_length:
		_trail_points.resize(trail_length)
	# While stuck in glue, the aim line moves with the mouse — force a
	# redraw every frame so the trail stays anchored to the cursor.
	queue_redraw()


## Called by a glue hazard when it catches the ball. The ball stays
## visually highlighted and renders an aim line toward the mouse cursor
## until exit_glue_aim() is called by the same hazard.
func enter_glue_aim(owner: Node = null) -> void:
	_glue_owner = owner
	queue_redraw()


## Called by the glue hazard when the ball is released.
func exit_glue_aim() -> void:
	_glue_owner = null
	queue_redraw()


## True while a glue hazard currently holds the ball. Other systems (the
## shoot input gate, the camera, …) read this so they don't fire actions
## that don't make sense while the ball is pinned.
func is_glue_stuck() -> bool:
	return _glue_owner != null and is_instance_valid(_glue_owner)


## Applies a cosmetic ball skin. The skin fully defines the ball body and
## its trail colour; called by the game controller on each level start.
func apply_skin(skin: Dictionary) -> void:
	_skin = skin
	if skin.has("trail"):
		trail_color = skin["trail"]


func reset_ball(at_global: Vector2) -> void:
	# Teleport reliably. Setting global_position alone on a RigidBody2D can be
	# overridden by the physics server, leaving the ball at its old spot
	# (the "restart drops me where I died" bug). Driving the physics server
	# state directly guarantees a true full-level restart from the top.
	var impulse := spawn_impulse + Vector2((randf() - 0.5) * 45.0, 0.0)
	global_position = at_global
	global_rotation = 0.0
	linear_velocity = impulse
	angular_velocity = 0.0
	var rid := get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, at_global))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, impulse)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	_last_hit_time = -1.0
	_trail_points.clear()
	# Any previous glue capture is meaningless after a full reset; clearing
	# this stops the aim trail from drawing on a re-spawned ball.
	_glue_owner = null


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
	# Skinned body. Falls back to the plain ball when no skin is applied.
	if _skin.is_empty():
		draw_circle(Vector2.ZERO, radius + 4.0, ball_glow_color)
		draw_circle(Vector2.ZERO, radius, ball_color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, outline_color, 2.0, true)
	else:
		BallSkinRenderer.paint(self, _skin, radius, _skin_time, rotation)
	# Glue aim trail — drawn on top so the player always sees where the
	# ball will launch, even when the body is mid-skin animation.
	if _glue_owner != null and is_instance_valid(_glue_owner):
		_draw_glue_aim()


## Renders a fading dotted trail (with an arrowhead) from the ball toward
## the mouse cursor, indicating the direction the ball will launch when
## the glue is released.
func _draw_glue_aim() -> void:
	var local_mouse := to_local(get_global_mouse_position())
	var dist := local_mouse.length()
	if dist < radius + 4.0:
		return
	var dir := local_mouse / dist
	var aim_len: float = minf(dist, 180.0)
	var step: float = 14.0
	var dot_count: int = maxi(int(aim_len / step), 1)
	for i in range(1, dot_count + 1):
		var t := float(i) / float(dot_count)
		var p := dir * (float(i) * step)
		var c := Color(1.0, 0.95, 0.55, lerpf(0.95, 0.18, t))
		draw_circle(p, lerpf(3.0, 1.4, t), c)
	# Arrowhead at the tip of the trail.
	var tip := dir * aim_len
	var perp := Vector2(-dir.y, dir.x)
	var a := tip - dir * 9.0 + perp * 5.5
	var b := tip - dir * 9.0 - perp * 5.5
	draw_polygon(PackedVector2Array([tip, a, b]),
		PackedColorArray([Color(1.0, 0.95, 0.55, 1.0)]))
