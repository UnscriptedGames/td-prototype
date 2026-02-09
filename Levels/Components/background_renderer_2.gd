@tool
extends Node2D
class_name BackgroundRenderer2

## Connected Islands background renderer (Polygon Version).
## Merges designated tiles from MazeLayer into solid, rounded polygons.

# -- Configuration --
@export var button_color: Color = Color("2c2c35"): # Neumorphic Dark
	set(value):
		button_color = value
		queue_redraw()

@export var side_color: Color = Color("22232a"): # Neumorphic Darker Side
	set(value):
		side_color = value
		queue_redraw()

@export var depth_offset: Vector2 = Vector2(0, 10):
	set(value):
		depth_offset = value
		queue_redraw()

@export var corner_radius: float = 6.0:
	set(value):
		corner_radius = value
		queue_redraw()

@export var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()
		
@export var island_tile_id: int = 1:
	set(value):
		island_tile_id = value
		queue_redraw()

@export_range(0.0, 1.0) var maze_intrusion_factor: float = 0.75:
	set(value):
		maze_intrusion_factor = value
		queue_redraw()

@export var shadow_pullback: float = 4.0:
	set(value):
		shadow_pullback = value
		queue_redraw()

@export_group("Shader Settings")
@export_range(0.0, 1.0) var noise_strength: float = 0.05:
	set(value):
		noise_strength = value
		_update_shader_params()

@export_range(0.0, 1.0) var gradient_strength: float = 0.1:
	set(value):
		gradient_strength = value
		_update_shader_params()

# -- References --
@export var floor_layer: TileMapLayer # (Maintained for compatibility, but not strictly used if pulling from Maze)

# -- Auto-wired by TemplateLevel if not set --
@export var maze_renderer: MazeRenderer

# -- State --
var _face_polygons: Array[PackedVector2Array] = []
var _shadow_polygons: Array[PackedVector2Array] = []

func _ready() -> void:
	# z_index = -1 # REMOVED: Allow Inspector control
	if not maze_renderer:
		maze_renderer = find_child("MazeRenderer", true, false)
		
	_setup_material()
		
	# Initial draw
	queue_redraw()

