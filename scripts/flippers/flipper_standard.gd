extends AnimatableBody2D
## Classic pinball flipper: rotates around its origin (the pivot).
##
## Two modes (designer-facing):
##  - Default (upward swing):    rest_angle_deg > active_angle_deg.
##    Bar hangs down, pressing swings it up. This is the classic flipper.
##  - Inverted (downward swing): rest_angle_deg < active_angle_deg.
##    Bar starts raised (often blocking the path), pressing drops it.
##
## For a right-side flipper, set `mirror = true` so the swing mirrors in
## world space while still using the same angle conventions.
##
## Reliability:
##  - sync_to_physics = true so the moving bar transfers real momentum to
##    the ball through the physics solver every step instead of teleporting
##    through a fast-moving ball. The flipper is a PURE physical paddle: the
##    ball is launched ONLY by genuine contact with the swinging bar, with no
##    magnetic assist kick (the assist is what made the ball appear to bounce
##    without touching the flipper, so it was removed).

@export_group("Geometry")
## Rest rotation in degrees (the angle when the flipper is NOT held).
## For a default left-side flipper this is positive (bar hangs down-right).
@export_range(-180.0, 180.0, 1.0) var rest_angle_deg: float = 30.0
## Active rotation in degrees (the angle when the flipper IS held).
## For a default left-side flipper this is negative (bar swings up).
@export_range(-180.0, 180.0, 1.0) var active_angle_deg: float = -52.0
## Length of the bar in pixels. Used to scale the flipper sprite so the
## hub-to-tip span matches this length.
@export_range(20.0, 240.0, 2.0) var bar_length: float = 96.0
## Mirror the swing for a right-side flipper. Both rest and active angles
## get negated, so you can keep using the same conventions on both sides.
@export var mirror: bool = false

@export_group("Motion")
## Swing speed in degrees per second.
@export_range(120.0, 2400.0, 30.0) var flick_speed_deg: float = 675.0

var _was_active: bool = false


func _ready() -> void:
	add_to_group("player_flippers")
	sync_to_physics = true
	rotation_degrees = _eff_rest()
	_apply_sprites()


## Single flipper sprite. The round hub sits near the LEFT end; the bar
## extends to the right toward the tip.
const FLIPPER_TEX := "res://assets/sprite_04.png"
## Measured hub (pivot) centre in sprite_04, in texels.
const HUB := Vector2(21.2, 17.5)
const POLY_NODES := ["Outline", "Visual", "VisualTrim", "VisualHighlight",
		"PivotRingOuter", "PivotDot", "PivotRing"]


func _apply_sprites() -> void:
	# Legacy two-part bar+pivot sprites (SpriteBank) take priority if a
	# project ever supplies them; otherwise use the single flipper sprite.
	var bar_tex := SpriteBank.get_texture(SpriteBank.FLIPPER_BAR)
	if bar_tex != null:
		_apply_bar_pivot_sprites(bar_tex)
		return
	if not ResourceLoader.exists(FLIPPER_TEX):
		return  # keep the Polygon2D visuals defined in the scene
	var tex := load(FLIPPER_TEX) as Texture2D
	if tex == null:
		return
	_hide_polys()
	# Scale so the hub→right-edge span matches bar_length (pivot to tip).
	var s := bar_length / float(tex.get_width() - HUB.x)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.modulate = Color.WHITE
	spr.scale = Vector2(s, s)
	# Set the sprite OFFSET so the round hub sits exactly on the rotation pivot
	# (the node origin). The bar then extends along +X over the collision bar
	# and rotates about the hub.
	spr.offset = Vector2(tex.get_width() * 0.5 - HUB.x, tex.get_height() * 0.5 - HUB.y)
	# Right flipper = the left flipper mirrored about the pivot. Its FlipMount
	# already rotates this node 180° (a point reflection = H+V mirror), so the
	# sprite only needs to cancel that rotation's VERTICAL half to land on the
	# clean HORIZONTAL mirror requested — i.e. flip_v here, NOT flip_h (a
	# literal flip_h on top of the 180° mount would point the bar to the wrong
	# side and shift the hub off the pivot).
	spr.flip_v = mirror
	add_child(spr)


func _hide_polys() -> void:
	for name in POLY_NODES:
		var n := get_node_or_null(name)
		if n:
			n.visible = false


## Legacy path: separate bar + pivot textures (kept for compatibility).
func _apply_bar_pivot_sprites(bar_tex: Texture2D) -> void:
	_hide_polys()
	var bar := Sprite2D.new()
	bar.texture = bar_tex
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.scale = Vector2(bar_length / float(bar_tex.get_width()), 1.0)
	bar.position = Vector2(bar_length * 0.5, 0.0)
	add_child(bar)
	var pivot_tex := SpriteBank.get_texture(SpriteBank.FLIPPER_PIVOT)
	if pivot_tex != null:
		var pivot := Sprite2D.new()
		pivot.texture = pivot_tex
		pivot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(pivot)


func _eff_rest() -> float:
	return -rest_angle_deg if mirror else rest_angle_deg


func _eff_active() -> float:
	return -active_angle_deg if mirror else active_angle_deg


func _physics_process(delta: float) -> void:
	var active := Input.is_action_pressed("flipper")
	if active and not _was_active:
		GameEvents.flipper_fired.emit()
	_was_active = active
	# Pure physical paddle: the swinging bar (sync_to_physics) bounces the ball
	# entirely through the physics solver, so the ball is ONLY ever launched on
	# real contact. There is no magnetic "assist" kick that could fling a ball
	# the bar is not actually touching (that was the reported phantom bounce).
	var target_deg := _eff_active() if active else _eff_rest()
	rotation_degrees = move_toward(rotation_degrees, target_deg, flick_speed_deg * delta)
