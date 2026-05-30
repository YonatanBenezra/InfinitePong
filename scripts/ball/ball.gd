extends RigidBody2D
## Physics ball: momentum-based rolling movement with stability clamps + trail.
##
## Design intent (rolling, not pinball):
##  - Low restitution + high friction in the PhysicsMaterial so the ball
##    grips surfaces and naturally rolls instead of skipping.
##  - Per-step, contact-aware sliding: shallow / slow contacts have their
##    residual normal velocity damped so the ball slides along the slope
##    instead of micro-bouncing. Steep, fast contacts keep the full
##    elastic bounce so flipper kicks and wall ricochets still feel
##    snappy.
##  - A patient stuck-timer replaces the old per-frame anti-rest nudge:
##    only after the ball has truly stopped for ~0.4 s does a tiny
##    downward kick fire, so flat ledges still resolve but rolling does
##    not get jittered by random horizontal pushes.
##  - max_speed: hard cap on velocity magnitude to keep the physics stable.
##  - spawn_impulse: initial downward+sideways push so the ball is never
##    stuck on the very first frame.

@export var max_speed: float = 900.0
## Hard cap on spin so a strong glancing hit can't set the ball spinning
## wildly. Bumped up vs. the old value because we now want the ball to
## actually look like it's rolling — friction will give it real spin.
@export var max_angular_speed: float = 28.0
## After this long sitting essentially still, a tiny gravity-aligned
## nudge fires so the ball never gets permanently parked on a flat
## ledge. Replaces the old per-frame jitter so a slowly rolling ball is
## NOT yanked around.
@export var stuck_release_seconds: float = 0.4
## Speed below which the stuck timer counts up.
@export var stuck_speed_threshold: float = 18.0
## Per-step velocity added downward once the stuck timer trips. Small
## on purpose — gravity does the heavy lifting after the first nudge.
@export var stuck_release_impulse: float = 90.0
@export var radius: float = 6.5
@export var ball_color: Color = Color(1.0, 0.97, 0.78)
@export var ball_glow_color: Color = Color(1.0, 0.85, 0.35, 0.5)
@export var outline_color: Color = Color(0.1, 0.12, 0.22)
@export var hit_cooldown: float = 0.12
## Above this speed at the moment of impact, the contact is treated as a
## ricochet (distinct audio cue) rather than a generic thud.
@export var ricochet_speed_threshold: float = 675.0
## Trail point capacity. Higher = longer streak. Each _process tick
## records the ball's current position, so trail length in seconds is
## roughly trail_length / frame_rate.
@export var trail_length: int = 28
## Trail thickness at the ball end. Tapers to ~0 at the tail.
@export var trail_width: float = 4.0
@export var trail_color: Color = Color(1.0, 0.9, 0.45, 0.7)
@export var spawn_impulse: Vector2 = Vector2(0, 90)

## A contact whose normal makes a smaller angle than this with the ball's
## incoming velocity is treated as a SHALLOW (slide) contact. Computed
## as |v · n| / |v|: 0 = velocity parallel to surface, 1 = head-on.
## 0.72 ≈ 44° — anything shallower than that rolls/slides instead of
## bouncing, anything steeper keeps its full elastic bounce.
@export var slide_perpendicularity_threshold: float = 0.72
## A slow impact (post-bounce normal speed below this) is always treated
## as a slide regardless of angle, so the ball can settle into a roll on
## flat or gently-angled ledges without jittering.
@export var slide_speed_threshold: float = 180.0

