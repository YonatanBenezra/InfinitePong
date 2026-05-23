extends Node
class_name ChunkGenerator
## Builds a vertical procedural level from modular chunk scenes.
##
## - Picks chunks via weighted random while respecting a per-level
##   difficulty budget, so levels stay solvable.
## - Aligns chunks vertically by snapping each new chunk's ConnectTop
##   marker to the previous chunk's ConnectBottom marker.
## - Bookends every level with the start and finale chunks (which carry
##   the safe spawn zone and the green exit, respectively).
##
## Progression: every generation knob scales with the LEVEL NUMBER (passed
## in as `level_index`), not the attempt count, so the player feels a clear
## step up from one level to the next:
##   * length        — more chunks per level
##   * budget         — more total difficulty to spend
##   * geometry gate  — harder chunk categories unlock with the level
##   * hazard speed   — moving hazards get faster on later levels
##   * recovery       — early chunks of each level are forced gentle
## Level 1 only ever sees Easy chunks; Medium unlocks at level 2; Hard at
## level 4. The budget maths keeps every produced layout finishable.

@export var config: LevelGenConfig
@export var chunk_pool: Array[ChunkDefinition] = []
@export var start_chunk: ChunkDefinition
@export var finale_chunk: ChunkDefinition
## Optional biome filter. Empty = include every chunk regardless of its
## biome tag. Set to e.g. &"factory" to restrict to chunks marked for that
## biome (or chunks with no biome set, which act as universal).
@export var active_biome: StringName = &""

const _MOVING_HAZARD_SCRIPT := "res://scripts/moving_hazard.gd"

## Canonical screen-edge wall geometry. Authored chunks vary the side walls
## by ~16px, which leaves a ledge at every chunk seam for the ball to snag
## on. Every edge wall is snapped to this single width + inner face so the
## arena reads as one continuous, flush column.
const EDGE_WALL_WIDTH := 80.0
const LEFT_WALL_INNER := 60.0
const RIGHT_WALL_INNER := 580.0


func _ensure_defaults() -> void:
	if config == null:
		config = preload("res://resources/default_level_config.tres")
	if start_chunk == null:
		start_chunk = preload("res://resources/chunk_def_start.tres")
	if finale_chunk == null:
		finale_chunk = preload("res://resources/chunk_def_finale.tres")
	if chunk_pool.is_empty():
		chunk_pool = [
			preload("res://resources/chunk_def_slide.tres"),
			preload("res://resources/chunk_def_flip_std.tres"),
			preload("res://resources/chunk_def_flip_flat.tres"),
			preload("res://resources/chunk_def_flip_drop.tres"),
			preload("res://resources/chunk_def_flip_inverted.tres"),
			preload("res://resources/chunk_def_spikes_static.tres"),
			preload("res://resources/chunk_def_spikes_moving.tres"),
			preload("res://resources/chunk_def_gauntlet.tres"),
			preload("res://resources/chunk_def_random_gate.tres"),
			preload("res://resources/chunk_def_zigzag.tres"),
			preload("res://resources/chunk_def_side_flippers.tres"),
			preload("res://resources/chunk_def_funnel.tres"),
			preload("res://resources/chunk_def_bumper_pit.tres"),
			preload("res://resources/chunk_def_corridor.tres"),
			preload("res://resources/chunk_def_skill.tres"),
			preload("res://resources/chunk_def_quarter_pipe.tres"),
			preload("res://resources/chunk_def_half_pipe.tres"),
		]


func _pick_weighted(rng: RandomNumberGenerator, pool: Array[ChunkDefinition]) -> ChunkDefinition:
	var total_weight := 0.0
	for c in pool:
		total_weight += maxf(c.weight, 0.01)
	var r := rng.randf() * total_weight
	for c in pool:
		r -= maxf(c.weight, 0.01)
		if r <= 0.0:
			return c
	return pool[pool.size() - 1]


func _filter_fitting(pool: Array[ChunkDefinition], max_difficulty: int) -> Array[ChunkDefinition]:
	var out: Array[ChunkDefinition] = []
	for c in pool:
		if c.difficulty <= max_difficulty:
			out.append(c)
	return out


func _filter_biome(pool: Array[ChunkDefinition]) -> Array[ChunkDefinition]:
	if active_biome == &"":
		return pool
	var out: Array[ChunkDefinition] = []
	for c in pool:
		if c.matches_biome(active_biome):
			out.append(c)
	return out


