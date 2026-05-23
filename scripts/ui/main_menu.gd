extends Control
## Main menu — clean, minimal, and uncluttered. A clearly readable title,
## one centred column of actions, and a single slim status bar along the
## bottom. Nothing overlaps the logo.

func _ready() -> void:
	UITheme.set_world(Profile.highest_world_unlocked)
	_add_background()
	_add_title()
	_add_buttons()
	_add_bottom_bar()
	_add_corner_icons()
	if MusicManager._mode != "menu":
		MusicManager.play_menu()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


func _add_background() -> void:
	var bg := Node2D.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.07, 0.55)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _add_title() -> void:
	var title := UITheme.make_title("PIN DOWN", 78)
	title.anchor_right = 1.0
	title.offset_top = 70
	title.offset_bottom = 158
	add_child(title)

	# Accent underline, centred under the wordmark.
	var rule := ColorRect.new()
	rule.color = UITheme.accent
	rule.custom_minimum_size = Vector2(150, 3)
	rule.anchor_left = 0.5
	rule.anchor_right = 0.5
	rule.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rule.offset_left = -75
	rule.offset_right = 75
	rule.offset_top = 162
	rule.offset_bottom = 165
	add_child(rule)

	var world := Worlds.world(Profile.highest_world_unlocked)
	var sub := UITheme.make_label(
		"WORLD %d   ·   %s" % [world["id"], String(world["name"]).to_upper()],
		15, UITheme.TEXT_DIM)
	sub.anchor_right = 1.0
	sub.offset_top = 176
	sub.offset_bottom = 198
	add_child(sub)


func _add_buttons() -> void:
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.offset_top = 244
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	var has_progress := Profile.highest_level_reached > 1

	var play := UITheme.make_button("PLAY", Color(0, 0, 0, 0), "play")
	play.custom_minimum_size = Vector2(312, 0)
	play.pressed.connect(_on_play)
	vb.add_child(play)
	play.grab_focus()

	var cont := UITheme.make_button("CONTINUE  ·  LEVEL %d" % Profile.highest_unlocked_level(),
		Color(0, 0, 0, 0), "continue")
	cont.custom_minimum_size = Vector2(312, 0)
	cont.disabled = not has_progress
	cont.pressed.connect(_on_continue)
	vb.add_child(cont)

	for entry in [
		["LEVELS", SceneRouter.LEVEL_SELECT, "levels"],
		["BALL SKINS", SceneRouter.BALL_SKINS, "skins"],
		["STATS", SceneRouter.STATS, "stats"],
		["ACHIEVEMENTS", SceneRouter.ACHIEVEMENTS, "trophy"],
	]:
		var b := UITheme.make_ghost_button(entry[0], entry[2])
		b.custom_minimum_size = Vector2(312, 0)
		var dest: String = entry[1]
		b.pressed.connect(func(): SceneRouter.goto(dest))
		vb.add_child(b)


func _add_bottom_bar() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.13, 0.88)
	style.border_width_top = 2
	style.border_color = Color(1, 1, 1, 0.07)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -78
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	# --- Left: player level + XP ---
	var lvl := UITheme.make_label("LV %d" % Profile.player_level, 26, UITheme.GOLD)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lvl)

	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 4)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.custom_minimum_size = Vector2(190, 0)
	row.add_child(who)
	var name_lbl := UITheme.make_label(Profile.equipped.get("title", "Newcomer"),
		15, UITheme.TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.add_child(name_lbl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = Profile.xp_progress()
	var bbg := StyleBoxFlat.new()
	bbg.bg_color = Color(0, 0, 0, 0.45)
	bbg.set_corner_radius_all(4)
	var bfill := StyleBoxFlat.new()
	bfill.bg_color = UITheme.accent
	bfill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bbg)
	bar.add_theme_stylebox_override("fill", bfill)
	who.add_child(bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# --- Right: daily challenge summary ---
	var daily := VBoxContainer.new()
	daily.add_theme_constant_override("separation", 2)
	daily.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(daily)
	var dhead := UITheme.make_label("DAILY CHALLENGES", 11, UITheme.accent)
	dhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	daily.add_child(dhead)
	var done := Challenges.completed_count()
	var total := Challenges.all().size()
	var dval := UITheme.make_label("%d / %d complete today" % [done, total],
		15, UITheme.TEXT if done < total else UITheme.GOLD)
	dval.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	daily.add_child(dval)


func _add_corner_icons() -> void:
	# Settings cog + music mute, paired in the top-right corner.
	var settings := Button.new()
	settings.set_script(load("res://scripts/ui/settings_button.gd"))
	_place_corner_icon(settings, -116, -70)
	var mute := Button.new()
	mute.set_script(load("res://scripts/ui/mute_button.gd"))
	_place_corner_icon(mute, -62, -16)


func _place_corner_icon(btn: Button, left: float, right: float) -> void:
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = left
	btn.offset_right = right
	btn.offset_top = 16
	btn.offset_bottom = 62
	add_child(btn)


func _on_play() -> void:
	SceneRouter.goto(SceneRouter.GAME, {"start_level": 1, "mode": "play"})


func _on_continue() -> void:
	SceneRouter.goto(SceneRouter.GAME,
		{"start_level": Profile.highest_unlocked_level(), "mode": "continue"})
