extends Node
## Autoload bus for game-wide signals.
##
## Gameplay signals fire from the physics/level systems; meta signals fire
## from the progression systems (Profile, Achievements, Challenges). Keeping
## one bus lets UI, audio, and analytics subscribe without hard references.

# --- Gameplay (emitted by ball / hazards / flippers / game controller) ---
signal player_died
signal level_completed
signal ball_hit(speed: float)
signal ball_ricochet(speed: float)
signal flipper_fired
signal ball_hit_flipper
signal hazard_hit

# --- Run lifecycle (emitted by game_controller) ---
signal run_started(level_index: int)
## result keys: outcome ("win"|"death"), level, depth_pct, score, time,
## flippers, distance, deaths_this_level, world, no_death.
signal run_ended(result: Dictionary)
signal chunk_discovered(chunk_id: String)
signal world_changed(world_index: int)

# --- Progression (emitted by Profile / Achievements / Challenges) ---
signal xp_gained(amount: int, reason: String)
signal player_leveled_up(new_level: int, rewards: Array)
signal achievement_unlocked(achievement: Dictionary)
signal challenge_progress(challenge: Dictionary)
signal challenge_completed(challenge: Dictionary)
signal world_unlocked(world_index: int)
signal reward_unlocked(reward: Dictionary)

# --- Settings ---
signal settings_changed
