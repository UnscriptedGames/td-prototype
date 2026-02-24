@tool
extends Node2D
class_name BackgroundRenderer

## Procedural renderer for grid background.
## 
## Draws rounded, "floating" buttons on all grid spots.
## Handles visuals for press animations, color randomization, and glowing effects.

@export_group("Grid")
@export var grid_width: int = 48
@export var grid_height: int = 30
@export var tile_size: Vector2 = Vector2(32, 32):
	set(value):
		tile_size = value
		queue_redraw()

@export_group("Visuals")
@export_range(0.0, 1.0) var noise_strength: float = 0.05:
	set(value):
		noise_strength = value
		_update_shader_params()

@export_range(0.0, 1.0) var gradient_strength: float = 0.1:
	set(value):
		gradient_strength = value
		_update_shader_params()

@export var button_color: Color = Color("2e2e30"): # Base idle color
	set(value):
		button_color = value
		queue_redraw()

@export var tile_texture: Texture2D:
	set(value):
		tile_texture = value
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
func _ready() -> void:
	if not Engine.is_editor_hint():
		process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_material()
	queue_redraw()

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
		var local_pos: Vector2 = to_local(get_global_mouse_position())
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
	if not enabled or tile_texture == null:
		return
		
	# Setup material in Editor/Runtime if missing
	if not material:
		_setup_material()
	
	for x: int in range(grid_width):
		for y: int in range(grid_height):
			var coords: Vector2i = Vector2i(x, y)
			
			# Hidden Check
			if _hidden_cells.has(coords):
				continue
				
			# 1. Determine Color
			var tile_color: Color = button_color
			if _pad_colors.has(coords):
				tile_color = _pad_colors[coords]
				
			# 2. Determine Scale & Animation state
			var cell_center: Vector2 = (Vector2(coords) * tile_size) + (tile_size / 2.0)
			var base_size := Vector2(28, 28)
			
			var cell_scale_mult: float = _cell_scales.get(coords, 1.0)
			var press_ratio: float = _pressed_states.get(coords, 0.0)
			
			# Shrink the pad entirely based on press ratio (1.0 = normal, 0.8 = fully pressed)
			var press_scale: float = lerpf(1.0, 0.8, press_ratio)
			var draw_size: Vector2 = base_size * cell_scale_mult * press_scale
			
			# Shift pad down slightly when pressed
			var y_offset: float = lerpf(0.0, 4.0, press_ratio)
			
			var draw_pos: Vector2 = cell_center - (draw_size / 2.0) + Vector2(0, y_offset)
			var face_rect: Rect2 = Rect2(draw_pos, draw_size)
			
			# 3. Draw!
			draw_texture_rect(tile_texture, face_rect, false, tile_color)
