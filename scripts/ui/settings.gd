extends Control
## Settings — audio levels, visual comfort toggles, and a guarded
## progress wipe. Every change is applied and persisted immediately.

var _reset_armed: bool = false


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

	var back := UITheme.make_ghost_button("‹ BACK")
	back.offset_left = 24
	back.offset_top = 22
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	add_child(back)

	var title := UITheme.make_title("SETTINGS", 40)
	title.anchor_right = 1.0
	title.offset_top = 26
	title.offset_bottom = 78
	add_child(title)

	var panel := UITheme.make_panel()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 110
	panel.custom_minimum_size = Vector2(440, 0)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	vb.add_child(_section("AUDIO"))
	vb.add_child(_slider_row("Master Volume", GameSettings.master_volume,
		func(v): GameSettings.master_volume = v; GameSettings.commit()))
	vb.add_child(_slider_row("Music", GameSettings.music_volume,
		func(v): GameSettings.music_volume = v; GameSettings.commit()))
	vb.add_child(_slider_row("Sound Effects", GameSettings.sfx_volume,
		func(v): GameSettings.sfx_volume = v; GameSettings.commit()))

	vb.add_child(_section("VISUALS"))
	vb.add_child(_slider_row("Screen Shake", GameSettings.screen_shake,
		func(v): GameSettings.screen_shake = v; GameSettings.commit()))
	vb.add_child(_toggle_row("Particle Effects", GameSettings.particles_enabled,
		func(on): GameSettings.particles_enabled = on; GameSettings.commit()))
	vb.add_child(_toggle_row("Screen Flash", GameSettings.screen_flash,
		func(on): GameSettings.screen_flash = on; GameSettings.commit()))
	vb.add_child(_toggle_row("Reduced Motion", GameSettings.reduced_motion,
		func(on): GameSettings.reduced_motion = on; GameSettings.commit()))
	vb.add_child(_toggle_row("Show FPS", GameSettings.show_fps,
		func(on): GameSettings.show_fps = on; GameSettings.commit()))

	vb.add_child(_section("DATA"))
	var reset := UITheme.make_button("RESET ALL PROGRESS", UITheme.DANGER)
	reset.pressed.connect(_on_reset.bind(reset))
	vb.add_child(reset)


func _section(text: String) -> Label:
	var l := UITheme.make_label(text, 14, UITheme.accent)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _slider_row(label: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := UITheme.make_label(label, 16, UITheme.TEXT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.custom_minimum_size = Vector2(170, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UITheme.make_label("%d%%" % int(value * 100.0), 14, UITheme.TEXT_DIM)
	val.custom_minimum_size = Vector2(44, 0)
	slider.value_changed.connect(func(v):
		val.text = "%d%%" % int(v * 100.0)
		on_change.call(v))
	row.add_child(slider)
	row.add_child(val)
	return row


func _toggle_row(label: String, value: bool, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	var lbl := UITheme.make_label(label, 16, UITheme.TEXT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(func(on): on_change.call(on))
	row.add_child(check)
	return row


func _on_reset(btn: Button) -> void:
	if not _reset_armed:
		_reset_armed = true
		btn.text = "ARE YOU SURE? CLICK AGAIN"
		return
	SaveSystem.wipe()
	Profile.reload()
	GameSettings.reload()
	Achievements.reload()
	Challenges.reload()
	UITheme.set_world(1)
	SceneRouter.goto(SceneRouter.BOOT)
