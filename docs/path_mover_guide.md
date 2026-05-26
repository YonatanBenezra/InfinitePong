# Path mover guide

`PathMover` (`scripts/gameplay/path_mover.gd`) is the reusable
path-movement primitive for this project. Drop one into a scene, give it
a few points, and **anything you parent under it follows the path** —
hazards, platforms, flippers, bumpers, secret doors, whatever you need.

It coexists with the older `scripts/hazards/moving_hazard.gd`. Existing
chunks that use `moving_hazard` keep working unchanged; `PathMover` is
the preferred system for new movement.

## Why use PathMover

- **More than one direction.** `moving_hazard` does a single axis sweep;
  `PathMover` takes an arbitrary list of waypoints.
- **Loop or ping-pong**, your choice.
- **Wait times** at each point — easy to author beats and pinch timings.
- **Editor preview.** The path is drawn as dots + lines in the Godot
  editor, so you can lay it out without launching the game.
- **One node, any child.** Parent anything underneath; it inherits the
  motion automatically because PathMover is a plain `Node2D`.

## Quick recipe

1. Open the chunk scene you want to add motion to (`scenes/chunks/…`).
2. **Add Child Node** and search for `PathMover`. Place it where the
   path should **start**. The PathMover itself is invisible — only the
   things you parent under it render.
3. In the Inspector, fill in **Path → points** with offsets from that
   start position:

   ```
   points = [
     Vector2(0, 0),       # start
     Vector2(200, 0),     # 200 px to the right
     Vector2(200, 120),   # then 120 px down
   ]
   ```

   The first point is the path start (usually `(0, 0)`).
4. Drag whatever you want moved underneath PathMover as a **child**.
   `hazard_spike.tscn`, a platform, a flipper, a chunk-local bumper —
   anything. It will travel along with the mover.
5. Pick a **mode** under *Path → mode*:

   - **LOOP** — after the last point, jump back to the first.
   - **PINGPONG** — after the last point, walk back to the first.
   - **ONESHOT** — stop at the last point.

   Then tweak **Motion → speed**, **start_delay** and **wait_time**.

## Inspector reference

**Path**
- `points: Array[Vector2]` — Waypoints, in pixels, as offsets from the
  PathMover's authored position.
- `mode: Mode` — `LOOP`, `PINGPONG`, or `ONESHOT`.

**Motion**
- `speed: float` `[20 .. 1200]` — Linear speed in px/s along the path.
- `start_delay: float` `[0 .. 10]` — Pause at `points[0]` before the
  first move. Stagger this across paired movers to create pinches.
- `wait_time: float` `[0 .. 5]` — Pause at *every* waypoint before
  continuing to the next.

**Debug**
- `debug_draw: bool` — Show the path overlay in editor and at runtime.
- `debug_color: Color` — Overlay tint.

## Patterns

| Pattern | points | mode | speed | wait_time | Notes |
|---|---|---|---:|---:|---|
| Horizontal sweep | `[(0,0), (240,0)]` | PINGPONG | 180 | 0 | Same as the old `moving_hazard` axis sweep |
| Pause at the ends | `[(0,0), (200,0)]` | PINGPONG | 200 | 0.4 | Tempting standstill — good for spikes |
| Square patrol | `[(0,0), (180,0), (180,120), (0,120)]` | LOOP | 150 | 0 | Classic platform patrol |
| Triangle pinch | `[(-120,0), (0,-60), (120,0)]` | LOOP | 220 | 0.15 | Two paired movers with staggered `start_delay` make a great pinch |
| One-shot drop | `[(0,0), (0,200)]` | ONESHOT | 320 | 0 | Door/gate that opens once |

## Migrating from `moving_hazard`

You don't *have* to. `moving_hazard.gd` still works and existing chunks
keep using it. If you want to swap one over:

1. Note the existing `axis`, `range_px`, `delay_seconds`.
2. Replace the `Node2D + moving_hazard.gd` parent with a `PathMover`.
3. Set `points = [axis * -range_px, axis * range_px]`, `mode = PINGPONG`,
   `start_delay = delay_seconds`, and tune `speed` to match.
4. Re-parent the existing hazard / object underneath the new mover.

The previous `moving_hazard`'s `ease_amount` (cosine slowdown at
endpoints) doesn't have a PathMover equivalent — PathMover travels each
segment at constant speed. Use `wait_time` for a hard pause at endpoints
instead, or stick with `moving_hazard` if you specifically need cosine
easing.

## Gotchas

- **Points are offsets**, not absolute parent-space positions. The mover
  is anchored at the position you authored, and the points describe how
  far to travel from there. The first point is usually `(0, 0)`.
- **At least two points are needed** for motion. One point or none →
  the mover stays put (useful while you're authoring).
- **Don't rotate / scale the PathMover.** It's authored to operate at
  identity transform; rotated parents can desync the debug overlay.
- **Physics children** (Area2D, RigidBody2D in animatable mode, …) move
  with the parent automatically — no extra setup. If you want a moving
  flipper, parent a `FlipperStandard` under PathMover the same way.