## Highest chunk difficulty this level is allowed to spawn. This is the
## Easy/Medium/Hard category gate expressed numerically.
func _max_difficulty_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 2   # Easy only.
	elif lvl <= 2:
		return 3   # Easy + Medium.
	elif lvl <= 3:
		return 4   # adds the lighter Hard chunks.
	return 6       # everything.


func build_level(world: Node2D, rng: RandomNumberGenerator, level_index: int = 1) -> Dictionary:
	_ensure_defaults()
	# Clear previous chunks.
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()

	if not is_instance_valid(config):
		push_error("ChunkGenerator: missing LevelGenConfig")
		return {}
	if chunk_pool.is_empty() or not is_instance_valid(start_chunk) or not is_instance_valid(finale_chunk):
		push_error("ChunkGenerator: missing chunk definitions")
		return {}

	var lvl: int = maxi(level_index, 1)
	# Ramp saturates so very deep runs stay sane, but it climbs for a long
	# time so progression keeps being felt level after level.
	var ramp: int = clampi(lvl - 1, 0, 12)

	# --- Progression knobs (all scale with the level number). ---
	# Length grows: later levels are noticeably longer.
	var min_chunks: int = config.min_chunks + ramp / 2
	var max_chunks: int = mini(config.max_chunks + (ramp * 2) / 3, 28)
	# Difficulty budget grows steadily so later levels pack harder chunks.
	var budget: int = config.target_difficulty_budget + ramp * 4
	# Geometry / precision gate: hard chunks unlock with the level number.
	var max_chunk_difficulty: int = _max_difficulty_for_level(lvl)
	# Moving hazards get faster on later levels ("faster hazards").
	var hazard_speed_mult: float = clampf(1.0 + 0.06 * float(ramp), 1.0, 1.7)
	# How many opening chunks are forced gentle (calm on-ramp / recovery).
	var easy_intro: int = 1 if lvl >= 4 else 2

	# Pre-filter the pool by active biome, then by what this level allows.
	var biome_pool := _filter_biome(chunk_pool)
	if biome_pool.is_empty():
		push_warning("ChunkGenerator: active_biome %s has no matching chunks; falling back to full pool" % active_biome)
		biome_pool = chunk_pool
	# Level-gated pool: never offer a chunk above this level's cap.
	var level_pool := _filter_fitting(biome_pool, max_chunk_difficulty)
	if level_pool.is_empty():
		push_warning("ChunkGenerator: level cap left no chunks; falling back to biome pool")
		level_pool = biome_pool

	var min_chunk_difficulty := level_pool[0].difficulty
	for c in level_pool:
		min_chunk_difficulty = mini(min_chunk_difficulty, c.difficulty)
	# Difficulty value below which a chunk counts as a gentle "intro" chunk.
	var intro_cap: int = maxi(2, min_chunk_difficulty)

	var initial_budget := budget
	var total_segments := rng.randi_range(min_chunks, max_chunks)
	var middle_count: int = maxi(total_segments - 2, 1)
	var remaining_budget: int = budget
	var used_budget: int = 0
	var last_def: ChunkDefinition = null

	var sequence: Array[ChunkDefinition] = []
	sequence.append(start_chunk)
	remaining_budget -= start_chunk.difficulty
	used_budget += start_chunk.difficulty
	if remaining_budget < 0:
		push_warning("ChunkGenerator: mandatory start chunk exceeds difficulty budget")
		remaining_budget = 0

	for i in middle_count:
		var remaining_slots := middle_count - i - 1
		# Always keep enough budget for the cheapest possible chunk in each
		# remaining slot, so the level never runs out of affordable chunks.
		var reserved_budget := remaining_slots * min_chunk_difficulty
		var max_diff_here: int = remaining_budget - reserved_budget
		# Force the opening chunks of every level to be gentle so the player
		# gets a recovery space before the level ramps up.
		if i < easy_intro:
			max_diff_here = mini(max_diff_here, intro_cap)
		if max_diff_here < min_chunk_difficulty:
			push_warning("ChunkGenerator: difficulty budget cannot satisfy target chunk count")
			break
		var picked: ChunkDefinition = null
		for _attempt in config.max_pick_attempts_per_slot:
			var candidate: ChunkDefinition = _pick_weighted(rng, level_pool)
			if candidate.difficulty > max_diff_here:
				continue
			if last_def != null and candidate == last_def:
				continue
			picked = candidate
			break
		if picked == null:
			var fitting := _filter_fitting(level_pool, max_diff_here)
			if fitting.is_empty():
				push_warning("ChunkGenerator: no affordable chunks fit remaining difficulty budget")
				break
			else:
				picked = _pick_weighted(rng, fitting)
		sequence.append(picked)
		last_def = picked
		remaining_budget -= picked.difficulty
		used_budget += picked.difficulty

	if finale_chunk.difficulty > remaining_budget:
		push_warning("ChunkGenerator: mandatory finale chunk exceeds difficulty budget")
	sequence.append(finale_chunk)
	remaining_budget -= finale_chunk.difficulty
	used_budget += finale_chunk.difficulty

	var sequence_names := PackedStringArray()
	for def in sequence:
		var label := def.resource_path.get_file().get_basename()
		sequence_names.append(label if label != "" else def.get_class())

	var last_root: Node2D = null
	var spawn_global := Vector2.ZERO

	for def in sequence:
		if not is_instance_valid(def.scene):
			push_error("ChunkDefinition has null scene")
			continue
		var root := def.scene.instantiate() as Node2D
		if root == null:
			push_error("Chunk scene root must be Node2D")
			continue
		world.add_child(root)
		if last_root == null:
			root.global_position = Vector2.ZERO
		else:
			var prev_bottom: Vector2 = (last_root.get_node("ConnectBottom") as Node2D).global_position
			var top: Node2D = root.get_node("ConnectTop") as Node2D
			root.global_position = prev_bottom - top.position
		_normalize_side_walls(root)
		WorldPainter.paint(root)
		last_root = root

	# Scale moving-hazard speed for this level ("faster hazards"). Done after
	# all chunks are built so it only touches this freshly generated level.
	if hazard_speed_mult > 1.001:
		_scale_moving_hazards(world, hazard_speed_mult)

	var first: Node2D = world.get_child(0) as Node2D
	if first.has_node("BallSpawn"):
		spawn_global = (first.get_node("BallSpawn") as Node2D).global_position
	elif first.has_node("ConnectTop"):
		spawn_global = (first.get_node("ConnectTop") as Node2D).global_position + Vector2(0, 40)

	var level_bottom_y: float = 0.0
	if is_instance_valid(last_root) and last_root.has_node("ConnectBottom"):
		level_bottom_y = (last_root.get_node("ConnectBottom") as Node2D).global_position.y

	return {
		"spawn_global": spawn_global,
		"last_chunk": last_root,
		"bottom_y": level_bottom_y,
		"level": lvl,
		"budget": initial_budget,
		"used_budget": used_budget,
		"remaining_budget": remaining_budget,
		"max_chunk_difficulty": max_chunk_difficulty,
		"hazard_speed_mult": hazard_speed_mult,
		"sequence": sequence_names,
	}


