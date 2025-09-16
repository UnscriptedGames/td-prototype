extends Node2D

## Manages the tower building process, including ghost towers and placement validation.
class_name BuildManager

var TargetingPriority = preload("res://Core/targeting_priority.gd")

signal tower_selected
signal tower_deselected
# REMOVED old tower_placed signal

enum State { VIEWING, BUILDING_TOWER, TOWER_SELECTED }

@export var ghost_tower_scene: PackedScene ## Set this in the Inspector!
# IDs for the selected tower's permanent highlights
@export var selected_tower_id: int = -1
@export var selected_range_id: int = -1
# IDs for the ghost tower's temporary highlights
@export var valid_tower_id: int = -1
@export var invalid_tower_id: int = -1
@export var valid_range_id: int = -1
@export var invalid_range_id: int = -1

## Internal State
var state: State = State.VIEWING
var _ghost_tower: Node2D
var _selected_tower: TemplateTower
var _is_placing: bool = false ## NEW: Prevents cancel signal on successful placement.

## Node References
@onready var hud: LevelHUD = get_node("../LevelHUD")
@onready var towers_container: Node2D = get_node("../Entities/Towers")
@onready var highlight_layer: TileMapLayer = get_node("../TileMaps/HighlightLayer")


## Called when the node enters the scene tree.
func _ready() -> void:
	# Connects to signals from the LevelHUD for legacy build buttons.
	if is_instance_valid(hud):
		hud.sell_tower_requested.connect(_on_sell_tower_requested)
		hud.target_priority_changed.connect(_on_target_priority_changed)

	# Connects to the new global signal for card-based building requests.
	GlobalSignals.build_tower_requested.connect(_on_build_tower_requested)

	# Register with the InputManager
	InputManager.register_build_manager(self)


# --- PUBLIC INPUT HANDLERS (Called by InputManager) ---

## Handles input while in build mode. Returns true if the input was handled.
func handle_build_input(event: InputEvent) -> bool:
	if state != State.BUILDING_TOWER:
		return false

	var is_cancel: bool = event.is_action_pressed("ui_cancel") or ((event is InputEventMouseButton) and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed())
	if is_cancel:
		_exit_build_mode()
		return true

	if (event is InputEventMouseButton) and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var path_layer: TileMapLayer = get_node("../TileMaps/PathLayer") as TileMapLayer
		if (not is_instance_valid(path_layer)) or (not is_instance_valid(_ghost_tower)):
			return true

		var map_coords: Vector2i = path_layer.local_to_map(path_layer.to_local(_ghost_tower.global_position))
		var can_place: bool = is_buildable_at(path_layer, map_coords)

		if can_place:
			# Set a flag to indicate we are successfully placing the tower.
			_is_placing = true
			var tower_data: TowerData = _ghost_tower.data
			var range_points: PackedVector2Array = _ghost_tower.get_range_points()
			place_tower(tower_data, _ghost_tower.global_position, range_points)
			_exit_build_mode()

		return true

	return false


## Handles input for selecting and deselecting towers.
func handle_selection_input(event: InputEvent) -> bool:
	if state == State.BUILDING_TOWER:
		return false

	if event.is_action_pressed("ui_cancel") and state == State.TOWER_SELECTED:
		_deselect_current_tower()
		return true
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var clicked_tower: TemplateTower = _get_tower_at_position(event.position)
		
		if is_instance_valid(clicked_tower):
			if clicked_tower != _selected_tower:
				_select_tower(clicked_tower)
			return true # Always handle clicks on towers
		else:
			_deselect_current_tower()
			return false # Let other systems handle clicks on empty space

	return false


# --- PUBLIC GETTERS ---

func get_selected_tower() -> TemplateTower:
	return _selected_tower


func get_selected_tower_sell_value() -> int:
	if not is_instance_valid(_selected_tower):
		return 0
	
	var tower_data: TowerData = _selected_tower.data
	if tower_data.levels.is_empty():
		push_error("TowerData for '%s' has no levels defined; cannot determine refund amount." % tower_data.tower_name)
		return 0

	var total_cost := 0
	for i in range(_selected_tower.current_level):
		total_cost += _selected_tower.data.levels[i].cost
	
	return int(total_cost * 0.80)


