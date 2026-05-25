extends Node
## Autoload: ball skin (cosmetic) catalogue + equip state.
##
## "classic" is the only starter skin. Every other skin is gated behind an
## achievement — SKIN_ACHIEVEMENTS maps skin id → achievement id.
## is_unlocked() is the single choke point for all gating logic.

const RARITY_ORDER := ["Common", "Rare", "Legendary", "Mythic", "Special"]

## Maps skin id to the achievement id that unlocks it.
## Skins not listed here are permanently locked (no unlock path).
const SKIN_ACHIEVEMENTS := {
	"slate":            "first_death",
	"blue_glow":        "first_clear",
	"verdant_glow":     "reach_l5",
	"neon_pulse":       "reach_l10",
	"ice_core":         "reach_l25",
	"celestial_crown":  "reach_l40",
	"dragon_eye":       "perfect_run",
	"plasma_sphere":    "perfect_10",
	"solar_core":       "flippers_100",
	"lightning_orb":    "flippers_1000",
	"frost_nova":       "distance_10k",
	"magma_core":       "distance_100k",
	"dark_matter":      "streak_5",
	"void_walker":      "streak_15",
	"cosmic_rift":      "level_10",
	"galaxy_heart":     "level_25",
	"singularity":      "world_3",
	"nebula_drift":     "world_5",
	"retro_arcade":     "explorer",
	"pixel_hero":       "runs_100",
}
const RARITY_COLORS := {
	"Common": Color(0.64, 0.69, 0.77),
	"Rare": Color(0.40, 0.66, 0.96),
	"Legendary": Color(0.74, 0.50, 0.97),
	"Mythic": Color(0.97, 0.48, 0.82),
	"Special": Color(1.0, 0.80, 0.34),
}

