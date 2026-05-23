extends Control
## Statistics — a lifetime dashboard of the player's career.

func _ready() -> void:
	var bg := Node2D.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.66)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var back := UITheme.make_ghost_button("‹ BACK")
	back.offset_left = 24
	back.offset_top = 22
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	add_child(back)

	var title := UITheme.make_title("STATISTICS", 40)
	title.anchor_right = 1.0
	title.offset_top = 26
	title.offset_bottom = 78
	add_child(title)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_top = 96
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	# Career header card.
	var header := UITheme.make_panel()
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	header.add_child(hb)
	hb.add_child(_big("PLAYER LEVEL %d  ·  %s" % [
		Profile.player_level, Profile.equipped.get("title", "Newcomer")]))
	hb.add_child(UITheme.make_label(
		"World %d unlocked  ·  %d%% game completion" % [
			Profile.highest_world_unlocked, int(Profile.completion_percent() * 100.0)],
		15, UITheme.TEXT_DIM))
	col.add_child(header)

	var s := Profile.stats
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)

	var tiles := [
		["Best Score", _commas(int(s.get("best_score", 0)))],
		["Highest Level", str(Profile.highest_level_reached)],
		["Longest Streak", str(int(s.get("longest_streak", 0)))],
		["Levels Cleared", str(int(s.get("levels_completed", 0)))],
		["Total Runs", str(int(s.get("total_runs", 0)))],
		["Deaths", str(int(s.get("deaths", 0)))],
		["Perfect Runs", str(int(s.get("perfect_runs", 0)))],
		["Flippers Hit", _commas(int(s.get("total_flippers", 0)))],
		["Distance Fallen", "%s px" % _commas(int(s.get("total_distance", 0.0)))],
		["Best Depth", "%d%%" % int(float(s.get("best_depth_pct", 0.0)) * 100.0)],
		["Achievements", "%d / %d" % [Achievements.unlocked_count(), Achievements.definitions.size()]],
		["Play Time", Profile.formatted_play_time()],
	]
	for tile in tiles:
		grid.add_child(_stat_tile(tile[0], tile[1]))


func _big(text: String) -> Label:
	var l := UITheme.make_label(text, 24, UITheme.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _stat_tile(label: String, value: String) -> Control:
	var panel := UITheme.make_panel(Color(0.13, 0.15, 0.24, 0.92))
	panel.custom_minimum_size = Vector2(176, 84)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var v := UITheme.make_label(value, 26, UITheme.accent)
	vb.add_child(v)
	var l := UITheme.make_label(label.to_upper(), 12, UITheme.TEXT_DIM)
	vb.add_child(l)
	return panel


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
