@tool
extends Node2D
class_name GridOverlay

## Draws a customizable grid overlay for the level.

@export_group("Grid Settings")
@export var grid_size: Vector2i = Vector2i(24, 16):
	set(value):
		grid_size = value
		queue_redraw()

@export var cell_size: Vector2i = Vector2i(64, 64):
	set(value):
		cell_size = value
		queue_redraw()

@export_group("Visuals")
@export var line_color: Color = Color(0.5, 0.5, 0.5, 0.5):
	set(value):
		line_color = value
		queue_redraw()

@export var line_thickness: float = 2.0:
	set(value):
		line_thickness = value
		queue_redraw()

func _draw() -> void:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return
		
	var width = grid_size.x * cell_size.x
	var height = grid_size.y * cell_size.y
	
	# Draw Vertical Lines
	for x in range(grid_size.x + 1):
		var start_pos = Vector2(x * cell_size.x, 0)
		var end_pos = Vector2(x * cell_size.x, height)
		draw_line(start_pos, end_pos, line_color, line_thickness)
		
	# Draw Horizontal Lines
	for y in range(grid_size.y + 1):
		var start_pos = Vector2(0, y * cell_size.y)
		var end_pos = Vector2(width, y * cell_size.y)
		draw_line(start_pos, end_pos, line_color, line_thickness)
