extends Node2D

## Manages the tower building process, including ghost towers and placement validation.
class_name BuildManager

signal tower_selected
signal tower_deselected

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

## Node References
@onready var hud: LevelHUD = get_node("../LevelHUD")
@onready var towers_container: Node2D = get_node("../Entities/Towers")
@onready var highlight_layer: TileMapLayer = get_node("../TileMaps/HighlightLayer")


## Called when the node enters the scene tree.
func _ready() -> void:
	if is_instance_valid(hud):
		hud.build_tower_requested.connect(_on_build_tower_requested)
		hud.sell_tower_requested.connect(_on_sell_tower_requested)


## Listens for player input for building and selection.
func _unhandled_input(event: InputEvent) -> void:
	# If we are building, let the build handler manage the input
	if state == State.BUILDING_TOWER:
		_handle_input_building(event)
		return

	# Handle deselection via Escape/Right-click at any time
	if event.is_action_pressed("ui_cancel") and state == State.TOWER_SELECTED:
		_deselect_current_tower()
		get_viewport().set_input_as_handled()
		return
	
	# Handle left clicks for selection/deselection
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var clicked_tower: TemplateTower = _get_tower_at_position(event.position)
		
		# If we clicked on a tower
		if is_instance_valid(clicked_tower):
			# If it's a new tower, switch selection
			if clicked_tower != _selected_tower:
				_select_tower(clicked_tower)
			# If it's the same tower, do nothing (or deselect if you prefer)
		# If we clicked on empty space
		else:
			_deselect_current_tower()


## Toggles build mode when the button is pressed.
func _on_build_tower_requested(tower_data: TowerData) -> void:
	if state == State.BUILDING_TOWER:
		_exit_build_mode()
	else:
		_enter_build_mode(tower_data)


## Handles the request to sell the currently selected tower.
func _on_sell_tower_requested() -> void:
	if not is_instance_valid(_selected_tower):
		return
	
	var tower_data: TowerData = _selected_tower.data
	var refund_amount := int(tower_data.cost * 0.80)
	
	GameManager.add_currency(refund_amount)
	
	var tower_to_remove = _selected_tower
	_deselect_current_tower()
	tower_to_remove.queue_free()


## Instantiates and places the final tower.
func place_tower(tower_data: TowerData, build_position: Vector2, range_points: PackedVector2Array) -> void:
	if not tower_data.placed_tower_scene:
		push_error("Attempted to place an invalid tower scene. Check the TowerData resource.")
		return

	var new_tower := tower_data.placed_tower_scene.instantiate() as TemplateTower
	new_tower.global_position = build_position
	towers_container.add_child(new_tower)

	new_tower.initialize(tower_data, highlight_layer, selected_tower_id, selected_range_id)
	new_tower.set_range_polygon(range_points)
	
	GameManager.remove_currency(tower_data.cost)


## Handles input while in build mode; final placement uses PathLayer 'buildable' only.
func _handle_input_building(event: InputEvent) -> void:
	# Determine if the player is cancelling build mode (Esc or Right-click).
	var is_cancel: bool = event.is_action_pressed("ui_cancel") \
		or ((event is InputEventMouseButton) and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed())
	if is_cancel:
		_exit_build_mode()                          # Leave build mode immediately on cancel.
		get_viewport().set_input_as_handled()       # Consume the input so nothing else reacts.
		return

	# If the player left-clicks, attempt to place a tower.
	if (event is InputEventMouseButton) and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var path_layer: TileMapLayer = get_node("../TileMaps/PathLayer") as TileMapLayer   # Source of 'buildable'.
		if (not is_instance_valid(path_layer)) or (not is_instance_valid(_ghost_tower)):
			get_viewport().set_input_as_handled()   # Safety: if either is missing, consume input and bail.
			return

		# Convert the ghost's world position into the Path layer's cell coordinates.
		var map_coords: Vector2i = path_layer.local_to_map(path_layer.to_local(_ghost_tower.global_position))

		# Authoritative rule: only the Path layer's tileset custom data 'buildable' matters.
		var can_place: bool = is_buildable_at(path_layer, map_coords)

		# If allowed, place the tower and exit build mode.
		if can_place:
			var tower_data: TowerData = _ghost_tower.data
			var range_points: PackedVector2Array = _ghost_tower.get_range_points()
			place_tower(tower_data, _ghost_tower.global_position, range_points)
			_exit_build_mode()

		get_viewport().set_input_as_handled()       # Consume the click regardless of result.


## Private: Selects a tower
func _select_tower(tower: TemplateTower) -> void:
	if is_instance_valid(_selected_tower) and _selected_tower != tower:
		_selected_tower.deselect()

	_selected_tower = tower
	_selected_tower.select()
	state = State.TOWER_SELECTED
	emit_signal("tower_selected")


## Private: Deselects the currently selected tower, if any.
func _deselect_current_tower() -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.deselect()
		_selected_tower = null
		state = State.VIEWING
		emit_signal("tower_deselected")


## Private: Uses a physics query to find a tower at the mouse position.
func _get_tower_at_position(screen_position: Vector2) -> TemplateTower:
	var space_state = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = screen_position
	# Ensure query checks against Area2D bodies
	query.collide_with_areas = true
	var results: Array = space_state.intersect_point(query)
	
	for result in results:
		var collider: Node = result.collider
		# Check if the collider is a hitbox and its parent is a tower
		if collider.name == "Hitbox" and collider.get_parent() is TemplateTower:
			return collider.get_parent()
			
	return null


## Enters build mode and spawns/initialises the ghost (no ObjectLayer argument).
func _enter_build_mode(tower_data: TowerData) -> void:
	_deselect_current_tower()                              # Clear any current selection.
	state = State.BUILDING_TOWER                           # Route input to the building handler.

	if ghost_tower_scene:                                  # Only proceed if the scene exists.
		_ghost_tower = ghost_tower_scene.instantiate()     # Create the ghost tower preview.
		add_child(_ghost_tower)                            # Parent under the manager for tidy cleanup.

		var highlight_ids := {                             # IDs for valid/invalid highlight tiles.
			"valid_tower": valid_tower_id,
			"invalid_tower": invalid_tower_id,
			"valid_range": valid_range_id,
			"invalid_range": invalid_range_id,
		}

		var path_layer := get_node("../TileMaps/PathLayer") as TileMapLayer
		_ghost_tower.initialize(                           # New 4-arg signature (no ObjectLayer).
			tower_data,                                    # Tower data for visuals / range.
			path_layer,                                    # Source of 'buildable' custom data.
			highlight_layer,                               # Layer that draws preview highlights.
			highlight_ids                                  # Mapping of highlight tile IDs.
		)


## Private: Cleans up and exits the build mode state.
func _exit_build_mode() -> void:
	state = State.VIEWING
	if is_instance_valid(_ghost_tower):
		_ghost_tower.queue_free()
		_ghost_tower = null


# Returns true if the Path layer cell has the 'buildable' tileset custom data.
static func is_buildable_at(path_layer: TileMapLayer, map_coords: Vector2i) -> bool:
	if path_layer == null or not is_instance_valid(path_layer):
		return false
	var tile_data: TileData = path_layer.get_cell_tile_data(map_coords)  # TileMapLayer API: coords only
	if tile_data == null:
		return false
	return bool(tile_data.get_custom_data("buildable"))
