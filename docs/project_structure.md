# Project structure

Quick map of what lives where. If something doesn't match this file,
treat the file system as the source of truth and update this doc.

## Top-level

```
project.godot               Godot project descriptor
readme.md                   Game overview + setup
docs/                       Designer- and dev-facing docs (you are here)
scenes/                     Every .tscn the game loads at runtime
scripts/                    Every .gd script
resources/                  Tuning data (.tres) — chunk metadata + level recipes
icon.svg                    Window / launcher icon
```

## scenes/

| Folder       | Contents                                                          |
|--------------|-------------------------------------------------------------------|
| `game/`      | `game.tscn` (the gameplay scene) and `level_exit.tscn`            |
| `ball/`      | `ball.tscn` — the physics ball, instanced once per run            |
| `flippers/`  | Reusable flipper scenes: `flipper_flat.tscn`, `flipper_standard.tscn` |
| `hazards/`   | Reusable hazard scenes: `hazard_spike.tscn`                       |
| `chunks/`    | One `.tscn` per procedural chunk (start, finale, corridors, …)    |
| `ui/`        | Splash, main menu, level select, settings, stats, achievements …  |

## scripts/

Grouped by gameplay concern, so each folder maps cleanly to one feature.

| Folder       | What lives here                                                   |
|--------------|-------------------------------------------------------------------|
| `ball/`      | `ball.gd`, `ball_skin_renderer.gd`                                |
| `flippers/`  | `flipper_flat.gd`, `flipper_standard.gd`                          |
| `hazards/`   | `hazard_spike.gd`, `hazard_breakable.gd`, `hazard_glue.gd`, `moving_hazard.gd` |
| `gameplay/`  | Reusable gameplay primitives — `path_mover.gd` (waypoint mover used by hazards, platforms, …) |
| `chunks/`    | `arena.gd`, `chunk_definition.gd`, `chunk_generator.gd`, `chunk_randomizer.gd`, `curved_ramp.gd`, `level_config.gd` |
| `camera/`    | `vertical_camera.gd` (Y-only follow with shake)                   |
| `vfx/`       | `vfx.gd` (one-shot particle bursts), `world_painter.gd`           |
| `audio/`     | `audio_synth.gd` (procedural SFX)                                 |
| `game/`      | `game_controller.gd` (run lifecycle), `game_events.gd` (signal bus), `level_exit.gd` |
| `ui/`        | One file per screen / overlay (`main_menu.gd`, `level_select.gd`, …) |
| `systems/`   | Autoload singletons (`Profile`, `SaveSystem`, `MusicManager`, …)  |

## resources/

| Folder      | Contents                                                           |
|-------------|--------------------------------------------------------------------|
| `chunks/`   | `chunk_def_*.tres` — one per chunk scene. Holds difficulty, weight, biome, category. |
| `levels/`   | `default_level_config.tres` — the recipe ChunkGenerator uses by default. |

## Naming conventions

- Scene files use snake_case (`flipper_flat.tscn`).
- Script files use snake_case (`flipper_flat.gd`).
- Class names use PascalCase (`ChunkGenerator`, `LevelConfig`).
- Chunk scenes are prefixed `chunk_` and chunk definitions `chunk_def_`.
- Inspector-facing exports are grouped with `@export_group("...")` so
  related knobs cluster together in the editor.

## Chunk coordinate convention

Every chunk is authored on the **(0, 0)-centered** frame:

- `x = 0` is the **center** of the arena.
- The arena is 640 px wide, so the edges are at `x = ±320`.
- Recommended edge walls sit at `x = ±284`.
- `y = 0` is the **top** of the chunk (where `ConnectTop` sits).
- `y` grows downward; `ConnectBottom` lives at `(0, chunk_height)`.

The single source of truth for arena dimensions is
`scripts/chunks/arena.gd`. See **`docs/chunks_guide.md`** for a diagram
and the full chunk-building workflow.
