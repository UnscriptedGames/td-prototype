extends Node2D
class_name TemplateTower

## The base script for all towers.

signal selected(tower)


## Enums
enum State {
	IDLE,
	ATTACKING
}


var data: TowerData
var _highlight_layer: TileMapLayer
var _highlight_tower_source_id: int = -1
var _highlight_range_source_id: int = -1


## Internal State
var state: State = State.IDLE


## Node References
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var range_shape: CollisionPolygon2D = $Range/RangeShape


## Called by the BuildManager to set up the tower.
func initialize(tower_data: TowerData, p_highlight_layer: TileMapLayer, p_tower_id: int, p_range_id: int) -> void:
	data = tower_data
	_highlight_layer = p_highlight_layer
	_highlight_tower_source_id = p_tower_id
	_highlight_range_source_id = p_range_id
	
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


func _on_hitbox_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("selected", self)
		get_viewport().set_input_as_handled()


## Applies a pre-calculated polygon to the range shape.
func set_range_polygon(points: PackedVector2Array) -> void:
	range_shape.polygon = points
