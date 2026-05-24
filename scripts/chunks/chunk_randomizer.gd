extends Node
## Removes one random child branch based on spawn_chance (0..1) for optional variants (GDD).


@export_range(0.0, 1.0) var spawn_chance: float = 0.5
@export var variant_a_path: NodePath
@export var variant_b_path: NodePath


func _ready() -> void:
	if variant_a_path.is_empty() or variant_b_path.is_empty():
		return
	var a := get_node_or_null(variant_a_path) as Node
	var b := get_node_or_null(variant_b_path) as Node
	if a == null or b == null:
		return
	if randf() < spawn_chance:
		b.queue_free()
	else:
		a.queue_free()
