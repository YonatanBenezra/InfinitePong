# Chunks guide

A **chunk** is one vertical slice of a level. The generator stacks
chunks top-to-bottom to assemble each level: a start chunk, several
middle chunks, then a finale chunk with the green exit.

This guide is written for level designers. You should not need to edit
any GDScript to author, tune, or remove chunks.

## TL;DR

1. **Open Godot** and load this project.
2. **Duplicate `scenes/chunks/chunk_TEMPLATE.tscn`** (or an existing chunk
   that's closest to what you want).
3. **Place** platforms, flippers and hazards inside it. The chunk is
   already centered around `(0, 0)` — see the diagram below.
4. **Create** a matching `chunk_def_xxx.tres` in `resources/chunks/`
   (or duplicate an existing one and point its `scene` field at your new
   chunk).
5. **Drop** the new `chunk_def_xxx.tres` into the `chunk_pool` of
   `resources/levels/default_level_config.tres`.
6. **Press F5** to playtest.

## The coordinate frame — read this first

Every chunk is authored on the **(0, 0)-centered** convention:

```
       (chunk-local coordinates)

        -320           0           +320
          │ ←——————— 640 ———————→ │     x = 0 is the CENTER
   y=0 ──┼───────[ConnectTop]─────┼──   ← top of the chunk
          │                       │
          │      ┌─────────┐      │     authored content
          │      │ BALL    │      │     lives at world
          │      │ ↓       │      │     x ∈ [-320, +320]
          │      │         │      │
  WallL ──┤██   chunk body  ██├── WallR
   -284   │██                ██│   +284
          │██                ██│
          │      ┌─────────┐      │
          │      └─────────┘      │
          │                       │
  y=height┼─────[ConnectBottom]───┼──   ← bottom of the chunk
          │                       │
```

| Concept                | Value                  |
|------------------------|------------------------|
| Arena width            | 640 px                 |
| Center of the arena    | **x = 0**              |
| Left edge of the arena | x = -320               |
| Right edge             | x = +320               |
| Recommended left wall  | **x = -284** (centered on its body) |
| Recommended right wall | **x = +284**           |
| Top of every chunk     | y = 0 (where `ConnectTop` sits) |
| Bottom of every chunk  | y = chunk's authored height (where `ConnectBottom` sits) |

These values are also exposed as named constants in
`scripts/chunks/arena.gd` (`Arena.CENTER_X`, `Arena.LEFT_WALL_X`,
`Arena.RIGHT_WALL_X`, …) — you can reference them if you ever write a
custom chunk script.

## Anatomy of a chunk

Every chunk scene must contain:

| Node                              | Where it goes        | Purpose |
|-----------------------------------|----------------------|---------|
| Root `Node2D`                     | (0, 0)               | The chunk container |
| Child `Marker2D` `ConnectTop`     | **(0, 0)**           | The point that snaps to the chunk above |
| Child `Marker2D` `ConnectBottom`  | **(0, height)**      | The point the next chunk's `ConnectTop` snaps to |

The **start chunk** must additionally contain a `Marker2D` called
`BallSpawn` — the generator drops the ball there.

The **finale chunk** must contain an instance of
`scenes/game/level_exit.tscn` so the run can end.

The **template** at `scenes/chunks/chunk_TEMPLATE.tscn` has all the
required pieces pre-placed. Duplicate it to start a new chunk.

## Chunk geometry — best practices

- **Center everything around x = 0.** A platform that should sit in the
  middle goes at `(0, y)`. A pair of symmetric platforms goes at
  `(-100, y)` and `(+100, y)`.
- **Use the edge walls at x = ±284** for the outer arena walls — that's
  the canonical position the generator will snap to anyway, but starting
  there keeps the editor preview matching the live game.
- For *tighter* chunks (gauntlets, narrow corridors) place inward walls
  at e.g. `x = ±180`. The generator's snap heuristic ignores anything
  inside `x ∈ [-230, +230]` (see `Arena.EDGE_WALL_LEFT_THRESHOLD` /
  `Arena.EDGE_WALL_RIGHT_THRESHOLD`).
- Use **`StaticBody2D` + `CollisionShape2D` + `RectangleShape2D`** for
  walls and platforms. The `WorldPainter` autoload adds a matching
  themed `Polygon2D` automatically — you never need to author visuals.
- `ConnectTop` is at `y = 0`, `ConnectBottom` is at the chunk's
  authored height. The distance between them is the chunk's height.
- Test the chunk in isolation by opening the `.tscn` and dropping a
  ball above it.

## Adding hazards and flippers

Don't build new ones from scratch — instance the prefabs:

- Drag `scenes/hazards/hazard_spike.tscn` into the chunk for an
  instant-kill spike.
- Drag `scenes/flippers/flipper_flat.tscn` or
  `scenes/flippers/flipper_standard.tscn` for a flipper.
- For a moving hazard, parent a `Node2D` with the script
  `scripts/hazards/moving_hazard.gd` over the hazard you want to wiggle,
  and point its `moving_node_path` at the hazard.

See `docs/hazards_guide.md` and `docs/flippers_guide.md` for tuning.

## The chunk definition (`chunk_def_xxx.tres`)

Open one in the Inspector and you'll see four groups:

### Chunk
- **scene** — the `.tscn` to instantiate. Must be a `Node2D` with the
  Connect markers above.

### Difficulty
- **difficulty** — cost subtracted from the level's difficulty budget
  when this chunk is picked.

  | Value | Bucket | Examples                                  |
  |-------|--------|-------------------------------------------|
  | 1-2   | Easy   | start chunk, calm corridor, single flipper |
  | 3     | Medium | one flipper + one hazard, simple gauntlet  |
  | 4-5   | Hard   | fast moving hazards, tight precision gates |
  | 6     | Brutal | only used on very late levels              |

- **category** — usually leave as `&""` to auto-derive from difficulty.
  Set explicitly to `&"easy"`, `&"medium"` or `&"hard"` only if you want
  to override the auto-bucketing.

### Selection weight
- **weight** — relative pick chance. 1.0 = baseline; 2.0 = twice as
  likely; 0.5 = half as likely.

### Biome (optional)
- **biome** — leave empty for a universal chunk that fits any biome.
  Set e.g. `&"factory"` to restrict it to one biome.

### Advanced (optional)
- **tags** — free-form labels for searching/filtering. Not used by the
  generator today.
- **connection_tags**, **hazard_pool** — reserved for future use.

## The level config (`resources/levels/default_level_config.tres`)

This single resource is the level recipe. Open it in the Inspector:

### Length
- **min_chunks** / **max_chunks** — how many middle chunks each level
  uses (start and finale chunks are added on top of this).

### Difficulty
- **target_difficulty_budget** — how much "difficulty" the generator is
  allowed to spend per level. Higher = harder. The budget also scales
  up per level number, so this is the **level-1 baseline**.
- **max_pick_attempts_per_slot** — designers rarely change this.

### Chunk pool
- **chunk_pool** — drag `chunk_def_*.tres` resources here to enable
  them. Remove an entry to disable a chunk without deleting it.
- **start_chunk** / **finale_chunk** — the fixed bookends. Leave them
  pointing at `chunk_def_start.tres` and `chunk_def_finale.tres` unless
  you've authored alternatives.

## Difficulty progression (built-in, behind the scenes)

You only author the **base** difficulty for level 1. The generator
ramps everything up automatically as the player progresses:

| Level | Length             | Budget            | Max chunk difficulty |
|-------|--------------------|-------------------|----------------------|
| 1     | base               | base              | 2 (easy only)        |
| 2     | base               | base + 4          | 3 (easy + medium)    |
| 3     | base + 1           | base + 8          | 4 (light hard)       |
| 4-6   | base + 1-3         | base + 12-20      | 6 (everything)       |
| 7+    | base + 3-6         | base + 24-48      | 6                    |

Moving hazards also speed up by up to ~70% on the latest levels.

## Half-pipes and quarter-pipes

Curved ramps live in `scripts/chunks/curved_ramp.gd` (a `StaticBody2D`
subclass called `CurvedRamp`). They're built procedurally from a fan of
short rotated rectangles — Godot 2D has no native curved collider — and
they integrate cleanly with everything else.

You instance them as plain `Node` references in a chunk; the Inspector
exposes the arc shape:

- **arc_radius** — radius in pixels.
- **start_angle_deg** / **end_angle_deg** — the arc's start/end. The
  ramp's docstring documents which angles open which way (e.g. a
  quarter-pipe opening up-right uses `0° → 90°`).
- **thickness** — wall thickness in pixels.
- **surface_color** / **edge_color** — visuals.

See `scenes/chunks/chunk_half_pipe.tscn` and
`scenes/chunks/chunk_quarter_pipe.tscn` for reference setups.

## Testing your chunk

The fastest loop:

1. Open `resources/levels/default_level_config.tres`.
2. Set `min_chunks` and `max_chunks` to **1** temporarily.
3. Put **only your chunk** in `chunk_pool`.
4. Press F5 and start a new run — every level will now be exactly
   `start + your_chunk + finale`.
5. Restore the original values before committing.

See `docs/testing.md` for the wider verification checklist.
