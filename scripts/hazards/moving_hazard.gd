extends Node2D
## Moves a child node back and forth (ping-pong) along an axis.
##
## Drop this script on any Node2D, point `moving_node_path` at the hazard
## (or anything) you want to wiggle, and tweak the knobs in the Inspector.
## The generator scales `speed` up automatically on later levels (see
## chunk_generator.gd → "hazard_speed_mult"), so you only need to author a
## hazard's BASE speed here.
##
## Geometry: the moving node sweeps from -range_px to +range_px along the
## `axis` direction, anchored at its starting position.
## Easing:   0 = constant speed, 1 = smooth cosine slowdown at endpoints.

@export_group("Motion")
## World-space direction to move along. (1, 0) = horizontal, (0, 1) =
## vertical, (1, 1) = diagonal — gets normalized at runtime.
@export var axis: Vector2 = Vector2.RIGHT
## Half-amplitude in pixels — the node sweeps from -range_px to +range_px.
@export_range(8.0, 600.0, 1.0) var range_px: float = 120.0
## Linear speed in pixels per second when ease_amount is 0. With easing > 0
## this is the AVERAGE speed across one sweep — peak speed is higher.
@export_range(20.0, 800.0, 5.0) var speed: float = 135.0

@export_group("Timing")
## Initial pause before the hazard starts moving. Use different values on
## paired hazards to desync them and create a "pinch" timing.
@export_range(0.0, 5.0, 0.05) var delay_seconds: float = 0.0
## 0 = constant speed (sharp triangle wave).
## 1 = smooth cosine: the hazard slows, stops, and reverses at endpoints.
@export_range(0.0, 1.0, 0.05) var ease_amount: float = 0.6

@export_group("Target")
## Node to move. Defaults to this node (self) when left as ".".
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
	# Sweep period is sized so the AVERAGE speed across the cycle is the
	# configured `speed`, regardless of ease — peak speed scales up with
	# easing, but per-cycle travel time stays predictable for level design.
	var sweep_time := (4.0 * range_px) / maxf(speed, 1.0)
	if sweep_time <= 0.0:
		return
	_phase = fmod(_phase + delta / sweep_time, 1.0)
	# Linear triangle position in [-1, +1].
	var tri := 1.0 - absf(_phase * 2.0 - 1.0) * 2.0
	# Cosine position in [-1, +1] — same endpoints / midpoint as the
	# triangle but with zero velocity at the endpoints, so the hazard
	# genuinely slows and reverses smoothly when ease_amount = 1.
	var cosine_pos := -cos(_phase * TAU)
	var eased := lerpf(tri, cosine_pos, ease_amount)
	var dir := axis.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_moving.position = _origin + dir * eased * range_px
