class_name GameWindow
extends Control

@onready var game_viewport: SubViewport = $MainLayout/WorkspaceSplit/GameViewContainer/SubViewport
@onready var menu_button: MenuButton = $MainLayout/TopBar/Content/MenuButton
@onready var main_menu_confirm: ConfirmationDialog = $MainMenuConfirmation
@onready var quit_confirm: ConfirmationDialog = $QuitConfirmation

# Transport Controls
@onready var play_button: Button = $MainLayout/TopBar/Content/TransportControls/PlayButton

@onready var gauge_l: TextureProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/GaugeLContainer/GaugeL
@onready var gauge_r: TextureProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/GaugeRContainer/GaugeR


@onready var wave_label: Label = $MainLayout/TopBar/Content/TransportControls/WaveInfoPanel/WaveLabel

# Card Grid
@onready var card_grid: GridContainer = $MainLayout/WorkspaceSplit/LeftSidebar/SidebarContent/CardMarginContainer/CardGrid
@export var player_deck: Resource # Loaded as DeckData

# Icons
var icon_play: Texture2D
var icon_pause: Texture2D

# Assets
const CARD_SCENE = preload("res://Entities/Cards/card.tscn")

# State
var is_playing: bool = false
var _card_manager: CardManager
var _build_manager: BuildManager
var _active_card: Card # Track the card currently being played/previewed
var _selected_tower: TemplateTower = null
var _tower_inspector: PanelContainer # Type is TowerInspector, loose coupling to avoid cyclic ref/lag

# Meter Animation State
var _target_damage_value: float = 0.0
var _meter_noise_offset_l: float = 0.0
var _meter_noise_offset_r: float = 0.0


# Path to the default level
const DEFAULT_LEVEL_PATH: String = "res://Levels/TemplateLevel/template_level.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://UI/MainMenu/main_menu.tscn"

enum MenuOptions {
	MAIN_MENU,
	QUIT
}

func _ready() -> void:
	# Wait for systems to settle
	await get_tree().process_frame
	
	_setup_menu()
	_setup_confirmations()
	_setup_transport()
	
	# Managers
	_active_card = null
	
	# Get BuildManager from InputManager if available
	if InputManager.has_method("get_build_manager"):
		_build_manager = InputManager.get_build_manager()
		if _build_manager:
			_build_manager.tower_selected.connect(_on_tower_selected)
			_build_manager.tower_deselected.connect(_on_tower_deselected)
			
			# Bind Viewport
			var viewport = $MainLayout/WorkspaceSplit/GameViewContainer/SubViewport
			var container = $MainLayout/WorkspaceSplit/GameViewContainer
			_build_manager.bind_to_viewport(viewport, container)
	
	# Setup Card Manager
	_card_manager = CardManager.new()
	add_child(_card_manager)
	_card_manager.hand_changed.connect(_on_hand_changed)
	
	# --- Player Health Integration ---
	if GameManager.has_signal("health_changed"):
		GameManager.health_changed.connect(_on_health_changed)
		
	# Initialize Gauge
	# Initialize Gauge
	if GameManager.player_data:
		gauge_l.max_value = GameManager.player_data.max_health
		gauge_r.max_value = GameManager.player_data.max_health
		_target_damage_value = float(GameManager.player_data.max_health - GameManager.player_data.health)
		gauge_l.value = (gauge_l.max_value * 0.10) + _target_damage_value
		gauge_r.value = (gauge_r.max_value * 0.10) + _target_damage_value
		

	# --- Wave Counter Integration ---
	if GameManager.has_signal("wave_changed"):
		GameManager.wave_changed.connect(_on_wave_changed)
		# Init
		_on_wave_changed(GameManager.current_wave, GameManager.total_waves)

	# --- Input Propagation Fix ---
	# Ensure the root controls do not swallow mouse events, allowing them to reach InputManager._unhandled_input
	mouse_filter = Control.MOUSE_FILTER_PASS
	if has_node("Background"):
		$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var viewport_container = $MainLayout/WorkspaceSplit/GameViewContainer
	if viewport_container:
		viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# --- UI Cursor Fix ---
	# Allow drag data to fall through these containers to the root
	# This prevents the "Forbidden" cursor when hovering empty sidebar/topbar areas
	var top_bar = $MainLayout/TopBar
	var left_sidebar = $MainLayout/WorkspaceSplit/LeftSidebar
	
	if top_bar: _set_container_mouse_ignore_recursive(top_bar)
	if left_sidebar: _set_container_mouse_ignore_recursive(left_sidebar)
	
	# --- Drag-to-Build Setup ---
	var game_view_container = $MainLayout/WorkspaceSplit/GameViewContainer
	
	# Create a dedicated Overlay Control to catch drop events
	# This bypasses SubViewportContainer's input swallowing
	var drop_overlay = Control.new()
	drop_overlay.name = "DropOverlay"
	drop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	drop_overlay.set_script(load("res://UI/Layout/game_view_dropper.gd"))
	
	game_view_container.add_child(drop_overlay)
	
	# Connect the success signal from the overlay
	if drop_overlay.has_signal("card_dropped"):
		drop_overlay.card_dropped.connect(_on_card_effect_completed_from_drag)
	
	# Initialise Deck
	if not player_deck:
		if FileAccess.file_exists("res://Config/Decks/player_deck.tres"):
			player_deck = load("res://Config/Decks/player_deck.tres")
			
	if player_deck:
		# Use 8 as the hand size for the grid
		_card_manager.initialise_deck(player_deck, 8)
		
	# Instantiating Inspector
	var inspector_scene = load("res://UI/Inspector/tower_inspector.tscn")
	if inspector_scene:
		_tower_inspector = inspector_scene.instantiate()
		game_view_container.add_child(_tower_inspector)
		# Ensure it's above the drop overlay (z-index or order)
		_tower_inspector.move_to_front()
		
		# Connect to BuildManager actions
		if _build_manager:
			_tower_inspector.sell_tower_requested.connect(_build_manager._on_sell_tower_requested)
			_tower_inspector.target_priority_changed.connect(_build_manager._on_target_priority_changed)


	# Ensure a level is loaded for testing
	if game_viewport.get_child_count() > 0:
		# Level already exists (from Editor or previous state), just wire it up
		_wire_up_level(game_viewport.get_child(0))
	else:
		# No level, load default
		_load_level(DEFAULT_LEVEL_PATH)

