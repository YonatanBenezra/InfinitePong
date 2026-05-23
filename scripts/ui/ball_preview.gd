extends Control
## Animated ball-skin preview widget. Runs its own clock and renders a skin
## through BallSkinRenderer with an idle bob, so previews look alive both in
## the big showcase and in the selection grid.

@export var radius: float = 30.0

var _skin: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	_t = randf() * 6.0   # desync grid tiles


func set_skin(skin: Dictionary) -> void:
	_skin = skin
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _skin.is_empty():
		return
	var bob := sin(_t * 2.0) * radius * 0.10
	draw_set_transform(size * 0.5 + Vector2(0, bob), 0.0, Vector2.ONE)
	BallSkinRenderer.paint(self, _skin, radius, _t, _t * 0.7)


## A short scale punch — used on select / equip for tactile feedback.
func punch(strength: float = 1.18) -> void:
	pivot_offset = size * 0.5
	scale = Vector2(strength, strength)
	create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT) \
		.tween_property(self, "scale", Vector2.ONE, 0.5)
