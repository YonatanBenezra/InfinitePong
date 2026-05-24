extends Control
## Ball Skins — a polished cosmetic collection: a large animated showcase,
## a rarity filter, and a scrollable grid of live skin previews. Selecting
## updates the showcase; equipping persists the choice for gameplay.

const FILTERS := ["All", "Common", "Rare", "Legendary", "Mythic", "Special"]

var _filter: String = "All"
var _selected_id: String = ""
var _preview: Control
var _name_lbl: Label
var _rarity_lbl: Label
var _rarity_chip: PanelContainer
var _desc_lbl: Label
var _equip_btn: Button
var _grid: GridContainer
var _filter_btns: Dictionary = {}
var _panel_box: StyleBoxFlat
var _chip_box: StyleBoxFlat


func _ready() -> void:
	UITheme.set_world(Profile.highest_world_unlocked)
	_selected_id = BallSkins.equipped_id()
	_build_background()
	_build_header()
	_build_filters()
	_build_showcase()
	_build_grid()
	_rebuild_grid()
	_select(_selected_id, false)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


func _build_background() -> void:
	var bg := Node2D.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.07, 0.66)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _build_header() -> void:
	var back := UITheme.make_ghost_button("‹ BACK")
	back.offset_left = 20
	back.offset_top = 20
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	add_child(back)
	var title := UITheme.make_title("BALL SKINS", 36)
	title.anchor_right = 1.0
	title.offset_top = 22
	title.offset_bottom = 64
	add_child(title)


func _build_filters() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Generous gap below the title so the tab row breathes.
	row.offset_top = 88
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for f in FILTERS:
		var b := Button.new()
		b.text = f.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(92, 36)
		b.pressed.connect(_set_filter.bind(f))
		b.mouse_entered.connect(UITheme.play_hover)
		_style_filter(b, f == _filter)
		row.add_child(b)
		_filter_btns[f] = b


func _style_filter(b: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	var ac: Color = UITheme.accent
	s.bg_color = Color(ac.r, ac.g, ac.b, 0.30) if active else Color(1, 1, 1, 0.04)
	s.set_corner_radius_all(9)
	s.set_border_width_all(2)
	s.border_color = ac if active else Color(1, 1, 1, 0.12)
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	s.content_margin_left = 10
	s.content_margin_right = 10
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", Color.WHITE if active else UITheme.TEXT_DIM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)


func _set_filter(f: String) -> void:
	if f == _filter:
		return
	_filter = f
	UITheme.play_click()
	for key in _filter_btns:
		_style_filter(_filter_btns[key], key == f)
	_rebuild_grid()


func _build_showcase() -> void:
	# A compact single-row card: small ball + info + equip button.
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 142
	panel.offset_bottom = 258
	_panel_box = StyleBoxFlat.new()
	_panel_box.bg_color = UITheme.PANEL_SOLID
	_panel_box.set_corner_radius_all(14)
	_panel_box.set_border_width_all(2)
	_panel_box.border_color = UITheme.accent
	_panel_box.set_content_margin_all(12)
	_panel_box.shadow_color = Color(0, 0, 0, 0.5)
	_panel_box.shadow_size = 14
	panel.add_theme_stylebox_override("panel", _panel_box)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# Framed ball stage — small.
	var stage := PanelContainer.new()
	var stage_box := StyleBoxFlat.new()
	stage_box.bg_color = Color(0.04, 0.05, 0.09, 0.92)
	stage_box.set_corner_radius_all(11)
	stage_box.set_border_width_all(1)
	stage_box.border_color = Color(1, 1, 1, 0.07)
	stage_box.set_content_margin_all(5)
	stage.add_theme_stylebox_override("panel", stage_box)
	stage.custom_minimum_size = Vector2(90, 90)
	stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stage)

	_preview = Control.new()
	_preview.set_script(load("res://scripts/ui/ball_preview.gd"))
	_preview.set("radius", 30.0)
	stage.add_child(_preview)

	# Info column — name + rarity pill on one line, description below.
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	info.add_child(name_row)
	_name_lbl = _left("", 21, UITheme.TEXT)
	_name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_row.add_child(_name_lbl)

	_rarity_chip = PanelContainer.new()
	_rarity_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_rarity_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip_box = StyleBoxFlat.new()
	_chip_box.set_corner_radius_all(9)
	_chip_box.set_border_width_all(1)
	_chip_box.content_margin_left = 10
	_chip_box.content_margin_right = 10
	_chip_box.content_margin_top = 2
	_chip_box.content_margin_bottom = 3
	_rarity_chip.add_theme_stylebox_override("panel", _chip_box)
	_rarity_lbl = UITheme.make_label("", 11, UITheme.TEXT)
	_rarity_chip.add_child(_rarity_lbl)
	name_row.add_child(_rarity_chip)

	_desc_lbl = _left("", 13, UITheme.TEXT_DIM)
	info.add_child(_desc_lbl)

	# Compact equip button, right-aligned and vertically centred.
	_equip_btn = UITheme.make_button("EQUIP")
	_equip_btn.custom_minimum_size = Vector2(148, 46)
	_equip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_equip_btn.add_theme_font_size_override("font_size", 18)
	_equip_btn.pressed.connect(_equip)
	row.add_child(_equip_btn)


