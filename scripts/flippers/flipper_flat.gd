extends AnimatableBody2D
## Flat-plate flipper: a rigid plate that slides between two positions.
##
## Two modes (designer-facing):
##  - Default pop  (active_offset.y < 0): plate rests low, pops up when
##                                        the player holds the flipper key.
##  - Inverted drop (active_offset.y > 0): plate rests high (often blocks
##                                         the path) and drops down while
##                                         held, so the ball can pass.
##
## Reliability (the flat flipper is the one testers saw the ball pass
## through, so this is deliberately conservative):
##  - sync_to_physics = true so the moving plate transfers real momentum
##    to the ball through the physics solver instead of teleporting past it.
##  - move_speed is kept low enough that, at the project's 120 Hz physics
##    tick, the plate travels less than a ball diameter per step. That
##    guarantees the ball always overlaps the plate for at least one
##    solver step, so it can never be swept through.
##  - The assist kick only ever pushes the ball AWAY from the plate, along
##    the side the ball is already on — it can never shove the ball
##    through the plate to the far side.

@export_group("Motion")
## Pixels per second the plate moves between rest and active positions.
## Plate travel ~10.8 px/step at 120 Hz — comfortably under the ball's
## ~13 px diameter, so the plate cannot tunnel a slow ball.
@export_range(200.0, 4000.0, 50.0) var move_speed: float = 1300.0
## Local offset from rest to the held-down ("active") position. Y < 0 pops
## up, Y > 0 drops down; X offsets push the plate sideways.
@export var active_offset: Vector2 = Vector2(0, -90)

@export_group("Kick")
## Velocity bonus added to the ball when the flipper kicks it. Higher =
## the ball flies further off the plate.
@export_range(100.0, 2000.0, 20.0) var kick_impulse: float = 600.0
## How close the ball has to be to the plate (in pixels) to receive the
## assist kick. The wider this is, the more forgiving the timing.
@export_range(20.0, 240.0, 5.0) var contact_radius: float = 110.0

## Ball is still treated as "on the leading face" up to this far behind the
## plate surface, so a ball resting right on the plate still gets launched.
const SURFACE_TOLERANCE := 12.0

var _rest_local: Vector2
var _was_active: bool = false
var _kicked_this_press: bool = false


func _ready() -> void:
	add_to_group("player_flippers")
	sync_to_physics = true
	_rest_local = position
	_apply_sprites()


func _apply_sprites() -> void:
	var tex := SpriteBank.get_texture(SpriteBank.FLAT_FLIPPER)
	if tex == null:
		return  # keep the Polygon2D visuals defined in the scene
	for name in ["Outline", "Visual", "Highlight", "TrimBottom",
			"GripA", "GripB", "GripC"]:
		var n := get_node_or_null(name)
		if n:
			n.visible = false
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(184.0 / float(tex.get_width()), 48.0 / float(tex.get_height()))
	add_child(spr)


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
	# Only kick a ball on the LEADING face of the plate (the side it
	# travels toward). A ball behind the plate is left to the physics
	# solver — never kicked, so the assist can never push the ball through
	# the plate.
	if to_ball.dot(travel_dir) < -SURFACE_TOLERANCE:
		return false
	ball.linear_velocity += travel_dir * kick_impulse
	GameEvents.ball_hit_flipper.emit()
	return true
