extends Node
## Autoload: world / theme definitions and level->world mapping.
##
## Five worlds, each spanning LEVELS_PER_WORLD levels. A world bundles a
## colour palette (consumed by WorldPainter, the background, the ball trail
## and the UI accent), a difficulty bias and a music-intensity floor.
## Worlds unlock as the player reaches their first level.

const LEVELS_PER_WORLD := 8

var worlds: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Azure Reach",
		"subtitle": "Where it begins.",
		"bg_top": Color(0.09, 0.11, 0.16),
		"bg_bottom": Color(0.05, 0.06, 0.09),
		"wall": Color(0.42, 0.52, 0.68),
		"wall_trim": Color(0.58, 0.70, 0.88),
		"platform": Color(0.52, 0.66, 0.84),
		"accent": Color(0.50, 0.68, 0.92),
		"ball": Color(0.92, 0.96, 1.0),
		"trail": Color(0.55, 0.72, 0.95, 0.5),
		"hazard": Color(0.95, 0.40, 0.44),
		"music_intensity": 0.0,
		"ambient": "spark",
	},
	{
		"id": 2,
		"name": "Ember Works",
		"subtitle": "The heat rises.",
		"bg_top": Color(0.15, 0.11, 0.08),
		"bg_bottom": Color(0.08, 0.06, 0.05),
		"wall": Color(0.64, 0.50, 0.38),
		"wall_trim": Color(0.84, 0.66, 0.46),
		"platform": Color(0.80, 0.62, 0.42),
		"accent": Color(0.88, 0.64, 0.40),
		"ball": Color(1.0, 0.96, 0.86),
		"trail": Color(0.88, 0.66, 0.42, 0.5),
		"hazard": Color(0.95, 0.38, 0.32),
		"music_intensity": 0.25,
		"ambient": "ember",
	},
	{
		"id": 3,
		"name": "Deep Space",
		"subtitle": "Silence and gravity.",
		"bg_top": Color(0.10, 0.09, 0.15),
		"bg_bottom": Color(0.05, 0.04, 0.08),
		"wall": Color(0.50, 0.46, 0.64),
		"wall_trim": Color(0.68, 0.62, 0.84),
		"platform": Color(0.62, 0.56, 0.80),
		"accent": Color(0.66, 0.58, 0.88),
		"ball": Color(0.96, 0.95, 1.0),
		"trail": Color(0.68, 0.60, 0.90, 0.5),
		"hazard": Color(0.95, 0.42, 0.56),
		"music_intensity": 0.45,
		"ambient": "star",
	},
	{
		"id": 4,
		"name": "Crystal Caverns",
		"subtitle": "Beautiful. Sharp.",
		"bg_top": Color(0.07, 0.13, 0.13),
		"bg_bottom": Color(0.04, 0.07, 0.07),
		"wall": Color(0.38, 0.58, 0.56),
		"wall_trim": Color(0.56, 0.78, 0.74),
		"platform": Color(0.48, 0.72, 0.68),
		"accent": Color(0.46, 0.76, 0.72),
		"ball": Color(0.94, 1.0, 0.99),
		"trail": Color(0.50, 0.80, 0.76, 0.5),
		"hazard": Color(0.95, 0.44, 0.40),
		"music_intensity": 0.65,
		"ambient": "crystal",
	},
	{
		"id": 5,
		"name": "Crimson Depths",
		"subtitle": "No mercy left.",
		"bg_top": Color(0.13, 0.08, 0.09),
		"bg_bottom": Color(0.06, 0.04, 0.05),
		"wall": Color(0.60, 0.44, 0.48),
		"wall_trim": Color(0.80, 0.58, 0.60),
		"platform": Color(0.74, 0.52, 0.54),
		"accent": Color(0.86, 0.52, 0.54),
		"ball": Color(1.0, 0.95, 0.95),
		"trail": Color(0.86, 0.54, 0.56, 0.5),
		"hazard": Color(1.0, 0.34, 0.34),
		"music_intensity": 0.9,
		"ambient": "glitch",
	},
]


func world_count() -> int:
	return worlds.size()


## 1-based world index that contains the given 1-based level number.
func world_index_for_level(level: int) -> int:
	var idx := (maxi(level, 1) - 1) / LEVELS_PER_WORLD + 1
	return clampi(idx, 1, worlds.size())


func world_for_level(level: int) -> Dictionary:
	return worlds[world_index_for_level(level) - 1]


func world(index: int) -> Dictionary:
	return worlds[clampi(index, 1, worlds.size()) - 1]


## First level number of a world (1-based).
func first_level_of_world(index: int) -> int:
	return (clampi(index, 1, worlds.size()) - 1) * LEVELS_PER_WORLD + 1


func last_level_of_world(index: int) -> int:
	return first_level_of_world(index) + LEVELS_PER_WORLD - 1


## Position of a level within its world, 1..LEVELS_PER_WORLD.
func level_in_world(level: int) -> int:
	return (maxi(level, 1) - 1) % LEVELS_PER_WORLD + 1


## Music intensity 0..1 for a level: world floor blended with depth in world.
func music_intensity_for_level(level: int) -> float:
	var w := world_for_level(level)
	var floor_v: float = float(w.get("music_intensity", 0.0))
	var progress := float(level_in_world(level) - 1) / float(LEVELS_PER_WORLD - 1)
	return clampf(floor_v + progress * 0.18, 0.0, 1.0)
