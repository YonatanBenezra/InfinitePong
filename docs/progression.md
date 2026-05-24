# Progression

## Worlds

There are **five worlds**, each spanning **8 levels** (40 levels total).
Definitions live in `scripts/systems/worlds.gd`.

| World | Name             | Levels  |
|-------|------------------|---------|
| 1     | Azure Reach      | 1 – 8   |
| 2     | Ember Works      | 9 – 16  |
| 3     | Deep Space       | 17 – 24 |
| 4     | Crystal Caverns  | 25 – 32 |
| 5     | Crimson Depths   | 33 – 40 |

Each world bundles a colour palette (used by the WorldPainter, the
background, the ball trail and the UI accent), a music-intensity floor
and an ambient particle type. Worlds unlock automatically when the
player reaches their first level.

## Level number → difficulty

`ChunkGenerator` scales generation knobs with the level number, not the
attempt count, so the player feels a clear step up from one level to the
next.

| Knob               | Effect                                                 |
|--------------------|--------------------------------------------------------|
| Length             | More chunks per level on later levels                  |
| Difficulty budget  | More total difficulty allowed per level                |
| Geometry gate      | Harder chunk categories unlock with the level (1=easy only, 4+=everything) |
| Hazard speed       | Moving hazards speed up by up to ~70%                  |
| Recovery zone      | Opening chunks of every level are forced gentle        |

See `docs/chunks_guide.md` for a per-level table.

## XP and player level

XP is earned from:

- Clearing a level (base + bonus for speed, flippers and no-death runs).
- Reaching deeper than your previous best in a death run.
- Discovering a chunk for the first time.
- Completing a daily challenge.

`scripts/systems/profile.gd` owns the XP curve. Player level grants
titles and cosmetics; the equipped title is shown in the main menu.

## Ball skins

`scripts/systems/ball_skins.gd` defines ~25 skins across five rarities
(Common, Rare, Legendary, Mythic, Special). All skins are currently
owned — the unlock hook `BallSkins.is_unlocked(id)` always returns true.
The Ball Skins screen (`scripts/ui/skins_screen.gd`) is the equip UI.

## Achievements and daily challenges

- `scripts/systems/achievements.gd` evaluates lifetime milestones
  against `Profile`'s metrics. They unlock as the metrics tick over.
- `scripts/systems/challenges.gd` regenerates three daily challenges
  every calendar day. Completion is tracked on `Profile`.

Both fire `Notifier` toasts on unlock.

## Save data

Everything persists to `user://pindown_save.json`, debounced by
`scripts/systems/save_system.gd`. To reset progression while developing,
delete that file (location depends on your OS — see
[Godot's `user://` docs](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#accessing-persistent-user-data-user)).