func _process(delta: float) -> void:
	if not is_instance_valid(gauge_l) or not is_instance_valid(gauge_r): return

	# 1. Update Noise (Simulate live signal jitter)
	# User Request: "Jitter moves up and down by 2%"
	var max_v = gauge_l.max_value
	var noise_amplitude = max_v * 0.02
	
	# Stereo Separation: Randomize L and R independently
	_meter_noise_offset_l = randf_range(-1.0, 1.0) * noise_amplitude
	_meter_noise_offset_r = randf_range(-1.0, 1.0) * noise_amplitude
	
	# Slight offset between channels (decorrelation)
	# User Request: "Around 1% difference"
	# We bias one channel slightly within 1% range
	var separation_bias = randf_range(-0.005, 0.005) * max_v
	_meter_noise_offset_r += separation_bias

	# 2. Lerp towards target value
	# User Request: "Starts at 10% of bars".
	# Logic: Display Value = (10% Base) + (Damage)
	var base_fill = max_v * 0.10
	var final_target = base_fill + _target_damage_value
	
	# Slower smooth speed (30% slower than 10.0 -> ~7.0)
	var smooth_speed = 7.0 * delta
	
	# L Channel
	var smoothed_l = lerp(gauge_l.value, final_target, smooth_speed)
	# Add noise to the smoothed value
	var final_l = smoothed_l + _meter_noise_offset_l
	gauge_l.value = clamp(final_l, 0.0, max_v)
	

	# R Channel
	var smoothed_r = lerp(gauge_r.value, final_target, smooth_speed)
	var final_r = smoothed_r + _meter_noise_offset_r
	gauge_r.value = clamp(final_r, 0.0, max_v)


func _setup_transport() -> void:
	# Load icons at runtime to avoid compile-time import errors
	if FileAccess.file_exists("res://UI/Icons/play.png"):
		icon_play = load("res://UI/Icons/play.png")
	if FileAccess.file_exists("res://UI/Icons/pause.png"):
		icon_pause = load("res://UI/Icons/pause.png")
		
	play_button.pressed.connect(_on_play_button_pressed)

func _on_play_button_pressed() -> void:
	if not icon_play or not icon_pause:
		printerr("Icons not initialized")
		return

	is_playing = not is_playing
	play_button.icon = icon_pause if is_playing else icon_play
	# TODO: Connect to SceneManager/GameLoop to actually pause/play
	print("Game State: ", "Playing" if is_playing else "Paused")

func _setup_menu() -> void:
	var popup = menu_button.get_popup()
	popup.add_item("Main Menu", MenuOptions.MAIN_MENU)
	popup.add_item("Quit", MenuOptions.QUIT)
	
	popup.id_pressed.connect(_on_menu_item_pressed)

func _setup_confirmations() -> void:
	main_menu_confirm.confirmed.connect(_on_main_menu_confirmed)
	quit_confirm.confirmed.connect(_on_quit_confirmed)

func _on_menu_item_pressed(id: int) -> void:
	match id:
		MenuOptions.MAIN_MENU:
			main_menu_confirm.popup_centered()
		MenuOptions.QUIT:
			quit_confirm.popup_centered()

