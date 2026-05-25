extends Node
class_name WorldPainter
## Walks each instantiated chunk and adds visuals to any StaticBody2D /
## AnimatableBody2D's RectangleShape2D collision children that don't already
## have a sibling Polygon2D or Sprite2D.
##
## Sprite mode (preferred): loads wall_tile.png / platform_tile.png from
## SpriteBank and creates a tiled Sprite2D sized to the collision shape.
## Polygon mode (fallback): used when the PNGs are not yet in place; draws
## the original 3-layer solid + highlight + shadow polygons.

const WALL_COLOR        := Color(0.68, 0.72, 0.84, 1.0)
const WALL_TRIM         := Color(0.34, 0.38, 0.52, 1.0)
const WALL_SHADOW       := Color(0.18, 0.20, 0.30, 1.0)
const PLATFORM_COLOR    := Color(0.86, 0.80, 0.55, 1.0)
const PLATFORM_TRIM     := Color(0.42, 0.36, 0.20, 1.0)
const PLATFORM_HIGHLIGHT := Color(1.0, 0.94, 0.7, 1.0)

## Active palette — overridden per world via apply_world(). Defaults keep
## the original look so chunks painted before a world is set still render.
static var wall_color: Color = WALL_COLOR
static var wall_trim_color: Color = WALL_TRIM
static var platform_color: Color = PLATFORM_COLOR
static var platform_trim_color: Color = PLATFORM_TRIM


## Switches the painter to a world's palette. Call before generating a level.
static func apply_world(world: Dictionary) -> void:
	wall_color = world.get("wall", WALL_COLOR)
	wall_trim_color = world.get("wall_trim", WALL_TRIM)
	platform_color = world.get("platform", PLATFORM_COLOR)
	platform_trim_color = world.get("wall_trim", PLATFORM_TRIM)


static func paint(root: Node) -> void:
	_paint_recursive(root)


static func _paint_recursive(node: Node) -> void:
	for child in node.get_children():
		_paint_recursive(child)
	if node is StaticBody2D or node is AnimatableBody2D:
		_paint_body(node)


static func _has_visual_child(node: Node) -> bool:
	for c in node.get_children():
		if c is Polygon2D or c is Sprite2D or c is Line2D:
			return true
	return false


static func _paint_body(body: Node2D) -> void:
	if _has_visual_child(body):
		return
	for c in body.get_children():
		if not (c is CollisionShape2D and c.shape is RectangleShape2D):
			continue
		var rect_size: Vector2 = (c.shape as RectangleShape2D).size
		var is_platform := rect_size.x >= rect_size.y * 1.6
		var fill_col: Color = platform_color if is_platform else wall_color
		var trim_col: Color = platform_trim_color if is_platform else wall_trim_color
		var tile_path := SpriteBank.PLATFORM_TILE if is_platform else SpriteBank.WALL_TILE
		# --- Sprite mode ---
		var spr := SpriteBank.make_tiled(tile_path, rect_size.x, rect_size.y, fill_col)
		if spr != null:
			spr.position = c.position
			spr.rotation = c.rotation
			body.add_child(spr)
			return
		# --- Polygon fallback ---
		_paint_polygons(body, c, rect_size, fill_col, trim_col, is_platform)
		return


static func _paint_polygons(body: Node2D, c: CollisionShape2D, rect_size: Vector2,
		fill: Color, trim: Color, is_platform: bool) -> void:
	var hx := rect_size.x * 0.5
	var hy := rect_size.y * 0.5
	var highlight: Color = PLATFORM_HIGHLIGHT if is_platform else fill.lightened(0.35)
	var fill_poly := Polygon2D.new()
	fill_poly.color = fill
	fill_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy),
		Vector2(hx, hy), Vector2(-hx, hy),
	])
	fill_poly.position = c.position
	fill_poly.rotation = c.rotation
	body.add_child(fill_poly)
	var trim_t := minf(3.0, minf(hx, hy) * 0.4)
	var hl_poly := Polygon2D.new()
	hl_poly.color = highlight
	hl_poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy),
		Vector2(hx, -hy + trim_t), Vector2(-hx, -hy + trim_t),
	])
	hl_poly.position = c.position
	hl_poly.rotation = c.rotation
	body.add_child(hl_poly)
	var shadow_poly := Polygon2D.new()
	shadow_poly.color = trim
	shadow_poly.polygon = PackedVector2Array([
		Vector2(-hx, hy - trim_t), Vector2(hx, hy - trim_t),
		Vector2(hx, hy), Vector2(-hx, hy),
	])
	shadow_poly.position = c.position
	shadow_poly.rotation = c.rotation
	body.add_child(shadow_poly)
