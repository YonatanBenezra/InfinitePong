class_name PinBall
extends RigidBody2D

signal died
signal reached_exit
signal bounced

const MAX_SPEED := 1500.0

@export var spawn_impulse := Vector2(30, 80)

var _impact_cooldown: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	contact_monitor = true
	max_contacts_reported = 8
	add_to_group("ball")
	body_entered.connect(_on_body_entered)


func reset_at(pos: Vector2) -> void:
	global_position = pos
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = false
	_impact_cooldown = 0.0
	apply_central_impulse(spawn_impulse)


func _physics_process(delta: float) -> void:
	if linear_velocity.length() > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("hazard"):
		die()
		return
	if body.is_in_group("flipper_body") and _impact_cooldown <= 0.0:
		_impact_cooldown = 0.08
		bounced.emit()
		var flipper_parent := body.get_parent()
		if flipper_parent is StandardFlipper:
			(flipper_parent as StandardFlipper)._apply_hit(self, 0.85)
		elif flipper_parent is FlatFlipper:
			(flipper_parent as FlatFlipper)._apply_hit(self, 0.85)
		elif flipper_parent.get_parent() is StandardFlipper:
			(flipper_parent.get_parent() as StandardFlipper)._apply_hit(self, 0.85)
		elif flipper_parent.get_parent() is FlatFlipper:
			(flipper_parent.get_parent() as FlatFlipper)._apply_hit(self, 0.85)


func die() -> void:
	linear_velocity = Vector2.ZERO
	sleeping = true
	died.emit()