var _trail_points: Array[Vector2] = []
var _last_hit_time: float = -1.0
var _skin: Dictionary = {}
var _skin_time: float = 0.0
## Tracks how long the ball has been sitting essentially still. While
## > stuck_release_seconds the integrate-forces step injects a tiny
## downward velocity so the player can always make progress on flat
## terrain. Reset to 0 the moment real motion returns.
var _stuck_timer: float = 0.0
## Set by a glue hazard when it captures the ball. While non-null, the
## ball renders an aim trail toward the mouse so the player can pick
## a launch direction.
var _glue_owner: Node = null
## Sprite2D body visual (sprite_03), shown as the default WHITE ball. Custom
## (unlocked) skins still paint procedurally via BallSkinRenderer; the sprite
## is hidden whenever one is equipped. See _use_sprite() / _update_body_visual().
var _ball_sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("ball")
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	_ball_sprite = get_node_or_null("BallSprite")
	if _ball_sprite != null and _ball_sprite.texture != null:
		# Centre on the body and match the collision radius. Tinted pure white
		# (Color.WHITE modulate) so the ball always reads as white.
		_ball_sprite.modulate = Color.WHITE
		var fit := (radius * 2.0) / float(_ball_sprite.texture.get_width())
		_ball_sprite.scale = Vector2(fit, fit)
	_update_body_visual()
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

	# Contact-aware response. The physics solver has already reflected
	# our velocity off any contacted surface this step (PhysicsMaterial
	# bounce keeps a real pop for genuine ricochets). For shallow / slow
	# contacts we want a pure SLIDE — roll/skim along the surface with
	# no normal residue — so we project out the outward-normal component.
	# For steep / fast contacts we leave the reflected velocity alone so
	# flipper kicks and wall ricochets still feel snappy.
	var contact_count := state.get_contact_count()
	if contact_count > 0 and v.length_squared() > 1.0:
		var changed := false
		for i in contact_count:
			var n := state.get_contact_local_normal(i)
			if n == Vector2.ZERO:
				continue
			var v_normal := v.dot(n)
			if v_normal <= 0.0:
				continue  # already heading into / parallel to the surface
			var v_len := v.length()
			var perpendicularity: float = v_normal / v_len  # 0=tangent, 1=head-on
			var steep := perpendicularity > slide_perpendicularity_threshold
			var fast := v_normal > slide_speed_threshold
			if steep and fast:
				continue  # genuine bounce — let it ride
			# Slide: strip the outward-normal component, keep tangent.
			# Mild residual normal pop (5%) prevents the ball from
			# being glued to the surface and missing the next gravity
			# integration when the contact is a ledge corner.
			v = v - n * v_normal * 0.95
			changed = true
		if changed:
			state.linear_velocity = v

	# Patient anti-rest nudge: only kick the ball when it has truly
	# stopped moving for a sustained moment. The old per-frame jitter
	# is what made shallow rolls feel chaotic — this never fires while
	# the ball is rolling.
	if v.length() < stuck_speed_threshold:
		_stuck_timer += state.step
		if _stuck_timer >= stuck_release_seconds:
			state.linear_velocity.y += stuck_release_impulse * state.step
			# Reset partway so we re-arm if the ball settles again.
			_stuck_timer = stuck_release_seconds * 0.5
	else:
		_stuck_timer = 0.0


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
	_update_body_visual()
	queue_redraw()


## True when the white sprite_03 body should be shown: no skin, or the
## default "classic" skin (which is just a white ball). Any other equipped
## skin uses the procedural BallSkinRenderer instead.
func _use_sprite() -> bool:
	return _ball_sprite != null and _ball_sprite.texture != null \
		and (_skin.is_empty() or String(_skin.get("id", "")) == "classic")


func _update_body_visual() -> void:
	if _ball_sprite != null:
		_ball_sprite.visible = _use_sprite()


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
	_stuck_timer = 0.0
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
	_draw_trail()
	# Body visual. Default / "classic" → the white sprite_03 node renders it
	# (nothing to draw here). Custom skins paint procedurally. If the sprite
	# texture is somehow missing we fall back to the old plain circle.
	if _use_sprite():
		pass
	elif _skin.is_empty():
		draw_circle(Vector2.ZERO, radius + 4.0, ball_glow_color)
		draw_circle(Vector2.ZERO, radius, ball_color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, outline_color, 2.0, true)
	else:
		BallSkinRenderer.paint(self, _skin, radius, _skin_time, rotation)
	# Glue aim trail — drawn on top so the player always sees where the
	# ball will launch, even when the body is mid-skin animation.
	if _glue_owner != null and is_instance_valid(_glue_owner):
		_draw_glue_aim()


## Continuous fading line trail. Each consecutive pair of trail samples
## is drawn as one antialiased segment whose width tapers and whose alpha
## falls off toward the tail. This reads as a smooth painted ribbon
## instead of the old dot string, and inherits its colour from the
## active ball skin (apply_skin overwrites trail_color).
func _draw_trail() -> void:
	var n := _trail_points.size()
	if n < 2:
		return
	# Front of the array is the newest sample (see _process). Render from
	# tail to head so the brightest, thickest segment sits closest to the
	# ball and naturally overlaps the older fainter ones.
	for i in range(n - 1, 0, -1):
		# t = 0 at the freshest segment, t ≈ 1 at the oldest.
		var t := float(i) / float(n - 1)
		var ease_t := t * t                       # cubic-ish falloff feels softer
		var alpha := (1.0 - ease_t) * trail_color.a
		if alpha <= 0.01:
			continue
		var width: float = maxf(trail_width * (1.0 - t * 0.85), 0.5)
		var c := Color(trail_color.r, trail_color.g, trail_color.b, alpha)
		var p_new := to_local(_trail_points[i - 1])
		var p_old := to_local(_trail_points[i])
		draw_line(p_old, p_new, c, width, true)


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
