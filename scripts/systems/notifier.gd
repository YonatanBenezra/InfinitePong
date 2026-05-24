extends Node
## Autoload: global toast popups for achievements, level-ups, rewards and
## completed challenges. Listens to GameEvents and presents a tidy,
## self-dismissing stack on a top-most layer so popups survive scene
## changes and never block input.

const HOLD := 3.6
const MAX_VISIBLE := 4

var _stack: VBoxContainer
var _chime: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_stack = VBoxContainer.new()
	_stack.anchor_left = 1.0
	_stack.anchor_right = 1.0
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.offset_left = -344
	_stack.offset_right = -16
	_stack.offset_top = 16
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_stack)

	_chime = AudioStreamPlayer.new()
	_chime.bus = "Sfx" if AudioServer.get_bus_index("Sfx") >= 0 else "Master"
	_chime.volume_db = -10.0
	_chime.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_chime)

	GameEvents.achievement_unlocked.connect(_on_achievement)
	GameEvents.player_leveled_up.connect(_on_level_up)
	GameEvents.challenge_completed.connect(_on_challenge)
	GameEvents.reward_unlocked.connect(_on_reward)
	GameEvents.world_unlocked.connect(_on_world)


func _on_achievement(a: Dictionary) -> void:
	toast("ACHIEVEMENT UNLOCKED", a.get("name", "?"), a.get("desc", ""), UITheme.GOLD, true)


func _on_level_up(level: int, _rewards: Array) -> void:
	toast("LEVEL UP", "Player Level %d" % level,
		"%d XP to next" % Profile.xp_for_next(level), UITheme.accent, true)


func _on_challenge(c: Dictionary) -> void:
	toast("CHALLENGE COMPLETE", c.get("desc", "?"),
		"+%d XP" % int(c.get("xp", 0)), UITheme.accent, false)


func _on_reward(r: Dictionary) -> void:
	var names := {"title": "New Title", "ball_skin": "New Ball Skin",
		"trail_fx": "New Trail", "theme": "New World Theme"}
	toast("REWARD UNLOCKED", names.get(r.get("type", ""), "Reward"),
		str(r.get("id", "")).capitalize(), UITheme.GOLD, false)


func _on_world(index: int) -> void:
	var w := Worlds.world(index)
	toast("NEW WORLD", w.get("name", "?"), w.get("subtitle", ""), w.get("accent", UITheme.accent), true)


## Builds and animates a single toast. Trims the stack to MAX_VISIBLE.
func toast(header: String, title: String, sub: String, accent: Color, chime: bool) -> void:
	while _stack.get_child_count() >= MAX_VISIBLE:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.20, 0.97)
	style.set_corner_radius_all(10)
	style.border_width_left = 5
	style.border_color = accent
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	panel.add_child(vb)
	vb.add_child(_line(header, 12, accent))
	vb.add_child(_line(title, 18, UITheme.TEXT))
	if sub != "":
		vb.add_child(_line(sub, 13, UITheme.TEXT_DIM))

	_stack.add_child(panel)
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(330, 24)
	panel.scale = Vector2(0.85, 0.85)
	var t := panel.create_tween().set_parallel(true)
	t.tween_property(panel, "modulate:a", 1.0, 0.22)
	t.tween_property(panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if chime and _chime:
		_chime.stream = AudioSynth.win_sound()
		_chime.play()

	get_tree().create_timer(HOLD).timeout.connect(func():
		if not is_instance_valid(panel):
			return
		var o := panel.create_tween()
		o.tween_property(panel, "modulate:a", 0.0, 0.4)
		o.tween_callback(panel.queue_free))


func _line(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
