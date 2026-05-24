extends Button
## Compact, asset-free music mute toggle for the menu corner. Draws its own
## speaker icon so it needs no art pipeline.

func _ready() -> void:
	custom_minimum_size = Vector2(46, 46)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Music: Off" if GameSettings.music_muted else "Music: On"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		var hot: bool = state == "hover" or state == "pressed"
		s.bg_color = Color(0.16, 0.19, 0.30, 0.95) if hot else Color(0.10, 0.12, 0.20, 0.88)
		s.set_corner_radius_all(23)
		s.set_border_width_all(2)
		s.border_color = Color(1, 1, 1, 0.22 if hot else 0.10)
		add_theme_stylebox_override(state, s)
	pressed.connect(_on_pressed)
	mouse_entered.connect(UITheme.play_hover)


func _on_pressed() -> void:
	GameSettings.toggle_music_mute()
	UITheme.play_click()
	tooltip_text = "Music: Off" if GameSettings.music_muted else "Music: On"
	queue_redraw()


func _draw() -> void:
	var muted: bool = GameSettings.music_muted
	var col: Color = UITheme.TEXT_FAINT if muted else UITheme.accent
	var c := size * 0.5
	# Speaker — base box + cone as one filled polygon.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-11, -4), c + Vector2(-5, -4), c + Vector2(1, -10),
		c + Vector2(1, 10), c + Vector2(-5, 4), c + Vector2(-11, 4),
	]), col)
	if muted:
		draw_line(c + Vector2(5, -7), c + Vector2(14, 8), col, 2.6, true)
		draw_line(c + Vector2(14, -7), c + Vector2(5, 8), col, 2.6, true)
	else:
		draw_arc(c + Vector2(1, 0), 8.0, -0.7, 0.7, 10, col, 2.0, true)
		draw_arc(c + Vector2(1, 0), 13.0, -0.7, 0.7, 12, col, 2.0, true)
