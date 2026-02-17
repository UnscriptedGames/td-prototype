@tool
class_name BuildManager
extends Node2D

## Manages the tower building process, including ghost towers and placement validation.
##
## Handles the "Ghost" tower during placement, validating grid coordinates against
## the path layer, and managing drag-and-drop interactions for both towers and buffs.

signal tower_selected(tower: TemplateTower)
signal tower_deselected

enum State {VIEWING, BUILDING_TOWER, TOWER_SELECTED}

const GHOST_TOWER_SCENE = preload("res://Entities/Towers/_GhostTower/ghost_tower.tscn")

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
var _is_placing: bool = false ## Prevents cancel signal on successful placement.
var _occupied_build_tiles: Dictionary[Vector2i, Node2D] = {}
var _pending_tower_scene: PackedScene ## Decoupled from TowerData to avoid circular dependencies.

## Node References
var towers_container: Node2D
var highlight_layer: TileMapLayer
var path_layer: TileMapLayer

var _bound_viewport: Viewport
var _bound_container: Control
var _is_dragging: bool = false ## Track drag state to prevent auto-exit
var _highlighted_tower_for_buff: TemplateTower = null ## Track tower under mouse for buffing
var _build_mode_grace_frames: int = 0


## Called when the node enters the scene tree.
func _ready() -> void:
	if not Engine.is_editor_hint():
		# Connects to the new global signal.
		GlobalSignals.build_tower_requested.connect(_on_build_tower_requested)

		# Register with the InputManager
		InputManager.register_build_manager(self)


# --- SETUP METHODS ---

## Binds the manager to a specific viewport for physics queries.
## @param viewport: The SubViewport containing the game world.
## @param container: The Control (SubViewportContainer) holding the viewport.
func bind_to_viewport(viewport: Viewport, container: Control) -> void:
	_bound_viewport = viewport
	_bound_container = container
	print("BuildManager bound to viewport: ", viewport.name)


## Updates references to level-specific nodes (called when level loads).
## @param new_path_layer: The TileMapLayer used for path/grid validation.
## @param new_highlight_layer: The TileMapLayer used for visual feedback.
## @param new_towers_container: The Node2D parent for tower instances.
func update_level_references(new_path_layer: TileMapLayer, new_highlight_layer: TileMapLayer, new_towers_container: Node2D) -> void:
	path_layer = new_path_layer
	highlight_layer = new_highlight_layer
	towers_container = new_towers_container
	# Reset state just in case
	_deselect_current_tower()
	_occupied_build_tiles.clear()
	print("BuildManager level references updated.")


## Called every frame. Checks for inputs and ensures Drag liveness.
func _process(_delta: float) -> void:
	# Check boundaries if we are BUILDING (Ghost) OR Dragging a known card (Buff)
	if state == State.BUILDING_TOWER or _is_dragging:
		# Grace period to allow mouse warp to settle
		if _build_mode_grace_frames > 0:
			_build_mode_grace_frames -= 1
			return
			
		# --- Boundary Check ---
		# Determine if the mouse is validly inside the game view.
		if is_instance_valid(_bound_container):
			# Convert mouse position to the Container's local space
			# This handles the mismatch between Global/Screen and Viewport/Local coordinates
			var local_mouse: Vector2 = _bound_container.get_local_mouse_position()
			var local_rect: Rect2 = Rect2(Vector2.ZERO, _bound_container.get_size())
			
			if not local_rect.has_point(local_mouse):
				banish_drag_session() # Use new universal banish
				return
		else:
			# Fallback if no container bound (shouldn't happen in game)
			if not get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()):
				_exit_build_mode()
				return


# --- PUBLIC INPUT HANDLERS (Called by InputManager) ---

## Handles input while in build mode. Returns true if the input was handled.
## @param event: The input event to process.
func handle_build_input(event: InputEvent) -> bool:
	if state != State.BUILDING_TOWER:
		return false

	var is_cancel: bool = event.is_action_pressed("ui_cancel") or ((event is InputEventMouseButton) and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed())
	if is_cancel:
		_exit_build_mode()
		return true

	if (event is InputEventMouseButton) and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if validate_and_place():
			return true

	return false


