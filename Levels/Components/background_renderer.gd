@tool
extends Node2D
class_name BackgroundRenderer

## Procedural renderer for grid background.
## Draws rounded, "floating" buttons on all grid spots.

@export_group("Grid")
@export var grid_width: int = 25
@export var grid_height: int = 16

@export_group("Visuals")
@export_range(0.0, 1.0) var noise_strength: float = 0.05:
	set(value):
		noise_strength = value
		_update_shader_params()

@export_range(0.0, 1.0) var gradient_strength: float = 0.1:
	set(value):
		gradient_strength = value
		_update_shader_params()

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

@export var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

var _pressed_states: Dictionary = {} # Coords(Vector2i) -> PressRatio(float 0.0 to 1.0)
var _active_tweens: Dictionary = {} # Coords(Vector2i) -> Tween
var _current_pressed_pad: Vector2i = Vector2i(-1, -1)

var _pad_colors: Dictionary = {} # Coords(Vector2i) -> Color
var _color_timers: Dictionary = {} # Coords(Vector2i) -> Tween (Timer)
var _hidden_cells: Dictionary = {} # Coords(Vector2i) -> bool
var _cell_scales: Dictionary = {} # Coords(Vector2i) -> float (Scale multiplier)
var _style_box_pool: Dictionary = {} # Key: {color, radius} -> StyleBoxFlat

func _ready() -> void:
	if _pressed_states == null:
		_pressed_states = {}
	if _pad_colors == null:
		_pad_colors = {}
	if _hidden_cells == null:
		_hidden_cells = {}
	if _cell_scales == null:
		_cell_scales = {}
	
	_preload_style_boxes()
	_setup_material()
	queue_redraw()

func _preload_style_boxes() -> void:
	# Pre-populate pool with known/common styles
	_style_box_pool.clear()
	
	# Cache main/side colors
	_create_style_box(button_color, corner_radius)
	_create_style_box(side_color, corner_radius)
	
	# Cache default glows
	if inner_padding > 0 and glow_opacity > 0:
		var c = glow_color
		c.a = glow_opacity
		for i in range(glow_steps):
			var current_padding = inner_padding + (i * glow_step_size)
			var inner_radius = 0.0
			if custom_glow_radius >= 0.0:
				inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
			else:
				inner_radius = max(0.0, corner_radius - current_padding)
			_create_style_box(c, inner_radius)

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

func set_cell_hidden(coords: Vector2i, is_hidden: bool) -> void:
	if _hidden_cells == null: _hidden_cells = {}
	
	if is_hidden:
		_hidden_cells[coords] = true
	else:
		_hidden_cells.erase(coords)
		# Also reset scale if unhiding
		if _cell_scales.has(coords):
			_cell_scales.erase(coords)
			
	queue_redraw()

func animate_hide_cell(coords: Vector2i, duration: float = 0.5) -> void:
	if _cell_scales == null: _cell_scales = {}
	
	# If already hidden, ignore
	if _hidden_cells.has(coords):
		return
		
	if duration <= 0.001:
		set_cell_hidden(coords, true)
		return
		
	# Create a tween to shrink the cell
	var tween = create_tween()
	# Changed to Cubic Out for smoother, more visible shrinking (responsive to duration)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Start from current scale or 1.0
	var start_scale = _cell_scales.get(coords, 1.0)
	
	tween.tween_method(
		func(val):
			if _cell_scales == null: _cell_scales = {}
			_cell_scales[coords] = val
			queue_redraw(),
		start_scale,
		0.0,
		duration
	)
	
	# Cleanup after shrink
	tween.finished.connect(func():
		set_cell_hidden(coords, true)
		# Clean up the scale entry since it's hidden now
		if _cell_scales.has(coords):
			_cell_scales.erase(coords)
	)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
		
	if not enabled:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Manual global to map conversion (Tile Size = 64x64)
		var local_pos = to_local(get_global_mouse_position())
		var tile_size = Vector2(64, 64)
		var grid_x = floor(local_pos.x / tile_size.x)
		var grid_y = floor(local_pos.y / tile_size.y)
		var coords = Vector2i(grid_x, grid_y)
		
		# Check if hidden
		if _hidden_cells.has(coords):
			return
		
		# Check bounds
		if coords.x >= 0 and coords.x < grid_width and coords.y >= 0 and coords.y < grid_height:
			if event.pressed:
				_animate_pad(coords, 1.0)
				_randomize_pad_color(coords)
				_current_pressed_pad = coords
				
		# Handle Release (Global or specific)
		if not event.pressed:
			# If we have a currently held pad, release it regardless of where the mouse is now
			if _current_pressed_pad != Vector2i(-1, -1):
				_animate_pad(_current_pressed_pad, 0.0)
				_start_color_reset_timer(_current_pressed_pad)
				_current_pressed_pad = Vector2i(-1, -1)

