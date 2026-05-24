extends StaticBody2D
class_name CurvedRamp
## Procedural curved momentum surface — a quarter pipe / half pipe element.
##
## Godot 2D has no native curved collider, so the arc is approximated by a
## fan of short rotated RectangleShape2D segments. That is the exact same
## primitive every wall and ledge in this game already uses, so a curved
## ramp integrates cleanly with the existing physics, CCD and WorldPainter
## without any special-casing.
##
## The ball rides the CONCAVE (inner) face of the arc, so momentum is
## preserved and redirected smoothly instead of being scattered. Place the
## node at the arc's center point and pick the angle span so the concave
## opening faces into the playable space.
##
## Common presets (open them in the Inspector and adjust the angles):
##   Quarter pipe, opens up-right: start =   0, end =  90
##   Quarter pipe, opens up-left : start =  90, end = 180
##   Half pipe (U shape, opens up): start =   0, end = 180
##   Half pipe (rotated for side): start = 270, end =  90  (use carefully)
##
## Angle convention (degrees): a point at angle T sits at
## Vector2(cos T, sin T) * arc_radius in local space.
## 0 = right, 90 = down (Godot's Y is down), 180 = left, 270 = up.

@export_group("Shape")
## Radius of the arc in pixels (distance from this node's origin to the
## surface the ball will ride on).
@export_range(40.0, 600.0, 2.0) var arc_radius: float = 200.0
## Starting angle of the arc in degrees. See the docstring for which value
## faces which direction.
@export_range(-360.0, 360.0, 1.0) var start_angle_deg: float = 0.0
## Ending angle of the arc in degrees. The arc sweeps from start to end.
@export_range(-360.0, 360.0, 1.0) var end_angle_deg: float = 90.0
## Number of straight collision segments used to approximate the curve.
## 12 is plenty for a quarter pipe; raise it for very large arcs.
@export_range(4, 64, 1) var segment_count: int = 12
## Thickness of the ramp wall in pixels.
@export_range(8.0, 80.0, 1.0) var thickness: float = 26.0

@export_group("Look")
## Fill colour of the ramp surface.
@export var surface_color: Color = Color(0.55, 0.78, 0.95, 1.0)
## Colour of the inner-edge highlight line. Helps the ride surface read
## clearly from above.
@export var edge_color: Color = Color(0.82, 0.94, 1.0, 1.0)


func _ready() -> void:
	# Behave like every other piece of level geometry.
	collision_layer = 1
	collision_mask = 0
	_build()


func _build() -> void:
	var seg: int = maxi(segment_count, 2)
	var a0 := deg_to_rad(start_angle_deg)
	var a1 := deg_to_rad(end_angle_deg)

	var inner: PackedVector2Array = []
	var outer: PackedVector2Array = []
	var surface: PackedVector2Array = []
	for i in range(seg + 1):
		var t := float(i) / float(seg)
		var ang := lerpf(a0, a1, t)
		var n := Vector2(cos(ang), sin(ang))
		inner.append(n * (arc_radius - thickness * 0.5))
		outer.append(n * (arc_radius + thickness * 0.5))
		surface.append(n * arc_radius)

	# Collision: one thin rectangle per arc segment, placed along the chord.
	for i in range(seg):
		var pa := surface[i]
		var pb := surface[i + 1]
		var mid := (pa + pb) * 0.5
		var chord := pb - pa
		var shape := RectangleShape2D.new()
		# Slight length overlap removes collision gaps at segment joints.
		shape.size = Vector2(chord.length() + 3.0, thickness)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = mid
		cs.rotation = chord.angle()
		add_child(cs)

	# Visual: a filled ring strip between the inner and outer radii.
	var fill := Polygon2D.new()
	var poly: PackedVector2Array = []
	for p in outer:
		poly.append(p)
	for i in range(inner.size() - 1, -1, -1):
		poly.append(inner[i])
	fill.polygon = poly
	fill.color = surface_color
	add_child(fill)

	# Inner-edge highlight so the ride surface reads clearly from above.
	var edge := Line2D.new()
	edge.points = inner
	edge.width = 3.0
	edge.default_color = edge_color
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(edge)