## Handles input for selecting and deselecting towers.
## @param event: The input event to process.
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

	var total_cost: int = tower_data.levels[0].cost
	for level_index in _selected_tower.upgrade_path_indices:
		total_cost += tower_data.levels[level_index].cost
	
	return int(ceil(total_cost * 0.80))


## Validates the current ghost placement and places the tower if valid.
## Checks cost, stock, and grid occupancy.
func validate_and_place() -> bool:
	if state != State.BUILDING_TOWER:
		return false
		
	if (not is_instance_valid(path_layer)) or (not is_instance_valid(_ghost_tower)):
		return false

	var map_coords: Vector2i = path_layer.local_to_map(path_layer.to_local(_ghost_tower.global_position))
	
	# Check Placement Validity
	if not is_buildable_at(map_coords):
		return false
		
	# Check Resources
	var tower_data: TowerData = _ghost_tower.data
	var cost = tower_data.levels[0].cost
	
	if GameManager.get_stock(tower_data) <= 0:
		# TODO: Valid UI Feedback (Floating Text / Shake)
		print("Not enough stock!")
		_exit_build_mode()
		return false
		
	if GameManager.player_data.currency < cost:
		# TODO: Valid UI Feedback
		print("Not enough gold!")
		_exit_build_mode()
		return false

	# Success
	_is_placing = true
	var range_points: PackedVector2Array = _ghost_tower.get_range_points()
	_place_tower(tower_data, _ghost_tower.global_position, range_points)
	_exit_build_mode()
	return true


# --- PRIVATE SIGNAL HANDLERS ---

func _on_build_tower_requested(tower_data: TowerData, tower_scene: PackedScene) -> void:
	if state == State.BUILDING_TOWER:
		_exit_build_mode()
	else:
		_enter_build_mode(tower_data, tower_scene)


func _on_sell_tower_requested() -> void:
	if not is_instance_valid(_selected_tower):
		return

	var map_coords: Vector2i = path_layer.local_to_map(_selected_tower.global_position)
	if _occupied_build_tiles.has(map_coords):
		_occupied_build_tiles.erase(map_coords)

	var refund_amount := get_selected_tower_sell_value()
	GameManager.add_currency(refund_amount)
	
	# Refund Stock
	if _selected_tower.data:
		GameManager.refund_stock(_selected_tower.data)

	var tower_to_remove = _selected_tower
	_deselect_current_tower()
	tower_to_remove.queue_free()


func _on_target_priority_changed(priority: TargetPriority.Priority) -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.set_target_priority(priority)


# --- PRIVATE METHODS ---

func _place_tower(tower_data: TowerData, build_position: Vector2, range_points: PackedVector2Array) -> void:
	if not _pending_tower_scene:
		push_error("Attempted to place an invalid tower scene. _pending_tower_scene is null.")
		return

	var new_tower := _pending_tower_scene.instantiate() as TemplateTower
	new_tower.global_position = build_position
	towers_container.add_child(new_tower)

	var map_coords: Vector2i = path_layer.local_to_map(build_position)
	_occupied_build_tiles[map_coords] = new_tower

	new_tower.initialize(tower_data, highlight_layer, selected_tower_id, selected_range_id)
	new_tower.set_range_polygon(range_points)

	if tower_data.levels.is_empty():
		push_error("TowerData for '%s' has no levels defined; cannot deduct build cost." % tower_data.tower_name)
		return

	var build_cost: int = tower_data.levels[0].cost
	
	# Consume Resources
	GameManager.consume_stock(tower_data)
	GameManager.remove_currency(build_cost)

	# Announce that the card effect was successfully completed.
	GlobalSignals.card_effect_completed.emit()


func _select_tower(tower: TemplateTower) -> void:
	if is_instance_valid(_selected_tower) and _selected_tower != tower:
		_selected_tower.deselect()

	_selected_tower = tower
	_selected_tower.select()
	state = State.TOWER_SELECTED
	emit_signal("tower_selected", tower)


func _deselect_current_tower() -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.deselect()
		_selected_tower = null
		state = State.VIEWING
		emit_signal("tower_deselected")


