extends Node

## Manages all tile highlighting logic for tower selection and placement.

const _HIGHLIGHT_ATLAS_COORDS := Vector2i(0, 0)

## Hides all highlights by clearing the given layer.
func hide_highlights(layer: TileMapLayer) -> void:
	if is_instance_valid(layer):
		layer.clear()


## Shows highlights for a placed tower that has been selected.
func show_selection_highlights(layer: TileMapLayer, center: Vector2i, tower_range: int, tower_id: int, range_id: int) -> void:
	if not is_instance_valid(layer):
		return
	
	layer.clear()
	layer.set_cell(center, tower_id, _HIGHLIGHT_ATLAS_COORDS)
	
	if range_id != -1 and tower_range > 0:
		var tiles_in_range := _get_tiles_in_range(center, tower_range)
		for tile_pos in tiles_in_range:
			layer.set_cell(tile_pos, range_id, _HIGHLIGHT_ATLAS_COORDS)


## Shows highlights for the ghost tower, using valid/invalid tile IDs.
func show_ghost_highlights(layer: TileMapLayer, center: Vector2i, tower_range: int, ids: Dictionary, is_valid: bool) -> void:
	if not is_instance_valid(layer):
		return
	
	layer.clear()
	
	var tower_id = ids.valid_tower if is_valid else ids.invalid_tower
	var range_id = ids.valid_range if is_valid else ids.invalid_range
	
	if tower_id != -1:
		layer.set_cell(center, tower_id, _HIGHLIGHT_ATLAS_COORDS)
	
	if range_id != -1 and tower_range > 0:
		var tiles_in_range := _get_tiles_in_range(center, tower_range)
		for tile_pos in tiles_in_range:
			layer.set_cell(tile_pos, range_id, _HIGHLIGHT_ATLAS_COORDS)


## Returns all tiles within a square range (Chebyshev distance).
func _get_tiles_in_range(start_pos: Vector2i, p_range: int) -> Array[Vector2i]:
	var tiles_in_range: Array[Vector2i] = []
	
	for x in range(-p_range, p_range + 1):
		for y in range(-p_range, p_range + 1):
			# Determine the tile position relative to the center
			var tile_pos := start_pos + Vector2i(x, y)
			tiles_in_range.append(tile_pos)
			
	return tiles_in_range