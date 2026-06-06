extends Node
## Autoload: the run upgrade pool and weighted-random draft.
##
## After clearing a level the game offers three upgrades; the player keeps
## one and it persists for the rest of the run (until death). The pool is
## rarity-weighted — a higher `weight` means the upgrade shows up more often,
## so powerful picks (Shot Damage) stay rare while utility picks (Heal) are
## common. roll() draws N DISTINCT upgrades using weighted selection without
## replacement, so an offer never contains the same upgrade twice.
##
## game_controller.gd owns how each `id` is actually applied; this system
## only defines the catalogue and the draft logic.

## The full draftable pool — one entry per design-spec upgrade. EVERY entry is
## eligible on every draw; roll() weights across all of them (then the remaining
## ones for picks 2 and 3), so the rarity curve below is what actually governs
## how often each shows up. Keep this list in sync with the spec — a missing
## entry silently drops that upgrade from the game.
##   id        — applied by game_controller._apply_upgrade()
##   name/desc — shown on the selection card
##   weight    — relative draw chance (rarity); higher = more common
var definitions: Array[Dictionary] = [
	{"id": "heal",        "name": "Heal +2",          "desc": "Restore 2 health",         "weight": 1.0},
	{"id": "max_ammo",    "name": "Max Ammo +1",      "desc": "+1 magazine capacity",     "weight": 0.8},
	{"id": "speed",       "name": "Speed x1.1",       "desc": "Ball moves 10% faster",    "weight": 0.5},
	{"id": "reload",      "name": "Reload Speed x1.1","desc": "Reload 10% faster",         "weight": 0.66},
	{"id": "shot_size",   "name": "Shot Size x1.1",   "desc": "Bullets are 10% larger",   "weight": 0.75},
	{"id": "recoil",      "name": "Shot Recoil x1.1", "desc": "Recoil kick 10% stronger", "weight": 0.66},
	{"id": "shot_damage", "name": "Shot Damage +1",   "desc": "+1 bullet damage",         "weight": 0.1},
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Returns `count` DISTINCT upgrades drawn by weight (rarer = less likely).
## Selection is without replacement, so the same upgrade never appears twice
## in one offer. If `count` exceeds the pool size, the whole pool is returned.
func roll(count: int = 3) -> Array:
	var pool := definitions.duplicate(true)
	var out: Array = []
	for _i in count:
		if pool.is_empty():
			break
		var pick := _weighted_pick(pool)
		out.append(pool[pick])
		pool.remove_at(pick)
	return out


## Index of one weighted random entry in `pool`. Each entry's draw chance is
## its weight over the sum of all remaining weights.
func _weighted_pick(pool: Array) -> int:
	var total := 0.0
	for u in pool:
		total += maxf(float(u.get("weight", 0.0)), 0.0)
	if total <= 0.0:
		return _rng.randi_range(0, pool.size() - 1)
	var r := _rng.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += maxf(float(pool[i].get("weight", 0.0)), 0.0)
		if r <= acc:
			return i
	return pool.size() - 1
