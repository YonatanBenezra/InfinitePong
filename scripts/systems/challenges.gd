extends Node
## Autoload: daily challenges — three fresh objectives every calendar day.
##
## The day's set is deterministic from the date string, so it regenerates
## once at midnight and is stable across sessions. Each run feeds progress;
## a finished challenge auto-awards XP and fires challenge_completed for the
## results-screen / popup. Unclaimed completions persist until shown.

const SECTION := "challenges"

var _templates: Array[Dictionary] = [
	{"type": "complete_levels", "desc": "Complete %d levels", "goals": [2, 3, 4], "xp": 120, "metric": "win"},
	{"type": "perfect_run", "desc": "Complete a level without dying", "goals": [1], "xp": 150, "metric": "perfect"},
	{"type": "reach_level", "desc": "Reach level %d", "goals": [4, 5, 7], "xp": 130, "metric": "reach"},
	{"type": "survive_time", "desc": "Spend %d seconds in runs", "goals": [180, 300], "xp": 110, "metric": "time"},
	{"type": "flippers", "desc": "Trigger %d flippers", "goals": [60, 100, 150], "xp": 110, "metric": "flippers"},
	{"type": "distance", "desc": "Travel %d pixels", "goals": [4000, 7000], "xp": 110, "metric": "distance"},
	{"type": "any_runs", "desc": "Start %d runs", "goals": [5, 8], "xp": 90, "metric": "runs"},
]

var today: String = ""
var challenges: Array = []          ## live list of challenge dicts


func _ready() -> void:
	_load()
	_refresh_if_new_day()
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.run_ended.connect(_on_run_ended)


func _load() -> void:
	var d := SaveSystem.get_section(SECTION)
	today = d.get("date", "")
	challenges = d.get("list", [])


func _save() -> void:
	SaveSystem.set_section(SECTION, {"date": today, "list": challenges})


## Re-reads challenge state from disk and regenerates (used after a wipe).
func reload() -> void:
	_load()
	_refresh_if_new_day()


func _date_string() -> String:
	var t := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]


func _refresh_if_new_day() -> void:
	var date := _date_string()
	if date == today and not challenges.is_empty():
		return
	today = date
	challenges = _generate(date)
	_save()


## Builds three distinct challenges deterministically from the date.
func _generate(date: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var pool := _templates.duplicate()
	var out: Array = []
	for i in 3:
		if pool.is_empty():
			break
		var pick: int = rng.randi_range(0, pool.size() - 1)
		var tpl: Dictionary = pool[pick]
		pool.remove_at(pick)
		var goal: int = tpl["goals"][rng.randi_range(0, tpl["goals"].size() - 1)]
		out.append({
			"id": "%s_%s" % [date, tpl["type"]],
			"type": tpl["type"],
			"metric": tpl["metric"],
			"desc": (tpl["desc"] % goal) if "%d" in tpl["desc"] else tpl["desc"],
			"goal": goal,
			"progress": 0,
			"xp": tpl["xp"],
			"completed": false,
			"claimed": false,
		})
	return out


func all() -> Array:
	_refresh_if_new_day()
	return challenges


func completed_count() -> int:
	var n := 0
	for c in challenges:
		if c.get("completed", false):
			n += 1
	return n


func _advance(c: Dictionary, amount: int) -> void:
	if c.get("completed", false) or amount <= 0:
		return
	c["progress"] = mini(int(c["progress"]) + amount, int(c["goal"]))
	GameEvents.challenge_progress.emit(c)
	if int(c["progress"]) >= int(c["goal"]):
		c["completed"] = true
		c["claimed"] = true
		Profile.add_xp(int(c["xp"]), "challenge")
		GameEvents.challenge_completed.emit(c)


func _on_run_started(_level: int) -> void:
	_refresh_if_new_day()
	for c in challenges:
		if c["metric"] == "runs":
			_advance(c, 1)
	_save()


func _on_run_ended(result: Dictionary) -> void:
	_refresh_if_new_day()
	var win := String(result.get("outcome", "")) == "win"
	for c in challenges:
		match c["metric"]:
			"win":
				if win:
					_advance(c, 1)
			"perfect":
				if win and bool(result.get("no_death", false)):
					_advance(c, 1)
			"reach":
				var lvl := int(result.get("level", 0))
				if lvl > int(c["progress"]):
					_advance(c, lvl - int(c["progress"]))
			"time":
				_advance(c, int(result.get("time", 0.0)))
			"flippers":
				_advance(c, int(result.get("flippers", 0)))
			"distance":
				_advance(c, int(result.get("distance", 0.0)))
	_save()