var skins: Array[Dictionary] = [
	# --- Common ---
	{"id": "classic", "name": "Classic White", "rarity": "Common", "style": "solid",
	 "desc": "Clean, timeless, reliable.",
	 "core": Color(0.97, 0.97, 1.0), "shell": Color(0.70, 0.74, 0.85),
	 "glow": Color(1, 1, 1), "accent": Color(1, 1, 1), "trail": Color(1.0, 0.95, 0.82, 0.5)},
	{"id": "blue_glow", "name": "Blue Glow", "rarity": "Common", "style": "glow",
	 "desc": "A steady cobalt shimmer.",
	 "core": Color(0.58, 0.80, 1.0), "shell": Color(0.30, 0.50, 0.86),
	 "glow": Color(0.42, 0.72, 1.0), "accent": Color(0.78, 0.92, 1.0), "trail": Color(0.50, 0.76, 1.0, 0.5)},

	# --- Rare ---
	{"id": "neon_pulse", "name": "Neon Pulse", "rarity": "Rare", "style": "pulse",
	 "desc": "Throbs with restless neon energy.",
	 "core": Color(1.0, 0.32, 0.76), "shell": Color(0.55, 0.18, 0.48),
	 "glow": Color(1.0, 0.42, 0.86), "accent": Color(0.34, 0.95, 1.0), "trail": Color(1.0, 0.40, 0.80, 0.5)},
	{"id": "ice_core", "name": "Ice Core", "rarity": "Rare", "style": "crystal",
	 "desc": "Frozen solid at its heart.",
	 "core": Color(0.78, 0.93, 1.0), "shell": Color(0.46, 0.70, 0.90),
	 "glow": Color(0.72, 0.95, 1.0), "accent": Color(0.92, 0.99, 1.0), "trail": Color(0.72, 0.92, 1.0, 0.5)},

	# --- Legendary ---
	{"id": "dragon_eye", "name": "Dragon Eye", "rarity": "Legendary", "style": "core",
	 "desc": "Burns with an ancient fire.",
	 "core": Color(1.0, 0.58, 0.16), "shell": Color(0.42, 0.10, 0.04),
	 "glow": Color(1.0, 0.40, 0.10), "accent": Color(1.0, 0.86, 0.32), "trail": Color(1.0, 0.50, 0.16, 0.5)},
	{"id": "plasma_sphere", "name": "Plasma Sphere", "rarity": "Legendary", "style": "core",
	 "desc": "Contained violet plasma.",
	 "core": Color(0.82, 0.46, 1.0), "shell": Color(0.26, 0.08, 0.46),
	 "glow": Color(0.72, 0.42, 1.0), "accent": Color(1.0, 0.74, 1.0), "trail": Color(0.82, 0.46, 1.0, 0.5)},
	{"id": "dark_matter", "name": "Dark Matter", "rarity": "Legendary", "style": "cosmic",
	 "desc": "Bends the space around it.",
	 "core": Color(0.14, 0.12, 0.24), "shell": Color(0.05, 0.04, 0.10),
	 "glow": Color(0.52, 0.32, 0.88), "accent": Color(0.74, 0.56, 1.0), "trail": Color(0.52, 0.32, 0.88, 0.5)},
	{"id": "solar_core", "name": "Solar Core", "rarity": "Legendary", "style": "spark",
	 "desc": "A captured piece of a star.",
	 "core": Color(1.0, 0.84, 0.32), "shell": Color(0.90, 0.44, 0.10),
	 "glow": Color(1.0, 0.62, 0.16), "accent": Color(1.0, 0.96, 0.62), "trail": Color(1.0, 0.70, 0.22, 0.5)},
	{"id": "lightning_orb", "name": "Lightning Orb", "rarity": "Legendary", "style": "lightning",
	 "desc": "Crackling, barely contained.",
	 "core": Color(0.96, 0.92, 0.46), "shell": Color(0.36, 0.38, 0.50),
	 "glow": Color(1.0, 0.96, 0.52), "accent": Color(1.0, 1.0, 0.74), "trail": Color(1.0, 0.96, 0.52, 0.5)},

	# --- Mythic ---
	{"id": "cosmic_rift", "name": "Cosmic Rift", "rarity": "Mythic", "style": "cosmic",
	 "desc": "A tear in the night sky.",
	 "core": Color(0.10, 0.15, 0.34), "shell": Color(0.03, 0.05, 0.14),
	 "glow": Color(0.42, 0.62, 1.0), "accent": Color(0.74, 0.86, 1.0), "trail": Color(0.42, 0.62, 1.0, 0.5)},
	{"id": "galaxy_heart", "name": "Galaxy Heart", "rarity": "Mythic", "style": "cosmic",
	 "desc": "Holds a galaxy spinning within.",
	 "core": Color(0.24, 0.10, 0.30), "shell": Color(0.08, 0.03, 0.12),
	 "glow": Color(1.0, 0.50, 0.86), "accent": Color(1.0, 0.82, 0.96), "trail": Color(1.0, 0.50, 0.86, 0.5)},
	{"id": "void_walker", "name": "Void Walker", "rarity": "Mythic", "style": "lightning",
	 "desc": "Walks where light cannot.",
	 "core": Color(0.12, 0.08, 0.18), "shell": Color(0.04, 0.02, 0.07),
	 "glow": Color(0.56, 0.32, 0.92), "accent": Color(0.82, 0.58, 1.0), "trail": Color(0.56, 0.32, 0.92, 0.5)},
	{"id": "celestial_crown", "name": "Celestial Crown", "rarity": "Mythic", "style": "halo",
	 "desc": "Worn only by champions of the sky.",
	 "core": Color(1.0, 0.96, 0.82), "shell": Color(0.86, 0.70, 0.42),
	 "glow": Color(1.0, 0.90, 0.60), "accent": Color(1.0, 1.0, 0.92), "trail": Color(1.0, 0.92, 0.70, 0.5)},
	{"id": "singularity", "name": "Singularity", "rarity": "Mythic", "style": "spark",
	 "desc": "Light goes in. Nothing comes out.",
	 "core": Color(0.06, 0.06, 0.09), "shell": Color(0.0, 0.0, 0.0),
	 "glow": Color(0.58, 0.70, 1.0), "accent": Color(0.90, 0.95, 1.0), "trail": Color(0.58, 0.70, 1.0, 0.5)},

	# --- Special ---
	{"id": "developer", "name": "Developer Ball", "rarity": "Special", "style": "solid",
	 "desc": "Compiled with love. No bugs. Probably.",
	 "core": Color(0.24, 0.95, 0.48), "shell": Color(0.10, 0.40, 0.22),
	 "glow": Color(0.32, 1.0, 0.52), "accent": Color(0.74, 1.0, 0.82), "trail": Color(0.32, 1.0, 0.52, 0.5)},
	{"id": "retro_arcade", "name": "Retro Arcade", "rarity": "Special", "style": "retro",
	 "desc": "Straight from the arcade floor.",
	 "core": Color(1.0, 0.85, 0.22), "shell": Color(0.96, 0.32, 0.32),
	 "glow": Color(1.0, 0.72, 0.24), "accent": Color(0.32, 0.80, 1.0), "trail": Color(1.0, 0.72, 0.30, 0.5)},
	{"id": "crystal_nova", "name": "Crystal Nova", "rarity": "Special", "style": "crystal",
	 "desc": "Shattering brilliance.",
	 "core": Color(0.96, 0.96, 1.0), "shell": Color(0.62, 0.76, 0.96),
	 "glow": Color(0.86, 0.90, 1.0), "accent": Color(1.0, 0.86, 1.0), "trail": Color(0.90, 0.92, 1.0, 0.5)},
	{"id": "golden_champion", "name": "Golden Champion", "rarity": "Special", "style": "gold",
	 "desc": "Reserved for the very best.",
	 "core": Color(1.0, 0.82, 0.32), "shell": Color(0.68, 0.48, 0.10),
	 "glow": Color(1.0, 0.86, 0.42), "accent": Color(1.0, 0.98, 0.82), "trail": Color(1.0, 0.82, 0.36, 0.5)},

	# --- Extra skins ---
	{"id": "slate", "name": "Slate", "rarity": "Common", "style": "solid",
	 "desc": "Understated and dependable.",
	 "core": Color(0.62, 0.66, 0.74), "shell": Color(0.36, 0.40, 0.48),
	 "glow": Color(0.72, 0.76, 0.84), "accent": Color(0.86, 0.89, 0.95), "trail": Color(0.72, 0.76, 0.84, 0.5)},
	{"id": "verdant_glow", "name": "Verdant Glow", "rarity": "Rare", "style": "glow",
	 "desc": "Alive with a quiet green light.",
	 "core": Color(0.50, 0.86, 0.52), "shell": Color(0.20, 0.50, 0.26),
	 "glow": Color(0.46, 0.92, 0.52), "accent": Color(0.82, 1.0, 0.82), "trail": Color(0.50, 0.88, 0.52, 0.5)},
	{"id": "frost_nova", "name": "Frost Nova", "rarity": "Legendary", "style": "crystal",
	 "desc": "A burst of eternal winter.",
	 "core": Color(0.84, 0.94, 1.0), "shell": Color(0.50, 0.72, 0.92),
	 "glow": Color(0.80, 0.96, 1.0), "accent": Color(1.0, 1.0, 1.0), "trail": Color(0.82, 0.95, 1.0, 0.5)},
	{"id": "magma_core", "name": "Magma Core", "rarity": "Legendary", "style": "core",
	 "desc": "Molten rock, barely cooled.",
	 "core": Color(1.0, 0.44, 0.18), "shell": Color(0.30, 0.06, 0.02),
	 "glow": Color(1.0, 0.36, 0.10), "accent": Color(1.0, 0.80, 0.32), "trail": Color(1.0, 0.44, 0.18, 0.5)},
	{"id": "nebula_drift", "name": "Nebula Drift", "rarity": "Mythic", "style": "cosmic",
	 "desc": "Adrift on a tide of stars.",
	 "core": Color(0.08, 0.20, 0.24), "shell": Color(0.03, 0.08, 0.10),
	 "glow": Color(0.36, 0.86, 0.86), "accent": Color(0.62, 1.0, 0.96), "trail": Color(0.36, 0.86, 0.86, 0.5)},
	{"id": "pixel_hero", "name": "Pixel Hero", "rarity": "Special", "style": "retro",
	 "desc": "8 bits of pure courage.",
	 "core": Color(0.36, 0.62, 1.0), "shell": Color(0.95, 0.34, 0.42),
	 "glow": Color(0.42, 0.70, 1.0), "accent": Color(1.0, 0.90, 0.32), "trail": Color(0.42, 0.70, 1.0, 0.5)},
]


