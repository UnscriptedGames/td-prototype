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

@onready var gauge_l: ProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerL/BarL
@onready var gauge_r: ProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerR/BarR
@onready var peak_line_l: ColorRect = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerL/BarL/PeakLineL
@onready var peak_line_r: ColorRect = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerR/BarR/PeakLineR

# Window Controls
@onready var btn_minimize: Button = $MainLayout/TopBar/Content/WindowControls/MinimizeButton
@onready var btn_maximize: Button = $MainLayout/TopBar/Content/WindowControls/MaximizeButton
@onready var btn_close: Button = $MainLayout/TopBar/Content/WindowControls/CloseButton


@onready var wave_label: Label = $MainLayout/TopBar/Content/WaveInfoPanel/InfoHBox/WaveLabel
@onready var speed_label: Label = $MainLayout/TopBar/Content/WaveInfoPanel/InfoHBox/SpeedLabel
@onready var gain_label: Label = $MainLayout/TopBar/Content/WaveInfoPanel/InfoHBox/GainLabel

# Card Grid
@onready var volume_button: Button = $MainLayout/TopBar/Content/TransportControls/VolumeButton
@onready var volume_slider: HSlider = $MainLayout/TopBar/Content/TransportControls/VolumeSlider
# Icons
var icon_play: Texture2D = preload("res://UI/Icons/play.svg")
var icon_pause: Texture2D = preload("res://UI/Icons/pause.svg")
var icon_volume: Texture2D = preload("res://UI/Icons/volume.svg")
var icon_mute: Texture2D = preload("res://UI/Icons/volume_mute.svg")

# State
var _build_manager: BuildManager
var _selected_tower: TemplateTower = null
var _tower_inspector: PanelContainer # Type is TowerInspector, loose coupling to avoid cyclic ref/lag
var _sidebar_hud: Control # Typed as Control to avoid resolution issues (SidebarHUD)

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

# Volume State
var _is_muted: bool = false
var _previous_volume: float = 80.0 # Default fallback


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
	_setup_window_controls()

	
	# Managers
	# Managers
	
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
			
			# Attach Drop Handler via Overlay
			# We use a child Control because SubViewportContainer has complex input handling
			var drop_zone = Control.new()
			drop_zone.name = "DropZone"
			drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
			drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS # Pass clicks to viewport, but catch drops?
			# Actually, for drop to work, it must handle it. If Pass, it handles it.
			
			container.add_child(drop_zone)
			drop_zone.set_script(load("res://UI/Layout/game_view_dropper.gd"))
			drop_zone.setup(_build_manager)
	
	# Setup Sidebar HUD
	# Setup Sidebar HUD
	var sidebar_container = $MainLayout/WorkspaceSplit/LeftSidebar
	if sidebar_container:
		for child in sidebar_container.get_children():
			child.queue_free()
			
		# Instantiate new HUD
		_sidebar_hud = (preload("res://UI/HUD/Sidebar/sidebar_hud.tscn")).instantiate()
		sidebar_container.add_child(_sidebar_hud)
	
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
		
	if volume_button:
		volume_button.pressed.connect(_on_volume_button_pressed)

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
		viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
		
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
	
	# DropOverlay code removed (game_view_dropper.gd deleted)
	var game_view_container = $MainLayout/WorkspaceSplit/GameViewContainer

	
	# Initialise Deck - REMOVED (Replaced by Loadout / SidebarHUD)
		
	# Instantiating Inspector
	var inspector_scene = load("res://UI/Inspector/tower_inspector.tscn")
	if inspector_scene:
		_tower_inspector = inspector_scene.instantiate()
		game_view_container.add_child(_tower_inspector)
		# Ensure it's above the drop overlay (z-index or order)
		_tower_inspector.move_to_front()
		_tower_inspector.visible = false # Hide by default
		# _tower_inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let it not block drops? 
		# But it needs to be interactive? 
		# For now, hiding it should prevent it from blocking if it's the culprit.
		
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


func _setup_window_controls() -> void:
	if btn_minimize:
		btn_minimize.pressed.connect(_on_minimize_pressed)
	if btn_maximize:
		btn_maximize.pressed.connect(_on_maximize_pressed)
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)

func _setup_transport() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	
	if speed_down_button:
		speed_down_button.pressed.connect(GameManager.step_speed_down)
	if speed_up_button:
		speed_up_button.pressed.connect(GameManager.step_speed_up)

func _on_play_button_pressed() -> void:
	GameManager.toggle_game_state()


func _on_minimize_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

func _on_maximize_pressed() -> void:
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_close_pressed() -> void:
	if quit_confirm:
		quit_confirm.popup_centered()

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


# --- Loadout Interaction ---

# --- Loadout Interaction ---

func _on_card_effect_completed_from_drag(_card_node: Node) -> void:
	# Logic moved to BuildManager/GameManager.
	# We might need this for visual feedback or sound?
	pass

func _on_card_effect_completed(_card_node: Node) -> void:
	pass


func _on_card_effect_cancelled() -> void:
	pass


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

# --- Drag Fix REPLACED (See end of file) ---
# Old logic removed to prevent duplicates.

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


func _on_volume_changed(value: float) -> void:
	# Convert 0-100 linear range to dB
	# Linear to dB: linear2db(value / 100.0)
	var linear_val = value / 100.0
	var db_val = linear_to_db(linear_val)
	
	var master_bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_idx, db_val)
	
	# Mute logic sync
	if value <= 0 and not _is_muted:
		_is_muted = true
		if volume_button: volume_button.icon = icon_mute
	elif value > 0 and _is_muted:
		_is_muted = false
		if volume_button: volume_button.icon = icon_volume


func _on_volume_button_pressed() -> void:
	if _is_muted:
		# UNMUTE
		_is_muted = false
		if volume_button: volume_button.icon = icon_volume
		
		# Restore previous volume
		if _previous_volume <= 0: _previous_volume = 50.0 # Safe default
		if volume_slider: volume_slider.value = _previous_volume
		
	else:
		# MUTE
		_is_muted = true
		if volume_button: volume_button.icon = icon_mute
		
		# Save current volume
		if volume_slider:
			_previous_volume = volume_slider.value
			volume_slider.value = 0


# --- DRAG AND DROP ---

# --- DRAG AND DROP ---
# Logic moved to game_view_dropper.gd attached to GameViewContainer
