extends Node2D
class_name TemplateTower

## The base script for all towers.

signal selected(tower)

var data: TowerData
var _highlight_layer: TileMapLayer
var _highlight_tower_source_id: int = -1
var _highlight_range_source_id: int = -1

## Target Management
var _enemies_in_range: Array[TemplateEnemy] = []
var _current_target: TemplateEnemy

## Node References
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var range_shape: CollisionPolygon2D = $Range/RangeShape
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	# Connect the hitbox's signals to our script
	hitbox.input_event.connect(_on_hitbox_input_event)


## Called by the BuildManager to set up the tower.
func initialize(new_tower_data: TowerData, new_highlight_layer: TileMapLayer, tower_highlight_id: int, range_highlight_id: int) -> void:
	data = new_tower_data
	_highlight_layer = new_highlight_layer
	_highlight_tower_source_id = tower_highlight_id
	_highlight_range_source_id = range_highlight_id
	
	if not is_instance_valid(data):
		push_error("Placed tower was initialized without valid TowerData!")
		return


## Shows the tower's selection highlight by calling the HighlightManager.
func select() -> void:
	var center_coords := _highlight_layer.local_to_map(global_position)
	HighlightManager.show_selection_highlights(
		_highlight_layer,
		center_coords,
		data.tower_range,
		_highlight_tower_source_id,
		_highlight_range_source_id
	)


## Hides the tower's selection highlight by calling the HighlightManager.
func deselect() -> void:
	HighlightManager.hide_highlights(_highlight_layer)


## Applies a pre-calculated polygon to the range shapes.
func set_range_polygon(points: PackedVector2Array) -> void:
	range_shape.polygon = points


func _on_hitbox_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	# Check if the input event was a left mouse button press
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Announce that this tower has been selected
		emit_signal("selected", self)
		get_viewport().set_input_as_handled()


func _on_range_area_entered(area: Area2D) -> void:
	# Make sure the area that entered is a TemplateEnemy
	if not area is TemplateEnemy:
		return
	
	_enemies_in_range.append(area)
	if OS.is_debug_build():
		print("Enemy entered range. Total in range: ", _enemies_in_range.size())


func _on_range_area_exited(area: Area2D) -> void:
	# Make sure the area that exited is a TemplateEnemy
	if not area is TemplateEnemy:
		return
	
	# Find and remove the enemy from the list
	var index = _enemies_in_range.find(area)
	if index != -1:
		_enemies_in_range.remove_at(index)
	
	if OS.is_debug_build():
		print("Enemy exited range. Total in range: ", _enemies_in_range.size())