func _randomize_pad_color(coords: Vector2i) -> void:
	if _pad_colors == null: _pad_colors = {}
	
	# Kill existing reset timer if any
	if _color_timers.has(coords):
		var timer = _color_timers[coords]
		if timer and timer.is_valid():
			timer.kill()
		_color_timers.erase(coords)
	
	# Generate random vibrant color (HSV)
	var hue = randf()
	# Constrain Saturation (0.5 to 0.8) to prevent "neon" look
	var sat = randf_range(0.5, 0.8)
	# Constrain Value (0.6 to 0.9) to prevent being too dark or too bright/washed out
	var val = randf_range(0.6, 0.9)
	var new_color = Color.from_hsv(hue, sat, val)
	
	_pad_colors[coords] = new_color
	queue_redraw()

func _start_color_reset_timer(coords: Vector2i) -> void:
	# Create a tween to act as a timer
	var tween = create_tween()
	_color_timers[coords] = tween
	
	tween.tween_interval(3.0)
	tween.tween_callback(func():
		if _pad_colors.has(coords):
			_pad_colors.erase(coords)
		if _color_timers.has(coords):
			_color_timers.erase(coords)
		queue_redraw()
	)

func _animate_pad(coords: Vector2i, target_value: float) -> void:
	if _pressed_states == null:
		_pressed_states = {}
		
	# Kill existing tween for this pad if it exists
	if _active_tweens.has(coords):
		var existing_tween = _active_tweens[coords]
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
		
	var tween = create_tween()
	_active_tweens[coords] = tween # Store reference
	
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	if target_value == 0.0:
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.set_ease(Tween.EASE_OUT)
	
	var start_val = _pressed_states.get(coords, 0.0)
	
	tween.tween_method(
		func(val):
			if _pressed_states == null: _pressed_states = {}
			_pressed_states[coords] = val
			queue_redraw(),
		start_val,
		target_value,
		0.1 if target_value > 0.5 else 0.3
	)
	
	# Cleanup when done
	tween.finished.connect(func():
		if _active_tweens.has(coords) and _active_tweens[coords] == tween:
			_active_tweens.erase(coords)
	)

