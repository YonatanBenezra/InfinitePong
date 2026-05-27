extends Area2D
## Glue trap: catches the ball on contact and holds it in place. While
## stuck, the player aims with the mouse — the ball draws an aim trail
## toward the cursor — and pressing the flipper input (SPACE) launches
## the ball with force in the aim direction.
##
## "Launch" here means assigning the ball a velocity; nothing is shot.
##
## A short release cooldown stops the ball from snapping straight back
## into the glue on the same frame it leaves.

## Speed (px/s) the ball is given when the player releases.
@export_range(100.0, 2000.0, 20.0) var launch_speed: float = 600.0
## How long after a release this glue ignores the ball, so the player
## isn't instantly re-stuck on the same launch.
@export var release_cooldown: float = 0.4
## Bullet hits the glue absorbs before being destroyed. 1 = one-shot.
@export_range(1, 10, 1) var max_hp: int = 1

var _hp: int = 1

var _stuck_ball: RigidBody2D = null
var _cooldown_left: float = 0.0
## Once the ball is captured, the player must let go of the flipper input
## before a press can fire the launch. Otherwise a press that was already
## being held when the ball touched the glue would launch on the same
## frame and the player would never get to aim.
var _flipper_released_since_capture: bool = false
## Time accumulator driving the visual wobble — the collision shape stays
## fixed; only the Body child is scaled, so gameplay is unaffected.
var _wobble_time: float = 0.0


func _ready() -> void:
	add_to_group("glue_hazard")
	monitoring = true
	# `monitorable = true` so player bullets (also Area2D) can detect the
	# glue via area_entered. Nothing else in the project scans for it.
	monitorable = true
	body_entered.connect(_on_body_entered)
	_hp = max_hp


## Damage hook used by bullets. If a stuck ball is still attached when
## the glue pops, release it first so the player isn't left frozen.
func take_damage(amount: int) -> void:
	_hp -= amount
	if _hp > 0:
		return
	if is_instance_valid(_stuck_ball):
		_stuck_ball.freeze = false
		if _stuck_ball.has_method("exit_glue_aim"):
			_stuck_ball.call("exit_glue_aim")
		_stuck_ball = null
	var scene := get_tree().current_scene
	if scene != null:
		VFX.burst(scene, global_position, Color(0.65, 0.95, 0.45),
			20, 220.0, 0.5)
	queue_free()


func _process(delta: float) -> void:
	# Visual-only wobble — the Body child gently breathes so the hazard
	# reads as sticky goo rather than a static blob. Doesn't touch the
	# Area's collision shape, so gameplay is unaffected.
	_wobble_time += delta
	var body := get_node_or_null("Body") as Node2D
	if body != null:
		var s := 1.0 + sin(_wobble_time * 2.6) * 0.05
		body.scale = Vector2(s, s)


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if not is_instance_valid(_stuck_ball):
		_stuck_ball = null
		return
	# Pin the ball to the glue centre so the aim line is anchored cleanly.
	_stuck_ball.global_position = global_position
	_stuck_ball.linear_velocity = Vector2.ZERO
	_stuck_ball.angular_velocity = 0.0
	if not Input.is_action_pressed("flipper"):
		_flipper_released_since_capture = true
	elif _flipper_released_since_capture:
		_release()


func _on_body_entered(body: Node) -> void:
	if _stuck_ball != null or _cooldown_left > 0.0:
		return
	if not body.is_in_group("ball"):
		return
	var ball := body as RigidBody2D
	if ball == null:
		return
	_stuck_ball = ball
	_flipper_released_since_capture = false
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.freeze = true
	ball.global_position = global_position
	if ball.has_method("enter_glue_aim"):
		ball.call("enter_glue_aim", self)
	GameEvents.hazard_hit.emit()


func _release() -> void:
	var ball := _stuck_ball
	_stuck_ball = null
	_cooldown_left = release_cooldown
	if ball == null:
		return
	ball.freeze = false
	# Aim from the ball toward the mouse cursor in world space.
	var mouse_world := ball.get_global_mouse_position()
	var dir := mouse_world - ball.global_position
	if dir.length() < 1.0:
		dir = Vector2.DOWN
	dir = dir.normalized()
	ball.linear_velocity = dir * launch_speed
	if ball.has_method("exit_glue_aim"):
		ball.call("exit_glue_aim")
