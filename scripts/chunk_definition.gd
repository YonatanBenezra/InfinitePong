extends Resource
class_name ChunkDefinition
## Data-driven chunk descriptor (GDD: "Chunks should ideally be data/prefab
## driven: difficulty value, allowed biome, hazard pool, connection points").
##
## - scene: the PackedScene to instantiate.
## - difficulty: cost subtracted from the level's difficulty budget.
## - weight: relative pick weight in the weighted-random selection.
## - biome: optional tag (e.g. &"factory", &"ice"). Empty = any biome.
##   Filtering by biome is opt-in on the generator side, so legacy chunks
##   with no biome set always pass.
## - hazard_pool: optional set of hazard PackedScenes this chunk is allowed
##   to spawn at runtime. Empty = whatever the scene declares statically.
## - connection_tags: marker names exposed by this chunk besides the default
##   ConnectTop/ConnectBottom (reserved for future multi-exit chunks).
## - tags: free-form labels for filtering and analytics ("learner",
##   "vertical", "puzzle", etc.).

@export var scene: PackedScene
@export var difficulty: int = 1
@export var weight: float = 1.0
@export var biome: StringName = &""
@export var hazard_pool: Array[PackedScene] = []
@export var connection_tags: PackedStringArray = PackedStringArray()
@export var tags: PackedStringArray = PackedStringArray()


func matches_biome(active_biome: StringName) -> bool:
	if active_biome == &"" or biome == &"":
		return true
	return biome == active_biome
