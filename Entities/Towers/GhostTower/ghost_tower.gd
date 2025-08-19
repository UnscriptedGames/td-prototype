extends Node2D

## A visual representation of a tower being placed. Follows the mouse and shows placement validity.

# These will be set by the BuildManager when the ghost is created.
var data: TowerData
var path_layer: TileMapLayer
var object_layer: TileMapLayer
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


## Called by the BuildManager to set up the ghost tower.
func initialize(p_data: TowerData, p_path_layer: TileMapLayer, p_object_layer: TileMapLayer, p_highlight_layer: TileMapLayer, p_highlight_ids: Dictionary) -> void:
	data = p_data
	path_layer = p_path_layer
	object_layer = p_object_layer
	highlight_layer = p_highlight_layer
	highlight_ids = p_highlight_ids

	if not is_instance_valid(data):
		push_error("GhostTower is missing its TowerData!")
		queue_free()
		return

	sprite.texture = data.ghost_texture
	sprite.position = data.visual_offset
	_generate_range_polygon()


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


## Checks tile data to determine if the current location is a valid build spot.
func _update_placement_validity(map_coords: Vector2i) -> void:
	if not is_instance_valid(path_layer) or not is_instance_valid(object_layer):
		is_placement_valid = false
		return

	var is_buildable := false
	var tile_data: TileData = path_layer.get_cell_tile_data(map_coords)
	if tile_data:
		is_buildable = tile_data.get_custom_data("buildable")

	var is_empty := object_layer.get_cell_source_id(map_coords) == -1

	if is_buildable and is_empty:
		is_placement_valid = true
	else:
		is_placement_valid = false


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
