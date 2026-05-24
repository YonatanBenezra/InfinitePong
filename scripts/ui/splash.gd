extends Control
## Splash screen — first scene loaded. A clean, minimal wordmark reveal
## while the autoloads initialise, then a smooth cut to the main menu.
## Any input skips ahead.

const HOLD := 2.4

var _advanced: bool = false


func _ready() -> void:
	var bg := UITheme.make_gradient_bg(Color(0.055, 0.065, 0.10), Color(0.02, 0.025, 0.045))
	add_child(bg)

	# Centred wordmark.
	var title := UITheme.make_title("PIN DOWN", 84)
	title.anchor_right = 1.0
	title.anchor_bottom = 1.0
	add_child(title)

	# Accent underline that draws itself in.
	var rule := ColorRect.new()
	rule.color = UITheme.accent
	rule.anchor_left = 0.5
	rule.anchor_right = 0.5
	rule.anchor_top = 0.5
	rule.anchor_bottom = 0.5
	rule.offset_top = 58
	rule.offset_bottom = 61
	add_child(rule)

	# Game-native loading indicator below the wordmark — the equipped ball
	# rallied between two flippers.
	var loader := Control.new()
	loader.set_script(load("res://scripts/ui/loading_ball.gd"))
	loader.anchor_left = 0.5
	loader.anchor_right = 0.5
	loader.anchor_top = 0.5
	loader.anchor_bottom = 0.5
	loader.offset_left = -190.0
	loader.offset_right = 190.0
	loader.offset_top = 92.0
	loader.offset_bottom = 224.0
	loader.modulate.a = 0.0
	add_child(loader)

	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.modulate.a = 0.0
	title.scale = Vector2(0.94, 0.94)
	title.pivot_offset = get_viewport_rect().size * 0.5

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(title, "modulate:a", 1.0, 0.55)
	t.tween_property(title, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(rule, "offset_left", -82.0, 0.6) \
		.set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(rule, "offset_right", 82.0, 0.6) \
		.set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(loader, "modulate:a", 1.0, 0.5).set_delay(0.45)

	get_tree().create_timer(HOLD).timeout.connect(_advance)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventKey or event is InputEventMouseButton):
		_advance()


func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	MusicManager.play_menu()
	SceneRouter.goto(SceneRouter.MENU)
