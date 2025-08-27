extends Node2D

## A visual representation of a tower being placed. Follows the mouse and shows placement validity.

# These will be set by the BuildManager when the ghost is created.
var data: TowerData
var path_layer: TileMapLayer
var highlight_layer: TileMapLayer
var highlight_ids: Dictionary

## Node References
@onready var sprite: Sprite2D = $Sprite
@onready var range_shape: CollisionPolygon2D = $Range/RangeShape

## Internal State
var is_placement_valid: bool = false
var _last_tile_pos: Vector2i = Vector2i(-1, -1)
var _range_points: PackedVector2Array


func _exit_tree() -> void:
	# Ensure highlights are cleared when the ghost is destroyed
	HighlightManager.hide_highlights(highlight_layer)


# Initialises the ghost with tower data and the required layers (no ObjectLayer parameter).
func initialize(
		tower_data: TowerData,                 # Data that defines visuals and behaviour for this ghost.
		path_layer_node: TileMapLayer,         # Path layer used to read the 'buildable' custom data.
		highlight_layer_node: TileMapLayer,    # Layer used for valid/invalid highlight tiles.
		highlight_ids_map: Dictionary          # Mapping of highlight tile IDs for quick lookups.
	) -> void:
	data = tower_data                         # Store tower data for sprite/range setup.
	path_layer = path_layer_node              # Cache the path layer reference for validity checks.
	highlight_layer = highlight_layer_node    # Cache the highlight layer for preview feedback.
	highlight_ids = highlight_ids_map         # Cache the highlight tile IDs dictionary.

	if not is_instance_valid(data):           # Fail fast if the tower data is missing/invalid.
		push_error("GhostTower is missing its TowerData!")
		queue_free()
		return

	sprite.texture = data.ghost_texture       # Apply the ghost sprite texture.
	sprite.position = data.visual_offset      # Apply any visual offset to line up with the tile centre.
	_generate_range_polygon()                 # Precompute the range polygon so preview renders immediately.


## Called every frame. Updates position and validity.
func _process(_delta: float) -> void:
	if not is_instance_valid(path_layer):
		return

	var mouse_pos := get_global_mouse_position()
	var map_coords := path_layer.local_to_map(path_layer.to_local(mouse_pos))

	var snapped_local_pos := path_layer.map_to_local(map_coords)
	global_position = path_layer.to_global(snapped_local_pos)

	_update_placement_validity(map_coords)

	if map_coords != _last_tile_pos:
		HighlightManager.show_ghost_highlights(highlight_layer, map_coords, data.tower_range, highlight_ids, is_placement_valid)
		_last_tile_pos = map_coords


# Updates preview validity using BuildManager's single rule (PathLayer 'buildable' only).
func _update_placement_validity(map_coords: Vector2i) -> void:
	# Fail safe if Path layer isn't ready.
	if not is_instance_valid(path_layer):
		is_placement_valid = false
		return

	# Single source of truth.
	is_placement_valid = BuildManager.is_buildable_at(path_layer, map_coords)


## Returns the calculated points for the range polygon.
func get_range_points() -> PackedVector2Array:
	return _range_points


## Calculates and sets the points for the range polygon.
func _generate_range_polygon() -> void:
	var points: PackedVector2Array = []
	var full_tile_size := Vector2(192, 96)
	var range_multiplier: float = data.tower_range + 0.5

	points.append(Vector2(0, -full_tile_size.y * range_multiplier))
	points.append(Vector2(full_tile_size.x * range_multiplier, 0))
	points.append(Vector2(0, full_tile_size.y * range_multiplier))
	points.append(Vector2(-full_tile_size.x * range_multiplier, 0))

	_range_points = points
	range_shape.polygon = _range_points
