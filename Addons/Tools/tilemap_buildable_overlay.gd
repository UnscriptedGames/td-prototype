@tool
class_name DataLayerOverlay
extends TileMapLayer
##
## Mirrors all cells from this TileMapLayer into a target highlight layer:
## - Places the "Valid" tile where the custom-data key is truthy.
## - Places the "Invalid" tile on all other used cells.
## Editor-only by default; can run in-game if enabled.
##


## ===== Exports =====

@export var overlay_enabled: bool = true:
	# Master toggle for the mirror overlay.
	set(value):
		overlay_enabled = value
		_rebuild_overlay()

@export var property_name: StringName = &"buildable":
	# Custom-data key read from this layer's TileData.
	set(value):
		property_name = value
		call_deferred("_rebuild_overlay")

@export var target_layer_path: NodePath:
	# TileMapLayer that will receive the highlight tiles.
	set(value):
		target_layer_path = value
		_cache_highlight_layer()
		call_deferred("_rebuild_overlay")

# Valid (buildable) highlight
@export var valid_source_id: int = 0:
	# TileSet source ID for valid tiles on the target layer.
	set(value):
		valid_source_id = value
		call_deferred("_rebuild_overlay")

@export var valid_atlas_coords: Vector2i = Vector2i(-1, -1):
	# Atlas coordinates for the valid tile (only if the valid source is an Atlas).
	set(value):
		valid_atlas_coords = value
		call_deferred("_rebuild_overlay")

@export var valid_alt_index: int = 0:
	# Alternative index for the valid atlas tile (usually 0).
	set(value):
		valid_alt_index = value
		call_deferred("_rebuild_overlay")

# Invalid (non-buildable) highlight
@export var invalid_source_id: int = 0:
	# TileSet source ID for invalid tiles on the target layer.
	set(value):
		invalid_source_id = value
		call_deferred("_rebuild_overlay")

@export var invalid_atlas_coords: Vector2i = Vector2i(-1, -1):
	# Atlas coordinates for the invalid tile (only if the invalid source is an Atlas).
	set(value):
		invalid_atlas_coords = value
		call_deferred("_rebuild_overlay")

@export var invalid_alt_index: int = 0:
	# Alternative index for the invalid atlas tile (usually 0).
	set(value):
		invalid_alt_index = value
		call_deferred("_rebuild_overlay")

@export var run_in_game: bool = false:
	# If true, mirrors tiles while the game is running; otherwise editor-only.
	set(value):
		run_in_game = value
		call_deferred("_rebuild_overlay")

@export var force_refresh: bool = false:
	# Tick in the Inspector to force a rebuild.
	set(value):
		force_refresh = false
		call_deferred("_rebuild_overlay")



## ===== Internals =====

var _highlight_layer: TileMapLayer = null
var _tile_set_connected: bool = false



## ===== Built-ins =====

func _enter_tree() -> void:
	# Cache target and listen to TileSet edits.
	_cache_highlight_layer()
	_connect_tile_set_changed()
	# Defer rebuild to ensure exported fields are deserialised before first use.
	call_deferred("_rebuild_overlay")



func _exit_tree() -> void:
	# Disconnect on exit.
	_disconnect_tile_set_changed()



## ===== Public Helpers =====

func refresh_now() -> void:
	# Manual rebuild callable from the editor.
	_rebuild_overlay()



## ===== Private Methods =====

func _cache_highlight_layer() -> void:
	# Resolve the target highlight layer from the exported path.
	_highlight_layer = null
	if target_layer_path != NodePath():
		_highlight_layer = get_node(target_layer_path) as TileMapLayer



func _connect_tile_set_changed() -> void:
	# React when this layer's TileSet changes.
	var source_tile_set := tile_set
	if source_tile_set != null and not _tile_set_connected:
		source_tile_set.changed.connect(_on_tile_set_changed)
		_tile_set_connected = true



func _disconnect_tile_set_changed() -> void:
	# Safely disconnect from TileSet.changed.
	var source_tile_set := tile_set
	if source_tile_set != null and source_tile_set.changed.is_connected(_on_tile_set_changed):
		source_tile_set.changed.disconnect(_on_tile_set_changed)
	_tile_set_connected = false



func _on_tile_set_changed() -> void:
	# Rebuild when the TileSet resource updates.
	_rebuild_overlay()



func _rebuild_overlay() -> void:
	# Re-resolve the target node each time.
	_cache_highlight_layer()

	# Decide if we should show anything right now.
	var editor_active := Engine.is_editor_hint()
	var should_show := overlay_enabled and (editor_active or run_in_game)

	# Require a valid target layer.
	if _highlight_layer == null:
		return

	# Clear target first to avoid stale tiles.
	_highlight_layer.clear()

	if not should_show:
		_highlight_layer.queue_redraw()
		return

	# Validate the target TileSet.
	var highlight_tileset := _highlight_layer.tile_set
	if highlight_tileset == null:
		push_warning("Highlight target has no TileSet assigned.")
		_highlight_layer.queue_redraw()
		return

	# Resolve and validate the valid highlight source.
	var valid_source := highlight_tileset.get_source(valid_source_id)
	if valid_source == null:
		push_warning("Valid source_id %d not found on target TileSet." % valid_source_id)
		_highlight_layer.queue_redraw()
		return
	var valid_is_atlas := valid_source is TileSetAtlasSource
	var valid_coords := valid_atlas_coords
	if valid_is_atlas:
		if valid_coords.x < 0 or valid_coords.y < 0:
			valid_coords = Vector2i.ZERO
		var valid_atlas := valid_source as TileSetAtlasSource
		if not valid_atlas.has_tile(valid_coords):
			push_warning("Valid atlas coords %s not found in source %d."
				% [str(valid_coords), valid_source_id])
			_highlight_layer.queue_redraw()
			return

	# Resolve and validate the invalid highlight source.
	var invalid_source := highlight_tileset.get_source(invalid_source_id)
	if invalid_source == null:
		push_warning("Invalid source_id %d not found on target TileSet." % invalid_source_id)
		_highlight_layer.queue_redraw()
		return
	var invalid_is_atlas := invalid_source is TileSetAtlasSource
	var invalid_coords := invalid_atlas_coords
	if invalid_is_atlas:
		if invalid_coords.x < 0 or invalid_coords.y < 0:
			invalid_coords = Vector2i.ZERO
		var invalid_atlas := invalid_source as TileSetAtlasSource
		if not invalid_atlas.has_tile(invalid_coords):
			push_warning("Invalid atlas coords %s not found in source %d."
				% [str(invalid_coords), invalid_source_id])
			_highlight_layer.queue_redraw()
			return

	# Place a tile on every used cell.
	for cell in get_used_cells():
		var tile_data := get_cell_tile_data(cell) as TileData
		var is_buildable := false
		if tile_data != null:
			is_buildable = bool(tile_data.get_custom_data(property_name))

		if is_buildable:
			if valid_is_atlas:
				_highlight_layer.set_cell(
					cell, valid_source_id, valid_coords, valid_alt_index
				)
			else:
				_highlight_layer.set_cell(cell, valid_source_id)
		else:
			if invalid_is_atlas:
				_highlight_layer.set_cell(
					cell, invalid_source_id, invalid_coords, invalid_alt_index
				)
			else:
				_highlight_layer.set_cell(cell, invalid_source_id)

	# Ensure the target redraws now.
	_highlight_layer.queue_redraw()
