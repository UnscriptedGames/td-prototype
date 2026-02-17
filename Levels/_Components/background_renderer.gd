@tool
extends Node2D
class_name BackgroundRenderer

## Procedural renderer for grid background.
## 
## Draws rounded, "floating" buttons on all grid spots.
## Handles visuals for press animations, color randomization, and glowing effects.

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

var _pressed_states: Dictionary[Vector2i, float] = {} # Coords(Vector2i) -> PressRatio(float 0.0 to 1.0)
var _active_tweens: Dictionary[Vector2i, Tween] = {} # Coords(Vector2i) -> Tween
var _current_pressed_pad: Vector2i = Vector2i(-1, -1)

var _pad_colors: Dictionary[Vector2i, Color] = {} # Coords(Vector2i) -> Color
var _color_timers: Dictionary[Vector2i, Tween] = {} # Coords(Vector2i) -> Tween (Timer)
var _hidden_cells: Dictionary[Vector2i, bool] = {} # Coords(Vector2i) -> bool
var _cell_scales: Dictionary[Vector2i, float] = {} # Coords(Vector2i) -> float (Scale multiplier)
var _style_box_pool: Dictionary[Array, StyleBoxFlat] = {} # Key: {color, radius} -> StyleBoxFlat

func _ready() -> void:
	_preload_style_boxes()
	_setup_material()
	queue_redraw()

func _preload_style_boxes() -> void:
	# Pre-populate pool with known/common styles to prevent stutter.
	_style_box_pool.clear()
	
	# Cache main/side colors
	_create_style_box(button_color, corner_radius)
	_create_style_box(side_color, corner_radius)
	
	# Cache default glows
	if inner_padding > 0 and glow_opacity > 0:
		var glow_col: Color = glow_color
		glow_col.a = glow_opacity
		for i: int in range(glow_steps):
			var current_padding: float = inner_padding + (i * glow_step_size)
			var inner_radius: float = 0.0
			if custom_glow_radius >= 0.0:
				inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
			else:
				inner_radius = max(0.0, corner_radius - current_padding)
			_create_style_box(glow_col, inner_radius)

func _setup_material() -> void:
	# Loads and applies the matte surface shader.
	var shader: Shader = load("res://Levels/_Components/matte_surface.gdshader")
	if shader:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		self.material = mat
		_update_shader_params()

func _update_shader_params() -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("noise_strength", noise_strength)
		material.set_shader_parameter("gradient_strength", gradient_strength)
		queue_redraw()

func set_cell_hidden(coords: Vector2i, is_hidden: bool) -> void:
	# Controls the visibility of a specific grid cell.
	if is_hidden:
		_hidden_cells[coords] = true
	else:
		_hidden_cells.erase(coords)
		# Also reset scale if unhiding
		if _cell_scales.has(coords):
			_cell_scales.erase(coords)
			
	queue_redraw()