func _get_tower_at_position(screen_position: Vector2) -> TemplateTower:
	var space_state: PhysicsDirectSpaceState2D
	
	# Use the bound viewport's physics space if available, otherwise fallback.
	if is_instance_valid(_bound_viewport):
		space_state = _bound_viewport.find_world_2d().direct_space_state
	else:
		space_state = get_world_2d().direct_space_state
		
	# Calculate local position relative to the container (viewport).
	var query_position: Vector2 = screen_position
	if is_instance_valid(_bound_container):
		query_position = screen_position - _bound_container.global_position
		
	var query := PhysicsPointQueryParameters2D.new()
	query.position = query_position
	query.collide_with_areas = true
	var results: Array = space_state.intersect_point(query)
	
	for result in results:
		var collider: Node = result.collider
		# Check for "Hitbox" specifically
		if collider.name == "Hitbox" and collider.get_parent() is TemplateTower:
			return collider.get_parent()
			
	return null


func _enter_build_mode(tower_data: TowerData, tower_scene: PackedScene) -> void:
	_deselect_current_tower()
	state = State.BUILDING_TOWER
	_pending_tower_scene = tower_scene
	_is_placing = false ## Reset the placing flag.
	InputManager.set_state(InputManager.State.BUILDING_TOWER) # Notify InputManager
	GlobalSignals.build_mode_entered.emit()

	if GHOST_TOWER_SCENE:
		_ghost_tower = GHOST_TOWER_SCENE.instantiate()
		
		# Parenting: Add to the bound viewport if available to match coordinate space.
		if is_instance_valid(_bound_viewport):
			_bound_viewport.add_child(_ghost_tower)
		else:
			add_child(_ghost_tower)

		var highlight_ids := {
			"valid_tower": valid_tower_id, "invalid_tower": invalid_tower_id,
			"valid_range": valid_range_id, "invalid_range": invalid_range_id,
		}

		_ghost_tower.initialize(
			self, tower_data, path_layer, highlight_layer, highlight_ids
		)
		
		# Reset grace frames to prevent immediate cancellation
		_build_mode_grace_frames = 10


func _exit_build_mode() -> void:
	state = State.VIEWING
	_is_dragging = false
	InputManager.set_state(InputManager.State.DEFAULT)
	GlobalSignals.build_mode_exited.emit()
	
	# If we are NOT successfully placing a tower, it means this was a cancellation.
	if not _is_placing:
		GlobalSignals.card_effect_cancelled.emit()

	if is_instance_valid(_ghost_tower):
		_ghost_tower.queue_free()
		_ghost_tower = null


# --- DRAG AND DROP SUPPORT ---

var _current_drag_id: int = -1
var _banished_drag_ids: Dictionary = {} # Using Dict for fast lookup
var _current_drag_card: Node = null # Reference to card for visual reset

## Public API: Permanently cancels the current drag session.
## This prevents the card from being used again until a NEW drag starts.
func banish_drag_session() -> void:
	print("BuildManager: banish_drag_session called! Cursor outside valid area?")
	if _current_drag_id != -1:
		_banished_drag_ids[_current_drag_id] = true
	
	# Reset card visuals
	if is_instance_valid(_current_drag_card) and _current_drag_card.has_method("reset_drag_visuals"):
		_current_drag_card.reset_drag_visuals()
		
	# Clean up local state
	_is_dragging = false
	_current_drag_id = -1
	_current_drag_card = null
	
	# Clean up ghosts/highlights
	_exit_build_mode()
	cancel_drag_buff()

## Checks if the given drag ID has been banished.
func is_drag_banished(drag_id: int) -> bool:
	return drag_id != -1 and _banished_drag_ids.has(drag_id)

func is_dragging() -> bool:
	return _is_dragging