func _draw() -> void:
	if not enabled:
		return

	# Use local safety variables to prevent threaded/tool script access issues
	var pressed_safe = _pressed_states
	if pressed_safe == null:
		pressed_safe = {}
		_pressed_states = pressed_safe
		
	var colors_safe = _pad_colors
	if colors_safe == null:
		colors_safe = {}
		_pad_colors = colors_safe
		
	var hidden_safe = _hidden_cells
	if hidden_safe == null:
		hidden_safe = {}
		_hidden_cells = hidden_safe

	var scales_safe = _cell_scales
	if scales_safe == null:
		scales_safe = {}
		_cell_scales = scales_safe

	# 1. Tile Size Fixed
	var tile_size = Vector2i(64, 64)
	
	# Setup material in Editor/Runtime if missing
	if not material:
		_setup_material()
	
	# 2. Pre-create StyleBoxes to avoid allocation spam
	var sb_face = _create_style_box(button_color, corner_radius)
	var sb_side = _create_style_box(side_color, corner_radius)
	var sb_glows: Array[StyleBoxFlat] = []
	
	if inner_padding > 0 and glow_opacity > 0:
		for i in range(glow_steps):
			var current_padding = inner_padding + (i * glow_step_size)
			# Calculate radius
			var inner_radius = 0.0
			if custom_glow_radius >= 0.0:
				inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
			else:
				inner_radius = max(0.0, corner_radius - current_padding)
			
			var c = glow_color
			c.a = glow_opacity
			
			var sb = _create_style_box(c, inner_radius)
			sb_glows.append(sb)

	# 3. Iterate all grid cells
	for x in range(grid_width):
		for y in range(grid_height):
			var coords = Vector2i(x, y)
			
			# Hidden Check
			if hidden_safe.has(coords):
				continue
			
			# Determine Colors for this pad
			var current_face_sb = sb_face
			var current_side_sb = sb_side
			var current_side_color = side_color
			var current_glow_sbs = sb_glows
			
			if colors_safe.has(coords):
				var base_col = colors_safe[coords]
				current_face_sb = _create_style_box(base_col, corner_radius)
				
				var darkened_col = base_col.darkened(0.65)
				current_side_color = darkened_col
				current_side_sb = _create_style_box(darkened_col, corner_radius)
				
				# Generate custom glow stack
				current_glow_sbs = []
				var lightened_col = base_col.lightened(0.5)
				lightened_col.a = glow_opacity # Keep transparency
				
				if inner_padding > 0 and glow_opacity > 0:
					for i in range(glow_steps):
						var current_padding = inner_padding + (i * glow_step_size)
						var inner_radius = 0.0
						if custom_glow_radius >= 0.0:
							inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
						else:
							inner_radius = max(0.0, corner_radius - current_padding)
						
						var sb = _create_style_box(lightened_col, inner_radius)
						current_glow_sbs.append(sb)

			# Calculate geometry
			# Explicitly use Vector2 for calculation to avoid integer division warning
			var cell_center = Vector2(coords * tile_size) + (Vector2(tile_size) / 2.0)
			
			var full_size = Vector2(tile_size)
			# Calculate available size (Cell - Shadow Depth) to ensure Scale 1.0 fits perfectly without overlap (Matching MazeRenderer)
			var available_size = (full_size - depth_offset.abs()).max(Vector2.ZERO)
			
			# Apply per-cell scale animation
			var cell_scale_mult = scales_safe.get(coords, 1.0)
			var draw_size = available_size * button_scale * cell_scale_mult
			
			# Animation Logic
			var press_ratio = pressed_safe.get(coords, 0.0)
			var current_depth_offset = depth_offset * (1.0 - press_ratio)
			
			var resting_pos = cell_center - (draw_size * 0.5) + (-depth_offset * 0.5)
			var pressed_pos = cell_center - (draw_size * 0.5)
			var offset_pos = resting_pos.lerp(pressed_pos, press_ratio)
			
			var face_rect = Rect2(offset_pos, draw_size)
			var back_rect = face_rect
			back_rect.position += current_depth_offset
			
			# Draw Extrusion (Manual implementation using pre-cached side stylebox)
			if current_depth_offset.length_squared() > 0.1:
				_draw_extrusion_optimized(face_rect, back_rect, current_side_color, current_side_sb, current_depth_offset)
			
			# Draw Face
			draw_style_box(current_face_sb, face_rect)
			
			# Draw Inner Glows
			for i in range(current_glow_sbs.size()):
				var current_padding = inner_padding + (i * glow_step_size)
				var inner_rect = face_rect.grow(-current_padding)
				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					draw_style_box(current_glow_sbs[i], inner_rect)

func _draw_extrusion_optimized(front: Rect2, back: Rect2, color: Color, sb_back: StyleBoxFlat, effective_depth: Vector2) -> void:
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
	draw_line(c_tl, c_tl + effective_depth, color, r * 2.0)
	var c_tr = Vector2(front.end.x - r, front.position.y + r)
	draw_line(c_tr, c_tr + effective_depth, color, r * 2.0)
	var c_br = Vector2(front.end.x - r, front.end.y - r)
	draw_line(c_br, c_br + effective_depth, color, r * 2.0)
	var c_bl = Vector2(front.position.x + r, front.end.y - r)
	draw_line(c_bl, c_bl + effective_depth, color, r * 2.0)
	
	# Draw Side Quads
	_draw_triangle_quad(f_tl_h, f_tr_h, b_tr_h, b_tl_h, color)
	_draw_triangle_quad(f_br_h, f_bl_h, b_bl_h, b_br_h, color)
	_draw_triangle_quad(f_bl_v, f_tl_v, b_tl_v, b_bl_v, color)
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
