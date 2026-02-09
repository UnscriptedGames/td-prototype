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

@export var custom_styles: Array[MazeTileStyle] = []:
	set(value):
		custom_styles = value
		queue_redraw()

@export var grid_width: int = 24 # Match BackgroundRenderer default

@export_range(0.0, 1.0) var reveal_ratio: float = 1.0:
	set(value):
		reveal_ratio = value
		queue_redraw()

@export_group("Visuals")
# Geometry-only settings (Global)
@export var glow_steps: int = 4:
	set(value):
		glow_steps = value
		queue_redraw()

@export var glow_step_size: float = 0.8:
	set(value):
		glow_step_size = value
		queue_redraw()

@export var custom_glow_radius: float = 5.0: # -1.0 = Auto (based on button radius), >= 0 = Custom
	set(value):
		custom_glow_radius = value
		queue_redraw()

@export var inner_padding: float = 3.0: # Distance from edge for the glow
	set(value):
		inner_padding = value
		queue_redraw()

@export_range(0.0, 1.0) var button_scale: float = 0.95:
	set(value):
		button_scale = value
		queue_redraw()
@export var corner_radius: float = 5.0:
	set(value):
		corner_radius = value
		queue_redraw()

@export var depth_offset: Vector2 = Vector2(4, 4):
	set(value):
		depth_offset = value
		queue_redraw()

var _source_layer: TileMapLayer
var _style_lookup: Dictionary = {}

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

func _rebuild_style_lookup() -> void:
	_style_lookup.clear()
	for map in custom_styles:
		if map:
			var key = Vector3i(map.source_id, map.atlas_coords.x, map.atlas_coords.y)
			_style_lookup[key] = map

func _get_active_style(coords: Vector2i) -> MazeTileStyle:
	# 1. Check Custom Mapping
	var source_id = _source_layer.get_cell_source_id(coords)
	var atlas_coords = _source_layer.get_cell_atlas_coords(coords)
	var key = Vector3i(source_id, atlas_coords.x, atlas_coords.y)
	
	if key in _style_lookup:
		# Return the specific style for this tile
		return _style_lookup[key]
		
	# No match found -> Return null (don't draw)
	return null

func has_cell(coords: Vector2i) -> bool:
	if not _source_layer: return false
	return _get_active_style(coords) != null

func _draw() -> void:
	if not _source_layer:
		return
		
	var tile_set = _source_layer.tile_set
	if not tile_set:
		return
		
	_rebuild_style_lookup() # Ensure lookup is fresh
		
	var tile_size = tile_set.tile_size
	var used_cells = _source_layer.get_used_cells()
	
	# Pass 1: Draw All Shadows/Extrusions (Bottom Layer)
	for coords in used_cells:
		# Reveal Logic
		if (float(coords.x) + 0.5) / float(grid_width) > reveal_ratio:
			continue

		var style = _get_active_style(coords)
		if not style:
			continue
		
		# Geometry
		var cell_center = _source_layer.map_to_local(coords)
		var full_size = Vector2(tile_size)
		var draw_size = full_size * button_scale
		var centering_offset = - depth_offset * 0.5
		var offset_pos = cell_center - (draw_size * 0.5) + centering_offset
		
		var face_rect = Rect2(offset_pos, draw_size)
		var back_rect = face_rect
		back_rect.position += depth_offset
		
		# Draw Extrusion Only
		_draw_extrusion(face_rect, back_rect, style.side_color)

	# Pass 2: Draw All Faces/Glows (Top Layer)
	for coords in used_cells:
		# Reveal Logic
		if (float(coords.x) + 0.5) / float(grid_width) > reveal_ratio:
			continue

		var style = _get_active_style(coords)
		if not style:
			continue
		
		# Geometry (Recalculated for independence)
		var cell_center = _source_layer.map_to_local(coords)
		var full_size = Vector2(tile_size)
		var draw_size = full_size * button_scale
		var centering_offset = - depth_offset * 0.5
		var offset_pos = cell_center - (draw_size * 0.5) + centering_offset
		
		var face_rect = Rect2(offset_pos, draw_size)
		
		# Draw Face
		draw_style_box(_create_style_box(style.button_color), face_rect)
		
		# Draw Inner Glow
		if inner_padding > 0 and style.glow_opacity > 0:
			for i in range(glow_steps):
				var current_padding = inner_padding + (i * glow_step_size)
				var inner_rect = face_rect.grow(-current_padding)
				
				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					var sb_glow = StyleBoxFlat.new()
					sb_glow.bg_color = style.glow_color
					sb_glow.bg_color.a = style.glow_opacity
					
					var inner_radius = 0.0
					if custom_glow_radius >= 0.0:
						inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
					else:
						inner_radius = max(0.0, corner_radius - current_padding)
					
					sb_glow.set_corner_radius_all(int(inner_radius))
					sb_glow.corner_detail = 4
					sb_glow.anti_aliasing = true
					
					draw_style_box(sb_glow, inner_rect)

