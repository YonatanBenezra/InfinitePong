@tool
extends Node2D
class_name PathMover
## Reusable path mover: walks this node (and therefore every child) along
## an authored list of waypoints. Drop a PathMover into a scene, give it a
## few points, parent the thing you want to move underneath, done.
##
## Use this for moving hazards, moving platforms, moving flippers, or any
## obstacle that needs scripted path movement.
##
## ── Designer workflow (no code needed) ─────────────────────────────────
##   1. Add a PathMover node to your scene (Add Child → PathMover).
##   2. Move it to where you want the path to START. The PathMover itself
##      is invisible; only its children render.
##   3. In the Inspector, fill in `points` with OFFSETS from that start —
##      e.g. [(0, 0), (200, 0)] for a 200 px horizontal sweep. The first
##      point is the path's start (usually (0, 0)).
##   4. Drop whatever you want moved (HazardSpike, a platform, a flipper,
##      …) as a CHILD of the PathMover. Anything parented inherits the
##      motion automatically.
##   5. Pick a `mode`:
##        LOOP     — after the last point, jump back to the first.
##        PINGPONG — after the last point, walk back to the first.
##        ONESHOT  — stop at the last point.
##      Tweak `speed`, `start_delay` and `wait_time` to taste.
##
## A faint dashed line + dots show the path in-editor and in-game while
## `debug_draw` is on, so you can see what the mover will do without
## launching the game. Turn it off for shipped chunks if you prefer no
## debug overlay.
##
## ── Coexisting with `moving_hazard.gd` ─────────────────────────────────
## The older `scripts/hazards/moving_hazard.gd` (axis + range_px sweep) is
## still supported and used by existing chunks. PathMover is the preferred
## new path-movement primitive for anything more involved than a single
## back-and-forth axis sweep.

enum Mode { LOOP, PINGPONG, ONESHOT }

@export_group("Path")
## Waypoints as OFFSETS from this node's authored position. The first
## point is the path's start (usually (0, 0)). With fewer than 2 points
## the mover doesn't move.
@export var points: Array[Vector2] = []:
	set(value):
		points = value
		if is_inside_tree():
			queue_redraw()
## After the last point: LOOP back to start, PINGPONG reverse direction,
## or ONESHOT stop.
@export var mode: Mode = Mode.LOOP:
	set(value):
		mode = value
		if is_inside_tree():
			queue_redraw()

@export_group("Motion")
## Linear speed along the path in pixels per second.
@export_range(20.0, 1200.0, 5.0) var speed: float = 180.0
## Seconds the mover waits at points[0] before its first move. Stagger
## this between paired movers to set up "pinch" timings.
@export_range(0.0, 10.0, 0.05) var start_delay: float = 0.0
## Seconds the mover pauses at every waypoint before continuing.
@export_range(0.0, 5.0, 0.05) var wait_time: float = 0.0

@export_group("Debug")
## Show the path as dots + lines in the Godot editor and at runtime.
@export var debug_draw: bool = true:
	set(value):
		debug_draw = value
		if is_inside_tree():
			queue_redraw()
## Colour used for the debug overlay. Pick something high-contrast with
## your chunk background.
@export var debug_color: Color = Color(0.98, 0.86, 0.32, 0.85):
	set(value):
		debug_color = value
		if is_inside_tree():
			queue_redraw()


# --- Runtime state -------------------------------------------------------

# Authored position captured on _ready; every point is interpreted as an
# OFFSET from this. Stays at Vector2.ZERO in the editor (where _ready
# returns early), and _draw() compensates for that.
var _origin: Vector2 = Vector2.ZERO
# Index of the start point of the current segment.
var _segment_index: int = 0
# +1 forward through `points`, -1 backward (used by PINGPONG).
var _direction: int = 1
# 0..1 progress along the current segment.
var _segment_t: float = 0.0
# Cached length of the current segment (px) for constant-speed traversal.
var _segment_length: float = 0.0
# Countdown timers for waypoint pauses and the initial start delay.
var _wait_left: float = 0.0
var _delay_left: float = 0.0


