extends Control
## Main menu — title, two primary actions, compact secondary nav row.

func _ready() -> void:
	UITheme.set_world(Profile.highest_world_unlocked)
	_add_background()
	_add_title()
	_add_buttons()
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
	vb.offset_top = 230
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)

	var has_progress := Profile.highest_level_reached > 1

	var play := UITheme.make_button("PLAY", Color(0, 0, 0, 0), "play")
	play.custom_minimum_size = Vector2(312, 0)
	play.pressed.connect(_on_play)
	vb.add_child(play)
	play.grab_focus()

	var cont := UITheme.make_button(
		"CONTINUE  ·  LV %d" % Profile.highest_unlocked_level(),
		Color(0, 0, 0, 0), "continue")
	cont.custom_minimum_size = Vector2(312, 0)
	cont.disabled = not has_progress
	cont.pressed.connect(_on_continue)
	vb.add_child(cont)

	for entry in [
		["SETTINGS", SceneRouter.SETTINGS, "settings"],
		["BALL SKINS", SceneRouter.BALL_SKINS, "skins"],
		["LEVELS", SceneRouter.LEVEL_SELECT, "levels"],
		["ACHIEVEMENTS", SceneRouter.ACHIEVEMENTS, "trophy"],
	]:
		var b := UITheme.make_ghost_button(entry[0], entry[2])
		b.custom_minimum_size = Vector2(312, 0)
		var dest: String = entry[1]
		b.pressed.connect(func(): SceneRouter.goto(dest))
		vb.add_child(b)


func _add_corner_icons() -> void:
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
