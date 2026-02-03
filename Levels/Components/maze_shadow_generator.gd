@tool
extends TileMapLayer
class_name MazeShadowGenerator

## Automatically generates a shadow layer based on a source TileMapLayer.

@export var source_layer_path: NodePath:
	set(value):
		source_layer_path = value
		_update_source_reference()
		_refresh_shadows()

@export var shadow_offset: Vector2 = Vector2(10, 10):
	set(value):
		shadow_offset = value
		position = shadow_offset # Apply offset directly to the layer position
		# No need to redraw tiles if we just move the layer layer

@export var shadow_color: Color = Color(0, 0, 0, 0.5):
	set(value):
		shadow_color = value
		modulate = shadow_color

@export var force_refresh: bool = false:
	set(value):
		if value:
			_refresh_shadows()
		force_refresh = false

var _source_layer: TileMapLayer

func _ready() -> void:
	_update_source_reference()
	if not Engine.is_editor_hint():
		# In game, run once at startup
		_refresh_shadows()

func _update_source_reference() -> void:
	if source_layer_path and has_node(source_layer_path):
		var node = get_node(source_layer_path)
		if node is TileMapLayer:
			if _source_layer and _source_layer.changed.is_connected(_on_source_changed):
				_source_layer.changed.disconnect(_on_source_changed)
			
			_source_layer = node
			
			# Connect to changed signal to update in editor
			if Engine.is_editor_hint():
				if not _source_layer.changed.is_connected(_on_source_changed):
					_source_layer.changed.connect(_on_source_changed)
			
			_refresh_shadows()

func _on_source_changed() -> void:
	_refresh_shadows()

func _refresh_shadows() -> void:
	if not _source_layer:
		return
		
	# We don't use set_cell anymore, so we clear any existing tiles
	clear()
	
	# Apply visual properties
	modulate = shadow_color
	position = shadow_offset
	
	queue_redraw()

func _draw() -> void:
	if not _source_layer or not tile_set:
		return
		
	# We want to draw "walls" connecting the shadow layer back to the source layer.
	# Since this layer is offset by 'shadow_offset', the source layer is at -position relative to us.
	var to_source = - position
	var tile_size = tile_set.tile_size
	
	var used_cells = _source_layer.get_used_cells()
	
	for coords in used_cells:
		# Draw the main shadow block (Flat Tile)
		var cell_center = map_to_local(coords)
		var half_size = Vector2(tile_size) * 0.5
		var top_left = cell_center - half_size
		
		# Draw flat shadow rect
		# We draw in WHITE so the 'modulate' (Shadow Color) applies strictly.
		draw_rect(Rect2(top_left, tile_size), Color.WHITE)
		
		# Now draw extrusions (Corner Gaps)
		var top_right = cell_center + Vector2(half_size.x, -half_size.y)
		var bottom_right = cell_center + half_size
		var bottom_left = cell_center + Vector2(-half_size.x, half_size.y)
		
		# Check Source Layer's Neighbors (since we are drawing based on source existence)
		# We also check if our current shadow drawing logic would draw there?
		# Actually, we should check if the Neighbor exists in the Source Layer.
		# If Source Neighbor is EMPTY, then this edge is exposed and casts a shadow "wall".
		
		# Check Right Neighbor of Source
		var right_neighbor_id = _source_layer.get_cell_source_id(coords + Vector2i.RIGHT)
		
		if right_neighbor_id == -1:
			# Exposed Right Edge: TR -> BR
			var shadow_edge = [top_right, bottom_right]
			var source_edge = [top_right + to_source, bottom_right + to_source]
			# Draw Quad: ShadowEdge -> SourceEdge
			var points = PackedVector2Array([
				shadow_edge[0], shadow_edge[1],
				source_edge[1], source_edge[0]
			])
			draw_polygon(points, [Color.WHITE])
			
		# Check Bottom Neighbor of Source
		var down_neighbor_id = _source_layer.get_cell_source_id(coords + Vector2i.DOWN)
		
		if down_neighbor_id == -1:
			# Exposed Bottom Edge: BL -> BR
			var shadow_edge = [bottom_left, bottom_right]
			var source_edge = [bottom_left + to_source, bottom_right + to_source]
			# Draw Quad: ShadowEdge -> SourceEdge
			var points = PackedVector2Array([
				shadow_edge[0], shadow_edge[1],
				source_edge[1], source_edge[0]
			])
			draw_polygon(points, [Color.WHITE])

		# Corner Check: Bottom-Right
		# If both Right and Down are exposed, we technically have a corner gap if the offset is diagonal.
		# But the quads above share the BR vertex, so they should touch.
		# Tricky case: External corners connecting.
		# With a diagonal offset (10, 10), TR->BR quad moves up-left. BL->BR quad moves up-left.
		# They share the BR -> BR' edge. It should be watertight.

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		pass