func _on_main_menu_confirmed() -> void:
	# In a real scenario, you might want to reset global state here
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_quit_confirmed() -> void:
	get_tree().quit()

func _load_level(level_path: String) -> void:
	var level_scene = load(level_path)
	if level_scene:
		var level_instance = level_scene.instantiate()
		load_level_instance(level_instance)

# --- Card Logic ---

func _on_hand_changed(new_hand: Array[CardData]) -> void:
	# Clear existing children
	for child in card_grid.get_children():
		child.queue_free()
		
	# Populate grid
	for card_data in new_hand:
		var card_instance = CARD_SCENE.instantiate()
		card_grid.add_child(card_instance)
		
		# Layout: Fixed Cell Size Calculation
		# Width: (384 Sidebar - 40 Margins/Sep) / 2 = 172 (safe 162)
		# Height: (1080 Screen - 56 Top - 60 Header - 20 Margin - 60 Spacing) / 4 Rows = ~226
		# We use 215 to be safe and ensure the TopBar is never squashed.
		card_instance.custom_minimum_size = Vector2(162, 215)
		
		# Do NOT expand vertically to push the UI.
		# Just sit at the fixed size.
		card_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_instance.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		
		# Data
		card_instance.display(card_data)
		
	# Buff States are now handled via drag-and-drop validation, so cards are always playable.
	# _update_buff_cards_state(_selected_tower) - REMOVED


# --- INPUT HANDLING ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# User pressed Escape
		if _build_manager and _build_manager.state == _build_manager.State.BUILDING_TOWER:
			# If we are in build mode (dragging or ghost), cancel it.
			_build_manager.cancel_drag_ghost()
			
			# Note: We can't easily force the system to "drop" the drag data,
			# but cancelling the ghost tower is the visual feedback we need.
			# Godot's drag system might auto-cancel if Esc is standard, but if not:
			# The ghost disappears, and eventually the user releases the mouse.
			# If they release validly, validate_and_place() handles checks.

# --- DRAG AND DROP HANDLERS REPLACED BY GAME_VIEW_DROPPER ---


func _on_card_effect_completed_from_drag(card: Card) -> void:
	# Similar to _on_card_effect_completed but for specific card instance
	if not is_instance_valid(card): return
	
	var cost = card.card_data.effect.get_cost() # Re-verify cost
	GameManager.remove_currency(cost)
	
	var card_index = card.get_index()
	if card_index != -1:
		_card_manager.play_card_shift(card_index, {})


func _on_card_effect_completed(_card: Card) -> void:
	if not is_instance_valid(_active_card):
		return
		
	# 1. Deduct Cost
	var cost = _active_card.card_data.effect.get_cost()
	GameManager.remove_currency(cost)
	
	# 2. Update Deck (Shift & Draw)
	# Find index of active card in the grid
	var card_index = _active_card.get_index()
	if card_index != -1:
		_card_manager.play_card_shift(card_index, {})
		
	_active_card = null


func _on_card_effect_cancelled() -> void:
	# Create ghost cancelled, just reset active card
	_active_card = null


# --- Buff / Selection Logic ---

func _on_tower_selected(tower: TemplateTower) -> void:
	# Disconnect old
	if is_instance_valid(_selected_tower):
		# No longer need to manage buff signals strictly for UI updates
		pass
				
	_selected_tower = tower
	
	# Connect new
	if _tower_inspector and _tower_inspector.has_method("set_tower"):
		_tower_inspector.set_tower(tower)
		
		# Update Anchor based on tower position
		if is_instance_valid(tower):
			var viewport_size = game_viewport.size
			# Note: Tower position is global, but viewport might be offset? 
			# In this setup, the viewport covers the whole game area.
			# Tower global position corresponds to viewport pixels if no camera zoom/pan.
			# If there is a camera, we need screen position.
			# CRITICAL FIX: The tower is inside a SubViewport.
			# get_global_transform_with_canvas().origin returns coordinates relative to that SubViewport (0,0 is Top-Left of Game View).
			# But the TowerInspector is in the Main Screen Space (0,0 is Top-Left of Monitor).
			# We must ADD the offset of the SubViewportContainer to convert to Screen Space.
			var viewport_local_pos = tower.get_global_transform_with_canvas().origin
			var container_offset = Vector2.ZERO
			
			var container = $MainLayout/WorkspaceSplit/GameViewContainer
			if container:
				container_offset = container.global_position
				
			var final_screen_pos = viewport_local_pos + container_offset
			
			# Calculate Map Coordinates for Grid Logic
			var map_coords = Vector2i(-1, -1)
			if _build_manager and is_instance_valid(_build_manager.path_layer):
				# Tower Global Position is in Viewport Space (same as path_layer local if layer at 0,0)
				# PathLayer is likely a child of the Viewport.
				# We can use path_layer.local_to_map() on the tower's position relative to the layer.
				var layer = _build_manager.path_layer
				var tower_local_to_layer = layer.to_local(tower.global_position)
				map_coords = layer.local_to_map(tower_local_to_layer)
			
			_tower_inspector.update_anchor(viewport_size, final_screen_pos, map_coords)


