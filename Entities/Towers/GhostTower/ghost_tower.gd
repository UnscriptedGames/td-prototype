extends Node2D

## A visual representation of a tower being placed. Follows the mouse and shows placement validity.

@export var valid_color := Color("33ff6677") # Translucent Green
@export var invalid_color := Color("ff333377") # Translucent Red

# These will be set by the BuildManager when the ghost is created.
var data: TowerData
var grass_layer: TileMapLayer
var objects_layer: TileMapLayer

## Node References
@onready var sprite: Sprite2D = $Sprite
@onready var range_shape: CollisionPolygon2D = $Range/RangeShape
@onready var range_visual: Polygon2D = $Range/RangeVisual

## Internal State
var is_placement_valid: bool = false


## Called by the BuildManager to set up the ghost tower.
func initialize(tower_data: TowerData, p_grass_layer: TileMapLayer, p_objects_layer: TileMapLayer) -> void:
	data = tower_data
	grass_layer = p_grass_layer
	objects_layer = p_objects_layer

	# Configure the ghost tower based on the provided data
	if not is_instance_valid(data):
		push_error("GhostTower is missing its TowerData!")
		queue_free() # Can't function without data, so remove itself
		return

	sprite.texture = data.ghost_texture
	_generate_range_polygon()


## Called every frame. Updates position and validity.
func _process(_delta: float) -> void:
	# If the tower hasn't been initialized yet, do nothing.
	if not is_instance_valid(grass_layer):
		return

	# Get the tile coordinate under the mouse
	var mouse_pos := get_global_mouse_position()
	var map_coords := grass_layer.local_to_map(grass_layer.to_local(mouse_pos))

	# Snap the ghost tower's position to the center of that tile
	var snapped_local_pos := grass_layer.map_to_local(map_coords)
	global_position = grass_layer.to_global(snapped_local_pos)

	# Update the validity check based on the same tile coordinate
	_update_placement_validity(map_coords)


## Checks tile data to determine if the current location is a valid build spot.
func _update_placement_validity(map_coords: Vector2i) -> void:
	# If the layer references haven't been set yet, do nothing.
	if not is_instance_valid(grass_layer) or not is_instance_valid(objects_layer):
		is_placement_valid = false
		return

	# Condition 1: Check if the grass tile is marked as 'buildable'
	var is_buildable := false
	var tile_data: TileData = grass_layer.get_cell_tile_data(map_coords)
	if tile_data:
		is_buildable = tile_data.get_custom_data("buildable")

	# Condition 2: Check if the corresponding tile on the objects layer is empty
	var is_empty := objects_layer.get_cell_source_id(map_coords) == -1

	# Update state and visuals based on the checks
	if is_buildable and is_empty:
		is_placement_valid = true
		#sprite.modulate = valid_color
		range_visual.color = valid_color
	else:
		is_placement_valid = false
		#sprite.modulate = invalid_color
		range_visual.color = invalid_color


## Calculates and sets the points for the range polygon and its visual representation.
func _generate_range_polygon() -> void:
	var points: PackedVector2Array = []
	var half_tile_size := Vector2(192, 96)
	
	# This calculation is from your working repository code
	var range_in_tiles: float = data.tower_range + 0.5

	# Calculate the vertices of the diamond shape
	points.append(Vector2(0, -half_tile_size.y * range_in_tiles))
	points.append(Vector2(half_tile_size.x * range_in_tiles, 0))
	points.append(Vector2(0, half_tile_size.y * range_in_tiles))
	points.append(Vector2(-half_tile_size.x * range_in_tiles, 0))

	# Assign the same points to both the collision shape and the visual shape
	range_shape.polygon = points
	range_visual.polygon = points
