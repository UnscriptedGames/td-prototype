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

@export var transition_layer_path: NodePath:
	set(value):
		transition_layer_path = value
		_update_transition_reference()
		queue_redraw()

@export var custom_styles: Array[MazeTileStyle] = []:
	set(value):
		custom_styles = value
		queue_redraw()

@export var grid_width: int = 25 # Match BackgroundRenderer default

enum RevealMode {LINEAR, CENTER_OUT}

@export var reveal_mode: RevealMode = RevealMode.LINEAR:
	set(value):
		reveal_mode = value
		queue_redraw()

@export var center_column: int = 12: # Approx grid_width / 2
	set(value):
		center_column = value
		queue_redraw()

@export_range(0.0, 1.0) var reveal_ratio: float = 1.0:
	set(value):
		reveal_ratio = value
		queue_redraw()

@export_range(0.0, 1.0) var transition_progress: float = 1.0:
	set(value):
		transition_progress = value
		queue_redraw()

@export var dissolve_anim_width: float = 0.1: # Width of the scaling band
	set(value):
		dissolve_anim_width = value
		queue_redraw()

@export var wipe_anim_width: float = 0.5: # Width of the wipe soft edge
	set(value):
		wipe_anim_width = value
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
var _transition_layer: TileMapLayer
var _style_lookup: Dictionary = {}
var _style_box_pool: Dictionary = {} # Key: {color, radius} -> StyleBoxFlat

func _ready() -> void:
	_preload_style_boxes()
	_update_source_reference()
	_update_transition_reference()

func _preload_style_boxes() -> void:
	# Pre-populate pool with known styles to prevent stutter during animation
	_style_box_pool.clear()
	
	# Preload default and custom styles
	for style in custom_styles:
		if style:
			# Cache main button
			_create_style_box(style.button_color, corner_radius)
			
			# Cache glows
			if style.glow_opacity > 0:
				var c = style.glow_color
				c.a = style.glow_opacity
				for i in range(glow_steps):
					var current_padding = inner_padding + (i * glow_step_size)
					var inner_radius = 0.0
					if custom_glow_radius >= 0.0:
						inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
					else:
						inner_radius = max(0.0, corner_radius - current_padding)
					_create_style_box(c, inner_radius)

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

func _update_transition_reference() -> void:
	if transition_layer_path and has_node(transition_layer_path):
		var node = get_node(transition_layer_path)
		if node is TileMapLayer:
			if _transition_layer and _transition_layer.changed.is_connected(_on_source_changed):
				_transition_layer.changed.disconnect(_on_source_changed)
			
			_transition_layer = node
			
			if Engine.is_editor_hint():
				if not _transition_layer.changed.is_connected(_on_source_changed):
					_transition_layer.changed.connect(_on_source_changed)
			
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
	
	# Determine set of all cells to draw (Union of Source and Transition)
	var all_cells = {}
	for coords in _source_layer.get_used_cells():
		all_cells[coords] = true
	
	if _transition_layer:
		for coords in _transition_layer.get_used_cells():
			all_cells[coords] = true
			
	# Process drawing
	for coords in all_cells.keys():
		# 1. Visibility / Scale Check (Wipe Logic)
		var wipe_scale = _get_reveal_scale(coords)
		if wipe_scale <= 0.001:
			continue

		# Transition Logic (Dissolve)
		# Deterministic random based on coordinates
		var noise_hash = float((coords.x * 73856093) ^ (coords.y * 19349663)) / 2147483647.0
		noise_hash = abs(noise_hash) # Ensure positive 0-1
		
		# Decide which layer to create style from
		var active_layer = _source_layer
		var scale_anim_mult = 1.0
		
		# If transition_progress is low, we might show the transition layer
		# transition_progress = 0.0 -> Show Transition (if exists)
		# transition_progress = 1.0 -> Show Source
		
		if _transition_layer:
			# Calculate distance from threshold for scaling animation
			var dist = transition_progress - noise_hash
			
			# Determine Active Layer based on progress relative to hash
			if dist > 0:
				active_layer = _source_layer
			else:
				active_layer = _transition_layer
				
			# Calculate Scale Animation
			# Check ends first to avoid artifacts/stuck scaling
			if transition_progress >= 0.99 or transition_progress <= 0.01:
				scale_anim_mult = 1.0
			else:
				# Apply scaling based on proximity to threshold
				if dist > 0:
					# Showing Source (Behind Wave)
					if dist < dissolve_anim_width:
						scale_anim_mult = smoothstep(0.0, 1.0, dist / dissolve_anim_width)
				else:
					# Showing Transition (Ahead of Wave)
					var abs_dist = abs(dist)
					if abs_dist < dissolve_anim_width:
						scale_anim_mult = smoothstep(0.0, 1.0, abs_dist / dissolve_anim_width)
		
		# Get style from the active layer
		var source_id = active_layer.get_cell_source_id(coords)
		var atlas_coords = active_layer.get_cell_atlas_coords(coords)
		var key = Vector3i(source_id, atlas_coords.x, atlas_coords.y)
		var style = _style_lookup.get(key)
		
		if not style:
			continue
		
		# Geometry
		var cell_center = Vector2(coords * int(tile_size.x)) + (Vector2(tile_size) / 2.0)
		var full_size = Vector2(tile_size)
		# Calculate available size (Cell - Shadow Depth) to ensure Scale 1.0 fits perfectly without overlap
		var available_size = (full_size - depth_offset.abs()).max(Vector2.ZERO)
		# Apply wipe scale to whatever layer we picked
		var draw_size = available_size * button_scale * scale_anim_mult * wipe_scale
		
		# Draw
		var centering_offset = - depth_offset * 0.5
		var offset_pos = cell_center - (draw_size * 0.5) + centering_offset
		
		var face_rect = Rect2(offset_pos, draw_size)
		var back_rect = face_rect
		back_rect.position += depth_offset
		
		# Draw Extrusion
		_draw_extrusion(face_rect, back_rect, style.side_color)
		
		# Draw Face
		draw_style_box(_create_style_box(style.button_color, corner_radius), face_rect)
		
		# Draw Inner Glow
		if inner_padding > 0 and style.glow_opacity > 0:
			for i in range(glow_steps):
				var current_padding = inner_padding + (i * glow_step_size)
				var inner_rect = face_rect.grow(-current_padding)
				
				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					# Use pooled stylebox
					var inner_color = style.glow_color
					inner_color.a = style.glow_opacity
					
					var inner_radius = 0.0
					if custom_glow_radius >= 0.0:
						inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
					else:
						inner_radius = max(0.0, corner_radius - current_padding)
					
					var sb_glow = _create_style_box(inner_color, inner_radius)
					
					draw_style_box(sb_glow, inner_rect)

