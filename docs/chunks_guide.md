# Chunks guide

A **chunk** is one vertical slice of a level. The generator stacks
chunks top-to-bottom to assemble each level: a start chunk, several
middle chunks, then a finale chunk with the green exit.

This guide is written for level designers. You should not need to edit
any GDScript to author, tune, or remove chunks.

## TL;DR

1. **Open Godot** and load this project.
2. **Duplicate** an existing chunk in `scenes/chunks/` that is closest
   to what you want.
3. **Rearrange** the platforms, flippers and hazards inside it.
4. **Create** a matching `chunk_def_xxx.tres` in `resources/chunks/`
   (or duplicate an existing one and point its `scene` field at your new
   chunk).
5. **Drop** the new `chunk_def_xxx.tres` into the `chunk_pool` of
   `resources/levels/default_level_config.tres`.
6. **Press F5** to playtest.

## Anatomy of a chunk

Every chunk scene must contain:

| Node                              | Purpose                                                  |
|-----------------------------------|----------------------------------------------------------|
| Root `Node2D` named whatever      | The chunk container                                      |
| Child `Marker2D` `ConnectTop`     | The point that snaps to the chunk above. Usually at y ≈ 0 |
| Child `Marker2D` `ConnectBottom`  | The point the next chunk's `ConnectTop` will snap to     |

The **start chunk** must additionally contain a `Marker2D` called
`BallSpawn` — the generator drops the ball there.

The **finale chunk** must contain an instance of
`scenes/game/level_exit.tscn` so the run can end.

Everything else (walls, platforms, kickers, flippers, hazards) is
freeform. Use the existing chunks in `scenes/chunks/` as references.

## Chunk geometry — best practices

- The arena is **640 × 720 px** wide on screen. Edge walls should sit at
  about `x = 36` (left) and `x = 604` (right) so the chunk seams stay
  flush. The `ChunkGenerator` snaps any wall named `WallLeft` or
  `WallRight` close to those positions to a canonical width — but
  staying close in the authored chunk keeps the editor preview clean.
- Use **`StaticBody2D` + `CollisionShape2D` + `RectangleShape2D`** for
  walls and platforms. The `WorldPainter` autoload adds a matching
  themed `Polygon2D` automatically so you never need to author visuals.
- Keep `ConnectTop` near `y = 0` and `ConnectBottom` at the bottom of
  the chunk. The vertical distance between them is the chunk's height.
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

## Testing your chunk

The fastest loop:

1. Open `resources/levels/default_level_config.tres`.
2. Set `min_chunks` and `max_chunks` to **1** temporarily.
3. Put **only your chunk** in `chunk_pool`.
4. Press F5 and start a new run — every level will now be exactly
   `start + your_chunk + finale`.
5. Restore the original values before committing.

See `docs/testing.md` for the wider verification checklist.
