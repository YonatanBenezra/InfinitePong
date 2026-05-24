extends Control
## Level Select — a real progression map: themed world cards, per-world
## completion, and level tiles that read instantly as locked / unlocked /
## cleared / perfect.

func _ready() -> void:
	var bg := Node2D.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.62)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_add_header()
	_add_world_list()


func _add_header() -> void:
	var back := UITheme.make_ghost_button("‹ BACK")
	back.offset_left = 22
	back.offset_top = 22
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	add_child(back)

	var title := UITheme.make_title("SELECT LEVEL", 42)
	title.anchor_right = 1.0
	title.offset_top = 24
	title.offset_bottom = 72
	add_child(title)

	var cleared := 0
	var perfect := 0
	for lvl in range(1, Profile.TOTAL_LEVELS + 1):
		var rec := Profile.level_record(lvl)
		if rec.get("cleared", false):
			cleared += 1
		if rec.get("perfect", false):
			perfect += 1
	var summary := UITheme.make_label(
		"%d / %d cleared      ★ %d perfect" % [cleared, Profile.TOTAL_LEVELS, perfect],
		15, UITheme.TEXT_DIM)
	summary.anchor_right = 1.0
	summary.offset_top = 70
	summary.offset_bottom = 92
	add_child(summary)


func _add_world_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 104
	scroll.offset_bottom = -20
	scroll.offset_left = 32
	scroll.offset_right = -32
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	scroll.add_child(col)

	var unlocked := Profile.highest_unlocked_level()
	for w in range(1, Worlds.world_count() + 1):
		col.add_child(_make_world_card(w, unlocked))
	# Trailing spacer so the last card clears the bottom edge.
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 8)
	col.add_child(tail)


func _make_world_card(world_index: int, unlocked: int) -> Control:
	var world := Worlds.world(world_index)
	var accent: Color = world["accent"]
	var world_locked := world_index > Profile.highest_world_unlocked
	var first := Worlds.first_level_of_world(world_index)

	var cleared := 0
	for i in Worlds.LEVELS_PER_WORLD:
		if Profile.level_record(first + i).get("cleared", false):
			cleared += 1

	var panel := PanelContainer.new()
	var ps := UITheme.panel_style(UITheme.PANEL,
		Color(accent.r, accent.g, accent.b, 0.0 if world_locked else 0.55))
	panel.add_theme_stylebox_override("panel", ps)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	# --- Card header ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)

	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(6, 46)
	var sw := StyleBoxFlat.new()
	sw.bg_color = accent if not world_locked else UITheme.TEXT_FAINT
	sw.set_corner_radius_all(3)
	swatch.add_theme_stylebox_override("panel", sw)
	head.add_child(swatch)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 1)
	head.add_child(titles)
	titles.add_child(_left("WORLD %d" % world_index, 12, UITheme.TEXT_FAINT))
	titles.add_child(_left(world["name"], 22,
		accent if not world_locked else UITheme.TEXT_DIM))
	titles.add_child(_left(world["subtitle"], 13, UITheme.TEXT_DIM))

	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 2)
	head.add_child(status)
	if world_locked:
		status.add_child(_right("LOCKED", 13, UITheme.TEXT_FAINT))
		status.add_child(_right("Reach level %d" % first, 11, UITheme.TEXT_FAINT))
	else:
		status.add_child(_right("%d / %d" % [cleared, Worlds.LEVELS_PER_WORLD],
			18, accent))
		status.add_child(_right("cleared", 11, UITheme.TEXT_DIM))

	# --- Progress bar ---
	var prog := ProgressBar.new()
	prog.custom_minimum_size = Vector2(0, 7)
	prog.show_percentage = false
	prog.max_value = Worlds.LEVELS_PER_WORLD
	prog.value = cleared
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0, 0, 0, 0.45)
	pbg.set_corner_radius_all(4)
	var pfill := StyleBoxFlat.new()
	pfill.bg_color = accent if not world_locked else UITheme.TEXT_FAINT
	pfill.set_corner_radius_all(4)
	prog.add_theme_stylebox_override("background", pbg)
	prog.add_theme_stylebox_override("fill", pfill)
	vb.add_child(prog)

	# --- Level grid ---
	var grid := GridContainer.new()
	grid.columns = Worlds.LEVELS_PER_WORLD
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	vb.add_child(grid)
	for i in Worlds.LEVELS_PER_WORLD:
		grid.add_child(_make_level_tile(first + i, unlocked, accent))
	return panel