## Snaps a chunk's screen-edge side walls (WallLeft / WallRight sitting near
## the arena edges) to one canonical width and inner face. Adjacent chunks
## then form a single flush column with no ledge to snag the ball. Walls
## deliberately placed far inward (tight chunks like the gauntlet) sit well
## away from the edge and are intentionally left untouched.
func _normalize_side_walls(root: Node) -> void:
	for child in root.get_children():
		if not (child is StaticBody2D):
			continue
		var body := child as StaticBody2D
		if body.name == "WallLeft" and body.position.x < 90.0:
			_snap_edge_wall(body, LEFT_WALL_INNER - EDGE_WALL_WIDTH * 0.5)
		elif body.name == "WallRight" and body.position.x > 550.0:
			_snap_edge_wall(body, RIGHT_WALL_INNER + EDGE_WALL_WIDTH * 0.5)


## Rewrites one edge wall to the canonical width at the given centre x,
## keeping its authored height. A fresh shape is used so shared SubResources
## are never mutated.
func _snap_edge_wall(body: StaticBody2D, center_x: float) -> void:
	var cs := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is RectangleShape2D):
		return
	var height: float = (cs.shape as RectangleShape2D).size.y
	var shape := RectangleShape2D.new()
	shape.size = Vector2(EDGE_WALL_WIDTH, height)
	cs.shape = shape
	cs.position = Vector2.ZERO
	cs.rotation = 0.0
	body.position.x = center_x


## Recursively multiplies the `speed` of every moving_hazard mover under the
## given node. Scoped to the freshly built `world` subtree so it never
## touches hazards from a previous (queued-free) level.
func _scale_moving_hazards(node: Node, mult: float) -> void:
	var script: Variant = node.get_script()
	if script is Script and (script as Script).resource_path == _MOVING_HAZARD_SCRIPT:
		var current: float = float(node.get("speed"))
		node.set("speed", current * mult)
	for child in node.get_children():
		_scale_moving_hazards(child, mult)