func _draw_extrusion(front: Rect2, back: Rect2, color: Color) -> void:
	# 8-Quad approach: Draw 4 side strips + 4 corner chamfers to connect the rounded
	# front and back faces. This fills the gaps that the old convex-hull approach missed.
	var r = min(corner_radius, min(front.size.x, front.size.y) * 0.5)
	
	# Draw the Back Face (Base) first
	draw_style_box(_create_style_box(color, corner_radius), back)
	
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

func _create_style_box(color: Color, radius: float) -> StyleBoxFlat:
	# Caching wrapper for StyleBoxes
	# Key construction: Color + Radius
	# We can use an Array or specific string key. String is safer for Dictionary keys in GDScript sometimes.
	var key = [color, radius]
	
	if _style_box_pool.has(key):
		return _style_box_pool[key]
		
	# Create new
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 4
	sb.anti_aliasing = true
	
	# Cache
	_style_box_pool[key] = sb
	return sb

func _get_reveal_scale(coords: Vector2i) -> float:
	# Returns 0.0 (Hidden) to 1.0 (Fully Visible)
	if reveal_mode == RevealMode.LINEAR:
		# Simple linear threshold (Hard edge for now, or could soft too)
		if (float(coords.x) + 0.5) / float(grid_width) <= reveal_ratio:
			return 1.0
		return 0.0
	
	elif reveal_mode == RevealMode.CENTER_OUT:
		# Distance from center column
		var dist = abs(coords.x - center_column)
		# Max possible distance is to the far edges (0 or grid_width)
		var max_dist = max(center_column, grid_width - center_column)
		
		# Normalized position of this tile (0.0 = center, 1.0 = edge)
		var norm_pos = float(dist) / float(max_dist) if max_dist > 0 else 0.0
		
		# If width is effectively zero, hard cut
		if wipe_anim_width < 0.001:
			return 1.0 if norm_pos <= reveal_ratio else 0.0
			
		# Soft scaling logic
		# We need the window (lower, upper) to slide such that:
		# At ratio=0: No tiles visible (window is below 0).
		# At ratio=1: All tiles visible (window is past 1).
		
		# To ensure norm_pos=1.0 is fully covered at ratio=1.0, the window lower bound must reach 1.0.
		# Range mapping for 'lower_bound' of the visible set:
		# We want IsVisible(pos) == 1 when pos < lower_bound.
		
		# Let's map reveal_ratio (0..1) to a sliding window of "Fully Revealed Threshold".
		# Actually, standard smoothstep usage:
		# scale = 1.0 - smoothstep(edge0, edge1, x)
		# We want 1.0 when x is small (inside the center).
		# So when x < edge0, scale is 1.
		# When x > edge1, scale is 0.
		
		# edge0 is the "Full Visibility" line.
		# edge1 is the "Start Appearing" line.
		# width = edge1 - edge0.
		
		# We want edge0 to go from (-width) to (1.0).
		# At ratio=0: edge1 = 0. edge0 = -W. Tile 0: smoothstep(-W, 0, 0) = 1. -> 1-1=0. Correct.
		# Ratio 1: edge1 = 1+W. edge0 = 1. Tile 1: smoothstep(1, 1+W, 1) = 0. -> 1-0=1. Correct.
		
		var leading_edge = reveal_ratio * (1.0 + wipe_anim_width)
		var trailing_edge = leading_edge - wipe_anim_width
		
		return 1.0 - smoothstep(trailing_edge, leading_edge, norm_pos)

	return 1.0
