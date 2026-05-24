extends Node
## Autoload: achievement definitions, evaluation and unlock notifications.
##
## Each achievement is metric-driven: it names a value to read from Profile
## and a goal to hit. Progress is therefore always derivable (no drift),
## and only the unlocked set is persisted. After any progression event the
## full list is re-evaluated and newly satisfied achievements fire
## GameEvents.achievement_unlocked (one per frame, queued, so popups stack).

const SECTION := "achievements"

## metric ids resolved by _metric(): see that function for the full set.
var definitions: Array[Dictionary] = [
	{"id": "first_death", "name": "Lesson One", "desc": "Die for the first time.", "metric": "deaths", "goal": 1, "icon": "skull"},
	{"id": "first_clear", "name": "Touchdown", "desc": "Complete your first level.", "metric": "levels_completed", "goal": 1, "icon": "flag"},
	{"id": "reach_l5", "name": "Getting Deep", "desc": "Reach level 5.", "metric": "highest_level", "goal": 5, "icon": "depth"},
	{"id": "reach_l10", "name": "Plunge", "desc": "Reach level 10.", "metric": "highest_level", "goal": 10, "icon": "depth"},
	{"id": "reach_l25", "name": "Abyss Diver", "desc": "Reach level 25.", "metric": "highest_level", "goal": 25, "icon": "depth"},
	{"id": "reach_l40", "name": "Rock Bottom", "desc": "Reach level 40 — clear every world.", "metric": "highest_level", "goal": 40, "icon": "crown"},
	{"id": "perfect_run", "name": "Untouchable", "desc": "Complete a level without dying.", "metric": "perfect_runs", "goal": 1, "icon": "shield"},
	{"id": "perfect_10", "name": "Flawless Streak", "desc": "Bank 10 perfect runs.", "metric": "perfect_runs", "goal": 10, "icon": "shield"},
	{"id": "flippers_100", "name": "Quick Hands", "desc": "Trigger 100 flippers.", "metric": "total_flippers", "goal": 100, "icon": "flipper"},
	{"id": "flippers_1000", "name": "Pinball Wizard", "desc": "Trigger 1,000 flippers.", "metric": "total_flippers", "goal": 1000, "icon": "flipper"},
	{"id": "distance_10k", "name": "Long Way Down", "desc": "Travel 10,000 pixels.", "metric": "total_distance", "goal": 10000, "icon": "ruler"},
	{"id": "distance_100k", "name": "Free Fall", "desc": "Travel 100,000 pixels.", "metric": "total_distance", "goal": 100000, "icon": "ruler"},
	{"id": "streak_5", "name": "On a Roll", "desc": "Win 5 levels in a row.", "metric": "longest_streak", "goal": 5, "icon": "fire"},
	{"id": "streak_15", "name": "Unstoppable", "desc": "Win 15 levels in a row.", "metric": "longest_streak", "goal": 15, "icon": "fire"},
	{"id": "level_10", "name": "Seasoned", "desc": "Reach player level 10.", "metric": "player_level", "goal": 10, "icon": "star"},
	{"id": "level_25", "name": "Prestige", "desc": "Reach player level 25.", "metric": "player_level", "goal": 25, "icon": "star"},
	{"id": "world_3", "name": "Spacefarer", "desc": "Unlock Deep Space.", "metric": "world", "goal": 3, "icon": "world"},
	{"id": "world_5", "name": "Into the Void", "desc": "Unlock the Digital Void.", "metric": "world", "goal": 5, "icon": "world"},
	{"id": "explorer", "name": "Cartographer", "desc": "Discover 15 chunk types.", "metric": "chunks", "goal": 15, "icon": "map"},
	{"id": "runs_100", "name": "One More Run", "desc": "Start 100 runs.", "metric": "total_runs", "goal": 100, "icon": "loop"},
]

var _unlocked: Dictionary = {}      ## id -> true


func _ready() -> void:
	var d := SaveSystem.get_section(SECTION)
	_unlocked = d.get("unlocked", {})
	GameEvents.run_ended.connect(func(_r): _evaluate())
	GameEvents.player_leveled_up.connect(func(_l, _r): _evaluate())
	GameEvents.world_unlocked.connect(func(_w): _evaluate())
	GameEvents.chunk_discovered.connect(func(_c): _evaluate())


## Re-reads unlocked state from disk (used after a progress wipe).
func reload() -> void:
	_unlocked = SaveSystem.get_section(SECTION).get("unlocked", {})


func _save() -> void:
	SaveSystem.set_section(SECTION, {"unlocked": _unlocked})


## Current value behind an achievement metric id.
func _metric(metric: String) -> float:
	match metric:
		"highest_level":
			return float(Profile.highest_level_reached)
		"player_level":
			return float(Profile.player_level)
		"world":
			return float(Profile.highest_world_unlocked)
		"chunks":
			return float(Profile.discovered_chunks.size())
		_:
			return float(Profile.stats.get(metric, 0))


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func progress(def: Dictionary) -> float:
	return clampf(_metric(def["metric"]) / float(def["goal"]), 0.0, 1.0)


func unlocked_count() -> int:
	return _unlocked.size()


## Re-checks every achievement and fires a signal for each new unlock.
func _evaluate() -> void:
	var changed := false
	for def in definitions:
		if _unlocked.has(def["id"]):
			continue
		if _metric(def["metric"]) >= float(def["goal"]):
			_unlocked[def["id"]] = true
			changed = true
			GameEvents.achievement_unlocked.emit(def)
	if changed:
		_save()
