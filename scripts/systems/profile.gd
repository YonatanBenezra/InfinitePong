extends Node
## Autoload: the player's persistent identity and progression.
##
## Owns lifetime stats, XP / player level, the streak counter, world &
## level unlocks, discovered chunks, and equipped cosmetics. Reacts to
## GameEvents.run_ended as the single source of truth for "what happened",
## then emits xp_gained / player_leveled_up / world_unlocked.

const SECTION := "profile"
const TOTAL_LEVELS := 40            ## 5 worlds * 8 levels — the 100% target.

# --- Live state (mirrored to the save section) ---
var xp: int = 0                     ## Progress toward the next player level.
var player_level: int = 1
var highest_level_reached: int = 1  ## Best level number ever started.
var highest_world_unlocked: int = 1
var current_streak: int = 0         ## Consecutive level wins, no death.
var stats: Dictionary = {}
var discovered_chunks: Array = []
## Per-level results: { "<level>": { cleared, perfect, best_time } }.
var level_records: Dictionary = {}
var equipped: Dictionary = {}
var unlocks: Dictionary = {}
var last_run_xp: int = 0            ## XP awarded by the most recent run.

var _default_stats := {
	"total_runs": 0,
	"levels_completed": 0,
	"deaths": 0,
	"best_score": 0,
	"best_depth_pct": 0.0,
	"longest_streak": 0,
	"total_play_time": 0.0,
	"total_flippers": 0,
	"total_distance": 0.0,
	"perfect_runs": 0,
}
var _default_unlocks := {
	"titles": ["Newcomer"],
	"ball_skins": ["classic"],
	"trail_fx": ["classic"],
	"themes": [1],
}


func _ready() -> void:
	_load()
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.run_ended.connect(_on_run_ended)
	GameEvents.chunk_discovered.connect(_on_chunk_discovered)


func _load() -> void:
	var d := SaveSystem.get_section(SECTION)
	xp = int(d.get("xp", 0))
	player_level = maxi(int(d.get("player_level", 1)), 1)
	highest_level_reached = maxi(int(d.get("highest_level_reached", 1)), 1)
	highest_world_unlocked = maxi(int(d.get("highest_world_unlocked", 1)), 1)
	current_streak = int(d.get("current_streak", 0))
	stats = _default_stats.duplicate(true)
	for k in d.get("stats", {}):
		stats[k] = d["stats"][k]
	discovered_chunks = d.get("discovered_chunks", [])
	level_records = d.get("level_records", {})
	unlocks = _default_unlocks.duplicate(true)
	for k in d.get("unlocks", {}):
		unlocks[k] = d["unlocks"][k]
	equipped = d.get("equipped", {
		"title": "Newcomer", "ball_skin": "classic", "trail_fx": "classic",
	})


## Re-reads state from disk (used after a progress wipe).
func reload() -> void:
	_load()


func save() -> void:
	SaveSystem.set_section(SECTION, {
		"xp": xp,
		"player_level": player_level,
		"highest_level_reached": highest_level_reached,
		"highest_world_unlocked": highest_world_unlocked,
		"current_streak": current_streak,
		"stats": stats,
		"discovered_chunks": discovered_chunks,
		"level_records": level_records,
		"unlocks": unlocks,
		"equipped": equipped,
	})


# --- XP & player level ----------------------------------------------------

## XP required to advance FROM the given player level.
func xp_for_next(level: int) -> int:
	return 120 + (maxi(level, 1) - 1) * 60


func xp_progress() -> float:
	return clampf(float(xp) / float(xp_for_next(player_level)), 0.0, 1.0)


