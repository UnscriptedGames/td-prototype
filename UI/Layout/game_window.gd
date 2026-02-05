class_name GameWindow
extends Control

@onready var game_viewport: SubViewport = $MainLayout/WorkspaceSplit/GameViewContainer/SubViewport
@onready var menu_button: MenuButton = $MainLayout/TopBar/Content/MenuButton
@onready var main_menu_confirm: ConfirmationDialog = $MainMenuConfirmation
@onready var quit_confirm: ConfirmationDialog = $QuitConfirmation

# Transport Controls
@onready var play_button: Button = $MainLayout/TopBar/Content/TransportControls/PlayButton
@onready var speed_down_button: Button = $MainLayout/TopBar/Content/TransportControls/SpeedDownButton
@onready var speed_up_button: Button = $MainLayout/TopBar/Content/TransportControls/SpeedUpButton

@onready var gauge_l: TextureProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/GaugeLContainer/Wrapper/GaugeL
@onready var gauge_r: TextureProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/GaugeRContainer/Wrapper/GaugeR
@onready var peak_line_l: ColorRect = $MainLayout/TopBar/Content/PerformanceMeterContainer/GaugeLContainer/Wrapper/PeakLineL
@onready var peak_line_r: ColorRect = $MainLayout/TopBar/Content/PerformanceMeterContainer/GaugeRContainer/Wrapper/PeakLineR


@onready var wave_label: Label = $MainLayout/TopBar/Content/TransportControls/WaveInfoPanel/InfoHBox/WaveLabel
@onready var speed_label: Label = $MainLayout/TopBar/Content/TransportControls/WaveInfoPanel/InfoHBox/SpeedLabel
@onready var gain_label: Label = $MainLayout/TopBar/Content/TransportControls/WaveInfoPanel/InfoHBox/GainLabel

# Card Grid
@onready var card_grid: GridContainer = $MainLayout/WorkspaceSplit/LeftSidebar/SidebarContent/CardMarginContainer/CardGrid
@onready var volume_slider: HSlider = $MainLayout/TopBar/Content/TransportControls/VolumeSlider
@export var player_deck: Resource # Loaded as DeckData

# Icons
var icon_play: Texture2D
var icon_pause: Texture2D

# Assets
const CARD_SCENE = preload("res://Entities/Cards/card.tscn")

# State
var _card_manager: CardManager
var _build_manager: BuildManager
var _active_card: Card # Track the card currently being played/previewed
var _selected_tower: TemplateTower = null
var _tower_inspector: PanelContainer # Type is TowerInspector, loose coupling to avoid cyclic ref/lag

# Meter Animation State
var _target_damage_value: float = 0.0
var _meter_noise_offset_l: float = 0.0
var _meter_noise_offset_r: float = 0.0

# Peak Hold State
var _peak_val_l: float = 0.0
var _peak_val_r: float = 0.0
var _peak_hold_timer_l: float = 0.0
var _peak_hold_timer_r: float = 0.0
const PEAK_HOLD_TIME: float = 0.75
const PEAK_DECAY_RATE: float = 25.0 # dB/sec equivalent

# Jitter Settings
const JITTER_SPEED: float = 20.0 # How fast the noise fluctuates (Higher = Faster)
const JITTER_AMPLITUDE: float = 0.01 # 2% of max value
const STEREO_SEPARATION: float = 0.15 # 0.0 = Mono (Synced), 1.0 = Independent

