extends Object
class_name VFX
## Lightweight one-shot particle bursts. Each call spawns a self-freeing
## CPUParticles2D so callers never manage lifetimes. Respects the player's
## "particles" setting — when disabled, calls are no-ops.

## Spawns a radial spark burst at a world position under `parent`.
static func burst(parent: Node, pos: Vector2, color: Color,
		amount: int = 14, speed: float = 200.0, lifetime: float = 0.55) -> void:
	if not GameSettings.particles_enabled:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 360)
	p.damping_min = 40.0
	p.damping_max = 110.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.8
	p.color = color
	parent.add_child(p)
	p.finished.connect(p.queue_free)


## A bigger, longer death explosion.
static func explode(parent: Node, pos: Vector2, color: Color) -> void:
	burst(parent, pos, color, 40, 380.0, 0.85)
	burst(parent, pos, Color(1, 1, 1, 0.9), 16, 240.0, 0.5)
