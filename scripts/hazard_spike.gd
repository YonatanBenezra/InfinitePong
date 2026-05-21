<<<<<<< HEAD
extends Area2D
## Spike hazard: instant death on ball contact (GDD).


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		GameEvents.player_died.emit()
=======
class_name SpikeHazard
extends Area2D

@export var move_enabled: bool = false
@export var move_speed: float = 80.0
@export var move_distance: float = 64.0
@export var move_axis := Vector2.RIGHT
@export var delay_offset: float = 0.0

var _origin: Vector2
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("hazard")
	monitoring = true
	_origin = position
	_time = delay_offset
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not move_enabled:
		return
	_time += delta
	var offset := sin(_time * move_speed * 0.02 + delay_offset) * move_distance
	position = _origin + move_axis.normalized() * offset
	if has_node("Visual"):
		var pulse := 0.85 + sin(_time * 4.0) * 0.15
		$Visual.modulate = Color(pulse, pulse * 0.3, pulse * 0.35, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball") and body.has_method("die"):
		body.die()
>>>>>>> 3baf8dd182d1f8559ff606cfad718104a3199c39
