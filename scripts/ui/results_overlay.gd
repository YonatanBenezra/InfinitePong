extends Control
## In-game results card shown after a level is cleared or the ball dies.
## Kept in-scene (no reload) so the "one more run" loop stays instant.
## Built procedurally via setup(); the owner supplies button callbacks.

func setup(result: Dictionary, on_primary: Callable, on_menu: Callable) -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var outcome := String(result.get("outcome", "death"))
	var win := outcome == "win"
	var game_over := outcome == "game_over"
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

	var header_text: String
	if win:
		header_text = "LEVEL %d CLEARED" % int(result.get("level", 1))
	elif game_over:
		header_text = "GAME OVER"
	else:
		header_text = "TRY AGAIN"
	var header := UITheme.make_title(header_text, 34, accent)
	vb.add_child(header)

	# On game over, lead with whether the run set a new record.
	if game_over:
		var record_text := ("NEW HIGH SCORE!" if bool(result.get("new_best", false))
			else "OUT OF HEALTH")
		var record_color: Color = UITheme.GOLD if bool(result.get("new_best", false)) else UITheme.TEXT_DIM
		vb.add_child(UITheme.make_label(record_text, 14, record_color))
	elif not win:
		var lives_left := int(result.get("lives", 0))
		vb.add_child(UITheme.make_label("LIVES REMAINING  %d" % lives_left, 13, UITheme.TEXT_DIM))

	vb.add_child(_divider())

	# Run stats.
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 24)
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(stats_row)
	if game_over:
		# The end-of-run summary: this run's total vs the persistent best.
		stats_row.add_child(_stat("SCORE", _commas(int(result.get("score", 0)))))
		stats_row.add_child(_stat("HIGH SCORE", _commas(int(result.get("high_score", 0)))))
	elif win:
		stats_row.add_child(_stat("TIME", "%.1fs" % float(result.get("time", 0.0))))
		stats_row.add_child(_stat("SCORE", _commas(int(result.get("score", 0)))))
	else:
		stats_row.add_child(_stat("TIME", "%.1fs" % float(result.get("time", 0.0))))
		stats_row.add_child(_stat("DEPTH", "%d%%" % int(float(result.get("depth_pct", 0.0)) * 100.0)))

	vb.add_child(_divider())

	# Button.
	var primary_text := "NEXT LEVEL" if win else ("MAIN MENU" if game_over else "RETRY")
	var primary := UITheme.make_button(primary_text, accent)
	primary.custom_minimum_size = Vector2(260, 0)
	primary.pressed.connect(on_primary)
	vb.add_child(primary)
	primary.call_deferred("grab_focus")

	# Entrance: simple fade only.
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.22)


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
