extends Button
## Compact, asset-free settings cog for the menu corner. Draws its own gear
## icon so it needs no art pipeline, and opens the Settings screen.

func _ready() -> void:
	custom_minimum_size = Vector2(46, 46)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Settings"
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
	UITheme.play_click()
	SceneRouter.goto(SceneRouter.SETTINGS)


func _draw() -> void:
	var col: Color = UITheme.accent
	var c := size * 0.5
	# Cog teeth — round bumps around the body.
	var teeth := 7
	for i in teeth:
		var a := TAU * float(i) / float(teeth)
		draw_circle(c + Vector2(cos(a), sin(a)) * 13.0, 4.2, col)
	# Body + centre hole.
	draw_circle(c, 10.5, col)
	draw_circle(c, 4.6, Color(0.10, 0.12, 0.20))
