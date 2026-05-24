extends Control
## Achievements screen — every achievement with unlock state and a live
## progress bar derived from the player's stats.

func _ready() -> void:
	var bg := Node2D.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.7)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var back := UITheme.make_ghost_button("‹ BACK")
	back.offset_left = 24
	back.offset_top = 22
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	add_child(back)

	var unlocked := Achievements.unlocked_count()
	var total := Achievements.definitions.size()
	var title := UITheme.make_title("ACHIEVEMENTS  %d / %d" % [unlocked, total], 34)
	title.anchor_right = 1.0
	title.offset_top = 28
	title.offset_bottom = 74
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 92
	scroll.offset_bottom = -20
	scroll.offset_left = 60
	scroll.offset_right = -60
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)

	for def in Achievements.definitions:
		col.add_child(_make_row(def))


func _make_row(def: Dictionary) -> Control:
	var done := Achievements.is_unlocked(def["id"])
	var panel := UITheme.make_panel(
		Color(0.14, 0.18, 0.16, 0.92) if done else Color(0.11, 0.12, 0.18, 0.85))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# Status badge.
	var badge := UITheme.make_label("★" if done else "○", 30,
		UITheme.GOLD if done else UITheme.TEXT_FAINT)
	badge.custom_minimum_size = Vector2(44, 0)
	row.add_child(badge)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 3)
	row.add_child(text_col)

	var name_lbl := UITheme.make_label(def["name"], 19,
		UITheme.TEXT if done else UITheme.TEXT_DIM)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_col.add_child(name_lbl)

	var desc := UITheme.make_label(def["desc"], 14, UITheme.TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_col.add_child(desc)

	if not done:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = Achievements.progress(def)
		var b := StyleBoxFlat.new()
		b.bg_color = Color(0, 0, 0, 0.4)
		b.set_corner_radius_all(4)
		var f := StyleBoxFlat.new()
		f.bg_color = UITheme.accent
		f.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", b)
		bar.add_theme_stylebox_override("fill", f)
		text_col.add_child(bar)

	var status := UITheme.make_label("UNLOCKED" if done else "LOCKED", 13,
		UITheme.GOLD if done else UITheme.TEXT_FAINT)
	status.custom_minimum_size = Vector2(96, 0)
	row.add_child(status)
	return panel