func _on_tower_deselected() -> void:
	# _on_tower_selected(null) # Simplified
	if is_instance_valid(_selected_tower):
		_selected_tower.deselect()
		_selected_tower = null
		
	if _tower_inspector and _tower_inspector.has_method("set_tower"):
		_tower_inspector.set_tower(null)
		
func _on_selected_tower_buff_ended() -> void:
	pass # No longer needed

# _update_buff_cards_state function removed


func load_level_instance(level_instance: Node) -> void:
	# Clear any existing children in the viewport
	for child in game_viewport.get_children():
		child.queue_free()
	
	game_viewport.add_child(level_instance)
	_wire_up_level(level_instance)

# --- Drag Fix ---
# Prevent "Forbidden" cursor when hovering empty UI space
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "card_drag":
		# We are dragging over the UI (outside GameViewDropper)
		if _build_manager:
			var drag_id = data.get("drag_id", -1)
			
			# Case A: We are transitioning from Game -> UI (Exiting). Banish!
			if _build_manager.is_dragging():
				_build_manager.banish_drag_session()
				if data.get("preview"): data["preview"].visible = false
				
			# Case B: We are already banished. Keep hidden.
			elif _build_manager.is_drag_banished(drag_id):
				if data.get("preview"): data["preview"].visible = false
				
			# Case C: We are just starting (Sidebar). Not dragging yet, not banished.
			else:
				if data.get("preview"): data["preview"].visible = true
			
		return true
	return false

func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	pass

func _wire_up_level(level_instance: Node) -> void:
	# Update Build Manager References
	if _build_manager:
		var path_layer = level_instance.get_node_or_null("TileMaps/MapLayer")
		var highlight = level_instance.get_node_or_null("TileMaps/HighlightLayer")
		var towers = level_instance.get_node_or_null("Entities/Towers")
		
		if path_layer and highlight and towers:
			_build_manager.update_level_references(path_layer, highlight, towers)
		else:
			printerr("Failed to find required level nodes for BuildManager.")

func _set_container_mouse_ignore_recursive(node: Node, allow_buttons: bool = true) -> void:
	if node is Control:
		# If it's a structural container (Panel, Box, Margin), ignore mouse.
		# If it's an actionable button or input:
		# - If allow_buttons is TRUE: KEEP it (MOUSE_FILTER_STOP)
		# - If allow_buttons is FALSE: IGNORE it (drag falls through)
		# Identify interactive elements: Buttons, Inputs, OR Draggable items (Cards)
		var is_interactive = node is BaseButton or node is LineEdit or node is TextEdit or node is Tree or node is ItemList
		if not is_interactive and node.has_method("_get_drag_data"):
			is_interactive = true

		if is_interactive:
			if allow_buttons:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
	# Recursively apply to children
	for child in node.get_children():
		_set_container_mouse_ignore_recursive(child, allow_buttons)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		# User started dragging (likely a card).
		# Disable buttons so the drag 'falls through' to our drop handlers.
		var top_bar = $MainLayout/TopBar
		var left_sidebar = $MainLayout/WorkspaceSplit/LeftSidebar
		if top_bar: _set_container_mouse_ignore_recursive(top_bar, false)
		if left_sidebar: _set_container_mouse_ignore_recursive(left_sidebar, false)
		
	elif what == NOTIFICATION_DRAG_END:
		# Drag ended (dropped or cancelled).
		# Re-enable buttons.
		var top_bar = $MainLayout/TopBar
		var left_sidebar = $MainLayout/WorkspaceSplit/LeftSidebar
		if top_bar: _set_container_mouse_ignore_recursive(top_bar, true)
		if left_sidebar: _set_container_mouse_ignore_recursive(left_sidebar, true)
		
		# Ensure buff/drag state is cleaned up
		if _build_manager:
			_build_manager.cancel_drag_buff()

func _on_health_changed(new_health: int) -> void:
	if is_instance_valid(gauge_l) and GameManager.player_data:
		# Inverted Logic: Gauge shows "Damage" (Max - Current)
		# Low Health = High Gauge (Red)
		_target_damage_value = float(GameManager.player_data.max_health - new_health)


func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	if is_instance_valid(wave_label):
		wave_label.text = "Track: %d / %d" % [current_wave, total_waves]
