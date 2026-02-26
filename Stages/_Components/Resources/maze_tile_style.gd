class_name MazeTileStyle
extends Resource

## Defines both the mapping and visual style for a maze tile.
## Used by MazeRenderer to map specific tiles to colors.

@export_group("Mapping")
@export var source_id: int = 5
@export var atlas_coords: Vector2i = Vector2i(0, 0)

@export_group("Visuals")
@export var button_color: Color = Color(0.114, 0.635, 0.255) # Green
@export var side_color: Color = Color(0.021, 0.218, 0.069) # Dark Green
@export var glow_color: Color = Color(0.551, 1.0, 0.61) # Light Green
@export_range(0.0, 1.0) var glow_opacity: float = 0.4
