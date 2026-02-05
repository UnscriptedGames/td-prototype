@tool
extends Node2D
class_name BackgroundRenderer

## Procedural renderer for grid background.
## Draws rounded, "floating" buttons on all grid spots.

@export_group("Grid")
@export var grid_width: int = 24
@export var grid_height: int = 16

@export_group("Visuals")
@export var button_color: Color = Color("2e2e30"): # Dark grey for pads
	set(value):
		button_color = value
		queue_redraw()

@export var side_color: Color = Color("1a1a1c"): # Darker shade for sides
	set(value):
		side_color = value
		queue_redraw()

@export var glow_color: Color = Color("4b4b50"): # Subtle glow
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

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# 1. Tile Size Fixed
	var tile_size = Vector2i(64, 64)
	
	# 2. Pre-create StyleBoxes to avoid allocation spam
	var sb_face = _create_style_box(button_color)
	var sb_side = _create_style_box(side_color)
	var sb_glows: Array[StyleBoxFlat] = []
	
	if inner_padding > 0 and glow_opacity > 0:
		for i in range(glow_steps):
			var sb = StyleBoxFlat.new()
			sb.bg_color = glow_color
			sb.bg_color.a = glow_opacity
			
			var current_padding = inner_padding + (i * glow_step_size)
			# Calculate radius
			var inner_radius = 0.0
			if custom_glow_radius >= 0.0:
				inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
			else:
				inner_radius = max(0.0, corner_radius - current_padding)
			
			sb.set_corner_radius_all(int(inner_radius))
			sb.corner_detail = 4
			sb.anti_aliasing = true
			sb_glows.append(sb)

	# 3. Iterate all grid cells
	for x in range(grid_width):
		for y in range(grid_height):
			var coords = Vector2i(x, y)
			
			# Always draw, no exclusion check
		
			# Calculate geometry
			# Explicitly use Vector2 for calculation to avoid integer division warning
			var cell_center = Vector2(coords * tile_size) + (Vector2(tile_size) / 2.0)
			
			var full_size = Vector2(tile_size)
			var draw_size = full_size * button_scale
			
			var centering_offset = - depth_offset * 0.5
			var offset_pos = cell_center - (draw_size * 0.5) + centering_offset
			
			var face_rect = Rect2(offset_pos, draw_size)
			var back_rect = face_rect
			back_rect.position += depth_offset
			
			# Draw Extrusion (Manual implementation using pre-cached side stylebox)
			_draw_extrusion_optimized(face_rect, back_rect, side_color, sb_side)
			
			# Draw Face
			draw_style_box(sb_face, face_rect)
			
			# Draw Inner Glows
			for i in range(sb_glows.size()):
				var current_padding = inner_padding + (i * glow_step_size)
				var inner_rect = face_rect.grow(-current_padding)
				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					draw_style_box(sb_glows[i], inner_rect)

func _draw_extrusion_optimized(front: Rect2, back: Rect2, color: Color, sb_back: StyleBoxFlat) -> void:
	var r = min(corner_radius, min(front.size.x, front.size.y) * 0.5)
	
	# Draw Back Face
	draw_style_box(sb_back, back)
	
	# Calculate Tangents (Same as before)
	var f_tl_h = Vector2(front.position.x + r, front.position.y)
	var f_tr_h = Vector2(front.end.x - r, front.position.y)
	var f_bl_h = Vector2(front.position.x + r, front.end.y)
	var f_br_h = Vector2(front.end.x - r, front.end.y)
	var f_tl_v = Vector2(front.position.x, front.position.y + r)
	var f_bl_v = Vector2(front.position.x, front.end.y - r)
	var f_tr_v = Vector2(front.end.x, front.position.y + r)
	var f_br_v = Vector2(front.end.x, front.end.y - r)
	
	var b_tl_h = Vector2(back.position.x + r, back.position.y)
	var b_tr_h = Vector2(back.end.x - r, back.position.y)
	var b_bl_h = Vector2(back.position.x + r, back.end.y)
	var b_br_h = Vector2(back.end.x - r, back.end.y)
	var b_tl_v = Vector2(back.position.x, back.position.y + r)
	var b_bl_v = Vector2(back.position.x, back.end.y - r)
	var b_tr_v = Vector2(back.end.x, back.position.y + r)
	var b_br_v = Vector2(back.end.x, back.end.y - r)
	
	# Draw Corner Pills
	var c_tl = Vector2(front.position.x + r, front.position.y + r)
	draw_line(c_tl, c_tl + depth_offset, color, r * 2.0)
	var c_tr = Vector2(front.end.x - r, front.position.y + r)
	draw_line(c_tr, c_tr + depth_offset, color, r * 2.0)
	var c_br = Vector2(front.end.x - r, front.end.y - r)
	draw_line(c_br, c_br + depth_offset, color, r * 2.0)
	var c_bl = Vector2(front.position.x + r, front.end.y - r)
	draw_line(c_bl, c_bl + depth_offset, color, r * 2.0)
	
	# Draw Side Quads
	_draw_triangle_quad(f_tl_h, f_tr_h, b_tr_h, b_tl_h, color)
	_draw_triangle_quad(f_br_h, f_bl_h, b_bl_h, b_br_h, color)
	_draw_triangle_quad(f_bl_v, f_tl_v, b_tl_v, b_bl_v, color)
	_draw_triangle_quad(f_tr_v, f_br_v, b_br_v, b_tr_v, color)

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
