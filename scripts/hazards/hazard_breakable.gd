extends RigidBody2D
## Destructible hazard: blocks the ball like a wall, takes one HP per
## qualifying impact, and is destroyed (with a particle burst) when HP
## reaches zero.
##
## The body colour is keyed to STARTING_HP so the player can read a
## hazard's toughness at a glance:
##   1 — red       (one-shot)
##   2 — orange
##   3 — yellow
##   4 — green
##   5 — cyan
##   6 — purple    (toughest)
##
## Implementation note: this is a frozen RigidBody2D (rather than a plain
## StaticBody2D) so we can subscribe to `body_entered` and count hits
## directly, without an extra Area2D sensor and tricky shape-size matching.

@export_range(1, 6, 1) var starting_hp: int = 3
## Minimum ball speed for an impact to count as a hit. Stops gentle
## brushes and slow rolls from chipping the hazard for free.
@export var min_hit_speed: float = 160.0
## Cooldown between counted hits, so one bounce can't be charged twice
## by overlapping contact reports.
@export var hit_cooldown: float = 0.18

const HP_COLORS: Array[Color] = [
	Color(1.00, 0.32, 0.36),  # 1
	Color(1.00, 0.55, 0.30),  # 2
	Color(1.00, 0.85, 0.30),  # 3
	Color(0.50, 0.92, 0.45),  # 4
	Color(0.40, 0.80, 0.96),  # 5
	Color(0.78, 0.55, 1.00),  # 6
]

var _hp: int
var _last_hit_time: float = -1.0


func _ready() -> void:
	add_to_group("breakable_hazard")
	# Frozen = acts statically; contact_monitor lets us count hits.
	freeze = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	_hp = clampi(starting_hp, 1, HP_COLORS.size())
	_apply_color()


func _apply_color() -> void:
	var col := HP_COLORS[clampi(starting_hp - 1, 0, HP_COLORS.size() - 1)]
	var v := get_node_or_null("Visual") as Polygon2D
	var o := get_node_or_null("Outline") as Polygon2D
	if v != null:
		v.color = col
	if o != null:
		o.color = col.darkened(0.55)
	# As HP drops, fade slightly so a "weakened" block reads visually.
	var ratio := float(_hp) / float(maxi(starting_hp, 1))
	modulate = Color(1, 1, 1, lerpf(0.55, 1.0, ratio))


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("ball"):
		return
	var ball := body as RigidBody2D
	if ball == null:
		return
	if ball.linear_velocity.length() < min_hit_speed:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hit_time < hit_cooldown:
		return
	_last_hit_time = now
	take_damage(1)


## Bullet damage hook. Shares the destroy / flash logic with the ball
## impact path so both sources of damage feel identical.
func take_damage(amount: int) -> void:
	_hp -= amount
	GameEvents.hazard_hit.emit()
	if _hp <= 0:
		_destroy()
	else:
		_apply_color()
		_flash()


func _flash() -> void:
	var v := get_node_or_null("Visual") as Polygon2D
	if v == null:
		return
	v.modulate = Color(1.8, 1.8, 1.8)
	var t := create_tween()
	t.tween_property(v, "modulate", Color(1, 1, 1), 0.18)


func _destroy() -> void:
	var col := HP_COLORS[clampi(starting_hp - 1, 0, HP_COLORS.size() - 1)]
	# Particles are parented to the current scene so they outlive `self`.
	var scene := get_tree().current_scene
	if scene != null:
		VFX.burst(scene, global_position, col, 22, 260.0, 0.55)
	queue_free()