# Jitter State
var _noise_target_common: float = 0.0
var _noise_val_common: float = 0.0
var _noise_target_diff: float = 0.0
var _noise_val_diff: float = 0.0


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

	# --- Gain (Currency) Integration ---
	if GameManager.has_signal("currency_changed"):
		GameManager.currency_changed.connect(_on_gain_changed)
		# Init
		if GameManager.player_data:
			_on_gain_changed(GameManager.player_data.currency)

	# --- Game State Integration ---
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)
		
	if GameManager.has_signal("wave_status_changed"):
		GameManager.wave_status_changed.connect(_on_wave_status_changed)

	if GameManager.has_signal("game_speed_changed"):
		GameManager.game_speed_changed.connect(_on_game_speed_changed)
		# Init Label
		_on_game_speed_changed(Engine.time_scale)

	# --- Volume Integration ---
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
		# Initialize slider with current Master bus volume
		var master_bus_idx = AudioServer.get_bus_index("Master")
		var vol_db = AudioServer.get_bus_volume_db(master_bus_idx)
		volume_slider.value = db_to_linear(vol_db) * 100.0

	# Init UI state based on current data
	_update_play_button_visuals()


	# --- Input Propagation Fix ---
	# Ensure the root controls do not swallow mouse events, allowing them to reach InputManager._unhandled_input
	mouse_filter = Control.MOUSE_FILTER_PASS
	if has_node("Background"):
		$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var viewport_container = $MainLayout/WorkspaceSplit/GameViewContainer
	if viewport_container:
		# IMPORTANT: GameWindow is PROCESS_MODE_ALWAYS (to handle UI inputs).
		# We must explicitly set the game container to PAUSABLE so it respects get_tree().paused.
		viewport_container.process_mode = Node.PROCESS_MODE_PAUSABLE
		viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Explicitly set the SubViewport as well, just to be safe/sure.
		if viewport_container.get_child_count() > 0:
			var vp = viewport_container.get_child(0)
			if vp is SubViewport:
				vp.process_mode = Node.PROCESS_MODE_PAUSABLE
	
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
	# Logic: Smoothed Random Walk for "Analog" feel.
	var max_v = gauge_l.max_value
	var noise_amp_val = max_v * JITTER_AMPLITUDE
	
	# Update Common Signal (Master Jitter)
	# If we are close to target, pick new one
	if abs(_noise_val_common - _noise_target_common) < 0.05:
		_noise_target_common = randf_range(-1.0, 1.0)
	
	# Update Difference Signal (Stereo Width Jitter)
	if abs(_noise_val_diff - _noise_target_diff) < 0.05:
		_noise_target_diff = randf_range(-1.0, 1.0)
		
	# Move towards targets (Speed Control)
	_noise_val_common = lerp(_noise_val_common, _noise_target_common, delta * JITTER_SPEED)
	_noise_val_diff = lerp(_noise_val_diff, _noise_target_diff, delta * JITTER_SPEED)
	
	# Calculate Final Offsets
	# L = Common + (Diff * Sep)
	# R = Common - (Diff * Sep)
	# This ensures they move together but deviate by the Separation amount
	var common_offset = _noise_val_common * noise_amp_val
	var diff_offset = _noise_val_diff * noise_amp_val * STEREO_SEPARATION
	
	_meter_noise_offset_l = common_offset + diff_offset
	_meter_noise_offset_r = common_offset - diff_offset


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
	
	_update_peak_hold(final_l, delta, true)

	# R Channel
	var smoothed_r = lerp(gauge_r.value, final_target, smooth_speed)
	var final_r = smoothed_r + _meter_noise_offset_r
	gauge_r.value = clamp(final_r, 0.0, max_v)
	
	_update_peak_hold(final_r, delta, false)

func _update_peak_hold(current_val: float, delta: float, is_left: bool) -> void:
	# Reference correct channel data
	var peak_val = _peak_val_l if is_left else _peak_val_r
	var timer = _peak_hold_timer_l if is_left else _peak_hold_timer_r
	var line = peak_line_l if is_left else peak_line_r
	# Verify node validity before access
	if not is_instance_valid(gauge_l): return
	var max_v = gauge_l.max_value
	
	# Logic: Push
	if current_val > peak_val:
		peak_val = current_val
		timer = PEAK_HOLD_TIME
	else:
		# Decay
		if timer > 0:
			timer -= delta
		else:
			# Decay Rate proportional to max range? 
			# Let's use linear decay
			peak_val -= PEAK_DECAY_RATE * delta
			
		# Clamp to prevent falling below current signal
		if peak_val < current_val:
			peak_val = current_val
			
	# Update State back to variables
	if is_left:
		_peak_val_l = peak_val
		_peak_hold_timer_l = timer
	else:
		_peak_val_r = peak_val
		_peak_hold_timer_r = timer
		
	# Update Visual Position
	if is_instance_valid(line) and is_instance_valid(line.get_parent()):
		# Width of container - line width
		# Line parent is Wrapper (Control), parent of Wrapper is Container (or Wrapper size is set by anchors)
		# Wrapper has anchor_right=1.0, so use its size
		var width = line.get_parent().size.x - line.size.x
		if width > 0:
			var pct = clamp(peak_val / max_v, 0.0, 1.0)
			line.position.x = width * pct


