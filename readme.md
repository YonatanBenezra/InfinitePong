# Pin Down

Pin Down is a physics-based vertical pinball game built in Godot. The player guides a falling ball from the top of a procedurally assembled level to the exit at the bottom by timing flippers, managing momentum, and avoiding instant-death hazards.

The design focus is fast, readable, skill-based movement: the ball is always physics-driven, the player controls the environment instead of the ball directly, and each run creates a fresh layout from modular chunks.

## Core Mechanics

- **Physics ball:** A `RigidBody2D` ball falls under gravity, bounces off level geometry, and carries momentum through the entire run.
- **Standard flippers:** Pinball-style arms rotate around a pivot when the flipper input is held.
- **Flat flippers:** Rigid platforms translate as a single plate, useful for blocking, pushing, or redirecting the ball.
- **Inverted flipper behavior:** Some flippers start raised and move downward while held, creating different timing patterns with the same input.
- **Hazards:** Spike hazards kill instantly on contact. Hazards can be static or move in a ping-pong path.
- **Procedural chunks:** Levels are assembled vertically from authored chunks with difficulty values and weighted selection.
- **Exit and restart loop:** Reaching the bottom exit generates a new level. Dying restarts quickly.

## Controls

- **Space** or **left mouse button:** Hold to activate flippers.
- **R:** Restart the current run.
- **Esc:** Pause or unpause.

## Gameplay Loop

1. Spawn at the top of the level.
2. Fall through a generated sequence of chunks.
3. Use flippers to redirect momentum and recover from bad angles.
4. Avoid spikes and moving hazards.
5. Reach the exit at the bottom.
6. Start a new generated level with a slightly tougher difficulty ramp.

Failure is immediate: touching a hazard kills the ball and triggers a fast restart.

## Systems Overview

- `scripts/game_controller.gd` owns the active run, ball spawning, restart flow, level completion, UI feedback, camera shake, and audio routing.
- `scripts/ball.gd` implements the physics ball, velocity clamps, anti-stuck nudging, impact events, and trail rendering.
- `scripts/flipper_standard.gd` and `scripts/flipper_flat.gd` implement the two MVP flipper types.
- `scripts/hazard_spike.gd` and `scripts/moving_hazard.gd` implement instant-death hazards and configurable ping-pong movement.
- `scripts/chunk_generator.gd` builds levels from chunk definitions, respects a difficulty budget, applies weighted random selection, and returns debug metadata for balancing.
- `scripts/chunk_definition.gd` and `resources/chunk_def_*.tres` hold chunk scene references, difficulty values, weights, and future-facing data fields.
- `scripts/vertical_camera.gd` follows the ball vertically while keeping horizontal framing fixed.
- `scripts/audio_synth.gd` generates placeholder sound effects for flippers, impacts, hazards, death, ricochets, and level completion.

## MVP Scope

The current MVP target includes:

- Physics-driven ball movement.
- Standard and flat flippers.
- Static spike hazards.
- Moving spike hazards with speed, range, direction, and delay settings.
- Modular chunk-based level generation.
- Difficulty-budgeted chunk selection.
- Level completion through a bottom exit.
- Death and restart flow.
- Vertical follow camera.
- Basic readable visuals, UI feedback, and placeholder audio.

Not included in the MVP:

- Combat or enemies.
- Roguelike upgrades.
- Multiple biomes.
- Meta progression.
- Narrative content.
- Final art, music, or production audio assets.

## Future Ideas

- Enemy hazards such as turrets, moving enemies, and projectile patterns.
- Between-level upgrades such as stronger flippers, extra lives, slow motion, magnet effects, or air control.
- Biomes with unique visuals, physics modifiers, music, hazards, and chunk pools.
- More chunk variants, optional routes, and risk-reward layouts.
- Stronger balancing tools for generated level difficulty and solvability.

## Setup and Technical Notes

This project targets Godot 4.6 or a compatible Godot 4.x version.

To run the project:

1. Install Godot 4.x.
2. Open `project.godot` in Godot.
3. Run the main scene at `scenes/main.tscn`.

The active runtime path is `scenes/main.tscn`, which uses `scripts/game_controller.gd` and `scripts/chunk_generator.gd`. Some older prototype scripts and scene folders may still exist in the repository; treat the active main scene and the top-level `chunks/`, `resources/chunk_def_*.tres`, and `scripts/` systems as the current MVP path.

Before calling the MVP complete, do a manual playtest in Godot to verify scene loading, hazard contact, flipper feel, generated-level fairness, restart flow, and exit completion.
