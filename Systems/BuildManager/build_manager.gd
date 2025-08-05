extends Node

## Manages the tower building process, including ghost towers and placement validation.

@export var ghost_tower_scene: PackedScene ## Set this in the Inspector!
# IDs for the ghost tower's temporary highlights
@export var highlight_tower_id: int = -1
@export var highlight_range_id: int = -1
@export var valid_tower_id: int = -1
@export var valid_range_id: int = -1
@export var invalid_tower_id: int = -1
@export var invalid_range_id: int = -1


## Enums
enum State {
	VIEWING,
	BUILDING_TOWER,
	TOWER_SELECTED
}


## Internal State
var state: State = State.VIEWING
var _active_ghost_tower: Node2D
var _currently_selected_tower: TemplateTower # Used only for reference, not as a state flag
const TOWER_DATA_PLACEHOLDER = preload("res://Entities/Towers/BombTower/bomb_tower_data.tres")

## Node References
@onready var hud: CanvasLayer = get_node("../LevelHUD")
@onready var towers_container: Node2D = get_node("../Entities/Towers")
@onready var highlight_layer: TileMapLayer = get_node("../TileMaps/HighlightLayer")


## Called when the node enters the scene tree.
func _ready() -> void:
	# Connect to the HUD's signal to know when the player wants to build.
	if is_instance_valid(hud):
		hud.build_tower_requested.connect(_on_build_tower_requested)


## Listens for player input for building and selection.
func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.BUILDING_TOWER:
			if is_instance_valid(_active_ghost_tower):
				var is_cancel_key: bool = event.is_action_pressed("ui_cancel")
				var is_right_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed()
				if is_cancel_key or is_right_click:
					_exit_build_mode()
					get_viewport().set_input_as_handled()
					return
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
					if _active_ghost_tower.is_placement_valid:
						var tower_data: TowerData = TOWER_DATA_PLACEHOLDER
						var range_points: PackedVector2Array = _active_ghost_tower.get_range_points()
						place_tower(tower_data, _active_ghost_tower.global_position, range_points)
						_exit_build_mode()
					get_viewport().set_input_as_handled()
		State.TOWER_SELECTED:
			if event.is_action_pressed("ui_cancel"):
				if is_instance_valid(_currently_selected_tower):
					_currently_selected_tower.deselect()
					_currently_selected_tower = null
				state = State.VIEWING
				get_viewport().set_input_as_handled()
		State.VIEWING:
			pass


## Toggles build mode when the button is pressed.
func _on_build_tower_requested() -> void:
	match state:
		State.BUILDING_TOWER:
			_exit_build_mode()
			return
		State.VIEWING, State.TOWER_SELECTED:
			state = State.BUILDING_TOWER
			if ghost_tower_scene:
				_active_ghost_tower = ghost_tower_scene.instantiate()
				add_child(_active_ghost_tower)
				var highlight_ids := {
					"valid_tower": valid_tower_id, "invalid_tower": invalid_tower_id,
					"valid_range": valid_range_id, "invalid_range": invalid_range_id
				}
				_active_ghost_tower.initialize(
					TOWER_DATA_PLACEHOLDER,
					get_node("../TileMaps/PathLayer"),
					get_node("../TileMaps/ObjectLayer"),
					highlight_layer,
					highlight_ids
				)


## Cleans up and exits the build mode state.
func _exit_build_mode() -> void:
	state = State.VIEWING
	if is_instance_valid(_active_ghost_tower):
		_active_ghost_tower.queue_free()
		_active_ghost_tower = null


## Instantiates and places the final tower.
func place_tower(tower_data: TowerData, position: Vector2, range_points: PackedVector2Array) -> void:
	if not tower_data.placed_tower_scene:
		push_error("Attempted to place an invalid tower scene. Check the TowerData resource.")
		return

	var new_tower := tower_data.placed_tower_scene.instantiate() as TemplateTower
	new_tower.global_position = position
	towers_container.add_child(new_tower)

	new_tower.initialize(tower_data, highlight_layer, highlight_tower_id, highlight_range_id)
	new_tower.set_range_polygon(range_points)

	new_tower.selected.connect(_on_tower_selected)

	GameManager.remove_currency(tower_data.cost)

## Handles logic when a tower is clicked.
func _on_tower_selected(tower: TemplateTower) -> void:
	match state:
		State.BUILDING_TOWER, State.VIEWING:
			if is_instance_valid(_currently_selected_tower) and _currently_selected_tower != tower:
				_currently_selected_tower.deselect()
			_currently_selected_tower = tower
			_currently_selected_tower.select()
			state = State.TOWER_SELECTED
		State.TOWER_SELECTED:
			if is_instance_valid(_currently_selected_tower) and _currently_selected_tower != tower:
				_currently_selected_tower.deselect()
			_currently_selected_tower = tower
			_currently_selected_tower.select()