func _draw_extrusion(front: Rect2, back: Rect2, color: Color) -> void:
	# 8-Quad approach: Draw 4 side strips + 4 corner chamfers to connect the rounded
	# front and back faces. This fills the gaps that the old convex-hull approach missed.
	var r = min(corner_radius, min(front.size.x, front.size.y) * 0.5)
	
	# Draw the Back Face (Base) first
	draw_style_box(_create_style_box(color), back)
	
	# Calculate the 8 tangent points for the front face:
	# Top edge tangents (horizontal)
	var f_tl_h = Vector2(front.position.x + r, front.position.y)
	var f_tr_h = Vector2(front.end.x - r, front.position.y)
	# Bottom edge tangents (horizontal)
	var f_bl_h = Vector2(front.position.x + r, front.end.y)
	var f_br_h = Vector2(front.end.x - r, front.end.y)
	# Left edge tangents (vertical)
	var f_tl_v = Vector2(front.position.x, front.position.y + r)
	var f_bl_v = Vector2(front.position.x, front.end.y - r)
	# Right edge tangents (vertical)
	var f_tr_v = Vector2(front.end.x, front.position.y + r)
	var f_br_v = Vector2(front.end.x, front.end.y - r)
	
	# Calculate the 8 tangent points for the back face:
	var b_tl_h = Vector2(back.position.x + r, back.position.y)
	var b_tr_h = Vector2(back.end.x - r, back.position.y)
	var b_bl_h = Vector2(back.position.x + r, back.end.y)
	var b_br_h = Vector2(back.end.x - r, back.end.y)
	var b_tl_v = Vector2(back.position.x, back.position.y + r)
	var b_bl_v = Vector2(back.position.x, back.end.y - r)
	var b_tr_v = Vector2(back.end.x, back.position.y + r)
	var b_br_v = Vector2(back.end.x, back.end.y - r)
	
	# Draw 4 Corner "Pills" (Swept Circles)
	# Instead of trying to triangulate the gap, we draw a thick line connecting
	# the center of the Front corner circle to the center of the Back corner circle.
	# Width = 2*r ensures it matches the circle diameter.
	# This creates a "skewed cylinder" that perfectly fills the corner volume.
	
	# Top-Left Center
	var c_tl = Vector2(front.position.x + r, front.position.y + r)
	draw_line(c_tl, c_tl + depth_offset, color, r * 2.0)
	
	# Top-Right Center
	var c_tr = Vector2(front.end.x - r, front.position.y + r)
	draw_line(c_tr, c_tr + depth_offset, color, r * 2.0)
	
	# Bottom-Right Center
	var c_br = Vector2(front.end.x - r, front.end.y - r)
	draw_line(c_br, c_br + depth_offset, color, r * 2.0)
	
	# Bottom-Left Center
	var c_bl = Vector2(front.position.x + r, front.end.y - r)
	draw_line(c_bl, c_bl + depth_offset, color, r * 2.0)
	
	# Draw 4 Side Strip Quads (connects the straight edges)
	# Top Side
	_draw_triangle_quad(f_tl_h, f_tr_h, b_tr_h, b_tl_h, color)
	# Bottom Side
	_draw_triangle_quad(f_br_h, f_bl_h, b_bl_h, b_br_h, color)
	# Left Side
	_draw_triangle_quad(f_bl_v, f_tl_v, b_tl_v, b_bl_v, color)
	# Right Side
	_draw_triangle_quad(f_tr_v, f_br_v, b_br_v, b_tr_v, color)

func _draw_triangle_quad(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, color: Color) -> void:
	# Splits Quad (P1, P2, P3, P4) into two triangles: (P1, P2, P3) and (P1, P3, P4).
	# Safely skips degenerate triangles (zero area) to avoid triangulation errors.
	_draw_safe_triangle(p1, p2, p3, color)
	_draw_safe_triangle(p1, p3, p4, color)

func _draw_safe_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	# Calculate signed area 
	# Area = 0.5 * |(xB*yA - xA*yB) + (xC*yB - xB*yC) + (xA*yC - xC*yA)|
	var area = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
	
	# Force consistent winding (CCW) to prevent potential backface culling
	if area < 0:
		var temp = b
		b = c
		c = temp
		area = - area
	
	if area > 0.1: # Threshold to ignore degenerate/collinear triangles
		draw_polygon([a, b, c], [color])

func _create_style_box(color: Color) -> StyleBoxFlat:
	# Helper to create a stylebox for drawing
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(corner_radius))
	sb.corner_detail = 4
	sb.anti_aliasing = true
	return sb
