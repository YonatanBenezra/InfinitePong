extends Area2D
## Spike hazard: instant death on ball contact (GDD).
##
## Emits a dedicated `hazard_hit` event in addition to `player_died` so
## the audio layer can play a distinct hazard-collision stinger separate
## from the longer player-death wail.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		GameEvents.hazard_hit.emit()
		GameEvents.player_died.emit()