func all() -> Array[Dictionary]:
	return skins


## Skins of a rarity, or every skin when rarity is "All".
func by_rarity(rarity: String) -> Array[Dictionary]:
	if rarity == "All":
		return skins
	var out: Array[Dictionary] = []
	for s in skins:
		if s["rarity"] == rarity:
			out.append(s)
	return out


func get_skin(id: String) -> Dictionary:
	for s in skins:
		if s["id"] == id:
			return s
	return skins[0]


func rarity_color(rarity: String) -> Color:
	var c: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	return c


## "classic" is always owned. All others require the mapped achievement.
func is_unlocked(id: String) -> bool:
	if id == "classic":
		return true
	var ach_id: String = SKIN_ACHIEVEMENTS.get(id, "")
	if ach_id == "":
		return false
	return Achievements.is_unlocked(ach_id)


## Returns the achievement name that unlocks this skin, or "" if none.
func unlock_hint(id: String) -> String:
	var ach_id: String = SKIN_ACHIEVEMENTS.get(id, "")
	if ach_id == "":
		return ""
	for def in Achievements.definitions:
		if String(def["id"]) == ach_id:
			return String(def["name"])
	return ""


func equipped_id() -> String:
	return String(Profile.equipped.get("ball_skin", "classic"))


func equipped_skin() -> Dictionary:
	return get_skin(equipped_id())


func equip(id: String) -> void:
	Profile.equip_ball_skin(id)