## Starts the ghost tower drag logic.
## @param tower_data: resource for the tower to build.
## @param tower_scene: scene to instantiate later.
## @param drag_id: unique ID for this drag session.
## @param card_ref: origin card node.
func start_drag_ghost_with_scene(tower_data: TowerData, tower_scene: PackedScene, drag_id: int = -1, card_ref: Node = null) -> void:
	# STRICT CHECK: If banished, refuse entirely.
	if drag_id != -1 and _banished_drag_ids.has(drag_id):
		return
		
	_is_dragging = true ## Enable drag mode
	_current_drag_id = drag_id
	_current_drag_card = card_ref
	
	if state == State.BUILDING_TOWER:
		if _ghost_tower and _ghost_tower.data == tower_data:
			return # Stability Check Passed
		_exit_build_mode()
		_is_dragging = true # Re-enable since exit cleared it
		
	_enter_build_mode(tower_data, tower_scene)
	
## Cancels a ghost drag operation.
func cancel_drag_ghost() -> void:
	if state == State.BUILDING_TOWER:
		_exit_build_mode()

## Updates the ghost tower's position during a drag.
## @param screen_position: The mouse position in screen coordinates.
func update_drag_ghost(screen_position: Vector2) -> void:
	# STRICT CHECK: If not dragging (because banished or cancelled), ignore updates.
	if not _is_dragging:
		return
		
	if state != State.BUILDING_TOWER or not is_instance_valid(_ghost_tower):
		return
		
	# Convert Screen Position -> Viewport Local Position
	var local_pos = screen_position
	if is_instance_valid(_bound_container):
		# Offset by the container's position in the main window
		local_pos = screen_position - _bound_container.global_position
		
	# Tell the ghost to update specifically to this position
	if is_instance_valid(_ghost_tower):
		if _ghost_tower.has_method("set_manual_update_mode"):
			_ghost_tower.set_manual_update_mode(true)
			
		if _ghost_tower.has_method("update_position_manually"):
			_ghost_tower.update_position_manually(local_pos)
		else:
			_ghost_tower.global_position = local_pos


## Returns true if the given map coordinates are valid for building.
func is_buildable_at(map_coords: Vector2i) -> bool:
	if not is_instance_valid(path_layer):
		return false
	if _occupied_build_tiles.has(map_coords):
		return false
	var tile_data: TileData = path_layer.get_cell_tile_data(map_coords)
	if tile_data == null:
		return false
	return bool(tile_data.get_custom_data("buildable"))


# --- BUFF DRAG LOGIC ---

var _buff_ghost: Sprite2D = null

## Starts dragging a buff card.
## @param card_ref: The origin card node.
## @param drag_id: Unique session ID.
func start_drag_buff(card_ref: Node, drag_id: int = -1) -> void:
	print("BuildManager: start_drag_buff called for %s" % drag_id)
	# STRICT CHECK: If banished, refuse entirely.
	if drag_id != -1 and _banished_drag_ids.has(drag_id):
		print("BuildManager: Drag banished, ignoring.")
		return

	# Idempotency check: If already dragging this card, don't reset state.
	if _is_dragging and _current_drag_card == card_ref:
		return

	_is_dragging = true
	_current_drag_card = card_ref
	_current_drag_id = drag_id
	
	# Add grace frames to prevent immediate banishment on boundary check
	_build_mode_grace_frames = 10
	
	# Ensure no tower ghost exists
	if is_instance_valid(_ghost_tower):
		_ghost_tower.queue_free()
		_ghost_tower = null
		
	# Create Buff Ghost Cursor (if needed)
	if not is_instance_valid(_buff_ghost):
		print("BuildManager: Creating new buff ghost sprite.")
		_buff_ghost = Sprite2D.new()
		_buff_ghost.z_index = 4096 # Ensure visibility on top of everything
		
		# Load Texture (Robust Fallback)
		var texture = null
		if ResourceLoader.exists("res://UI/Icons/buff_cursor.png"):
			texture = load("res://UI/Icons/buff_cursor.png")
		elif FileAccess.file_exists("res://UI/Icons/buff_cursor.png"):
			var img = Image.load_from_file("res://UI/Icons/buff_cursor.png")
			if img: texture = ImageTexture.create_from_image(img)
			
		if texture:
			_buff_ghost.texture = texture
			_buff_ghost.centered = true
		else:
			push_warning("Buff cursor texture not found at res://UI/Icons/buff_cursor.png")
			
		# Add to Viewport (match GhostTower behavior)
		if is_instance_valid(_bound_viewport):
			_bound_viewport.add_child(_buff_ghost)
		else:
			add_child(_buff_ghost)

