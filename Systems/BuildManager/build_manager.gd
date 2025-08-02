extends Node

## Manages the tower building process, including ghost towers and placement validation.

@export var highlight_source_id: int = -1 ## Set this in the Inspector!

## Internal State
var _is_in_build_mode: bool = false
const _HIGHLIGHT_ATLAS_COORDS := Vector2i(0, 0)

## Node References
@onready var hud: CanvasLayer = get_node("../LevelHUD") # Make sure this matches your HUD node's name
@onready var tile_maps_node: Node2D = get_node("../TileMaps")
@onready var grass_layer: TileMapLayer = tile_maps_node.get_node("Grass")
@onready var objects_layer: TileMapLayer = tile_maps_node.get_node("Objects")
@onready var highlight_layer: TileMapLayer = tile_maps_node.get_node("Highlight")


## Called when the node enters the scene tree.
func _ready() -> void:
	# Connect to the HUD's signal to know when the player wants to build.
	if is_instance_valid(hud):
		hud.build_tower_requested.connect(_on_build_tower_requested)


## Toggles build mode when the button is pressed.
func _on_build_tower_requested() -> void:
	_is_in_build_mode = not _is_in_build_mode

	if _is_in_build_mode:
		_show_buildable_tiles()
	else:
		_hide_buildable_tiles()


## Shows all valid buildable locations on the highlight layer.
func _show_buildable_tiles() -> void:
	if highlight_source_id == -1:
		push_error("Highlight Source ID is not set in the BuildManager's Inspector.")
		return

	# Get the rectangle of all used cells in the grass layer
	var used_cells := grass_layer.get_used_cells()

	for cell_coords in used_cells:
		var tile_data: TileData = grass_layer.get_cell_tile_data(cell_coords)

		# Condition 1: Check if the grass tile is marked as 'buildable'
		var is_buildable := false
		if tile_data:
			is_buildable = tile_data.get_custom_data("buildable")

		# Condition 2: Check if the corresponding tile on the objects layer is empty
		var is_empty := objects_layer.get_cell_source_id(cell_coords) == -1

		# If both conditions are met, paint a highlight tile
		if is_buildable and is_empty:
			highlight_layer.set_cell(
				cell_coords,
				highlight_source_id, # Use the exported variable
				_HIGHLIGHT_ATLAS_COORDS
			)


## Hides all highlights by clearing the layer.
func _hide_buildable_tiles() -> void:
	highlight_layer.clear()
