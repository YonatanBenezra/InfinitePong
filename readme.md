# Pin Down

A physics-based vertical pinball survival game built with Godot.

Guide a falling ball through dangerous procedurally generated levels using strategically placed flippers. Master momentum, avoid deadly hazards, and reach the exit at the bottom of each level.

## Gameplay

The player controls a physics-driven ball indirectly through flippers.

Your objective is simple:

1. Spawn at the top of the level
2. Use flippers to redirect momentum
3. Avoid hazards and obstacles
4. Reach the exit
5. Survive increasingly challenging layouts

Fast restarts and skill-based movement encourage players to improve with every run.

## Features

- Physics-based ball movement
- Responsive flipper controls
- Momentum-driven gameplay
- Procedural chunk generation
- Difficulty scaling system
- Static and moving hazards
- Instant death and fast retry loop
- Vertical follow camera
- Sound effects and gameplay feedback
- Replayable level layouts

## Controls

| Action            | Key                       |
| ----------------- | ------------------------- |
| Activate Flippers | Space / Left Mouse Button |
| Restart Level     | R                         |
| Pause             | Esc                       |

## Design Pillars

- Physics-driven skill gameplay
- Precision timing
- Momentum control
- Fast retries
- High replayability
- Clear and readable gameplay

## Built With

- Godot Engine 4.x
- GDScript

## Current Status

Prototype / MVP

Implemented:

- Ball physics
- Flipper system
- Hazard system
- Camera system
- Level generation
- Audio feedback
- Death and restart flow
- Exit and completion system

Planned Improvements:

- Additional hazard types
- More procedural chunk variety
- Improved difficulty progression
- Advanced flipper mechanics
- Enhanced visual effects
- Expanded level content

## Running the Project

1. Install Godot 4.x
2. Clone the repository

```bash
git clone <repository-url>
```

3. Open the project in Godot
4. Load `project.godot`
5. Press **F5** to run

## Project Structure

```text
scenes/
├── main.tscn
├── chunks/
├── hazards/
├── flippers/

scripts/
├── ball.gd
├── game_controller.gd
├── chunk_generator.gd
├── hazard_spike.gd
├── moving_hazard.gd
├── flipper_standard.gd
├── flipper_flat.gd
```

## License

This project is provided for educational and development purposes.

---

Pin Down is an experimental arcade game focused on satisfying physics interactions, procedural replayability, and momentum-based skill gameplay.
