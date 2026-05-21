class_name ChunkConnector
extends RefCounted

static func get_marker_local(chunk: Node2D, marker_name: String) -> Vector2:
	var marker := chunk.get_node_or_null(marker_name) as Marker2D
	if marker:
		return marker.position
	return Vector2.ZERO


static func get_marker_global(chunk: Node2D, marker_name: String) -> Vector2:
	return chunk.global_position + get_marker_local(chunk, marker_name)


static func place_chunk_connecting_top(chunk: Node2D, connect_top_to: Vector2) -> void:
	var top_local := get_marker_local(chunk, "ConnectTop")
	chunk.global_position = connect_top_to - top_local
