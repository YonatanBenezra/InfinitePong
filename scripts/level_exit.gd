extends Area2D
## Bottom exit: completes the level when the ball enters.
## Animates a soft pulse so the goal is highly visible from above.

@onready var _glow: Polygon2D = $Glow
var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _glow == null:
		return
	_t += delta
	var pulse := 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 4.0))
	_glow.modulate.a = pulse


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		GameEvents.level_completed.emit()