func _setup_material() -> void:
	# Load Matte Shader
	var shader = load("res://Levels/Components/matte_surface.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		self.material = mat
		_update_shader_params()

func _update_shader_params() -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("noise_strength", noise_strength)
		material.set_shader_parameter("gradient_strength", gradient_strength)
		queue_redraw()

func _input(_event: InputEvent) -> void:
	pass

func _draw() -> void:
	if not enabled or not maze_renderer:
		return
	
	_generate_polygons()
	
	# Draw Shadows (Bottom Layer)
	for poly in _shadow_polygons:
		draw_colored_polygon(poly, side_color)
		
	# Draw Extrusion (Side Walls)
	# We connect the perimeter of Face to Shadow.
	for poly in _face_polygons:
		_draw_extrusion(poly)
		
	# Draw Faces (Top Layer)
	for poly in _face_polygons:
		draw_colored_polygon(poly, button_color)

func _generate_polygons() -> void:
	_face_polygons.clear()
	_shadow_polygons.clear()
	
	var layer = maze_renderer.get_node_or_null(maze_renderer.source_layer_path) as TileMapLayer
	if not layer:
		return
		
	var used_cells = layer.get_used_cells()
	var raw_shadow_polys: Array[PackedVector2Array] = []
	var raw_face_polys: Array[PackedVector2Array] = []
	
	# Identify valid island cells
	var island_set = {}
	for coords in used_cells:
		if layer.get_cell_source_id(coords) == island_tile_id:
			island_set[coords] = true
			
	if island_set.is_empty():
		return

	var tile_size_v = Vector2(layer.tile_set.tile_size if layer.tile_set else Vector2i(64, 64))
	
	for coords in island_set.keys():
		var pos = Vector2(coords) * tile_size_v
		
		var right = coords + Vector2i(1, 0)
		var bottom = coords + Vector2i(0, 1)
		var left = coords + Vector2i(-1, 0)
		var top = coords + Vector2i(0, -1)
		var bottom_right = coords + Vector2i(1, 1)
		
		var has_right = island_set.has(right)
		var has_bottom = island_set.has(bottom)
		var has_br = island_set.has(bottom_right)
		var has_left = island_set.has(left)
		var has_top = island_set.has(top)
		
		# -- Calculate Geometry Modifiers --
		
		# 1. Intrusion (West/North) -> Expands the Island INTO the wall.
		var intrusion_w = 0.0
		var intrusion_n = 0.0
		
		if not has_left:
			# West Wall: Extend Left
			intrusion_w = depth_offset.x * maze_intrusion_factor
			
		if not has_top:
			# North Wall: Extend Up
			intrusion_n = depth_offset.y * maze_intrusion_factor
			
		# 2. Shadow Pullback (East/South) -> Shrinks the Shadow Base FROM the neighbor.
		var pullback_e = 0.0
		var pullback_s = 0.0
		
		if not has_right:
			pullback_e = shadow_pullback
			
		if not has_bottom:
			pullback_s = shadow_pullback
			
		# -- Shadow Rect (Base) --
		# Start with full tile
		var s_rect = Rect2(pos, tile_size_v)
		
		# Apply Intrusion (Expansion)
		s_rect.position.x -= intrusion_w
		s_rect.position.y -= intrusion_n
		s_rect.size.x += intrusion_w
		s_rect.size.y += intrusion_n
		
		# Apply Pullback (Contraction on East/South)
		# Only affects the "Max" side.
		s_rect.size.x -= pullback_e
		s_rect.size.y -= pullback_s
		
		raw_shadow_polys.append(_rect_to_poly(s_rect))
		
		# -- Face Rect (Top) --
		# Start with full tile
		# Apply Intrusion (Expansion) SAME as Shadow (Top extends too!)
		var f_pos = pos
		var f_size = tile_size_v
		
		f_pos.x -= intrusion_w
		f_pos.y -= intrusion_n
		f_size.x += intrusion_w
		f_size.y += intrusion_n
		
		# Apply Insets (Standard "Cliff" Logic)
		# If !has_right, Top is Inset by full depth_offset.
		var face_pts = PackedVector2Array([
			f_pos, # TL
			f_pos + Vector2(f_size.x, 0), # TR
			f_pos + f_size, # BR
			f_pos + Vector2(0, f_size.y) # BL
		])
		
		# Apply Insets manually to points (easier than rect math)
		if not has_right and not has_bottom:
			# Verified Isolated/Corner
			face_pts[1].x -= depth_offset.x
			face_pts[2].x -= depth_offset.x
			face_pts[2].y -= depth_offset.y
			face_pts[3].y -= depth_offset.y
			
		elif not has_right:
			# Right Edge
			face_pts[1].x -= depth_offset.x
			face_pts[2].x -= depth_offset.x
			
		elif not has_bottom:
			# Bottom Edge
			face_pts[2].y -= depth_offset.y
			face_pts[3].y -= depth_offset.y
			
		elif has_right and has_bottom and not has_br:
			# Outer Corner (Chamfer)
			# Rebuild chamfer polygon based on expanded size
			face_pts = PackedVector2Array([
				f_pos, # TL
				f_pos + Vector2(f_size.x, 0), # TR
				f_pos + Vector2(f_size.x, f_size.y - depth_offset.y), # BR_Inset_Y
				f_pos + Vector2(f_size.x - depth_offset.x, f_size.y), # BR_Inset_X
				f_pos + Vector2(0, f_size.y) # BL
			])
			
		raw_face_polys.append(face_pts)
		
	# -- Process Polygons (Merge -> Round) --
	_shadow_polygons = _process_raw_polys(raw_shadow_polys)
	_face_polygons = _process_raw_polys(raw_face_polys)

func _process_raw_polys(raw_list: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# 1. Merge all raw rects into unified shapes
	if raw_list.is_empty(): return []
	
	var merged_shapes: Array[PackedVector2Array] = []
	
	# Current Set starts with first polygon
	if not raw_list.is_empty():
		merged_shapes.append(raw_list[0])
		
	for i in range(1, raw_list.size()):
		var next_poly = raw_list[i]
		
		# Robust Approach:
		merged_shapes.append(next_poly)
		merged_shapes = _merge_overlapping_shapes(merged_shapes)

	# 2. Rounding (Grow -> Shrink -> Grow)
	var final_shapes: Array[PackedVector2Array] = []
	
	for shape in merged_shapes:
		if shape.size() < 3: continue
		
		# Step 1: Grow (+R)
		var s1 = Geometry2D.offset_polygon(shape, corner_radius, Geometry2D.JOIN_ROUND)
		
		for p1 in s1:
			# Step 2: Shrink (-2R)
			var s2 = Geometry2D.offset_polygon(p1, -2.0 * corner_radius, Geometry2D.JOIN_ROUND)
			
			for p2 in s2:
				# Step 3: Grow (+R)
				var s3 = Geometry2D.offset_polygon(p2, corner_radius, Geometry2D.JOIN_ROUND)
				final_shapes.append_array(s3)
			
	return final_shapes

func _process_patch_polys(raw_list: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Specialized process for Patches (which can be thin strips).
	if raw_list.is_empty(): return []
	
	var merged_shapes: Array[PackedVector2Array] = []
	if not raw_list.is_empty():
		merged_shapes.append(raw_list[0])
		
	for i in range(1, raw_list.size()):
		var next_poly = raw_list[i]
		merged_shapes.append(next_poly)
		merged_shapes = _merge_overlapping_shapes(merged_shapes)
		
	var final_shapes: Array[PackedVector2Array] = []
	
	for shape in merged_shapes:
		if shape.size() < 3: continue
		
		# Attempt "Butler Method" (Grow -> Shrink -> Grow) first.
		var s1 = Geometry2D.offset_polygon(shape, corner_radius, Geometry2D.JOIN_ROUND)
		var s2_step: Array[PackedVector2Array] = []
		
		for p1 in s1:
			var shr = Geometry2D.offset_polygon(p1, -2.0 * corner_radius, Geometry2D.JOIN_ROUND)
			s2_step.append_array(shr)
			
		if not s2_step.is_empty():
			# Success! It survived the shrink. Grow back.
			for p2 in s2_step:
				var s3 = Geometry2D.offset_polygon(p2, corner_radius, Geometry2D.JOIN_ROUND)
				final_shapes.append_array(s3)
		else:
			# Isolate thin parts? No, just round Convex Corners if possible.
			# Fallback: simple rounding (Grow -> Shrink).
			var simple_round = Geometry2D.offset_polygon(shape, corner_radius, Geometry2D.JOIN_ROUND)
			for p_simple in simple_round:
				var shrunk_back = Geometry2D.offset_polygon(p_simple, -corner_radius, Geometry2D.JOIN_ROUND)
				final_shapes.append_array(shrunk_back)
				
	return final_shapes

func _merge_overlapping_shapes(shapes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Brute force reduce: find any 2 that merge.
	# If merge found, restart/continue.
	# Repeat until no merges occur.
	var dirty = true
	while dirty:
		dirty = false
		var i = 0
		while i < shapes.size():
			var j = i + 1
			while j < shapes.size():
				var result = Geometry2D.merge_polygons(shapes[i], shapes[j])
				if result.size() == 1: # Successfully merged into one
					shapes[i] = result[0]
					shapes.remove_at(j)
					dirty = true
					# We modified list at i, stay at i (check new shape against rest)
					# But we removed j, so j is now next element.
					# Actually, 'shapes[i]' changed, we should re-check against ALL?
					# Or just continue.
					# dirty=true will trigger outer loop restart.
				else:
					j += 1
			i += 1
	return shapes

func _rect_to_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])

func _draw_extrusion(_face_poly: PackedVector2Array) -> void:
	# Not needed if Shadow Polygon covers the base.
	pass
