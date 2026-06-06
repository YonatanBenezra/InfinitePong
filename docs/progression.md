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

## Run upgrades

Clearing a level opens a three-card draft (`scripts/ui/upgrade_select.gd`).
`scripts/systems/upgrades.gd` rolls three **distinct** upgrades by rarity
weight (heavier weight = more common); the player keeps one and it applies
immediately and persists for the rest of the run. `game_controller.gd`
owns how each upgrade id is applied and resets every run modifier on death.

| Upgrade            | Weight | Effect                          |
|--------------------|--------|---------------------------------|
| Heal +2            | 1.00   | +2 health                       |
| Max Ammo +1        | 0.80   | +1 magazine capacity            |
| Shot Size ×1.1     | 0.75   | bullets 10% larger              |
| Reload Speed ×1.1  | 0.66   | reload 10% faster               |
| Shot Recoil ×1.1   | 0.66   | recoil kick 10% stronger        |
| Speed ×1.1         | 0.50   | ball top speed 10% higher       |
| Shot Damage +1     | 0.10   | +1 bullet damage                |

Health depletes one point per lethal hit; while any remains the ball
respawns at the top of the current level. At zero health the run ends,
all run progress (health, upgrades, run score) is wiped and the player
returns to the menu via a game-over card showing the run score and the
persistent high score (`Profile.stats.best_score`).

### Continue / saved run

`game_controller.gd` checkpoints the live run to `Profile.active_run` at the
start of every level (level index + health + ammo + all upgrade modifiers +
run score). The menu's **Continue** button is shown *only* when
`Profile.has_active_run()` is true and resumes from that snapshot. The saved
run is cleared on death and whenever a new game is started (Play), so Continue
never points at a stale level — unlike the lifetime `highest_level_reached`
stat, which it deliberately no longer reads.

## Achievements and daily challenges

- `scripts/systems/achievements.gd` evaluates lifetime milestones
  against `Profile`'s metrics. They still unlock and persist silently,
  but the unlock **notification is intentionally disabled** (the
  achievements screen was removed) — the `achievement_unlocked` emit in
  `_evaluate()` is commented out, so no toast fires.
- `scripts/systems/challenges.gd` regenerates three daily challenges
  every calendar day. Completion is tracked on `Profile` and still fires
  a `Notifier` toast.

## Save data

Everything persists to `user://pindown_save.json`, debounced by
`scripts/systems/save_system.gd`. To reset progression while developing,
delete that file (location depends on your OS — see
[Godot's `user://` docs](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#accessing-persistent-user-data-user)).
