extends Area2D
## Spike hazard: instant death on ball contact (GDD). Can also be
## destroyed by player bullets — `max_hp` controls how many bullets a
## spike absorbs before it pops.
##
## Emits a dedicated `hazard_hit` event in addition to `player_died` so
## the audio layer can play a distinct hazard-collision stinger separate
## from the longer player-death wail.

## How many bullet hits the spike absorbs before being destroyed. 1 =
## one-shot (the default for a "basic" hazard); raise it for tougher
## spike variants placed by hand in chunk scenes.
@export_range(1, 10, 1) var max_hp: int = 1

var _hp: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_hp = max_hp
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


## Damage hook used by bullets. The contact-with-ball path is unchanged
## (still an instant kill on touch); this is only for projectile fire.
func take_damage(amount: int) -> void:
	_hp -= amount
	if _hp <= 0:
		var scene := get_tree().current_scene
		if scene != null:
			VFX.burst(scene, global_position, Color(1.0, 0.32, 0.36),
				18, 240.0, 0.5)
		queue_free()
