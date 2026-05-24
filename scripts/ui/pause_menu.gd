extends Control
## In-game pause overlay. Runs while the tree is paused, so its own input
## and animations keep working. Built procedurally via setup().

func setup(on_resume: Callable, on_restart: Callable, on_menu: Callable) -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	anchor_right = 1.0
	anchor_bottom = 1.0

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.74)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	add_child(scrim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := UITheme.make_panel(UITheme.PANEL_SOLID)
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	vb.add_child(UITheme.make_title("PAUSED", 40))
	vb.add_child(UITheme.make_label("Esc to resume", 14, UITheme.TEXT_DIM))

	var resume := UITheme.make_button("RESUME")
	resume.custom_minimum_size = Vector2(260, 0)
	resume.pressed.connect(on_resume)
	vb.add_child(resume)

	var restart := UITheme.make_ghost_button("RESTART LEVEL")
	restart.custom_minimum_size = Vector2(260, 0)
	restart.pressed.connect(on_restart)
	vb.add_child(restart)

	var menu := UITheme.make_ghost_button("MAIN MENU")
	menu.custom_minimum_size = Vector2(260, 0)
	menu.pressed.connect(on_menu)
	vb.add_child(menu)

	resume.call_deferred("grab_focus")

	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.18)
