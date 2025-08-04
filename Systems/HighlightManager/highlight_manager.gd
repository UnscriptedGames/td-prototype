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


## Uses a Breadth-First Search to find all tiles within a given range.
func _get_tiles_in_range(start_pos: Vector2i, p_range: int) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start_pos]
	var visited: Dictionary = {start_pos: 0} # Stores tile -> distance
	var tiles_in_range: Array[Vector2i] = []
	
	var head: int = 0
	while head < queue.size():
		var current_tile: Vector2i = queue[head]
		head += 1
		
		var current_distance: int = visited[current_tile]
		
		if current_distance >= p_range:
			continue
			
		var is_even_row: bool = current_tile.y % 2 == 0
		var neighbor_offsets := _get_neighbor_offsets(is_even_row)
		
		for offset in neighbor_offsets:
			var neighbor: Vector2i = current_tile + offset
			if not visited.has(neighbor):
				visited[neighbor] = current_distance + 1
				queue.append(neighbor)
				tiles_in_range.append(neighbor)
				
	return tiles_in_range


## Returns the correct 8 neighbor offsets based on row parity.
func _get_neighbor_offsets(is_even_row: bool) -> Array[Vector2i]:
	if is_even_row: # EVEN rows
		return [
			Vector2i(0, -2), Vector2i(-1, -1), Vector2i(0, -1),
			Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(0, 2)
		]
	else: # ODD rows
		return [
			Vector2i(0, -2), Vector2i(0, -1), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1),
			Vector2i(1, 0), Vector2i(1, -1)
		]