extends Node
## Autoload: the game's design system + procedural widget factory.
##
## Screens are built in code, so this is the single source of visual truth:
## colour tokens, a type scale, premium button/panel factories with full
## hover / press / focus states, and shared UI sound effects. The accent
## colour tracks the player's furthest world so menus feel cohesive.

# --- Colour tokens --------------------------------------------------------
const BG_TOP := Color(0.07, 0.08, 0.14)
const BG_BOTTOM := Color(0.02, 0.025, 0.05)
const PANEL := Color(0.11, 0.13, 0.21, 0.94)
const PANEL_SOLID := Color(0.10, 0.115, 0.19, 1.0)
const PANEL_RAISED := Color(0.15, 0.17, 0.27, 0.96)
const TEXT := Color(0.95, 0.96, 1.0)
const TEXT_DIM := Color(0.66, 0.70, 0.82)
const TEXT_FAINT := Color(0.42, 0.46, 0.58)
const INK := Color(0.05, 0.06, 0.11)         ## dark text on bright fills
const DANGER := Color(1.0, 0.38, 0.42)
const GOLD := Color(1.0, 0.81, 0.32)
const SUCCESS := Color(0.40, 0.76, 0.52)
const SHADOW := Color(0, 0, 0, 0.75)

var accent: Color = Color(0.50, 0.68, 0.92)

var _hover_sfx: AudioStreamPlayer
var _click_sfx: AudioStreamPlayer
var _back_sfx: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_world(Profile.highest_world_unlocked)
	_hover_sfx = _make_sfx(AudioSynth.ui_hover_sound(), -16.0)
	_click_sfx = _make_sfx(AudioSynth.ui_click_sound(), -10.0)
	_back_sfx = _make_sfx(AudioSynth.ui_back_sound(), -11.0)


func _make_sfx(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = "Sfx" if AudioServer.get_bus_index("Sfx") >= 0 else "Master"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func set_world(world_index: int) -> void:
	accent = Worlds.world(world_index).get("accent", accent)


func play_hover() -> void:
	if _hover_sfx:
		_hover_sfx.play()


func play_click() -> void:
	if _click_sfx:
		_click_sfx.play()


func play_back() -> void:
	if _back_sfx:
		_back_sfx.play()


# --- Type scale -----------------------------------------------------------

func make_title(text: String, size: int = 64, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", maxi(2, size / 14))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 18))
	l.add_theme_constant_override("shadow_outline_size", maxi(4, size / 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func make_label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- Panels ---------------------------------------------------------------

func panel_style(fill: Color = PANEL, border: Color = Color(1, 1, 1, 0.10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(16)
	s.set_border_width_all(2)
	s.border_color = border
	s.set_content_margin_all(22)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 8)
	return s


func make_panel(fill: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(fill))
	return p


# --- Buttons --------------------------------------------------------------

func _style(bg: Color, border: Color, border_w: int, glow: float, glow_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(11)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	if glow > 0.0:
		s.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.55)
		s.shadow_size = int(glow)
	else:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 3)
	return s


## Primary button — a bright, filled accent CTA that visually dominates.
func make_button(text: String, accent_color: Color = Color(0, 0, 0, 0), icon_kind: String = "") -> Button:
	var ac := accent if accent_color.a == 0.0 else accent_color
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 21)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_color_override("font_focus_color", INK)
	btn.add_theme_color_override("font_pressed_color", INK)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.66))
	btn.add_theme_stylebox_override("normal",
		_style(Color(ac.r, ac.g, ac.b, 0.92), ac.lightened(0.3), 0, 0.0, ac))
	btn.add_theme_stylebox_override("hover",
		_style(ac.lightened(0.16), Color(1, 1, 1, 0.9), 2, 20.0, ac))
	btn.add_theme_stylebox_override("focus",
		_style(ac.lightened(0.16), Color(1, 1, 1, 0.9), 2, 20.0, ac))
	btn.add_theme_stylebox_override("pressed",
		_style(ac.darkened(0.12), Color(1, 1, 1, 0.9), 2, 8.0, ac))
	btn.add_theme_stylebox_override("disabled",
		_style(Color(0.22, 0.24, 0.30, 0.7), Color(1, 1, 1, 0.06), 0, 0.0, ac))
	_wire(btn)
	if icon_kind != "":
		_attach_icon(btn, icon_kind, INK)
	return btn


## Secondary button — outlined, transparent, recedes behind primaries.
func make_ghost_button(text: String, icon_kind: String = "") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_focus_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", accent)
	btn.add_theme_stylebox_override("normal",
		_style(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.16), 2, 0.0, accent))
	btn.add_theme_stylebox_override("hover",
		_style(Color(accent.r, accent.g, accent.b, 0.20), accent, 2, 14.0, accent))
	btn.add_theme_stylebox_override("focus",
		_style(Color(accent.r, accent.g, accent.b, 0.20), accent, 2, 14.0, accent))
	btn.add_theme_stylebox_override("pressed",
		_style(Color(accent.r, accent.g, accent.b, 0.32), accent, 2, 6.0, accent))
	btn.add_theme_stylebox_override("disabled",
		_style(Color(0.16, 0.17, 0.22, 0.5), Color(1, 1, 1, 0.05), 2, 0.0, accent))
	_wire(btn)
	if icon_kind != "":
		_attach_icon(btn, icon_kind, accent)
	return btn


## Adds a procedurally-drawn icon to the left side of a button.
func _attach_icon(btn: Button, kind: String, color: Color) -> void:
	var ic := Control.new()
	ic.set_script(load("res://scripts/ui/nav_icon.gd"))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set("kind", kind)
	ic.set("icon_color", color)
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_top = -13.0
	ic.offset_bottom = 13.0
	ic.offset_left = 20.0
	ic.offset_right = 46.0
	btn.add_child(ic)


## Adds hover/press scale animation, focus pop, and UI sounds to a button.
func _wire(btn: Button) -> void:
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	var pop := func(scale: float, t: float):
		if not btn.is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(scale, scale), t)
	btn.mouse_entered.connect(func():
		if btn.disabled:
			return
		pop.call(1.05, 0.16)
		play_hover())
	btn.mouse_exited.connect(func(): pop.call(1.0, 0.12))
	btn.focus_entered.connect(func():
		if btn.disabled:
			return
		pop.call(1.05, 0.16)
		play_hover())
	btn.focus_exited.connect(func(): pop.call(1.0, 0.12))
	btn.button_down.connect(func(): pop.call(0.97, 0.06))
	btn.pressed.connect(func():
		if btn.text.begins_with("‹"):
			play_back()
		else:
			play_click())


# --- Backgrounds ----------------------------------------------------------

func make_gradient_bg(top: Color = BG_TOP, bottom: Color = BG_BOTTOM) -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 16
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
