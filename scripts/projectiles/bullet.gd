extends Area2D
## Player projectile. Travels in a fixed direction at constant speed,
## damages anything with a `take_damage(amount)` method on collision, and
## self-destructs after `lifetime` seconds or on hit.
##
## - Hazards expose `take_damage(amount: int)` so the bullet can damage
##   them uniformly (spikes, glue, breakable blocks, future hazards).
## - Walls (or any body without `take_damage`) simply stop the bullet.
## - The ball is excluded via the collision mask — bullets cannot harm
##   the player. Other bullets are ignored too.

@export_range(100.0, 3000.0, 10.0) var speed: float = 900.0
@export_range(0.1, 4.0, 0.05) var lifetime: float = 1.1
@export_range(1, 10, 1) var damage: int = 1
@export var bullet_color: Color = Color(1.0, 0.92, 0.45, 1.0)
@export var trail_color: Color = Color(1.0, 0.78, 0.30, 0.55)
@export var radius: float = 3.0

var _direction: Vector2 = Vector2.RIGHT
var _life_left: float = 0.0
var _spent: bool = false


func _ready() -> void:
	_life_left = lifetime
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()


## Called by the spawner immediately after instancing. Locks in the
## travel direction and visual rotation.
func setup(dir: Vector2) -> void:
	if dir.length() < 0.001:
		dir = Vector2.DOWN
	_direction = dir.normalized()
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	position += _direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_consume()


func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	_try_hit(area)


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	if not _try_hit(body):
		# Hit something solid (wall, frozen body) with no damage hook —
		# the bullet just stops there.
		_consume()


func _try_hit(node: Node) -> bool:
	if node.has_method("take_damage"):
		node.call("take_damage", damage)
		GameEvents.bullet_hit_hazard.emit(global_position)
		_consume()
		return true
	return false


func _consume() -> void:
	_spent = true
	queue_free()


func _draw() -> void:
	# Short oriented trail behind the bullet head — drawn in local space,
	# so the bullet's rotation gives us "behind" as -X.
	var tail_len := radius * 4.5
	var tail := PackedVector2Array([
		Vector2(0, -radius * 0.6),
		Vector2(-tail_len, 0),
		Vector2(0, radius * 0.6),
	])
	draw_colored_polygon(tail, trail_color)
	draw_circle(Vector2.ZERO, radius, bullet_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 12,
		Color(0.25, 0.15, 0.05, 0.8), 1.0, true)
