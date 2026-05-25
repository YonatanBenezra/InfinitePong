extends Area2D
## Bottom exit: completes the level when the ball enters.
## Animates a soft pulse so the goal is highly visible from above.

## CanvasItem covers both Polygon2D (fallback) and Sprite2D (sprite mode).
@onready var _glow: CanvasItem = $Glow
var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_sprites()


func _apply_sprites() -> void:
	var tex := SpriteBank.get_texture(SpriteBank.EXIT_GATE)
	if tex == null:
		return  # keep the Polygon2D visuals defined in the scene
	for child in get_children():
		if child is Polygon2D:
			child.visible = false
	# Glow layer — full size, animated alpha.
	var glow_spr := Sprite2D.new()
	glow_spr.name = "GlowSprite"
	glow_spr.texture = tex
	glow_spr.scale = Vector2(200.0 / float(tex.get_width()), 64.0 / float(tex.get_height()))
	glow_spr.modulate = Color(0.3, 1.0, 0.5, 0.7)
	add_child(glow_spr)
	_glow = glow_spr


func _process(delta: float) -> void:
	if _glow == null:
		return
	_t += delta
	var pulse := 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 4.0))
	_glow.modulate.a = pulse


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		GameEvents.level_completed.emit()
