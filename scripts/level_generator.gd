class_name LevelGenerator
extends Node

const PLAY_CENTER_X := 576.0
const EXIT_PADDING_Y := 48.0

@export var spawn_chunk_scene: PackedScene
@export var exit_chunk_scene: PackedScene
@export var min_chunks: int = 3
@export var max_chunks: int = 6
@export var difficulty_budget: int = 14
@export var max_pick_attempts: int = 32

@export var chunk_pool: Array[ChunkDefinition] = []

var level_root: Node2D
var walls_root: Node2D
var lane_visuals: Node2D

var spawn_position: Vector2 = Vector2(PLAY_CENTER_X, 80.0)
var level_top_y: float = 0.0
var level_bottom_y: float = 800.0
var exit_area: Area2D

var _built_height: float = 0.0
var _last_connect_bottom: Vector2


func setup(p_level_root: Node2D, p_walls_root: Node2D, p_lane_visuals: Node2D) -> void:
	level_root = p_level_root
	walls_root = p_walls_root
	lane_visuals = p_lane_visuals


func build_level() -> float:
	_clear_level()
	if spawn_chunk_scene == null or exit_chunk_scene == null:
		push_error("LevelGenerator: assign spawn and exit chunk scenes.")
		return 0.0

	var remaining_budget := difficulty_budget
	var chunk_count := randi_range(min_chunks, max_chunks)
	var placed := 0
	var attempts := 0

	var spawn_chunk := spawn_chunk_scene.instantiate() as Node2D
	level_root.add_child(spawn_chunk)
	ChunkConnector.place_chunk_connecting_top(spawn_chunk, Vector2(PLAY_CENTER_X, 0.0))
	spawn_position = ChunkConnector.get_marker_global(spawn_chunk, "SpawnPoint")
	level_top_y = spawn_position.y - 40.0
	_last_connect_bottom = ChunkConnector.get_marker_global(spawn_chunk, "ConnectBottom")

	while placed < chunk_count and attempts < max_pick_attempts * chunk_count:
		attempts += 1
		var def := _pick_chunk(remaining_budget, placed < min_chunks)
		if def == null:
			break
		if def.difficulty > remaining_budget and placed >= min_chunks:
			continue
		var chunk := def.scene.instantiate() as Node2D
		level_root.add_child(chunk)
		ChunkConnector.place_chunk_connecting_top(chunk, _last_connect_bottom)
		_randomize_chunk(chunk)
		_last_connect_bottom = ChunkConnector.get_marker_global(chunk, "ConnectBottom")
		remaining_budget = maxi(0, remaining_budget - def.difficulty)
		placed += 1

	_built_height = _last_connect_bottom.y
	_place_exit()
	_resize_walls()
	level_bottom_y = _last_connect_bottom.y + 120.0
	return _built_height


func get_spawn_position() -> Vector2:
	return spawn_position


func get_level_bounds() -> Vector2:
	return Vector2(level_top_y, level_bottom_y)


func _clear_level() -> void:
	for child in level_root.get_children():
		child.queue_free()
	exit_area = null
	_built_height = 0.0


func _pick_chunk(remaining: int, force_any: bool) -> ChunkDefinition:
	if chunk_pool.is_empty():
		return null
	var affordable: Array[ChunkDefinition] = []
	var weighted: Array[ChunkDefinition] = []
	for def in chunk_pool:
		if def.difficulty <= remaining:
			affordable.append(def)
			var weight := maxi(1, remaining - def.difficulty + 2)
			if def.difficulty >= 3:
				weight += 1
			for _i in weight:
				weighted.append(def)
	var pool: Array[ChunkDefinition] = weighted if not weighted.is_empty() else chunk_pool
	if not force_any and affordable.is_empty():
		return null
	return pool[randi() % pool.size()]


func _randomize_chunk(chunk: Node2D) -> void:
	for node in _find_in_group(chunk, "hazard_random"):
		node.visible = randf() > 0.5
		if node is Area2D:
			var spike := node as Area2D
			spike.monitoring = node.visible
			spike.monitorable = node.visible


func _find_in_group(root: Node, group_name: String) -> Array[Node]:
	var found: Array[Node] = []
	if root.is_in_group(group_name):
		found.append(root)
	for child in root.get_children():
		found.append_array(_find_in_group(child, group_name))
	return found


func _place_exit() -> void:
	var exit_chunk := exit_chunk_scene.instantiate() as Node2D
	level_root.add_child(exit_chunk)
	var connect_top := _last_connect_bottom + Vector2(0.0, EXIT_PADDING_Y)
	ChunkConnector.place_chunk_connecting_top(exit_chunk, connect_top)
	exit_area = exit_chunk.get_node("ExitArea") as Area2D
	_last_connect_bottom = ChunkConnector.get_marker_global(exit_chunk, "ConnectBottom")


func _resize_walls() -> void:
	var total_h := level_bottom_y + 200.0
	var center_y := total_h * 0.5
	for wall in walls_root.get_children():
		if wall is StaticBody2D:
			var col := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col and col.shape is RectangleShape2D:
				(col.shape as RectangleShape2D).size.y = total_h
				wall.position.y = center_y
	if lane_visuals:
		for lane in lane_visuals.get_children():
			if lane is Line2D:
				lane.points = PackedVector2Array([Vector2(lane.position.x, 0), Vector2(lane.position.x, total_h)])
