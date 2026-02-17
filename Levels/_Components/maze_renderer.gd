@tool
extends Node2D
class_name MazeRenderer

## Procedural renderer for maze walls, mimicking a Soundpad/Launchpad button style.
##
## Draws rounded, "floating" buttons on top of MapLayer data.
## Supports animated wipe reveals and dissolve transitions between two TileMapLayers.

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
var _style_lookup: Dictionary[Vector3i, MazeTileStyle] = {}
var _style_box_pool: Dictionary[Array, StyleBoxFlat] = {}

func _ready() -> void:
	_preload_style_boxes()
	_update_source_reference()
	_update_transition_reference()

func _preload_style_boxes() -> void:
	# Pre-populate pool with known styles to prevent stutter during animation.
	_style_box_pool.clear()
	
	for style: MazeTileStyle in custom_styles:
		if style:
			# Cache main button
			_create_style_box(style.button_color, corner_radius)
			
			# Cache glows
			if style.glow_opacity > 0:
				var glow_col: Color = style.glow_color
				glow_col.a = style.glow_opacity
				for i: int in range(glow_steps):
					var current_padding: float = inner_padding + (i * glow_step_size)
					var inner_radius: float = 0.0
					if custom_glow_radius >= 0.0:
						inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
					else:
						inner_radius = max(0.0, corner_radius - current_padding)
					_create_style_box(glow_col, inner_radius)

func _update_source_reference() -> void:
	# Resolves the source TileMapLayer from exported NodePath.
	if source_layer_path and has_node(source_layer_path):
		var node: Node = get_node(source_layer_path)
		if node is TileMapLayer:
			if _source_layer and _source_layer.changed.is_connected(_on_source_changed):
				_source_layer.changed.disconnect(_on_source_changed)
			
			_source_layer = node
			
			if Engine.is_editor_hint():
				if not _source_layer.changed.is_connected(_on_source_changed):
					_source_layer.changed.connect(_on_source_changed)
			
			queue_redraw()

func _update_transition_reference() -> void:
	# Resolves the transition TileMapLayer from exported NodePath.
	if transition_layer_path and has_node(transition_layer_path):
		var node: Node = get_node(transition_layer_path)
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
	# Rebuilds the tile-to-style mapping from the custom_styles array.
	_style_lookup.clear()
	for tile_style: MazeTileStyle in custom_styles:
		if tile_style:
			var key: Vector3i = Vector3i(
				tile_style.source_id,
				tile_style.atlas_coords.x,
				tile_style.atlas_coords.y
			)
			_style_lookup[key] = tile_style

func _get_active_style(coords: Vector2i) -> MazeTileStyle:
	# Looks up the style for a specific cell based on source layer tile data.
	var source_id: int = _source_layer.get_cell_source_id(coords)
	var atlas_coords: Vector2i = _source_layer.get_cell_atlas_coords(coords)
	var key: Vector3i = Vector3i(source_id, atlas_coords.x, atlas_coords.y)
	
	if key in _style_lookup:
		return _style_lookup[key]
	
	# No match found -> Return null (don't draw)
	return null

func has_cell(coords: Vector2i) -> bool:
	# Returns true if the given cell has a matching style.
	if not _source_layer:
		return false
	return _get_active_style(coords) != null