## Updates the buff ghost position and highlights validity.
## @param screen_position: Mouse position in screen coordinates.
func update_drag_buff(screen_position: Vector2) -> void:
	# STRICT CHECK: If not dragging (banished), ignore updates.
	if not _is_dragging:
		return

	# Adjust Screen Position to Viewport Local Position
	var viewport_pos = screen_position
	if is_instance_valid(_bound_container):
		viewport_pos = screen_position - _bound_container.global_position

	# --- 1. Update Ghost Position (Snapped) ---
	if is_instance_valid(_buff_ghost):
		if is_instance_valid(path_layer):
			var local_pos = path_layer.to_local(viewport_pos) # Convert Viewport Global to Layer Local
			# Snap to Grid
			var map_pos = path_layer.local_to_map(local_pos)
			var snapped_pos = path_layer.map_to_local(map_pos)
			
			# Use global_position to be safe
			_buff_ghost.global_position = path_layer.to_global(snapped_pos)
		else:
			_buff_ghost.position = viewport_pos # Fallback if no path layer
	
	# --- 2. Highlight Logic ---
	# Note: Highlight logic acts on Hitboxes which are likely in Viewport Global space? 
	# _get_tower_at_position handles the offset internally! 
	var hovered_tower = _get_tower_at_position(screen_position)
	
	# If we moved off a tower, or moved to a DIFFERENT tower
	if hovered_tower != _highlighted_tower_for_buff:
		# Reset the OLD tower (if valid)
		if is_instance_valid(_highlighted_tower_for_buff):
			_highlighted_tower_for_buff.modulate = Color.WHITE
			
		# Update reference
		_highlighted_tower_for_buff = hovered_tower
		
		# Highlight the NEW tower (if valid)
		if is_instance_valid(_highlighted_tower_for_buff):
			_highlighted_tower_for_buff.modulate = Color(1.2, 1.5, 1.2)

## Cancels the current buff drag session.
func cancel_drag_buff() -> void:
	print("BuildManager: cancel_drag_buff called.")
	if is_instance_valid(_buff_ghost):
		_buff_ghost.queue_free()
		_buff_ghost = null

	if is_instance_valid(_highlighted_tower_for_buff):
		_highlighted_tower_for_buff.modulate = Color.WHITE
		_highlighted_tower_for_buff = null
	
	# We don't unset _is_dragging here because this might be a temporary hover-off.
	# But if called from banish, banish handles the flags.

## Applies the buff at the given position if a valid tower is present.
## @param screen_position: Mouse position in screen coordinates.
## @param item_data: The BuffData resource to apply.
func apply_buff_at(screen_position: Vector2, item_data: Resource) -> bool:
	if not _is_dragging: return false # Banished
	
	var buff_data: BuffData = item_data as BuffData
	if not buff_data:
		push_error("BuildManager: apply_buff_at called with invalid data type. Expected BuffData.")
		return false

	var target_tower: TemplateTower = _get_tower_at_position(screen_position)
	
	# Cleanup highlight
	if is_instance_valid(_highlighted_tower_for_buff):
		_highlighted_tower_for_buff.modulate = Color.WHITE
		_highlighted_tower_for_buff = null
	
	_is_dragging = false
	_current_drag_card = null
	
	if is_instance_valid(target_tower):
		# Check Resources
		if GameManager.player_data.currency < buff_data.gold_cost:
			print("Not enough gold to apply buff!")
			return false

		# Create execution context
		var context: Dictionary = {"tower": target_tower}
		
		# Execute the effect
		if buff_data.effect:
			buff_data.effect.execute(context)
			
			# Consume Resources
			GameManager.remove_currency(buff_data.gold_cost)
			
			GlobalSignals.buff_applied.emit(buff_data)
			GlobalSignals.card_effect_completed.emit()
			return true
		else:
			push_error("BuffData '%s' has no effect assigned." % buff_data.display_name)
	
	return false
