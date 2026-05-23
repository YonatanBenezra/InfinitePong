extends Control
## In-game results card shown after a level is cleared or the ball dies.
## Kept in-scene (no reload) so the "one more run" loop stays instant.
## Built procedurally via setup(); the owner supplies button callbacks.

func setup(result: Dictionary, on_primary: Callable, on_menu: Callable) -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var win := String(result.get("outcome", "death")) == "win"
	var accent: Color = UITheme.accent if win else UITheme.DANGER

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.0)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	add_child(scrim)
	scrim.create_tween().tween_property(scrim, "color:a", 0.78, 0.25)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := UITheme.make_panel(UITheme.PANEL_SOLID)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var header := UITheme.make_title(
		"LEVEL %d CLEARED" % int(result.get("level", 1)) if win else "YOU DIED",
		38, accent)
	vb.add_child(header)

	if win:
		vb.add_child(UITheme.make_label(
			"Score  %s" % _commas(int(result.get("score", 0))), 22, UITheme.GOLD))
	else:
		vb.add_child(UITheme.make_label(
			"Reached %d%% depth" % int(float(result.get("depth_pct", 0.0)) * 100.0),
			20, UITheme.TEXT_DIM))

	vb.add_child(_divider())

	# Run breakdown.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	grid.add_child(_stat("DEPTH", "%d%%" % int(float(result.get("depth_pct", 0.0)) * 100.0)))
	grid.add_child(_stat("TIME", "%.1fs" % float(result.get("time", 0.0))))
	grid.add_child(_stat("FLIPPERS", str(int(result.get("flippers", 0)))))

	# XP reward.
	var xp_gain := int(Profile.last_run_xp)
	vb.add_child(_divider())
	var xp_row := UITheme.make_label("+ %d XP" % xp_gain, 24, UITheme.accent)
	vb.add_child(xp_row)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = Profile.xp_progress()
	var bbg := StyleBoxFlat.new()
	bbg.bg_color = Color(0, 0, 0, 0.4)
	bbg.set_corner_radius_all(7)
	var bfill := StyleBoxFlat.new()
	bfill.bg_color = UITheme.accent
	bfill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bbg)
	bar.add_theme_stylebox_override("fill", bfill)
	vb.add_child(bar)
	vb.add_child(UITheme.make_label("Player Level %d" % Profile.player_level, 14, UITheme.TEXT_DIM))

	if bool(result.get("no_death", false)) and win:
		var perfect := UITheme.make_label("★ PERFECT — NO DEATHS ★", 16, UITheme.GOLD)
		vb.add_child(perfect)

	vb.add_child(_divider())

	# Buttons.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var primary := UITheme.make_button("NEXT LEVEL" if win else "RETRY", accent)
	primary.custom_minimum_size = Vector2(190, 0)
	primary.pressed.connect(on_primary)
	row.add_child(primary)
	var menu := UITheme.make_ghost_button("MENU")
	menu.custom_minimum_size = Vector2(150, 0)
	menu.pressed.connect(on_menu)
	row.add_child(menu)
	primary.call_deferred("grab_focus")

	# Entrance animation.
	panel.pivot_offset = Vector2(210, 220)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var t := panel.create_tween().set_parallel(true)
	t.tween_property(panel, "modulate:a", 1.0, 0.28)
	t.tween_property(panel, "scale", Vector2.ONE, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Animate the XP gain counting onto the bar.
	var start := clampf(Profile.xp_progress() - float(xp_gain) / float(Profile.xp_for_next(Profile.player_level)), 0.0, 1.0)
	bar.value = start
	bar.create_tween().tween_property(bar, "value", Profile.xp_progress(), 0.7).set_delay(0.3)


func _stat(label: String, value: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.custom_minimum_size = Vector2(116, 0)
	box.add_child(UITheme.make_label(value, 22, UITheme.TEXT))
	box.add_child(UITheme.make_label(label, 11, UITheme.TEXT_FAINT))
	return box


func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 2)
	return line


func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