func animate_hide_cell(coords: Vector2i, duration: float = 0.5) -> void:
	# Animates a cell shrinking to zero scale before hiding it.
	# If already hidden, ignore
	if _hidden_cells.has(coords):
		return
		
	if duration <= 0.001:
		set_cell_hidden(coords, true)
		return
		
	# Create a tween to shrink the cell
	var tween: Tween = create_tween()
	# Cubic Out for smoother, more visible shrinking
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Start from current scale or 1.0
	var start_scale: float = _cell_scales.get(coords, 1.0)
	
	tween.tween_method(
		func(val: float) -> void:
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
		# Manual global-to-map conversion (Tile Size = 64x64)
		var local_pos: Vector2 = to_local(get_global_mouse_position())
		var tile_size: Vector2 = Vector2(64, 64)
		var grid_x: int = int(floor(local_pos.x / tile_size.x))
		var grid_y: int = int(floor(local_pos.y / tile_size.y))
		var coords: Vector2i = Vector2i(grid_x, grid_y)
		
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
	# Assigns a random vibrant HSV color to a pad.
	# Kill existing reset timer if any
	if _color_timers.has(coords):
		var timer: Tween = _color_timers[coords]
		if timer and timer.is_valid():
			timer.kill()
		_color_timers.erase(coords)
	
	# Generate random vibrant colour (HSV)
	var hue: float = randf()
	# Constrain Saturation (0.5 to 0.8) to prevent "neon" look
	var saturation: float = randf_range(0.5, 0.8)
	# Constrain Value (0.6 to 0.9) to prevent being too dark or too bright/washed out
	var brightness: float = randf_range(0.6, 0.9)
	var new_color: Color = Color.from_hsv(hue, saturation, brightness)
	
	_pad_colors[coords] = new_color
	queue_redraw()

func _start_color_reset_timer(coords: Vector2i) -> void:
	# Schedules a colour reset after a delay using a tween-based timer.
	var tween: Tween = create_tween()
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
	# Tweens the press ratio of a pad (0.0 = resting, 1.0 = fully pressed).
	# Kill existing tween for this pad if it exists
	if _active_tweens.has(coords):
		var existing_tween: Tween = _active_tweens[coords]
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
	
	var tween: Tween = create_tween()
	_active_tweens[coords] = tween
	
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Use elastic ease for the release bounce
	if target_value == 0.0:
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.set_ease(Tween.EASE_OUT)
	
	var start_val: float = _pressed_states.get(coords, 0.0)
	
	tween.tween_method(
		func(val: float) -> void:
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
		
	# 1. Tile Size Fixed
	var tile_size: Vector2i = Vector2i(64, 64)
	
	# Setup material in Editor/Runtime if missing
	if not material:
		_setup_material()
	
	# 2. Pre-create StyleBoxes to avoid allocation spam
	var sb_face: StyleBoxFlat = _create_style_box(button_color, corner_radius)
	var sb_side: StyleBoxFlat = _create_style_box(side_color, corner_radius)
	var sb_glows: Array[StyleBoxFlat] = []
	
	if inner_padding > 0 and glow_opacity > 0:
		for i: int in range(glow_steps):
			var current_padding: float = inner_padding + (i * glow_step_size)
			var inner_radius: float = 0.0
			if custom_glow_radius >= 0.0:
				inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
			else:
				inner_radius = max(0.0, corner_radius - current_padding)
			
			var glow_col: Color = glow_color
			glow_col.a = glow_opacity
			
			var sb: StyleBoxFlat = _create_style_box(glow_col, inner_radius)
			sb_glows.append(sb)

	# 3. Iterate all grid cells
	for x: int in range(grid_width):
		for y: int in range(grid_height):
			var coords: Vector2i = Vector2i(x, y)
			
			# Hidden Check
			if _hidden_cells.has(coords):
				continue
			
			# Determine Colors for this pad
			var current_face_sb: StyleBoxFlat = sb_face
			var current_side_sb: StyleBoxFlat = sb_side
			var current_side_color: Color = side_color
			var current_glow_sbs: Array[StyleBoxFlat] = sb_glows
			
			if _pad_colors.has(coords):
				var base_col: Color = _pad_colors[coords]
				current_face_sb = _create_style_box(base_col, corner_radius)
				
				var darkened_col: Color = base_col.darkened(0.65)
				current_side_color = darkened_col
				current_side_sb = _create_style_box(darkened_col, corner_radius)
				
				# Generate custom glow stack for coloured pad
				current_glow_sbs = []
				var lightened_col: Color = base_col.lightened(0.5)
				lightened_col.a = glow_opacity
				
				if inner_padding > 0 and glow_opacity > 0:
					for i: int in range(glow_steps):
						var current_padding: float = inner_padding + (i * glow_step_size)
						var inner_radius: float = 0.0
						if custom_glow_radius >= 0.0:
							inner_radius = max(0.0, custom_glow_radius - (i * glow_step_size))
						else:
							inner_radius = max(0.0, corner_radius - current_padding)
						
						var sb: StyleBoxFlat = _create_style_box(lightened_col, inner_radius)
						current_glow_sbs.append(sb)

			# Calculate geometry
			var cell_center: Vector2 = Vector2(coords * tile_size) + (Vector2(tile_size) / 2.0)
			
			var full_size: Vector2 = Vector2(tile_size)
			# Available size accounts for shadow depth so Scale 1.0 fits without overlap
			var available_size: Vector2 = (full_size - depth_offset.abs()).max(Vector2.ZERO)
			
			# Apply per-cell scale animation
			var cell_scale_mult: float = _cell_scales.get(coords, 1.0)
			var draw_size: Vector2 = available_size * button_scale * cell_scale_mult
			
			# Animation Logic
			var press_ratio: float = _pressed_states.get(coords, 0.0)
			var current_depth_offset: Vector2 = depth_offset * (1.0 - press_ratio)
			
			var resting_pos: Vector2 = cell_center - (draw_size * 0.5) + (-depth_offset * 0.5)
			var pressed_pos: Vector2 = cell_center - (draw_size * 0.5)
			var offset_pos: Vector2 = resting_pos.lerp(pressed_pos, press_ratio)
			
			var face_rect: Rect2 = Rect2(offset_pos, draw_size)
			var back_rect: Rect2 = face_rect
			back_rect.position += current_depth_offset
			
			# Draw Extrusion (Manual implementation using pre-cached side stylebox)
			if current_depth_offset.length_squared() > 0.1:
				_draw_extrusion_optimized(face_rect, back_rect, current_side_color, current_side_sb, current_depth_offset)
			
			# Draw Face
			draw_style_box(current_face_sb, face_rect)
			
			# Draw Inner Glows
			for i: int in range(current_glow_sbs.size()):
				var current_padding: float = inner_padding + (i * glow_step_size)
				var inner_rect: Rect2 = face_rect.grow(-current_padding)
				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					draw_style_box(current_glow_sbs[i], inner_rect)

func _draw_extrusion_optimized(front: Rect2, back: Rect2, color: Color, sb_back: StyleBoxFlat, effective_depth: Vector2) -> void:
	# Draws the 3D extrusion connecting the front face to the back face.
	# Uses a "pill" technique for corners and quads for sides to ensure a watertight mesh.
	var r: float = min(corner_radius, min(front.size.x, front.size.y) * 0.5)
	
	# Draw Back Face
	draw_style_box(sb_back, back)
	
	# Calculate Tangents
	# These points represent the start/end of the straight edges on the rounded rectangle.
	
	# Front Face Tangents
	var f_tl_h: Vector2 = Vector2(front.position.x + r, front.position.y)
	var f_tr_h: Vector2 = Vector2(front.end.x - r, front.position.y)
	var f_bl_h: Vector2 = Vector2(front.position.x + r, front.end.y)
	var f_br_h: Vector2 = Vector2(front.end.x - r, front.end.y)
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
	
	# Draw Corner Pills
	# Connects the rounded corners of front and back faces with a thick line.
	var c_tl: Vector2 = Vector2(front.position.x + r, front.position.y + r)
	draw_line(c_tl, c_tl + effective_depth, color, r * 2.0)
	var c_tr: Vector2 = Vector2(front.end.x - r, front.position.y + r)
	draw_line(c_tr, c_tr + effective_depth, color, r * 2.0)
	var c_br: Vector2 = Vector2(front.end.x - r, front.end.y - r)
	draw_line(c_br, c_br + effective_depth, color, r * 2.0)
	var c_bl: Vector2 = Vector2(front.position.x + r, front.end.y - r)
	draw_line(c_bl, c_bl + effective_depth, color, r * 2.0)
	
	# Draw Side Quads
	# Connects the straight edges between front and back.
	_draw_triangle_quad(f_tl_h, f_tr_h, b_tr_h, b_tl_h, color)
	_draw_triangle_quad(f_br_h, f_bl_h, b_bl_h, b_br_h, color)
	_draw_triangle_quad(f_bl_v, f_tl_v, b_tl_v, b_bl_v, color)
	_draw_triangle_quad(f_tr_v, f_br_v, b_br_v, b_tr_v, color)

func _draw_triangle_quad(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, color: Color) -> void:
	# Splits Quad (P1, P2, P3, P4) into two triangles: (P1, P2, P3) and (P1, P3, P4).
	# Safely skips degenerate triangles (zero area) to avoid triangulation errors.
	if p1 == p2 or p1 == p3 or p2 == p3:
		# Degenerate first triangle
		pass
	else:
		_draw_safe_triangle(p1, p2, p3, color)
		
	if p1 == p3 or p1 == p4 or p3 == p4:
		# Degenerate second triangle
		pass
	else:
		_draw_safe_triangle(p1, p3, p4, color)

func _draw_safe_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	# Draws a single triangle with winding checks.
	# Calculate signed area 
	# Area = 0.5 * |(xB*yA - xA*yB) + (xC*yB - xB*yC) + (xA*yC - xC*yA)|
	var area: float = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
	
	# Force consistent winding (CCW) to prevent potential backface culling
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
		
	# Create new
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 4
	sb.anti_aliasing = true
	
	# Cache
	_style_box_pool[key] = sb
	return sb
