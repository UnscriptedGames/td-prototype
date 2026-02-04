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

@export var glow_color: Color = Color("8ecbf4"): # Much brighter/cyanish for better contrast
	set(value):
		glow_color = value
		queue_redraw()

@export var glow_opacity: float = 0.4: # Base opacity for the glow layers
	set(value):
		glow_opacity = value
		queue_redraw()

@export var glow_steps: int = 3: # Number of concentric layers
	set(value):
		glow_steps = value
		queue_redraw()

@export var glow_step_size: float = 2.0: # Distance between layers
	set(value):
		glow_step_size = value
		queue_redraw()

@export var custom_glow_radius: float = -1.0: # -1.0 = Auto (based on button radius), >= 0 = Custom
	set(value):
		custom_glow_radius = value
		queue_redraw()

@export var inner_padding: float = 5.0: # Distance from edge for the glow
	set(value):
		inner_padding = value
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
		
		# Center the entire visual mass (Front + Back) on the cell center
		# The visual center is the midpoint between Front Face and Back Face.
		# Back Face is at depth_offset relative to Front.
		# So we shift the origin by -depth_offset * 0.5
		var centering_offset = - depth_offset * 0.5
		var offset_pos = cell_center - (draw_size * 0.5) + centering_offset
		
		# Define the main Rect (Face)
		var face_rect = Rect2(offset_pos, draw_size)
		
		# Define Side/Depth Rect (shifted by depth_offset)
		var back_rect = face_rect
		back_rect.position += depth_offset
		
		# Draw the block "body" (extrusions) first
		_draw_extrusion(face_rect, back_rect, side_color)
		
		# Draw the Face on top (Base Layer)
		draw_style_box(_create_style_box(button_color), face_rect)
		
		# Draw Inner Glow (Inset Layer)
		# We use a multi-pass approach to simulate a soft gradient.
		if inner_padding > 0 and glow_opacity > 0:
			for i in range(glow_steps):
				var current_padding = inner_padding + (i * glow_step_size)
				var inner_rect = face_rect.grow(-current_padding)
				
				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					var sb_glow = StyleBoxFlat.new()
					sb_glow.bg_color = glow_color
					# Use the user-defined opacity
					sb_glow.bg_color.a = glow_opacity
					
					# Calculate radius: shrunk by padding
					var inner_radius = 0.0
					if custom_glow_radius >= 0.0:
						# User override, still shrink for inner layers to keep concentric look
						inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
					else:
						# Auto: relative to outer button radius
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
