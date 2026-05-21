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
## - Difficulty budget and length scale gently with run_count so the
##   first run is forgiving and later runs feel like an arcade ramp.

@export var config: LevelGenConfig
@export var chunk_pool: Array[ChunkDefinition] = []
@export var start_chunk: ChunkDefinition
@export var finale_chunk: ChunkDefinition
## Optional biome filter. Empty = include every chunk regardless of its
## biome tag. Set to e.g. &"factory" to restrict to chunks marked for that
## biome (or chunks with no biome set, which act as universal).
@export var active_biome: StringName = &""


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


func build_level(world: Node2D, rng: RandomNumberGenerator, run_count: int = 1) -> Dictionary:
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

	# Difficulty ramp: every run, allow more chunks and more budget,
	# clamped so things don't get absurd.
	var ramp: int = clampi(run_count - 1, 0, 8)
	var min_chunks: int = config.min_chunks + ramp / 2
	var max_chunks: int = mini(config.max_chunks + ramp, 22)
	var budget: int = config.target_difficulty_budget + ramp * 3

	var initial_budget := budget
	var total_segments := rng.randi_range(min_chunks, max_chunks)
	var middle_count: int = maxi(total_segments - 2, 1)
	var remaining_budget: int = budget
	var used_budget: int = 0
	var last_def: ChunkDefinition = null

	# First couple of mids on run 1 should be easy so player learns.
	var easy_threshold: int = 2 if run_count == 1 else 0

	# Pre-filter the pool by active biome once. Empty biome = pass everything.
	var biome_pool := _filter_biome(chunk_pool)
	if biome_pool.is_empty():
		push_warning("ChunkGenerator: active_biome %s has no matching chunks; falling back to full pool" % active_biome)
		biome_pool = chunk_pool
	var min_chunk_difficulty := biome_pool[0].difficulty
	for c in biome_pool:
		min_chunk_difficulty = mini(min_chunk_difficulty, c.difficulty)

	var sequence: Array[ChunkDefinition] = []
	sequence.append(start_chunk)
	remaining_budget -= start_chunk.difficulty
	used_budget += start_chunk.difficulty
	if remaining_budget < 0:
		push_warning("ChunkGenerator: mandatory start chunk exceeds difficulty budget")
		remaining_budget = 0

	for i in middle_count:
		var remaining_slots := middle_count - i - 1
		var reserved_budget := remaining_slots * min_chunk_difficulty
		var max_diff_here: int = remaining_budget - reserved_budget
		if i < 2 and easy_threshold > 0 and min_chunk_difficulty <= easy_threshold:
			max_diff_here = mini(max_diff_here, easy_threshold)
		if max_diff_here < min_chunk_difficulty:
			push_warning("ChunkGenerator: difficulty budget cannot satisfy target chunk count")
			break
		var picked: ChunkDefinition = null
		for _attempt in config.max_pick_attempts_per_slot:
			var candidate: ChunkDefinition = _pick_weighted(rng, biome_pool)
			if candidate.difficulty > max_diff_here:
				continue
			if last_def != null and candidate == last_def:
				continue
			picked = candidate
			break
		if picked == null:
			var fitting := _filter_fitting(biome_pool, max_diff_here)
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
		WorldPainter.paint(root)
		last_root = root

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
		"budget": initial_budget,
		"used_budget": used_budget,
		"remaining_budget": remaining_budget,
		"sequence": sequence_names,
	}
