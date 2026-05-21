extends Area2D
## Spike hazard: instant death on ball contact (GDD).


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		GameEvents.player_died.emit()