func _make_level_tile(level: int, unlocked: int, accent: Color) -> Control:
	var rec := Profile.level_record(level)
	var is_locked := level > unlocked
	var is_cleared: bool = rec.get("cleared", false)
	var is_perfect: bool = rec.get("perfect", false)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(62, 62)
	btn.text = str(level)
	btn.add_theme_font_size_override("font_size", 21)
	btn.focus_mode = Control.FOCUS_ALL
	btn.clip_contents = false

	var bg: Color
	var border: Color
	var border_w := 2
	var text_col: Color
	var green := UITheme.SUCCESS
	if is_locked:
		bg = Color(0.11, 0.12, 0.17, 0.7)
		border = Color(1, 1, 1, 0.05)
		text_col = UITheme.TEXT_FAINT
		btn.disabled = true
	elif is_perfect:
		bg = Color(green.r, green.g, green.b, 0.96)
		border = green.lightened(0.4)
		text_col = UITheme.INK
	elif is_cleared:
		bg = Color(green.r, green.g, green.b, 0.82)
		border = green.lightened(0.2)
		text_col = UITheme.INK
	else:
		bg = Color(accent.r, accent.g, accent.b, 0.12)
		border = accent
		text_col = Color.WHITE

	var normal := _tile_style(bg, border, border_w, 0.0)
	var hover := _tile_style(bg.lightened(0.12) if not is_locked else bg,
		border, border_w + (1 if not is_locked else 0), 12.0 if not is_locked else 0.0)
	for s in ["normal", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(s, normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("font_disabled_color", text_col)

	# Completion badge — a checkmark in the top-right corner.
	if is_perfect or is_cleared:
		var badge := Panel.new()
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.offset_left = -23
		badge.offset_top = 3
		badge.offset_right = -3
		badge.offset_bottom = 23
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs := StyleBoxFlat.new()
		bs.bg_color = UITheme.GOLD if is_perfect else Color(0.96, 0.98, 1.0)
		bs.set_corner_radius_all(10)
		bs.set_border_width_all(2)
		bs.border_color = UITheme.INK
		badge.add_theme_stylebox_override("panel", bs)
		badge.add_child(_make_checkmark())
		btn.add_child(badge)

	if not is_locked:
		btn.pressed.connect(func():
			UITheme.play_click()
			SceneRouter.goto(SceneRouter.GAME, {"start_level": level, "mode": "select"}))
		btn.mouse_entered.connect(UITheme.play_hover)
		btn.tooltip_text = ("Level %d — %s" % [level,
			"perfect" if is_perfect else ("cleared" if is_cleared else "not cleared")])
	return btn


## A small checkmark drawn as a rounded polyline, for the completion badge.
func _make_checkmark() -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array([Vector2(4, 10), Vector2(8, 14), Vector2(15, 5)])
	l.width = 3.0
	l.default_color = UITheme.INK
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	return l


func _tile_style(bg: Color, border: Color, border_w: int, glow: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.set_border_width_all(border_w)
	s.border_color = border
	if glow > 0.0:
		s.shadow_color = Color(border.r, border.g, border.b, 0.5)
		s.shadow_size = int(glow)
	return s


func _left(text: String, size: int, color: Color) -> Label:
	var l := UITheme.make_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _right(text: String, size: int, color: Color) -> Label:
	var l := UITheme.make_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