func _draw() -> void:
	if not _source_layer:
		return
	
	var tile_set: TileSet = _source_layer.tile_set
	if not tile_set:
		return
	
	_rebuild_style_lookup()
	
	var tile_size: Vector2i = tile_set.tile_size
	
	# Determine set of all cells to draw (Union of Source and Transition)
	var all_cells: Dictionary[Vector2i, bool] = {}
	for coords: Vector2i in _source_layer.get_used_cells():
		all_cells[coords] = true
	
	if _transition_layer:
		for coords: Vector2i in _transition_layer.get_used_cells():
			all_cells[coords] = true
	
	# Process drawing
	for coords: Vector2i in all_cells.keys():
		# 1. Visibility / Scale Check (Wipe Logic)
		var wipe_scale: float = _get_reveal_scale(coords)
		if wipe_scale <= 0.001:
			continue
		
		# Transition Logic (Dissolve)
		# Deterministic hash based on coordinates for consistent per-tile noise
		var noise_hash: float = float(
			(coords.x * 73856093) ^ (coords.y * 19349663)
		) / 2147483647.0
		noise_hash = abs(noise_hash) # Ensure positive 0-1
		
		# Decide which layer provides the tile data
		var active_layer: TileMapLayer = _source_layer
		var scale_anim_mult: float = 1.0
		
		# transition_progress = 0.0 -> Show Transition (if exists)
		# transition_progress = 1.0 -> Show Source
		
		if _transition_layer:
			var dist: float = transition_progress - noise_hash
			
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
				if dist > 0:
					# Showing Source (Behind Wave)
					if dist < dissolve_anim_width:
						scale_anim_mult = smoothstep(0.0, 1.0, dist / dissolve_anim_width)
				else:
					# Showing Transition (Ahead of Wave)
					var abs_dist: float = abs(dist)
					if abs_dist < dissolve_anim_width:
						scale_anim_mult = smoothstep(0.0, 1.0, abs_dist / dissolve_anim_width)
		
		# Get style from the active layer
		var source_id: int = active_layer.get_cell_source_id(coords)
		var atlas_coords: Vector2i = active_layer.get_cell_atlas_coords(coords)
		var key: Vector3i = Vector3i(source_id, atlas_coords.x, atlas_coords.y)
		var style: MazeTileStyle = _style_lookup.get(key)
		
		if not style:
			continue
		
		# Geometry
		var cell_center: Vector2 = Vector2(coords * int(tile_size.x)) + (Vector2(tile_size) / 2.0)
		var full_size: Vector2 = Vector2(tile_size)
		# Available size accounts for shadow depth so Scale 1.0 fits without overlap
		var available_size: Vector2 = (full_size - depth_offset.abs()).max(Vector2.ZERO)
		var draw_size: Vector2 = available_size * button_scale * scale_anim_mult * wipe_scale
		
		# Draw
		var centering_offset: Vector2 = - depth_offset * 0.5
		var offset_pos: Vector2 = cell_center - (draw_size * 0.5) + centering_offset
		
		var face_rect: Rect2 = Rect2(offset_pos, draw_size)
		var back_rect: Rect2 = face_rect
		back_rect.position += depth_offset
		
		# Draw Extrusion
		_draw_extrusion(face_rect, back_rect, style.side_color)
		
		# Draw Face
		draw_style_box(_create_style_box(style.button_color, corner_radius), face_rect)
		
		# Draw Inner Glow
		if inner_padding > 0 and style.glow_opacity > 0:
			for i: int in range(glow_steps):
				var current_padding: float = inner_padding + (i * glow_step_size)
				var inner_rect: Rect2 = face_rect.grow(-current_padding)
				
				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					var inner_color: Color = style.glow_color
					inner_color.a = style.glow_opacity
					
					var inner_radius: float = 0.0
					if custom_glow_radius >= 0.0:
						inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
					else:
						inner_radius = max(0.0, corner_radius - current_padding)
					
					var sb_glow: StyleBoxFlat = _create_style_box(inner_color, inner_radius)
					draw_style_box(sb_glow, inner_rect)

