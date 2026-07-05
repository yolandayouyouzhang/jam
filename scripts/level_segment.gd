extends Node2D
class_name LevelSegment

enum SegmentTheme {
	WASTELAND,
	TRANSITION,
	NATURE_PROTOTYPE
}

@export var segment_id: int = 1
@export var display_name: String = ""
@export var width: float = 960.0
@export var checkpoint_path: NodePath = ^"Markers/Checkpoint"
@export var theme: SegmentTheme = SegmentTheme.WASTELAND


func checkpoint_position() -> Vector2:
	var marker := get_node_or_null(checkpoint_path)
	if marker is Node2D:
		return marker.global_position
	return global_position + Vector2(120, 476)


func start_x() -> float:
	return global_position.x


func end_x() -> float:
	return global_position.x + width