func _build_grid() -> void:
	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 24
	scroll.offset_right = -24
	scroll.offset_top = 274
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for skin in BallSkins.by_rarity(_filter):
		_grid.add_child(_make_tile(skin))


func _make_tile(skin: Dictionary) -> Button:
	var id := String(skin["id"])
	var rarity := String(skin["rarity"])
	var rcol: Color = BallSkins.rarity_color(rarity)
	var equipped := id == BallSkins.equipped_id()

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(132, 168)
	btn.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		var hot: bool = state == "hover" or state == "pressed" or state == "focus"
		s.bg_color = Color(0.11, 0.13, 0.20, 0.95)
		s.set_corner_radius_all(12)
		s.set_border_width_all(3 if equipped else 2)
		s.border_color = UITheme.accent if equipped else Color(rcol.r, rcol.g, rcol.b, 0.85 if hot else 0.45)
		if hot or equipped:
			s.shadow_color = Color(rcol.r, rcol.g, rcol.b, 0.4)
			s.shadow_size = 10
		btn.add_theme_stylebox_override(state, s)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	vb.offset_top = 14
	vb.offset_bottom = -14
	vb.offset_left = 8
	vb.offset_right = -8
	btn.add_child(vb)

	# Ball preview gets the bulk of the tile, vertically centred in its slot.
	var mini := Control.new()
	mini.set_script(load("res://scripts/ui/ball_preview.gd"))
	mini.set("radius", 26.0)
	mini.custom_minimum_size = Vector2(0, 80)
	mini.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.call("set_skin", skin)
	vb.add_child(mini)

	var nm := UITheme.make_label(String(skin["name"]), 13, UITheme.TEXT)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	vb.add_child(nm)
	var rl := UITheme.make_label("EQUIPPED" if equipped else rarity.to_upper(),
		11, UITheme.accent if equipped else rcol)
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(rl)

	btn.pressed.connect(func(): _select(id, true))
	btn.mouse_entered.connect(UITheme.play_hover)
	return btn


func _select(id: String, animate: bool) -> void:
	_selected_id = id
	var skin := BallSkins.get_skin(id)
	_preview.call("set_skin", skin)
	_name_lbl.text = String(skin["name"])
	var rarity := String(skin["rarity"])
	_set_rarity_chip(rarity)
	_desc_lbl.text = String(skin.get("desc", ""))
	_panel_box.border_color = BallSkins.rarity_color(rarity)
	_refresh_equip_button()
	if animate:
		UITheme.play_click()
		_preview.call("punch", 1.14)


## Recolours the rarity pill to the skin's rarity.
func _set_rarity_chip(rarity: String) -> void:
	var rcol := BallSkins.rarity_color(rarity)
	_rarity_lbl.text = rarity.to_upper()
	_rarity_lbl.add_theme_color_override("font_color", rcol)
	_chip_box.bg_color = Color(rcol.r, rcol.g, rcol.b, 0.22)
	_chip_box.border_color = Color(rcol.r, rcol.g, rcol.b, 0.7)
	_rarity_chip.queue_redraw()


func _refresh_equip_button() -> void:
	var is_on := _selected_id == BallSkins.equipped_id()
	_equip_btn.text = "EQUIPPED" if is_on else "EQUIP"
	_equip_btn.disabled = is_on


func _equip() -> void:
	BallSkins.equip(_selected_id)
	UITheme.play_click()
	_preview.call("punch", 1.26)
	_refresh_equip_button()
	_rebuild_grid()


func _left(text: String, size: int, color: Color) -> Label:
	var l := UITheme.make_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l
