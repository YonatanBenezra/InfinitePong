extends Area2D
## Spike hazard: instant death on ball contact (GDD).
##
## Emits a dedicated `hazard_hit` event in addition to `player_died` so
## the audio layer can play a distinct hazard-collision stinger separate
## from the longer player-death wail.


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_sprites()


func _apply_sprites() -> void:
	var tex := SpriteBank.get_texture(SpriteBank.SPIKE)
	if tex == null:
		return  # keep the Polygon2D visuals defined in the scene
	for child in get_children():
		if child is Polygon2D:
			child.visible = false
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(40.0 / float(tex.get_width()), 44.0 / float(tex.get_height()))
	add_child(spr)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		GameEvents.hazard_hit.emit()
		GameEvents.player_died.emit()