func _draw_extrusion(front: Rect2, back: Rect2, color: Color) -> void:
	# Draws the 3D extrusion connecting front and back faces.
	# Uses 4 side strip quads + 4 corner "pills" (swept circles).
	var r: float = min(corner_radius, min(front.size.x, front.size.y) * 0.5)
	
	# Draw the Back Face (Base) first
	draw_style_box(_create_style_box(color, corner_radius), back)
	
	# Front Face Tangents (horizontal)
	var f_tl_h: Vector2 = Vector2(front.position.x + r, front.position.y)
	var f_tr_h: Vector2 = Vector2(front.end.x - r, front.position.y)
	var f_bl_h: Vector2 = Vector2(front.position.x + r, front.end.y)
	var f_br_h: Vector2 = Vector2(front.end.x - r, front.end.y)
	# Front Face Tangents (vertical)
	var f_tl_v: Vector2 = Vector2(front.position.x, front.position.y + r)
	var f_bl_v: Vector2 = Vector2(front.position.x, front.end.y - r)
	var f_tr_v: Vector2 = Vector2(front.end.x, front.position.y + r)
	var f_br_v: Vector2 = Vector2(front.end.x, front.end.y - r)
	
	# Back Face Tangents
	var b_tl_h: Vector2 = Vector2(back.position.x + r, back.position.y)
	var b_tr_h: Vector2 = Vector2(back.end.x - r, back.position.y)
	var b_bl_h: Vector2 = Vector2(back.position.x + r, back.end.y)
	var b_br_h: Vector2 = Vector2(back.end.x - r, back.end.y)
	var b_tl_v: Vector2 = Vector2(back.position.x, back.position.y + r)
	var b_bl_v: Vector2 = Vector2(back.position.x, back.end.y - r)
	var b_tr_v: Vector2 = Vector2(back.end.x, back.position.y + r)
	var b_br_v: Vector2 = Vector2(back.end.x, back.end.y - r)
	
	# Draw Corner Pills (thick line connecting front/back corner circle centres)
	var c_tl: Vector2 = Vector2(front.position.x + r, front.position.y + r)
	draw_line(c_tl, c_tl + depth_offset, color, r * 2.0)
	var c_tr: Vector2 = Vector2(front.end.x - r, front.position.y + r)
	draw_line(c_tr, c_tr + depth_offset, color, r * 2.0)
	var c_br: Vector2 = Vector2(front.end.x - r, front.end.y - r)
	draw_line(c_br, c_br + depth_offset, color, r * 2.0)
	var c_bl: Vector2 = Vector2(front.position.x + r, front.end.y - r)
	draw_line(c_bl, c_bl + depth_offset, color, r * 2.0)
	
	# Draw Side Strip Quads
	_draw_triangle_quad(f_tl_h, f_tr_h, b_tr_h, b_tl_h, color) # Top
	_draw_triangle_quad(f_br_h, f_bl_h, b_bl_h, b_br_h, color) # Bottom
	_draw_triangle_quad(f_bl_v, f_tl_v, b_tl_v, b_bl_v, color) # Left
	_draw_triangle_quad(f_tr_v, f_br_v, b_br_v, b_tr_v, color) # Right

func _draw_triangle_quad(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, color: Color) -> void:
	# Splits a quad into two triangles, skipping degenerate ones.
	_draw_safe_triangle(p1, p2, p3, color)
	_draw_safe_triangle(p1, p3, p4, color)

func _draw_safe_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	# Draws a single triangle with winding correction.
	var area: float = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
	
	# Force consistent winding (CCW)
	if area < 0:
		var temp: Vector2 = b
		b = c
		c = temp
		area = - area
	
	if area > 0.1: # Threshold to ignore degenerate/collinear triangles
		draw_polygon([a, b, c], [color])

func _create_style_box(color: Color, radius: float) -> StyleBoxFlat:
	# Caching wrapper for StyleBoxes to prevent excessive allocation.
	var key: Array = [color, radius]
	
	if _style_box_pool.has(key):
		return _style_box_pool[key]
	
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 4
	sb.anti_aliasing = true
	
	_style_box_pool[key] = sb
	return sb

func _get_reveal_scale(coords: Vector2i) -> float:
	# Returns 0.0 (Hidden) to 1.0 (Fully Visible) based on reveal_mode and reveal_ratio.
	if reveal_mode == RevealMode.LINEAR:
		if (float(coords.x) + 0.5) / float(grid_width) <= reveal_ratio:
			return 1.0
		return 0.0
	
	elif reveal_mode == RevealMode.CENTER_OUT:
		var dist: int = abs(coords.x - center_column)
		var max_dist: int = max(center_column, grid_width - center_column)
		
		# Normalised position of this tile (0.0 = centre, 1.0 = edge)
		var norm_pos: float = float(dist) / float(max_dist) if max_dist > 0 else 0.0
		
		# If width is effectively zero, hard cut
		if wipe_anim_width < 0.001:
			return 1.0 if norm_pos <= reveal_ratio else 0.0
		
		# Soft scaling via a sliding smoothstep window
		var leading_edge: float = reveal_ratio * (1.0 + wipe_anim_width)
		var trailing_edge: float = leading_edge - wipe_anim_width
		
		return 1.0 - smoothstep(trailing_edge, leading_edge, norm_pos)
	
	return 1.0