func _ready() -> void:
	# In the editor we only want the debug overlay to refresh — the path
	# should not animate while authoring.
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_origin = position
	_segment_index = 0
	_direction = 1
	_delay_left = start_delay
	if not points.is_empty():
		position = _origin + points[0]
	_begin_segment()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if points.size() < 2:
		return
	if _delay_left > 0.0:
		_delay_left = maxf(_delay_left - delta, 0.0)
		return
	if _wait_left > 0.0:
		_wait_left = maxf(_wait_left - delta, 0.0)
		return
	if _segment_length <= 0.001:
		# Degenerate segment (two coincident points). Skip to the next.
		_advance_segment()
		return
	var step := (speed * delta) / _segment_length
	_segment_t += step
	if _segment_t >= 1.0:
		_segment_t = 1.0
		_apply_segment()
		_advance_segment()
		return
	_apply_segment()


# --- Path traversal helpers ---------------------------------------------

func _apply_segment() -> void:
	if points.size() < 2:
		return
	var from := points[_segment_index]
	var to := points[_target_index()]
	position = _origin + from.lerp(to, _segment_t)


func _target_index() -> int:
	var n := points.size()
	var i := _segment_index + _direction
	if i >= n:
		match mode:
			Mode.LOOP:
				return 0
			Mode.PINGPONG:
				return maxi(n - 2, 0)
			Mode.ONESHOT:
				return n - 1
	elif i < 0:
		match mode:
			Mode.LOOP:
				return n - 1
			Mode.PINGPONG:
				return mini(1, n - 1)
			Mode.ONESHOT:
				return 0
	return i


func _begin_segment() -> void:
	_segment_t = 0.0
	if points.size() < 2:
		_segment_length = 0.0
		return
	var from := points[_segment_index]
	var to := points[_target_index()]
	_segment_length = from.distance_to(to)


func _advance_segment() -> void:
	var n := points.size()
	if n < 2:
		return
	var next := _segment_index + _direction
	if next >= n:
		match mode:
			Mode.LOOP:
				_segment_index = 0
			Mode.PINGPONG:
				_direction = -1
				_segment_index = n - 1
			Mode.ONESHOT:
				_segment_index = n - 1
				_segment_length = 0.0
				return
	elif next < 0:
		match mode:
			Mode.LOOP:
				_segment_index = n - 1
			Mode.PINGPONG:
				_direction = 1
				_segment_index = 0
			Mode.ONESHOT:
				_segment_index = 0
				_segment_length = 0.0
				return
	else:
		_segment_index = next
	_wait_left = wait_time
	_begin_segment()


# --- Debug overlay -------------------------------------------------------

func _draw() -> void:
	if not debug_draw or points.is_empty():
		return
	# Offsets are stored relative to `_origin`. In the editor `_origin` is
	# zero, but `position` IS the authored origin — so using `position` as
	# the origin in editor draws the path correctly relative to it.
	# At runtime `_origin` is captured on _ready, and `position - _origin`
	# is the current animated offset; subtracting it keeps the dots
	# anchored to their world positions while the mover travels.
	var origin: Vector2 = _origin if not Engine.is_editor_hint() else position
	var cur_local := position - origin
	var dot_col := debug_color
	var line_col := Color(debug_color.r, debug_color.g, debug_color.b, debug_color.a * 0.65)
	var loop_col := Color(debug_color.r, debug_color.g, debug_color.b, debug_color.a * 0.40)
	# Connecting lines between consecutive points.
	for i in range(points.size() - 1):
		var a := points[i] - cur_local
		var b := points[i + 1] - cur_local
		draw_line(a, b, line_col, 1.6, true)
	# Loop closure dashes — only meaningful when we'll actually travel it.
	if mode == Mode.LOOP and points.size() > 2:
		var a := points[points.size() - 1] - cur_local
		var b := points[0] - cur_local
		draw_dashed_line(a, b, loop_col, 1.2, 8.0)
	# Waypoint dots. The first point is highlighted as the path start.
	for i in points.size():
		var p := points[i] - cur_local
		var r := 7.0 if i == 0 else 5.0
		draw_circle(p, r, dot_col)
		draw_arc(p, r, 0.0, TAU, 16, Color(0, 0, 0, 0.75), 1.2, true)
