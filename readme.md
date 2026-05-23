# Pin Down

Pin Down is a physics-based vertical pinball game built in Godot. The player
guides a falling ball from the top of a procedurally assembled level to the
exit at the bottom by timing flippers, managing momentum, and avoiding
instant-death hazards.

The design focus is fast, readable, skill-based movement wrapped in a full
production loop: menus, worlds, progression, achievements, daily challenges
and presentation polish — all built on top of the original physics core.

## Core Mechanics

- **Physics ball:** a `RigidBody2D` falls under gravity, bounces off geometry
  and carries momentum through the whole run.
- **Flippers:** pinball-style standard arms and rigid flat plates; some start
  raised and move down while held, for varied timing.
- **Hazards:** spikes kill instantly; hazards can be static or ping-pong.
- **Procedural chunks:** levels are assembled vertically from authored chunks
  using a difficulty budget and weighted selection.
- **Worlds:** five themed worlds (8 levels each) re-skin the level, ball,
  background and music as difficulty climbs.

## Game Flow

`Splash → Main Menu → (Play / Continue / Level Select) → Gameplay →
Results → next level`, with Stats, Achievements, Settings and Credits
reachable from the menu.

## Controls

- **Space / Left mouse:** hold to activate flippers.
- **R:** retry the current level.
- **Esc:** pause (in-game pause menu).

## Architecture

### Autoload systems (`scripts/systems/`)

| Singleton | Role |
|-----------|------|
| `GameEvents` | global signal bus (gameplay + progression) |
| `SaveSystem` | debounced JSON persistence (`user://pindown_save.json`) |
| `GameSettings` | audio/visual options; creates the Music & Sfx buses |
| `Worlds` | five world/theme definitions + level→world mapping |
| `Profile` | lifetime stats, XP, player level, unlocks, streaks |
| `Achievements` | metric-driven achievement evaluation |
| `Challenges` | deterministic daily challenges |
| `MusicManager` | synthesised, crossfading, intensity-scaled music |
| `SceneRouter` | fade-wiped screen transitions + payload passing |
| `UITheme` | shared visual language + procedural widget factory |
| `Notifier` | global toast popups for unlocks |

### Gameplay (`scripts/`)

- `game_controller.gd` — run lifecycle, theming, results, pause, feedback.
- `ball.gd`, `flipper_*.gd`, `hazard_spike.gd`, `moving_hazard.gd` — physics.
- `chunk_generator.gd`, `chunk_definition.gd` — procedural level building.
- `world_painter.gd` — runtime, world-themed chunk visuals.
- `vertical_camera.gd` — vertical follow camera with shake.
- `audio_synth.gd` / `music_synth.gd` — procedural SFX and music.
- `vfx.gd` — one-shot particle bursts.

### Screens (`scripts/ui/`, `scenes/ui/`)

Splash, Main Menu (with a live animated background), Level Select, Settings,
Stats, Achievements and Credits — all built procedurally through `UITheme`.

## Progression

- **XP** is earned from clearing levels, perfect runs, discovering chunks and
  completing challenges; player levels grant titles and cosmetics.
- **Worlds** unlock as the player reaches their first level.
- **Achievements** track lifetime milestones.
- **Daily challenges** refresh every calendar day and award XP.

## Setup

Targets Godot 4.6 (or a compatible 4.x). Open `project.godot` and run — the
main scene is `scenes/ui/splash.tscn`. All progression persists to
`user://pindown_save.json`.

## Possible Next Steps

- Per-world unique hazards and chunk pools.
- Equipped-cosmetic visual variations (ball skins, trail effects).
- A short interactive first-run tutorial.
- Bonus rooms, secret routes and rare chunks for deeper replayability.