func _setup_transport() -> void:
	# Load icons at runtime to avoid compile-time import errors
	if FileAccess.file_exists("res://UI/Icons/play.png"):
		icon_play = load("res://UI/Icons/play.png")
	if FileAccess.file_exists("res://UI/Icons/pause.png"):
		icon_pause = load("res://UI/Icons/pause.png")
		
	play_button.pressed.connect(_on_play_button_pressed)
	
	if speed_down_button:
		speed_down_button.pressed.connect(GameManager.step_speed_down)
	if speed_up_button:
		speed_up_button.pressed.connect(GameManager.step_speed_up)

func _on_play_button_pressed() -> void:
	GameManager.toggle_game_state()


func _on_volume_changed(value: float) -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	# Convert 0-100 linear scale to decibels
	var vol_db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(master_bus_idx, vol_db)
	
	# Optional: Mute if volume is very low
	AudioServer.set_bus_mute(master_bus_idx, value <= 0.0)


func _on_game_state_changed(new_state: int) -> void:
	_update_play_button_visuals()
	
	# Block interactions when paused
	var is_paused = (new_state == GameManager.GameState.PAUSED)
	
	# Block Sidebar (Cards) and other non-system UI
	if has_node("MainLayout/WorkspaceSplit/LeftSidebar"):
		_set_container_input_state($MainLayout/WorkspaceSplit/LeftSidebar, not is_paused)
		
	# Note: TopBar must remain active so we can Unpause!
	# But maybe specific children of TopBar (like buttons other than Play) should be disabled?
	# For now, allowing TopBar is safer usage.


func _set_container_input_state(node: Node, enabled: bool) -> void:
	if node is Control:
		if node is BaseButton or node is LineEdit:
			node.disabled = not enabled
		
		# For draggable controls (Cards), we must block mouse events entirely
		if not enabled:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			# Restore. 
			if node is BaseButton:
				node.mouse_filter = Control.MOUSE_FILTER_STOP # Buttons usually Stop
			elif node.has_method("_get_drag_data"):
				node.mouse_filter = Control.MOUSE_FILTER_STOP # Draggables usually Stop
			else:
				node.mouse_filter = Control.MOUSE_FILTER_PASS # Containers usually Pass
			
	for child in node.get_children():
		_set_container_input_state(child, enabled)


func _on_wave_status_changed(_is_active: bool) -> void:
	_update_play_button_visuals()


func _on_game_speed_changed(new_speed: float) -> void:
	if speed_label:
		speed_label.text = "Speed: %.2fx" % new_speed


func _update_play_button_visuals() -> void:
	if not icon_play or not icon_pause:
		return
	
	# Logic:
	# If NO wave active -> Show Play (Meaning "Start Next Wave")
	# If Wave Active AND Playing -> Show Pause (Meaning "Pause Game")
	# If Wave Active AND Paused -> Show Play (Meaning "Resume Game")
	
	var show_pause_icon: bool = false
	
	if GameManager.is_wave_active:
		if GameManager.game_state == GameManager.GameState.PLAYING:
			show_pause_icon = true
		else:
			show_pause_icon = false # Paused, so show Play to resume
	else:
		show_pause_icon = false # Idle, show Play to start next wave
		
	play_button.icon = icon_pause if show_pause_icon else icon_play

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
	get_tree().paused = false # Valid state for Main Menu
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
	
	# var cost = card.card_data.effect.get_cost() 
	# GameManager.remove_currency(cost) -> Handled by BuildManager
	
	var card_index = card.get_index()
	if card_index != -1:
		_card_manager.play_card_shift(card_index, {})


func _on_card_effect_completed(_card: Card) -> void:
	if not is_instance_valid(_active_card):
		return
		
	# 1. Deduct Cost
	# var cost = _active_card.card_data.effect.get_cost()
	# GameManager.remove_currency(cost) -> Handled by BuildManager
	
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
		var path_layer = level_instance.get_node_or_null("TileMaps/MazeLayer")
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
		var is_interactive = node is BaseButton or node is LineEdit or node is TextEdit or node is Tree or node is ItemList or node is Range
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


func _on_gain_changed(new_gain: int) -> void:
	if is_instance_valid(gain_label):
		gain_label.text = "Gain: %d dB" % new_gain
