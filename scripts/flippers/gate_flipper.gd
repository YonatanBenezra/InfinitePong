extends AnimatableBody2D
## GATE flipper (the "flat flipper") - fully INDEPENDENT of the big slider
## (scripts/flippers/flipper_flat.gd). Editing this file has no effect on the
## big slider and vice-versa.
##
## Two upright bars (one instance each) that SLIDE APART horizontally when the
## flipper key is held, then slide back together. They NEVER rotate or tilt.
##   Rest:  []   bars together, plungers facing the centre seam.
##   Held:  [  ] each bar slides outward by open_offset, staying upright.
##
## Built two-part: the slotted bar (sprite_06) + three plungers
## (sprite_08/09/10) seated as CHILDREN in the bar's slots, so they ride along
## with the bar and stay seated (they are never repositioned by this script).

@export_group("Motion")
## How far each bar slides OUTWARD (away from the centre seam) when held, px.
@export_range(0.0, 200.0, 2.0) var open_offset: float = 44.0
## Slide speed in pixels per second (used opening and closing).
@export_range(200.0, 4000.0, 50.0) var slide_speed: float = 520.0
## Kick direction only (which way a contacted ball is launched). Does not move
## the bar; the bar slides via open_offset.
@export var active_offset: Vector2 = Vector2(-90, 0)

@export_group("Kick")
## Velocity bonus added to a nearby ball when the flipper is pressed.
@export_range(100.0, 2000.0, 20.0) var kick_impulse: float = 450.0
## How close the ball has to be (px) to receive the kick.
@export_range(20.0, 240.0, 5.0) var contact_radius: float = 110.0

@export_group("Plungers")
## Plunger length as a fraction of the bar height (1.0 = the full bar).
@export_range(0.5, 1.0, 0.01) var plunger_length_ratio: float = 0.9
## Plunger width as a multiple of the bar's slot width (1.0 = fills the slot).
@export_range(0.6, 2.0, 0.05) var plunger_width_fill: float = 1.15

const BAR_TEX := "res://assets/sprite_06.png"
const PLUNGER_TEX: Array[String] = [
	"res://assets/sprite_08.png",
	"res://assets/sprite_09.png",
	"res://assets/sprite_10.png",
]
const BAR_TEX_W := 114.0
const BAR_TEX_H := 37.0
## Slot centres in bar texels.
const SLOT_TEX_X: Array[float] = [26.5, 56.5, 86.5]
## Slot width in bar texels (the channel each plunger fills).
const SLOT_TEX_W := 8.0
const POLY_NODES := ["Outline", "Visual", "Highlight", "TrimBottom",
		"GripA", "GripB", "GripC"]

## Ball is still treated as "on the leading face" up to this far behind the
## plate surface, so a ball resting right on the plate still gets launched.
const SURFACE_TOLERANCE := 12.0

var _rest_local: Vector2
var _rest_rotation: float = 0.0
var _was_active: bool = false
var _kicked_this_press: bool = false
var _plungers: Array[Sprite2D] = []


func _ready() -> void:
	add_to_group("player_flippers")
	sync_to_physics = true
	_rest_local = position
	_rest_rotation = rotation
	_apply_sprites()


## Builds the slotted bar (sprite_06) + three plungers seated as children.
func _apply_sprites() -> void:
	if not ResourceLoader.exists(BAR_TEX):
		return
	var bar_tex := load(BAR_TEX) as Texture2D
	if bar_tex == null:
		return
	for name in POLY_NODES:
		var n := get_node_or_null(name)
		if n:
			n.visible = false
	var plate := _plate_size()
	var sx := plate.x / BAR_TEX_W
	var sy := plate.y / BAR_TEX_H
	_build_plungers(plate, sx, sy)
	var bar := Sprite2D.new()
	bar.texture = bar_tex
	bar.centered = true
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.scale = Vector2(sx, sy)
	bar.z_index = 0
	add_child(bar)


func _build_plungers(plate: Vector2, bar_sx: float, bar_sy: float) -> void:
	for i in PLUNGER_TEX.size():
		var tex := load(PLUNGER_TEX[i]) as Texture2D
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Fill the bar's slot: width = slot width, length = most of the bar.
		spr.scale = Vector2(
			(SLOT_TEX_W * bar_sx * plunger_width_fill) / float(tex.get_width()),
			(BAR_TEX_H * plunger_length_ratio * bar_sy) / float(tex.get_height()))
		spr.z_index = 1  # in front so the purple shows in its slot
		# Seated centred in its slot; never repositioned (rides with the bar).
		spr.position = Vector2((SLOT_TEX_X[i] - BAR_TEX_W * 0.5) * bar_sx, 0.0)
		add_child(spr)
		_plungers.append(spr)


func _plate_size() -> Vector2:
	for c in get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
			return ((c as CollisionShape2D).shape as RectangleShape2D).size
	return Vector2(176, 40)


func _physics_process(delta: float) -> void:
	# Never rotate/tilt: lock to the placed (upright) orientation every frame.
	rotation = _rest_rotation

	var active := Input.is_action_pressed("flipper")
	if active and not _was_active:
		GameEvents.flipper_fired.emit()
		_kicked_this_press = false
	if not active:
		_kicked_this_press = false
	_was_active = active

	# Slide purely HORIZONTALLY, away from the centre seam (x=0): the bar on the
	# left goes left, the bar on the right goes right - no rotation, no crossing.
	var dir := signf(_rest_local.x)
	if dir == 0.0:
		dir = signf(active_offset.x)
	var target := _rest_local
	if active:
		target = Vector2(_rest_local.x + dir * open_offset, _rest_local.y)
	# Assist kick: any frame during the slide where the ball is in contact,
	# fired at most once per press.
	if active and not _kicked_this_press and not position.is_equal_approx(target):
		if _try_kick_overlapping_ball():
			_kicked_this_press = true
	position = position.move_toward(target, slide_speed * delta)


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
	var kick_dir := active_offset.normalized()
	if kick_dir == Vector2.ZERO:
		kick_dir = Vector2.UP
	if to_ball.dot(kick_dir) < -SURFACE_TOLERANCE:
		return false
	ball.linear_velocity += kick_dir * kick_impulse
	GameEvents.ball_hit_flipper.emit()
	return true
