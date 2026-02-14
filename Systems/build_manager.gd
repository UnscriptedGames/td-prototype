extends Node2D

## Manages the tower building process, including ghost towers and placement validation.
class_name BuildManager

signal tower_selected
signal tower_deselected
# REMOVED old tower_placed signal

enum State {VIEWING, BUILDING_TOWER, TOWER_SELECTED}

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
var _occupied_build_tiles: Dictionary = {}
var _pending_tower_scene: PackedScene ## Coupelled from TowerData to avoid circular dependencies.

## Node References
# These are now dynamic to support scene changing.
var towers_container: Node2D
var highlight_layer: TileMapLayer
var path_layer: TileMapLayer

var _bound_viewport: Viewport
var _bound_container: Control
var _is_dragging: bool = false ## NEW: Track drag state to prevent auto-exit
var _highlighted_tower_for_buff: TemplateTower = null ## NEW: Track tower under mouse for buffing

## Called when the node enters the scene tree.
func _ready() -> void:
	# Connects to the new global signal.
	GlobalSignals.build_tower_requested.connect(_on_build_tower_requested)

	# Register with the InputManager
	InputManager.register_build_manager(self)


# --- SETUP METHODS ---

## Binds the manager to a specific viewport for physics queries.
## @param viewport: The SubViewport containing the game world.
## @param container: The Control (SubViewportContainer) holding the viewport, used for coordinate offsets.
func bind_to_viewport(viewport: Viewport, container: Control) -> void:
	_bound_viewport = viewport
	_bound_container = container
	print("BuildManager bound to viewport: ", viewport.name)


## Updates references to level-specific nodes (called when level loads).
func update_level_references(new_path_layer: TileMapLayer, new_highlight_layer: TileMapLayer, new_towers_container: Node2D) -> void:
	path_layer = new_path_layer
	highlight_layer = new_highlight_layer
	towers_container = new_towers_container
	# Reset state just in case
	_deselect_current_tower()
	_occupied_build_tiles.clear()
	print("BuildManager level references updated.")
var _build_mode_grace_frames: int = 0


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
			var local_mouse = _bound_container.get_local_mouse_position()
			var local_rect = Rect2(Vector2.ZERO, _bound_container.get_size())
			
			if not local_rect.has_point(local_mouse):
				banish_drag_session() # Use new universal banish
				return
		else:
			# Fallback if no container bound (shouldn't happen in game)
			if not get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()):
				_exit_build_mode()
				return


# --- PUBLIC INPUT HANDLERS (Called by InputManager) ---


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
		if validate_and_place():
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

	var total_cost: int = tower_data.levels[0].cost
	for level_index in _selected_tower.upgrade_path_indices:
		total_cost += tower_data.levels[level_index].cost
	
	return int(ceil(total_cost * 0.80))


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
	place_tower(tower_data, _ghost_tower.global_position, range_points)
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

func place_tower(tower_data: TowerData, build_position: Vector2, range_points: PackedVector2Array) -> void:
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

	if ghost_tower_scene:
		_ghost_tower = ghost_tower_scene.instantiate()
		
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

# --- DRAG AND DROP SUPPORT ---

var _current_drag_id: int = -1
var _banished_drag_ids: Dictionary = {} # Using Dict for fast lookup
var _current_drag_card: Node = null # Reference to card for visual reset

## Public API: Permanently cancels the current drag session.
## This prevents the card from being used again until a NEW drag starts.
func banish_drag_session() -> void:
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

func is_drag_banished(drag_id: int) -> bool:
	return drag_id != -1 and _banished_drag_ids.has(drag_id)

func is_dragging() -> bool:
	return _is_dragging

## Starts the ghost tower drag logic.
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
	
func cancel_drag_ghost() -> void:
	if state == State.BUILDING_TOWER:
		_exit_build_mode()

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

# _banish_current_drag removed (replaced by banish_drag_session)

# validate_and_place removed (Duplicate)
# dangling return removed
	

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

func start_drag_buff(card_ref: Node, drag_id: int = -1) -> void:
	# STRICT CHECK: If banished, refuse entirely.
	if drag_id != -1 and _banished_drag_ids.has(drag_id):
		return

	# Idempotency check: If already dragging this card, don't reset state.
	if _is_dragging and _current_drag_card == card_ref:
		return

	_is_dragging = true
	_current_drag_card = card_ref
	_current_drag_id = drag_id
	
	# Ensure no tower ghost exists
	if is_instance_valid(_ghost_tower):
		_ghost_tower.queue_free()
		_ghost_tower = null
		
	# Create Buff Ghost Cursor (if needed)
	if not is_instance_valid(_buff_ghost):
		_buff_ghost = Sprite2D.new()
		
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
			# _buff_ghost.modulate.a = 0.8 # Optional transparency
			
		# Add to PathLayer (so it matches grid coordinates)
		if is_instance_valid(path_layer):
			path_layer.add_child(_buff_ghost)
		elif is_instance_valid(_bound_viewport):
			_bound_viewport.add_child(_buff_ghost)
		else:
			add_child(_buff_ghost)

func update_drag_buff(screen_position: Vector2) -> void:
	# STRICT CHECK: If not dragging (banished), ignore updates.
	if not _is_dragging:
		return

	# Adjust Screen Position to Viewport Local Position
	var viewport_pos = screen_position
	if is_instance_valid(_bound_container):
		viewport_pos = screen_position - _bound_container.global_position

	# --- 1. Update Ghost Position (Snapped) ---
	if is_instance_valid(_buff_ghost) and is_instance_valid(path_layer):
		var local_pos = path_layer.to_local(viewport_pos) # Convert Viewport Global to Layer Local
		# Snap to Grid
		var map_pos = path_layer.local_to_map(local_pos)
		var snapped_pos = path_layer.map_to_local(map_pos)
		
		_buff_ghost.position = snapped_pos
	
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

func cancel_drag_buff() -> void:
	if is_instance_valid(_buff_ghost):
		_buff_ghost.queue_free()
		_buff_ghost = null

	if is_instance_valid(_highlighted_tower_for_buff):
		_highlighted_tower_for_buff.modulate = Color.WHITE
		_highlighted_tower_for_buff = null
	
	# We don't unset _is_dragging here because this might be a temporary hover-off.
	# But if called from banish, banish handles the flags.

func apply_buff_at(screen_position: Vector2, buff_effect: Resource) -> bool:
	if not _is_dragging: return false # Banished
	
	var target_tower = _get_tower_at_position(screen_position)
	
	# Cleanup highlight
	if is_instance_valid(_highlighted_tower_for_buff):
		_highlighted_tower_for_buff.modulate = Color.WHITE
		_highlighted_tower_for_buff = null
	
	_is_dragging = false
	_current_drag_card = null
	
	if is_instance_valid(target_tower):
		# Apply the buff directly
		if target_tower.has_method("apply_buff"):
			target_tower.apply_buff(buff_effect)
			GlobalSignals.buff_applied.emit(buff_effect)
			return true
	
	return false