# --- PRIVATE SIGNAL HANDLERS ---

func _on_build_tower_requested(tower_data: TowerData) -> void:
	if state == State.BUILDING_TOWER:
		_exit_build_mode()
	else:
		_enter_build_mode(tower_data)


func _on_sell_tower_requested() -> void:
	if not is_instance_valid(_selected_tower):
		return
	
	var refund_amount := get_selected_tower_sell_value()
	GameManager.add_currency(refund_amount)
	
	var tower_to_remove = _selected_tower
	_deselect_current_tower()
	tower_to_remove.queue_free()


func _on_target_priority_changed(priority: TargetingPriority.Priority) -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.set_target_priority(priority)


# --- PRIVATE METHODS ---

func place_tower(tower_data: TowerData, build_position: Vector2, range_points: PackedVector2Array) -> void:
	if not tower_data.placed_tower_scene:
		push_error("Attempted to place an invalid tower scene. Check the TowerData resource.")
		return

	var new_tower := tower_data.placed_tower_scene.instantiate() as TemplateTower
	new_tower.global_position = build_position
	towers_container.add_child(new_tower)

	new_tower.initialize(tower_data, highlight_layer, selected_tower_id, selected_range_id)
	new_tower.set_range_polygon(range_points)
	
	if tower_data.levels.is_empty():
		push_error("TowerData for '%s' has no levels defined; cannot deduct build cost." % tower_data.tower_name)
		return

	var build_cost: int = tower_data.levels[0].cost
	GameManager.remove_currency(build_cost)
	
	# Announce that the card effect was successfully completed.
	GlobalSignals.card_effect_completed.emit()


func _select_tower(tower: TemplateTower) -> void:
	if is_instance_valid(_selected_tower) and _selected_tower != tower:
		_selected_tower.deselect()

	_selected_tower = tower
	_selected_tower.select()
	state = State.TOWER_SELECTED
	emit_signal("tower_selected")


func _deselect_current_tower() -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.deselect()
		_selected_tower = null
		state = State.VIEWING
		emit_signal("tower_deselected")


func _get_tower_at_position(screen_position: Vector2) -> TemplateTower:
	var space_state = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = screen_position
	query.collide_with_areas = true
	var results: Array = space_state.intersect_point(query)
	
	for result in results:
		var collider: Node = result.collider
		if collider.name == "Hitbox" and collider.get_parent() is TemplateTower:
			return collider.get_parent()
			
	return null


func _enter_build_mode(tower_data: TowerData) -> void:
	_deselect_current_tower()
	state = State.BUILDING_TOWER
	_is_placing = false ## Reset the placing flag.
	InputManager.set_state(InputManager.State.BUILDING_TOWER) # Notify InputManager
	GlobalSignals.build_mode_entered.emit()

	if ghost_tower_scene:
		_ghost_tower = ghost_tower_scene.instantiate()
		add_child(_ghost_tower)

		var highlight_ids := {
			"valid_tower": valid_tower_id, "invalid_tower": invalid_tower_id,
			"valid_range": valid_range_id, "invalid_range": invalid_range_id,
		}

		var path_layer := get_node("../TileMaps/PathLayer") as TileMapLayer
		_ghost_tower.initialize(
			tower_data, path_layer, highlight_layer, highlight_ids
		)


func _exit_build_mode() -> void:
	state = State.VIEWING
	InputManager.set_state(InputManager.State.DEFAULT)
	GlobalSignals.build_mode_exited.emit()
	
	# If we are NOT successfully placing a tower, it means this was a cancellation.
	if not _is_placing:
		GlobalSignals.card_effect_cancelled.emit()

	if is_instance_valid(_ghost_tower):
		_ghost_tower.queue_free()
		_ghost_tower = null


static func is_buildable_at(path_layer: TileMapLayer, map_coords: Vector2i) -> bool:
	if path_layer == null or not is_instance_valid(path_layer):
		return false
	var tile_data: TileData = path_layer.get_cell_tile_data(map_coords)
	if tile_data == null:
		return false
	return bool(tile_data.get_custom_data("buildable"))
