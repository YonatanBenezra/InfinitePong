extends Control
## Post-level upgrade draft. Shown the moment a level is cleared: presents
## three upgrade cards (rolled by the Upgrades system) and lets the player
## keep exactly one. Built procedurally via setup(); the owner supplies the
## on_select callback, which applies the pick and advances to the next level.
##
## Kept in-scene (no reload) so the level -> upgrade -> next-level loop stays
## instant, mirroring results_overlay.gd.

var _on_select: Callable


func setup(result: Dictionary, choices: Array, on_select: Callable) -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_on_select = on_select
	var accent: Color = UITheme.accent

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.0)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	add_child(scrim)
	scrim.create_tween().tween_property(scrim, "color:a", 0.82, 0.25)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := UITheme.make_panel(UITheme.PANEL_SOLID)
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	vb.add_child(UITheme.make_title(
		"LEVEL %d CLEARED" % int(result.get("level", 1)), 30, accent))
	vb.add_child(UITheme.make_label("CHOOSE AN UPGRADE", 13, UITheme.TEXT_DIM))

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 2)
	vb.add_child(line)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	var first: Button = null
	for u in choices:
		var card := _make_card(u)
		row.add_child(card)
		if first == null:
			first = card
	if first != null:
		first.call_deferred("grab_focus")

	# Entrance: simple fade only.
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.22)


## One clickable upgrade card. The whole card is a ghost button; a non-
## interactive VBox paints the name + description centred on top of it, so a
## click (or Enter on the focused card) selects that upgrade.
func _make_card(u: Dictionary) -> Button:
	var btn := UITheme.make_ghost_button("")
	btn.custom_minimum_size = Vector2(150, 132)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	vb.anchor_right = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left = 10
	vb.offset_right = -10
	vb.offset_top = 10
	vb.offset_bottom = -10

	var name_l := UITheme.make_label(String(u.get("name", "?")), 17, UITheme.TEXT)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(name_l)

	var desc_l := UITheme.make_label(String(u.get("desc", "")), 12, UITheme.TEXT_DIM)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(desc_l)

	btn.add_child(vb)
	btn.pressed.connect(func() -> void: _choose(u))
	return btn


## Guards against a double-fire: once a card is chosen the overlay stops
## responding so a fast second click can't apply two upgrades.
func _choose(u: Dictionary) -> void:
	if not _on_select.is_valid():
		return
	var cb := _on_select
	_on_select = Callable()
	cb.call(u)
