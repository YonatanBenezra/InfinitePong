extends Resource
class_name LevelConfig
## Designer-facing level recipe.
##
## One LevelConfig resource (see resources/levels/default_level_config.tres)
## describes everything a level needs to be assembled: the pool of chunks
## the generator may pick from, the fixed start and finale chunks, and the
## tuning knobs that decide how long and how hard each generated level is.
##
## Editing this resource in the Inspector is the *only* file a level
## designer needs to touch to change the chunk lineup or difficulty curve —
## no script edits required.
##
## Difficulty budget: every chunk has a `difficulty` cost (1 = trivial,
## 6 = brutal). The generator spends `target_difficulty_budget` on each
## level, so raising the budget produces a harder level on average.

@export_group("Length")
## Minimum number of middle chunks per level (the start and finale chunks
## are always added on top of this).
@export_range(1, 30, 1) var min_chunks: int = 3
## Maximum number of middle chunks per level.
@export_range(1, 40, 1) var max_chunks: int = 7

@export_group("Difficulty")
## How much "difficulty" the generator is allowed to spend on one level.
## Higher = harder. Each chunk's own `difficulty` value is subtracted from
## this budget. Use the chart in docs/chunks_guide.md for typical values.
@export_range(4, 60, 1) var target_difficulty_budget: int = 14
## How many random picks the generator may try before giving up on a slot
## and falling back to the cheapest fitting chunk. Designers rarely need
## to change this; raising it makes generation more pedantic, not harder.
@export_range(8, 256, 1) var max_pick_attempts_per_slot: int = 48

@export_group("Bumpers")
## Static bumpers spawned per level at `BumperSlot` markers (see chunk scenes).
@export_range(0, 6, 1) var min_bumpers_per_run: int = 2
@export_range(0, 6, 1) var max_bumpers_per_run: int = 3

@export_group("Chunk pool")
## The pool of chunks the generator may pick from for the middle of every
## level. Drag chunk_def_*.tres resources here to enable them, remove an
## entry to disable a chunk without deleting it. Empty = the generator
## falls back to its built-in default pool (defined in chunk_generator.gd).
@export var chunk_pool: Array[ChunkDefinition] = []
## The opening chunk every level starts with. Holds the ball spawn point
## and a safe entrance, so always pick a gentle chunk here.
@export var start_chunk: ChunkDefinition
## The closing chunk every level ends with. Holds the green exit gate.
@export var finale_chunk: ChunkDefinition
