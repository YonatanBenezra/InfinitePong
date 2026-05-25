extends Control
## Small navigation icon on menu buttons.
## Uses a PNG sprite when one is available in SpriteBank; falls back to
## the original procedural _draw() so nothing breaks before art is added.

@export var kind: String = ""
@export var icon_color: Color = Color.WHITE

var _use_sprite := false


func _ready() -> void:
	var path := SpriteBank.icon_path(kind)
	if path == "":
		return
	var tex := SpriteBank.get_texture(path)
	if tex == null:
		return
	_use_sprite = true
	var tr := TextureRect.new()
	tr.texture = tex
	tr.modulate = icon_color
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


func _draw() -> void:
	if _use_sprite:
		return
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.42
	var col := icon_color
	match kind:
		"play", "continue":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.72, -s), c + Vector2(-s * 0.72, s),
				c + Vector2(s, 0)]), col)
		"levels":
			var g := s * 0.56
			for i in 4:
				var gx := -1.0 if i % 2 == 0 else 1.0
				var gy := -1.0 if i < 2 else 1.0
				draw_rect(Rect2(c + Vector2(gx * g - g * 0.42, gy * g - g * 0.42),
					Vector2(g * 0.84, g * 0.84)), col)
		"skins":
			draw_circle(c, s, col)
			draw_circle(c + Vector2(-s * 0.32, -s * 0.34), s * 0.34, Color(0, 0, 0, 0.30))
		"stats":
			var hs := PackedFloat32Array([0.66, 1.3, 0.98])
			var bw := s * 0.52
			for i in 3:
				var h := s * hs[i]
				draw_rect(Rect2(c + Vector2(float(i - 1) * bw - bw * 0.36, s - h),
					Vector2(bw * 0.72, h)), col)
		"trophy":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.78, -s * 0.85), c + Vector2(s * 0.78, -s * 0.85),
				c + Vector2(s * 0.40, s * 0.12), c + Vector2(-s * 0.40, s * 0.12)]), col)
			draw_rect(Rect2(c + Vector2(-s * 0.15, s * 0.12), Vector2(s * 0.30, s * 0.40)), col)
			draw_rect(Rect2(c + Vector2(-s * 0.58, s * 0.52), Vector2(s * 1.16, s * 0.30)), col)
		"settings":
			for i in 7:
				var a := TAU * float(i) / 7.0
				draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.92, s * 0.32, col)
			draw_circle(c, s * 0.72, col)
			draw_circle(c, s * 0.30, Color(0, 0, 0, 0.32))
		"back":
			draw_polyline(PackedVector2Array([
				c + Vector2(s * 0.45, -s), c + Vector2(-s * 0.55, 0),
				c + Vector2(s * 0.45, s)]), col, 3.2, true)
