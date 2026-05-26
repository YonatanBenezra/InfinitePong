extends Resource
class_name ChunkDefinition
## Designer-facing description of one procedural chunk.
##
## One ChunkDefinition (a .tres in resources/chunks/) is the contract
## between a chunk scene and the ChunkGenerator: the scene is the geometry,
## the definition is its metadata — how hard it is, how often it should be
## picked, which biomes it belongs to, etc.
##
## Edit these values in Godot's Inspector — no code changes needed.
## See docs/chunks_guide.md for a step-by-step on creating a new chunk.

@export_group("Chunk")
## The chunk scene to instantiate. Must be a Node2D with ConnectTop and
## ConnectBottom Marker2D children so the generator can stack chunks.
@export var scene: PackedScene

@export_group("Difficulty")
## Cost subtracted from the level's difficulty budget when this chunk is
## picked. Higher = harder. Suggested values:
##   1-2 = Easy   (open, slow, gentle hazards)
##   3   = Medium (some precision needed, simple hazards)
##   4-5 = Hard   (precision, fast hazards, tight corridors)
##   6   = Brutal (only late-game levels)
@export_range(1, 6, 1) var difficulty: int = 1
## Coarse difficulty bucket used by the generator's per-level gating.
## Leave empty (&"") to derive it automatically from `difficulty`:
##   1-2 -> easy, 3 -> medium, 4+ -> hard.
## Set explicitly to &"easy", &"medium" or &"hard" to override.
@export var category: StringName = &""

@export_group("Selection weight")
## Relative pick chance in the weighted-random selection. 1.0 is the
## baseline; 2.0 = roughly twice as likely as a 1.0 chunk; 0.5 = half as
## likely. Use this to bias the mix without forcing exact ratios.
@export_range(0.1, 5.0, 0.1) var weight: float = 1.0

@export_group("Biome (optional)")
## Optional tag for biome filtering, e.g. &"factory" or &"ice". Leave
## empty for a universal chunk that fits any biome. The generator's
## `active_biome` decides which biomes are included in a given run.
@export var biome: StringName = &""

@export_group("Geometry")
## Vertical length of this chunk in pixels (distance from ConnectTop to
## ConnectBottom). The generator moves ConnectBottom to this Y at runtime,
## so you can change the height here without opening the scene.
##
## Pick a named preset from the dropdown — covers the useful range with
## predictable steps. "Use scene default" inherits whatever the scene's
## ConnectBottom already defines (the common case). If you genuinely need
## an off-grid value, edit the .tres directly (e.g. `length = 425`); the
## generator just reads the int and any positive number works.
@export_enum(
	"Use scene default:0",
	"Tiny — 240 px:240",
	"Short — 320 px:320",
	"Compact — 400 px:400",
	"Medium — 480 px:480",
	"Tall — 560 px:560",
	"Long — 640 px:640",
	"Extra-long — 800 px:800",
	"Giant — 1000 px:1000"
) var length: int = 0

@export_group("Advanced (optional)")
## Free-form labels for filtering and analytics ("learner", "vertical",
## "puzzle", "curved", …). Not used by the generator today but searchable
## and useful for grouping chunks in the editor.
@export var tags: PackedStringArray = PackedStringArray()
## Marker names exposed by this chunk besides the default ConnectTop /
## ConnectBottom (reserved for future multi-exit chunks).
@export var connection_tags: PackedStringArray = PackedStringArray()
## Hazard PackedScenes this chunk is allowed to spawn at runtime. Empty
## = whatever the scene declares statically (the common case).
@export var hazard_pool: Array[PackedScene] = []


func matches_biome(active_biome: StringName) -> bool:
	if active_biome == &"" or biome == &"":
		return true
	return biome == active_biome


## Easy / Medium / Hard bucket for this chunk. Uses the explicit `category`
## override when set, otherwise derives it from the numeric difficulty.
func get_category() -> StringName:
	if category != &"":
		return category
	if difficulty <= 2:
		return &"easy"
	elif difficulty <= 3:
		return &"medium"
	return &"hard"
