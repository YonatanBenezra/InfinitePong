extends Control
## Splash loading widget — the player's equipped ball rallied back and forth
## between two flippers, trailing light. A loading indicator that's pure
## PIN DOWN: fully self-drawn, runs its own clock, and shows the default ball.

const PLAY_INSET := 58.0    ## gap from the widget edges to each flipper pivot
const TURN := 27.0          ## how far inside the pivot the ball turns around
const BALL_R := 12.0
const TRIP_SECS := 0.92     ## seconds for one edge-to-edge trip
const TRAIL_LEN := 16

var _skin: Dictionary = {}
var _label: Label
var _t := 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Always the default ball — the splash shows the game's signature look,
	# not whatever cosmetic the player happens to have equipped.
	_skin = BallSkins.get_skin("classic")
	_label = UITheme.make_label("LOADING", 14, UITheme.TEXT_DIM)
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_top = -28.0
	_label.offset_bottom = -2.0
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	_trail.push_front(_ball_pos())
	if _trail.size() > TRAIL_LEN:
		_trail.resize(TRAIL_LEN)
	_label.text = "LOADING" + ".".repeat(int(_t * 2.5) % 4)
	queue_redraw()


## Y of the playfield row — flippers, rail and ball all reference this.
func _rail_y() -> float:
	return size.y * 0.42


## Triangle-wave horizontal sweep with two bounce hops per trip.
func _ball_pos() -> Vector2:
	var span := size.x - (PLAY_INSET + TURN) * 2.0
	var phase := fmod(_t / TRIP_SECS, 2.0)                 # 0 .. 2
	var f: float = phase if phase < 1.0 else 2.0 - phase   # 0 .. 1 .. 0
	var x := PLAY_INSET + TURN + span * f
	var hop := absf(sin(f * PI * 2.0))                     # peaks mid-trip
	return Vector2(x, _rail_y() - 6.0 - hop * 20.0)


## Flick strength 0..1 for a flipper as the ball reaches its side.
func _flick(side: int) -> float:
	var phase := fmod(_t / TRIP_SECS, 2.0)
	var d: float = minf(phase, 2.0 - phase) if side == 0 else absf(phase - 1.0)
	return clampf(1.0 - d * 5.5, 0.0, 1.0)


func _draw() -> void:
	var ac: Color = UITheme.accent
	var ry := _rail_y()
	var x0 := PLAY_INSET
	var x1 := size.x - PLAY_INSET

	# Faint dotted guide rail the ball rallies along.
	draw_line(Vector2(x0, ry + 20.0), Vector2(x1, ry + 20.0),
		Color(ac.r, ac.g, ac.b, 0.12), 2.0)
	for i in 9:
		var gx := lerpf(x0, x1, float(i) / 8.0)
		draw_circle(Vector2(gx, ry + 20.0), 1.4, Color(ac.r, ac.g, ac.b, 0.20))

	# Flippers at each end.
	_draw_flipper(Vector2(x0, ry + 20.0), 0, ac)
	_draw_flipper(Vector2(x1, ry + 20.0), 1, ac)

	# Glowing comet trail behind the ball.
	var tc: Color = _skin.get("trail", Color(1, 1, 1, 0.5))
	for i in _trail.size():
		var k := 1.0 - float(i) / float(TRAIL_LEN)
		draw_circle(_trail[i], BALL_R * (0.28 + 0.55 * k),
			Color(tc.r, tc.g, tc.b, tc.a * k * k * 0.7))

	# The ball itself, drawn through the shared skin renderer.
	var p := _ball_pos()
	draw_set_transform(p, 0.0, Vector2.ONE)
	BallSkinRenderer.paint(self, _skin, BALL_R, _t, _t * 0.7)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws one flipper that rests pointing inward-down and whips up on a hit.
func _draw_flipper(pivot: Vector2, side: int, ac: Color) -> void:
	var e := 1.0 - pow(1.0 - _flick(side), 3.0)            # snappy whip ease
	var dirx := 1.0 if side == 0 else -1.0
	var ang := deg_to_rad(lerpf(30.0, -36.0, e))           # rests down, flicks up
	var tip := pivot + Vector2(cos(ang) * dirx, sin(ang)) * 34.0
	var col := ac.lerp(Color.WHITE, e * 0.7)
	var w := lerpf(7.0, 9.5, e)

	if e > 0.02:                                           # active glow
		draw_line(pivot, tip, Color(col.r, col.g, col.b, 0.28 * e), w + 9.0)
	draw_line(pivot, tip, Color(col.r, col.g, col.b, 0.95), w)
	draw_circle(pivot, w * 0.5 + 1.5, col)
	draw_circle(tip, w * 0.5, col)
	draw_circle(pivot, 3.0, Color(0.05, 0.06, 0.11))       # pivot peg
