extends RigidBody2D
## Round static bumper: pops the ball outward on contact and pulses the
## sprite for hit feedback. Spawned at `BumperSlot` markers by ChunkGenerator.

@export_group("Bounce")
@export_range(200.0, 900.0, 10.0) var bounce_speed: float = 520.0
@export_range(0.06, 0.5, 0.01) var hit_cooldown: float = 0.12

@export_group("Visual")
@export_range(8.0, 80.0, 1.0) var display_radius: float = 17.0
@export_range(1.05, 1.5, 0.01) var pulse_peak_scale: float = 1.22
@export_range(0.08, 0.4, 0.01) var pulse_duration: float = 0.2

const TEX_PATH := "res://assets/sprite_05.png"
const RICOCHET_SPEED := 675.0
## Local-space padding (px) added to the detector radius beyond the solid
## collider, so the ball reliably trips the bumper right as it makes contact.
## Local px: it scales with the bumper, so a 2x slot stays correct.
const CONTACT_PAD := 3.0
## Collision-layer bit the ball lives on (see ball.tscn collision_layer = 2).
const BALL_LAYER_MASK := 2

var _last_hit_time: float = -1.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var _sprite: Sprite2D
var _pulse_tween: Tween
var _detector: Area2D


func _ready() -> void:
	add_to_group("static_bumper")
	freeze = true
	_sprite = get_node_or_null("Sprite") as Sprite2D
	_apply_sprite()
	_sync_collision_radius()
	_build_detector()


func _apply_sprite() -> void:
	if _sprite == null:
		return
	var tex := load(TEX_PATH) as Texture2D
	if tex == null:
		return
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	var diameter := display_radius * 2.0
	var s := diameter / float(tex.get_width())
	_base_sprite_scale = Vector2(s, s)
	_sprite.scale = _base_sprite_scale


func _sync_collision_radius() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not col.shape is CircleShape2D:
		return
	(col.shape as CircleShape2D).radius = display_radius


## Detection runs through a child Area2D, NOT the body's own contact_monitor:
## a frozen RigidBody2D does not reliably emit body_entered (that is why the
## pop never fired), and an Area2D child inherits the bumper's scale, so a
## 2x-scaled slot (e.g. chunk_bumper_pit) is still detected at the right
## distance instead of the ball bouncing off well outside the poll range.
func _build_detector() -> void:
	_detector = Area2D.new()
	_detector.collision_layer = 0
	_detector.collision_mask = BALL_LAYER_MASK
	var shape := CircleShape2D.new()
	shape.radius = display_radius + CONTACT_PAD
	var cs := CollisionShape2D.new()
	cs.shape = shape
	_detector.add_child(cs)
	add_child(_detector)
	_detector.body_entered.connect(_on_detector_body)


## Pop on first contact, and every physics step the ball stays overlapping,
## so a ball that settles against the bumper keeps getting bounced off.
func _physics_process(_delta: float) -> void:
	if _detector == null:
		return
	for body in _detector.get_overlapping_bodies():
		if body.is_in_group("ball"):
			_try_push(body as RigidBody2D)
			break


func _on_detector_body(body: Node) -> void:
	if body.is_in_group("ball"):
		_try_push(body as RigidBody2D)


## Pops the ball outward at (at least) bounce_speed and pulses the sprite.
## Gated by hit_cooldown so the poll above can run every frame without the
## bumper machine-gunning the ball.
func _try_push(ball: RigidBody2D) -> void:
	if ball == null or ball.freeze:
		return  # ball is dead / between lives; don't pop it or fire hit cues
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hit_time < hit_cooldown:
		return
	_last_hit_time = now

	var away := ball.global_position - global_position
	if away.length_squared() < 4.0:
		away = Vector2.UP
	else:
		away = away.normalized()

	var speed := maxf(ball.linear_velocity.dot(away), bounce_speed)
	ball.linear_velocity = away * speed

	_pulse()
	var total := ball.linear_velocity.length()
	if total >= RICOCHET_SPEED:
		GameEvents.ball_ricochet.emit(total)
	else:
		GameEvents.ball_hit.emit(total)


func _pulse() -> void:
	if _sprite == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_sprite.scale = _base_sprite_scale
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK)
	_pulse_tween.set_ease(Tween.EASE_OUT)
	var peak := _base_sprite_scale * pulse_peak_scale
	_pulse_tween.tween_property(_sprite, "scale", peak, pulse_duration * 0.38)
	_pulse_tween.tween_property(_sprite, "scale", _base_sprite_scale, pulse_duration * 0.62)
