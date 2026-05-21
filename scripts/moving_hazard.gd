extends Node2D
## Moves a node ping-pong along axis with optional easing.
##
## - axis: world-space direction.
## - range_px: half-amplitude — moves from -range_px to +range_px.
## - speed: linear speed when not eased; with easing > 0 this is peak speed.
## - delay_seconds: initial pause so multiple movers can be desynced.
## - ease_amount: 0 = constant speed, 1 = full cosine ease at endpoints.

@export var axis: Vector2 = Vector2.RIGHT
@export var range_px: float = 120.0
@export var speed: float = 180.0
@export var delay_seconds: float = 0.0
@export_range(0.0, 1.0) var ease_amount: float = 0.6
@export var moving_node_path: NodePath = NodePath(".")

var _moving: Node2D
var _origin: Vector2
var _phase: float = 0.0
var _delay_left: float = 0.0


func _ready() -> void:
	_moving = get_node_or_null(moving_node_path) as Node2D
	if _moving == null:
		_moving = self
	_origin = _moving.position
	_delay_left = delay_seconds


func _physics_process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	# Advance phase across a full sweep cycle [0, 2*range_px] then mirror.
	# Sweep period is sized so the average speed across the cycle is the
	# configured `speed`, regardless of ease — peak speed scales up with
	# easing, but per-cycle travel time stays predictable for level design.
	var sweep_time := (4.0 * range_px) / maxf(speed, 1.0)
	if sweep_time <= 0.0:
		return
	_phase = fmod(_phase + delta / sweep_time, 1.0)
	# Linear triangle position in [-1, +1].
	var tri := 1.0 - absf(_phase * 2.0 - 1.0) * 2.0
	# Cosine position in [-1, +1] — same endpoints/midpoint as the triangle
	# but with zero velocity at the endpoints, so the hazard genuinely slows
	# and reverses smoothly when ease_amount = 1.
	var cosine_pos := -cos(_phase * TAU)
	var eased := lerpf(tri, cosine_pos, ease_amount)
	var dir := axis.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_moving.position = _origin + dir * eased * range_px
