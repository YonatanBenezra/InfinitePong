# Flippers guide

The game has two flipper prefabs. Both are tuned for reliability — the
ball never tunnels through them — so as a designer you only need to
think about geometry and feel.

| File                                       | When to use                                 |
|--------------------------------------------|---------------------------------------------|
| `scenes/flippers/flipper_standard.tscn`    | A classic pivot flipper. Swings around the pivot. |
| `scenes/flippers/flipper_flat.tscn`        | A rigid plate that slides between two positions.  |

Both flippers respond to the same input — `Space` or `Left mouse`.

## Adding a flipper to a chunk

1. Open your chunk scene under `scenes/chunks/`.
2. Drag the flipper `.tscn` into the scene tree.
3. Position it. For a standard flipper the **position is the pivot**,
   so place the node where the bar should hinge.
4. Tune the knobs in the Inspector (see below).

## Standard flipper (`flipper_standard.gd`)

A bar that rotates around its pivot. Two modes:

- **Default (upward swing)** — `rest_angle_deg > active_angle_deg`. Bar
  hangs down and swings up while held. The classic pinball flipper.
- **Inverted (downward swing)** — `rest_angle_deg < active_angle_deg`.
  Bar starts raised (often blocking the path) and drops while held.

### Inspector knobs

**Geometry**
- **rest_angle_deg** `[-180 .. 180]` — angle when the flipper is NOT held.
- **active_angle_deg** `[-180 .. 180]` — angle when the flipper IS held.
- **bar_length** `[20 .. 240]` — bar length in pixels. Used by the
  assist kick to know where the bar tip is.
- **mirror** `bool` — set true for a right-side flipper. Both angles get
  negated, so you can keep the same conventions on both sides.

**Motion**
- **flick_speed_deg** `[120 .. 2400]` — swing speed in degrees per
  second. ~900 is the default snappy feel.

**Kick**
- **kick_impulse** `[100 .. 2000]` — velocity bonus added to the ball
  when the bar kicks it.
- **contact_radius** `[16 .. 96]` — how close the ball has to be to the
  bar (in pixels) to receive the assist kick.

### Typical setups

| Pattern                | rest | active | mirror |
|------------------------|-----:|-------:|:------:|
| Left, classic upward   |   30 |    -52 |        |
| Right, classic upward  |   30 |    -52 |   ✓    |
| Left, inverted drop    |  -30 |     30 |        |
| Centered, sweep right  |   90 |     -5 |        |

## Flat flipper (`flipper_flat.gd`)

A rigid plate that translates between two positions. Two modes:

- **Default pop** — `active_offset.y < 0`. Plate rests low, pops up
  while held.
- **Inverted drop** — `active_offset.y > 0`. Plate rests high (often
  blocking the path) and drops while held so the ball can pass.

### Inspector knobs

**Motion**
- **move_speed** `[200 .. 4000]` — pixels per second the plate moves
  between rest and active positions.
- **active_offset** `Vector2` — local offset from rest to the active
  position. `(0, -90)` pops up, `(0, 90)` drops down, `(120, 0)` slides
  right, etc.

**Kick**
- **kick_impulse** `[100 .. 2000]` — velocity bonus added to the ball
  when the plate kicks it.
- **contact_radius** `[20 .. 240]` — how close the ball has to be (in
  pixels) to receive the assist kick.

### Typical setups

| Pattern                  | active_offset | move_speed | kick_impulse |
|--------------------------|---------------|-----------:|-------------:|
| Floor pop launcher       | (0, -90)      | 1300       | 600          |
| Ceiling gate drop        | (0, 90)       | 1300       | 600          |
| Side puncher (left→right)| (120, 0)      | 1100       | 700          |

## Reliability notes (FYI)

- Both flippers use `sync_to_physics = true`, so a moving flipper
  transfers real momentum to the ball through the physics solver instead
  of teleporting past it.
- The plate's max move speed is capped at a value that, at the project's
  120 Hz physics tick, is below the ball's diameter per step. That's why
  pushing `move_speed` very high doesn't help — the ball would just
  tunnel.
- The assist kick fires **at most once per press** and only on the
  leading face / in the swing direction. It can never push the ball
  through the flipper to the far side.
