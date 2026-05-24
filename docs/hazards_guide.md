# Hazards guide

There are exactly two hazard types in the game today, and both work by
instance-and-tune — you should not need to write code.

## Spike (`scenes/hazards/hazard_spike.tscn`)

An instant-kill `Area2D`. The ball dies the moment it touches a spike.

### Adding a spike to a chunk

1. Open your chunk scene under `scenes/chunks/`.
2. Drag `scenes/hazards/hazard_spike.tscn` into the scene tree.
3. Position it. Rotate it freely — Godot's `Area2D` rotates with the
   parent so it stays valid.
4. Scale it carefully — if you change scale you may need to update the
   `CollisionShape2D` size inside the spike instance instead.

### Tuning a single spike

The spike scene has no Inspector knobs — it's intentionally minimal so a
hazard always reads the same to the player. If you want a different
look, edit `scenes/hazards/hazard_spike.tscn` directly; the visuals will
update for every spike in every chunk.

## Moving hazard (`scripts/hazards/moving_hazard.gd`)

Any node can be made to ping-pong along an axis by parenting it under a
`Node2D` with the `moving_hazard.gd` script attached. The script does
not own a scene — you compose it.

### Recipe

1. In your chunk scene, add a `Node2D` named e.g. `SpikeMover`.
2. Add the script `scripts/hazards/moving_hazard.gd` to it.
3. Drag a `hazard_spike.tscn` instance underneath `SpikeMover`.
4. In the Inspector, set `moving_node_path` to the spike (the default
   `"."` makes the mover itself move, which is also fine if the mover
   *is* the hazard).
5. Adjust the knobs:

### Inspector knobs (grouped)

**Motion**
- **axis** `Vector2` — direction of movement. `(1, 0)` = horizontal,
  `(0, 1)` = vertical, `(1, 1)` = diagonal.
- **range_px** `float` `[8 .. 600]` — half-amplitude. The hazard sweeps
  from `-range_px` to `+range_px` along the axis, anchored at its
  starting position.
- **speed** `float` `[20 .. 800]` — average pixels per second. The
  generator scales this **up by up to 70%** on later levels, so author
  the base speed for level 1.

**Timing**
- **delay_seconds** `float` `[0 .. 5]` — initial pause before motion
  starts. Pair two hazards with different delays to create timing
  pinches.
- **ease_amount** `float` `[0 .. 1]` — 0 is a sharp triangle wave (the
  hazard reverses instantly at the endpoints); 1 is a smooth cosine
  (the hazard slows, stops, and reverses).

**Target**
- **moving_node_path** `NodePath` — node to move. Defaults to `"."`
  (self).

### Typical setups

| Pattern              | axis      | range_px | speed | ease_amount |
|----------------------|-----------|---------:|------:|------------:|
| Slow horizontal sweep | (1, 0)   | 120      | 100   | 0.6         |
| Snappy vertical poke  | (0, 1)   | 60       | 220   | 0.0         |
| Smooth pendulum       | (1, 0)   | 200      | 180   | 1.0         |
| Diagonal feint        | (1, 0.4) | 150      | 200   | 0.4         |
