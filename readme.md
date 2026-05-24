# Pin Down

Pin Down is a physics-based vertical pinball game built in Godot 4.6. The
player guides a falling ball from the top of a procedurally assembled
level to the green exit at the bottom by timing flippers, managing
momentum, and avoiding instant-death hazards.

The design focus is fast, readable, skill-based movement wrapped in a
full production loop: menus, worlds, progression, achievements, daily
challenges and presentation polish — all built on top of the physics core.

## Running the game

1. Install **Godot 4.6** (any 4.6.x stable build).
2. Open `project.godot` in the Godot editor.
3. Press **F5** (or click the play-icon in the top-right) to launch.

The main scene is `scenes/ui/splash.tscn` — the splash routes into the
main menu, which lets you Play, Continue, browse Levels, change Ball
Skins, and so on. All progression persists to
`user://pindown_save.json`.

## Controls

| Input              | Action                            |
|--------------------|-----------------------------------|
| Space / Left mouse | Hold to activate flippers         |
| R                  | Retry the current level           |
| Esc                | Pause (opens in-game pause menu)  |

## Core mechanics

- **Physics ball:** a `RigidBody2D` falls under gravity, bounces off
  geometry and carries momentum through the whole run.
- **Flippers:** pinball-style standard arms and rigid flat plates; some
  start raised and move down while held, for varied timing.
- **Hazards:** spikes kill instantly; hazards can be static or ping-pong.
- **Procedural chunks:** levels are assembled vertically from authored
  chunks using a difficulty budget and weighted selection.
- **Worlds:** five themed worlds (8 levels each) re-skin the level, ball,
  background and music as difficulty climbs.

## Project layout

```
scenes/
├── game/        the gameplay scene (game.tscn) and level exit
├── ball/        ball.tscn
├── flippers/    flipper_flat.tscn, flipper_standard.tscn
├── hazards/     hazard_spike.tscn
├── chunks/      every procedural chunk scene (chunk_*.tscn)
└── ui/          splash, main menu, level select, etc.

scripts/
├── ball/        ball + ball-skin renderer
├── flippers/    flipper logic
├── hazards/     spike + moving-hazard mover
├── chunks/      chunk_definition, chunk_generator, curved_ramp,
│                level_config, chunk_randomizer
├── camera/      vertical_camera
├── vfx/         vfx + world_painter
├── audio/       audio_synth
├── game/        game_controller, game_events, level_exit
├── ui/          every screen / overlay script
└── systems/     autoload singletons (Profile, SaveSystem, MusicManager …)

resources/
├── chunks/      chunk_def_*.tres (one per chunk scene)
└── levels/      default_level_config.tres (the level recipe)

docs/
├── project_structure.md   what each folder is for
├── chunks_guide.md        how to author and tune a chunk
├── hazards_guide.md       spike + moving-hazard reference
├── flippers_guide.md      flipper reference (flat + standard)
├── progression.md         how XP, worlds and unlocks work
└── testing.md             how to verify a change locally
```

## Autoload systems (`scripts/systems/`)

| Singleton       | Role                                                     |
|-----------------|----------------------------------------------------------|
| `GameEvents`    | global signal bus (gameplay + progression)               |
| `SaveSystem`    | debounced JSON persistence (`user://pindown_save.json`)  |
| `GameSettings`  | audio/visual options; creates the Music & Sfx buses      |
| `Worlds`        | five world/theme definitions + level→world mapping       |
| `Profile`       | lifetime stats, XP, player level, unlocks, streaks       |
| `BallSkins`     | ball-skin catalogue + equip state                        |
| `Achievements`  | metric-driven achievement evaluation                     |
| `Challenges`    | deterministic daily challenges                           |
| `MusicManager`  | synthesised, crossfading, intensity-scaled music         |
| `SceneRouter`   | fade-wiped screen transitions + payload passing          |
| `UITheme`       | shared visual language + procedural widget factory       |
| `Notifier`      | global toast popups for unlocks                          |

## Level design — start here

If you want to add a new chunk, balance an existing one, or change the
pool of chunks the generator may pick from, **you do not need to edit
any code**. Open these in the Godot Inspector:

- `resources/levels/default_level_config.tres` — the level recipe
  (chunk pool, start/finale chunks, length and difficulty knobs).
- `resources/chunks/chunk_def_*.tres` — one per chunk; controls how often
  that chunk is picked (`weight`), how hard it is (`difficulty`), and
  which biome / category it belongs to.
- `scenes/chunks/chunk_*.tscn` — the actual chunk geometry.

See **`docs/chunks_guide.md`** for the full walkthrough.

## Progression

- **XP** is earned from clearing levels, perfect runs, discovering chunks
  and completing challenges; player levels grant titles and cosmetics.
- **Worlds** unlock as the player reaches their first level.
- **Achievements** track lifetime milestones.
- **Daily challenges** refresh every calendar day and award XP.

See **`docs/progression.md`** for details.
