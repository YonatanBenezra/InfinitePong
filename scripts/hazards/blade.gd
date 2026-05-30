extends Area2D
class_name Blade
## Spinning blade / saw HAZARD (sprite_07).
##
## Instant death on ball contact — the same contract as `hazard_spike`
## (emits `hazard_hit` for the audio sting, then `player_died`). It is NOT a
## bouncer. The source art is greyscale on purpose so it can be COLOURED in
## engine via `blade_color`, and it SPINS continuously in `_process`.

const BLADE_TEX := "res://assets/sprite_07.png"

## Tint applied to the greyscale art (Sprite2D.modulate).
@export var blade_color: Color = Color(0.72, 0.78, 0.92)
## Spin rate in radians per second. Negative spins the other way.
@export_range(-20.0, 20.0, 0.5) var spin_speed: float = 6.0
## How many player-bullet hits the blade absorbs before it pops. Bullets are
## the only thing that can destroy it; ball contact is still an instant kill.
@export_range(1, 10, 1) var hp: int = 2

var _sprite: Sprite2D
var _hp: int = 2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_hp = hp
	var tex := load(BLADE_TEX) as Texture2D
	if tex == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate = blade_color
	var cs := _find_circle()
	if cs != null:
		var r: float = (cs.shape as CircleShape2D).radius
		var fit := (r * 2.0) / float(maxi(tex.get_width(), tex.get_height()))
		_sprite.scale = Vector2(fit, fit)
	add_child(_sprite)


func _process(delta: float) -> void:
	# Spin only the art — the round kill-box is rotation-symmetric, so the
	# hazard's reach stays constant while the blade visibly rotates.
	if _sprite != null:
		_sprite.rotation += spin_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		GameEvents.hazard_hit.emit()
		GameEvents.player_died.emit()


## Damage hook used by player bullets (same contract as the other hazards —
## see bullet.gd / hazard_spike.gd). The ball-contact path above is unchanged:
## touching the blade is still an instant kill. Each bullet consumes itself on
## the hit (bullet.gd), so one bullet = 1 HP. At 0 HP the blade pops with the
## standard hazard burst and frees itself. Rotation is left untouched.
func take_damage(amount: int) -> void:
	_hp -= amount
	if _hp <= 0:
		var scene := get_tree().current_scene
		if scene != null:
			VFX.burst(scene, global_position, blade_color, 20, 240.0, 0.5)
		queue_free()


func _find_circle() -> CollisionShape2D:
	for c in get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is CircleShape2D:
			return c
	return null
