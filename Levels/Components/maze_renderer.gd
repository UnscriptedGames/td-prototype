@tool
extends Node2D
class_name MazeRenderer

## Procedural renderer for maze walls, mimicking a Soundpad/Launchpad button style.
## Draws rounded, "floating" buttons on top of MapLayer data.

@export var source_layer_path: NodePath:
	set(value):
		source_layer_path = value
		_update_source_reference()
		queue_redraw()

@export_group("Visuals")
@export var button_color: Color = Color("4b80ca"): # Default blueish
	set(value):
		button_color = value
		queue_redraw()

@export var side_color: Color = Color("2a4478"): # Darker shade for sides
	set(value):
		side_color = value
		queue_redraw()

@export_range(0.0, 1.0) var button_scale: float = 0.85:
	set(value):
		button_scale = value
		queue_redraw()

@export var corner_radius: float = 8.0:
	set(value):
		corner_radius = value
		queue_redraw()

@export var depth_offset: Vector2 = Vector2(0, 10):
	set(value):
		depth_offset = value
		queue_redraw()

@export var wall_source_id: int = -1: # -1 means all, set to specific ID to filter
	set(value):
		wall_source_id = value
		queue_redraw()

var _source_layer: TileMapLayer

func _ready() -> void:
	_update_source_reference()

func _update_source_reference() -> void:
	if source_layer_path and has_node(source_layer_path):
		var node = get_node(source_layer_path)
		if node is TileMapLayer:
			if _source_layer and _source_layer.changed.is_connected(_on_source_changed):
				_source_layer.changed.disconnect(_on_source_changed)
			
			_source_layer = node
			
			if Engine.is_editor_hint():
				if not _source_layer.changed.is_connected(_on_source_changed):
					_source_layer.changed.connect(_on_source_changed)
			
			queue_redraw()

func _on_source_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if not _source_layer:
		return
		
	var tile_set = _source_layer.tile_set
	if not tile_set:
		return
		
	var tile_size = tile_set.tile_size
	var used_cells = _source_layer.get_used_cells()
	
	for coords in used_cells:
		if wall_source_id != -1:
			var sid = _source_layer.get_cell_source_id(coords)
			if sid != wall_source_id:
				continue
		
		# Calculate geometry
		var cell_center = _source_layer.map_to_local(coords)
		# NOTE: map_to_local returns center of tile in TileMapLayer local space.
		
		var full_size = Vector2(tile_size)
		var draw_size = full_size * button_scale
		var offset_pos = cell_center - (draw_size * 0.5)
		
		# Define the main Rect (Face)
		var face_rect = Rect2(offset_pos, draw_size)
		
		# Define Side/Depth Rect (shifted by depth_offset)
		var back_rect = face_rect
		back_rect.position += depth_offset
		
		# Draw the block "body" (extrusions) first
		_draw_extrusion(face_rect, back_rect, side_color)
		
		# Draw the Face on top
		draw_style_box(_create_style_box(button_color), face_rect)

func _draw_extrusion(front: Rect2, back: Rect2, color: Color) -> void:
	# To make the extrusion look like a solid 3D rounded object, we need to:
	# 1. Draw the "Back" rounded face (the bottom of the block).
	# 2. Draw the "Swept" straight edges connecting Front to Back.
	# We do this by calculating the "Inner Strips" (rects excluding the corner radius)
	# and drawing the convex hull of the Front+Back strips.
	# Clamp radius to half size to avoid invalid rects
	var r = min(corner_radius, min(front.size.x, front.size.y) * 0.5)
	
	# Draw the Back Face (Base)
	draw_style_box(_create_style_box(color), back)
	
	# Vertical Strip (Left/Right straight edges)
	# Rect from y+r to y+h-r
	var f_v = Rect2(front.position.x, front.position.y + r, front.size.x, front.size.y - 2.0 * r)
	var b_v = Rect2(back.position.x, back.position.y + r, back.size.x, back.size.y - 2.0 * r)
	_draw_hull(f_v, b_v, color)
	
	# Horizontal Strip (Top/Bottom straight edges)
	# Rect from x+r to x+w-r
	var f_h = Rect2(front.position.x + r, front.position.y, front.size.x - 2.0 * r, front.size.y)
	var b_h = Rect2(back.position.x + r, back.position.y, back.size.x - 2.0 * r, back.size.y)
	_draw_hull(f_h, b_h, color)

func _draw_hull(r1: Rect2, r2: Rect2, color: Color) -> void:
	# Collect 4 corners of both rects
	var points = PackedVector2Array([
		r1.position,
		r1.position + Vector2(r1.size.x, 0),
		r1.end,
		r1.position + Vector2(0, r1.size.y),
		r2.position,
		r2.position + Vector2(r2.size.x, 0),
		r2.end,
		r2.position + Vector2(0, r2.size.y)
	])
	
	# Compute convex hull to create the connecting polygon
	var hull = Geometry2D.convex_hull(points)
	draw_polygon(hull, [color])

func _create_style_box(color: Color) -> StyleBoxFlat:
	# Helper to create a stylebox for drawing
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(corner_radius))
	sb.corner_detail = 4
	sb.anti_aliasing = true
	return sb