func add_xp(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	xp += amount
	GameEvents.xp_gained.emit(amount, reason)
	while xp >= xp_for_next(player_level):
		xp -= xp_for_next(player_level)
		player_level += 1
		var rewards := _grant_level_rewards(player_level)
		GameEvents.player_leveled_up.emit(player_level, rewards)
	save()


## Resolves and grants every reward tied to reaching `level`.
func _grant_level_rewards(level: int) -> Array:
	var table := {
		2:  {"type": "title", "id": "Flipper", "name": "Title: Flipper"},
		4:  {"type": "trail_fx", "id": "comet", "name": "Trail: Comet"},
		6:  {"type": "ball_skin", "id": "plasma", "name": "Ball: Plasma"},
		8:  {"type": "title", "id": "Descender", "name": "Title: Descender"},
		11: {"type": "trail_fx", "id": "rainbow", "name": "Trail: Spectrum"},
		14: {"type": "ball_skin", "id": "core", "name": "Ball: Reactor Core"},
		16: {"type": "title", "id": "Pinballer", "name": "Title: Pinballer"},
		20: {"type": "title", "id": "Veteran", "name": "Title: Veteran"},
		25: {"type": "ball_skin", "id": "void", "name": "Ball: Voidwalker"},
		30: {"type": "title", "id": "Ace", "name": "Title: Ace"},
		40: {"type": "title", "id": "Master", "name": "Title: Master"},
		50: {"type": "title", "id": "Legend", "name": "Title: Legend"},
	}
	var granted: Array = []
	if table.has(level):
		var r: Dictionary = table[level]
		if grant_unlock(r["type"], r["id"]):
			granted.append(r)
	return granted


## Adds a cosmetic/title to the player's collection. Returns true if new.
func grant_unlock(kind: String, id) -> bool:
	var bucket: String = {
		"title": "titles", "ball_skin": "ball_skins",
		"trail_fx": "trail_fx", "theme": "themes",
	}.get(kind, "")
	if bucket == "" or not unlocks.has(bucket):
		return false
	if unlocks[bucket].has(id):
		return false
	unlocks[bucket].append(id)
	GameEvents.reward_unlocked.emit({"type": kind, "id": id})
	save()
	return true


## Equips a ball skin and persists it.
func equip_ball_skin(id: String) -> void:
	equipped["ball_skin"] = id
	save()


func is_unlocked(kind: String, id) -> bool:
	var bucket: String = {
		"title": "titles", "ball_skin": "ball_skins",
		"trail_fx": "trail_fx", "theme": "themes",
	}.get(kind, "")
	return bucket != "" and unlocks.has(bucket) and unlocks[bucket].has(id)


# --- Derived helpers ------------------------------------------------------

func completion_percent() -> float:
	return clampf(float(highest_level_reached - 1) / float(TOTAL_LEVELS), 0.0, 1.0)


## Highest level the player may jump straight to from Level Select.
func highest_unlocked_level() -> int:
	return clampi(highest_level_reached, 1, TOTAL_LEVELS)


func formatted_play_time() -> String:
	var t := int(stats.get("total_play_time", 0.0))
	var h := t / 3600
	var m := (t % 3600) / 60
	var s := t % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm %02ds" % [m, s]


# --- Event handlers -------------------------------------------------------

func _on_run_started(level_index: int) -> void:
	stats["total_runs"] = int(stats.get("total_runs", 0)) + 1
	if level_index > highest_level_reached:
		highest_level_reached = level_index
		_check_world_unlock(level_index)
	save()


func _on_run_ended(result: Dictionary) -> void:
	stats["total_play_time"] = float(stats.get("total_play_time", 0.0)) + float(result.get("time", 0.0))
	stats["total_flippers"] = int(stats.get("total_flippers", 0)) + int(result.get("flippers", 0))
	stats["total_distance"] = float(stats.get("total_distance", 0.0)) + float(result.get("distance", 0.0))
	stats["best_depth_pct"] = maxf(float(stats.get("best_depth_pct", 0.0)), float(result.get("depth_pct", 0.0)))

	var level := int(result.get("level", 1))
	var outcome := String(result.get("outcome", "death"))
	var score := int(result.get("score", 0))
	stats["best_score"] = maxi(int(stats.get("best_score", 0)), score)

	var xp_award := 0
	if outcome == "win":
		stats["levels_completed"] = int(stats.get("levels_completed", 0)) + 1
		current_streak += 1
		stats["longest_streak"] = maxi(int(stats.get("longest_streak", 0)), current_streak)
		xp_award = 55 + level * 12 + int(float(result.get("depth_pct", 1.0)) * 25.0)
		if bool(result.get("no_death", false)):
			stats["perfect_runs"] = int(stats.get("perfect_runs", 0)) + 1
			xp_award += 45
		_record_level_clear(level, bool(result.get("no_death", false)), float(result.get("time", 0.0)))
	else:
		stats["deaths"] = int(stats.get("deaths", 0)) + 1
		current_streak = 0
		xp_award = 12 + int(float(result.get("depth_pct", 0.0)) * 28.0)

	last_run_xp = xp_award
	save()
	add_xp(xp_award, "run")


## Records a level clear for the Level Select medals.
func _record_level_clear(level: int, perfect: bool, time: float) -> void:
	var key := str(level)
	var rec: Dictionary = level_records.get(key, {"cleared": false, "perfect": false, "best_time": 0.0})
	rec["cleared"] = true
	rec["perfect"] = bool(rec.get("perfect", false)) or perfect
	var prev := float(rec.get("best_time", 0.0))
	rec["best_time"] = time if prev <= 0.0 else minf(prev, time)
	level_records[key] = rec


## Returns the saved record for a level (cleared / perfect / best_time).
func level_record(level: int) -> Dictionary:
	var rec: Dictionary = level_records.get(str(level),
		{"cleared": false, "perfect": false, "best_time": 0.0})
	return rec


func _on_chunk_discovered(chunk_id: String) -> void:
	if chunk_id == "" or discovered_chunks.has(chunk_id):
		return
	discovered_chunks.append(chunk_id)
	add_xp(8, "discovery")


func _check_world_unlock(level_index: int) -> void:
	var w := Worlds.world_index_for_level(level_index)
	if w > highest_world_unlocked:
		highest_world_unlocked = w
		grant_unlock("theme", w)
		GameEvents.world_unlocked.emit(w)
