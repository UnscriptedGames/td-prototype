## Root UI controller for the game session.
## Manages the top bar (transport, meters, menus), sidebar HUD, tower inspector,
## and the game SubViewport. Delegates drag-and-drop to GameViewDropper.
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

# Volume Controls
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
var _tower_inspector: PanelContainer # Typed loose to avoid cyclic ref with TowerInspector
var _sidebar_hud: Control # Typed loose to avoid cyclic ref with SidebarHUD

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
var _previous_volume: float = 80.0

const DEFAULT_LEVEL_PATH: String = "res://Levels/_TemplateLevel/template_level.tscn"
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
	_setup_build_manager()
	_setup_sidebar_hud()
	_setup_signal_connections()
	_update_play_button_visuals()
	_setup_input_propagation()
	_setup_inspector()
	_setup_level()


## Acquires the BuildManager from InputManager, binds the SubViewport, and
## creates the GameViewDropper overlay for drag-and-drop tower placement.
func _setup_build_manager() -> void:
	if not InputManager.has_method("get_build_manager"):
		return

	_build_manager = InputManager.get_build_manager()
	if not _build_manager:
		return

	_build_manager.tower_selected.connect(_on_tower_selected)
	_build_manager.tower_deselected.connect(_on_tower_deselected)

	# Bind Viewport
	var viewport: SubViewport = $MainLayout/WorkspaceSplit/GameViewContainer/SubViewport
	var container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewContainer
	_build_manager.bind_to_viewport(viewport, container)

	# Attach drop handler via child Control overlay
	var drop_zone: Control = Control.new()
	drop_zone.name = "DropZone"
	drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS

	container.add_child(drop_zone)
	drop_zone.set_script(load("res://UI/Layout/game_view_dropper.gd"))
	drop_zone.setup(_build_manager)


## Instantiates the SidebarHUD scene into the left sidebar panel, replacing
## any existing children.
func _setup_sidebar_hud() -> void:
	var sidebar_container: PanelContainer = $MainLayout/WorkspaceSplit/LeftSidebar
	if not sidebar_container:
		return

	for child: Node in sidebar_container.get_children():
		child.queue_free()

	_sidebar_hud = (preload("res://UI/HUD/Sidebar/sidebar_hud.tscn")).instantiate()
	sidebar_container.add_child(_sidebar_hud)


## Wires up GameManager signals for wave tracking, currency display, game
## state changes, speed updates, and volume control.
func _setup_signal_connections() -> void:
	# Wave counter
	if GameManager.has_signal("wave_changed"):
		GameManager.wave_changed.connect(_on_wave_changed)
		_on_wave_changed(GameManager.current_wave, GameManager.total_waves)

	# Currency display
	if GameManager.has_signal("currency_changed"):
		GameManager.currency_changed.connect(_on_gain_changed)
		if GameManager.player_data:
			_on_gain_changed(GameManager.player_data.currency)

	# Game state (pause/play)
	if GameManager.has_signal("game_state_changed"):
		GameManager.game_state_changed.connect(_on_game_state_changed)

	# Peak Meter display
	if GameManager.has_signal("peak_meter_changed"):
		GameManager.peak_meter_changed.connect(_on_peak_changed)
		_on_peak_changed(GameManager.current_peak, GameManager.MAX_PEAK)

	# Wave active/idle
	if GameManager.has_signal("wave_status_changed"):
		GameManager.wave_status_changed.connect(_on_wave_status_changed)

	# Speed multiplier
	if GameManager.has_signal("game_speed_changed"):
		GameManager.game_speed_changed.connect(_on_game_speed_changed)
		_on_game_speed_changed(Engine.time_scale)

	# Volume slider + mute button
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
		var master_bus_idx: int = AudioServer.get_bus_index("Master")
		var vol_db: float = AudioServer.get_bus_volume_db(master_bus_idx)
		volume_slider.value = db_to_linear(vol_db) * 100.0

	if volume_button:
		volume_button.pressed.connect(_on_volume_button_pressed)


## Configures mouse filters and process modes so that UI containers do not
## swallow mouse events intended for InputManager or the game SubViewport.
func _setup_input_propagation() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if has_node("Background"):
		$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport_container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewContainer
	if viewport_container:
		# GameWindow is PROCESS_MODE_ALWAYS for UI; game container must be PAUSABLE
		viewport_container.process_mode = Node.PROCESS_MODE_PAUSABLE
		viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS

		if viewport_container.get_child_count() > 0:
			var vp: SubViewport = viewport_container.get_child(0) as SubViewport
			assert(vp != null)
			vp.process_mode = Node.PROCESS_MODE_PAUSABLE

	# Allow drag data to fall through containers (prevents "Forbidden" cursor)
	var top_bar: PanelContainer = $MainLayout/TopBar
	var left_sidebar: PanelContainer = $MainLayout/WorkspaceSplit/LeftSidebar

	if top_bar: _set_container_mouse_ignore_recursive(top_bar)
	if left_sidebar: _set_container_mouse_ignore_recursive(left_sidebar)


## Instantiates the TowerInspector panel inside the game view container and
## connects its action signals to the BuildManager.
func _setup_inspector() -> void:
	var game_view_container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewContainer
	var inspector_scene: PackedScene = load("res://UI/Inspector/tower_inspector.tscn")
	if not inspector_scene:
		return

	_tower_inspector = inspector_scene.instantiate()
	game_view_container.add_child(_tower_inspector)
	_tower_inspector.move_to_front()
	_tower_inspector.visible = false

	if _build_manager:
		_tower_inspector.sell_tower_requested.connect(_build_manager._on_sell_tower_requested)
		_tower_inspector.target_priority_changed.connect(
			_build_manager._on_target_priority_changed
		)


## Loads or wires up the initial level. If a level already exists in the
## SubViewport (e.g. from the Editor), it is wired up directly.
func _setup_level() -> void:
	if game_viewport.get_child_count() > 0:
		_wire_up_level(game_viewport.get_child(0))
	else:
		_load_level(DEFAULT_LEVEL_PATH)


## Animates performance meters with smoothed jitter and peak-hold indicators.
func _process(delta: float) -> void:
	if not is_instance_valid(gauge_l) or not is_instance_valid(gauge_r): return
	
	# We want UI meters to animate smoothly even if the game is fast-forwarding,
	# so we get the raw, unscaled delta time by removing the time_scale multiplier.
	var time_scale: float = Engine.time_scale
	var unscaled_delta: float = delta / time_scale if time_scale > 0.0 else 0.0

	# 1. Update Noise (simulate live signal jitter for "analogue" feel)
	var max_v: float = gauge_l.max_value
	var noise_amp_val: float = max_v * JITTER_AMPLITUDE

	# Common signal — master jitter shared between L and R
	if abs(_noise_val_common - _noise_target_common) < 0.05:
		_noise_target_common = randf_range(-1.0, 1.0)

	# Difference signal — stereo width jitter
	if abs(_noise_val_diff - _noise_target_diff) < 0.05:
		_noise_target_diff = randf_range(-1.0, 1.0)

	_noise_val_common = lerp(_noise_val_common, _noise_target_common, unscaled_delta * JITTER_SPEED)
	_noise_val_diff = lerp(_noise_val_diff, _noise_target_diff, unscaled_delta * JITTER_SPEED)

	# Final offsets: L = Common + Diff, R = Common - Diff
	var common_offset: float = _noise_val_common * noise_amp_val
	var diff_offset: float = _noise_val_diff * noise_amp_val * STEREO_SEPARATION

	_meter_noise_offset_l = common_offset + diff_offset
	_meter_noise_offset_r = common_offset - diff_offset

	# 2. Lerp towards target value (display = 10% base + damage)
	var base_fill: float = max_v * 0.10
	var final_target: float = base_fill + _target_damage_value
	var smooth_speed: float = 7.0 * unscaled_delta

	# L Channel
	var smoothed_l: float = lerp(gauge_l.value, final_target, smooth_speed)
	var final_l: float = smoothed_l + _meter_noise_offset_l
	gauge_l.value = clamp(final_l, 0.0, max_v)
	_update_peak_hold(final_l, unscaled_delta, true)

	# R Channel
	var smoothed_r: float = lerp(gauge_r.value, final_target, smooth_speed)
	var final_r: float = smoothed_r + _meter_noise_offset_r
	gauge_r.value = clamp(final_r, 0.0, max_v)
	_update_peak_hold(final_r, unscaled_delta, false)


## Updates peak-hold indicator position for one channel. The peak value is
## held for PEAK_HOLD_TIME seconds, then decays linearly.
func _update_peak_hold(current_val: float, delta: float, is_left: bool) -> void:
	var peak_val: float = _peak_val_l if is_left else _peak_val_r
	var timer: float = _peak_hold_timer_l if is_left else _peak_hold_timer_r
	var line: ColorRect = peak_line_l if is_left else peak_line_r

	if not is_instance_valid(gauge_l): return
	var max_v: float = gauge_l.max_value

	# Push peak upward when signal exceeds current peak
	if current_val > peak_val:
		peak_val = current_val
		timer = PEAK_HOLD_TIME
	else:
		if timer > 0:
			timer -= delta
		else:
			peak_val -= PEAK_DECAY_RATE * delta

		# Clamp to prevent falling below current signal
		if peak_val < current_val:
			peak_val = current_val

	# Write back to correct channel
	if is_left:
		_peak_val_l = peak_val
		_peak_hold_timer_l = timer
	else:
		_peak_val_r = peak_val
		_peak_hold_timer_r = timer

	# Update visual position of peak line
	if is_instance_valid(line) and is_instance_valid(line.get_parent()):
		var width: float = line.get_parent().size.x - line.size.x
		if width > 0:
			var pct: float = clamp(peak_val / max_v, 0.0, 1.0)
			line.position.x = width * pct


## Connects window chrome buttons (minimise, maximise, close).
func _setup_window_controls() -> void:
	if btn_minimize:
		btn_minimize.pressed.connect(_on_minimize_pressed)
	if btn_maximize:
		btn_maximize.pressed.connect(_on_maximize_pressed)
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)


## Connects transport bar buttons (play/pause, speed up, speed down).
func _setup_transport() -> void:
	play_button.pressed.connect(_on_play_button_pressed)

	if speed_down_button:
		speed_down_button.pressed.connect(GameManager.step_speed_down)
	if speed_up_button:
		speed_up_button.pressed.connect(GameManager.step_speed_up)


## Toggles the game between playing and paused states.
func _on_play_button_pressed() -> void:
	GameManager.toggle_game_state()


## Minimises the application window.
func _on_minimize_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


## Toggles between windowed and fullscreen modes.
func _on_maximize_pressed() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Opens the quit confirmation dialog.
func _on_close_pressed() -> void:
	if quit_confirm:
		quit_confirm.popup_centered()


## Responds to game state changes by updating the play button icon and
## toggling sidebar interaction (disabled when paused).
func _on_game_state_changed(new_state: int) -> void:
	_update_play_button_visuals()

	var is_paused: bool = (new_state == GameManager.GameState.PAUSED)

	if has_node("MainLayout/WorkspaceSplit/LeftSidebar"):
		_set_container_input_state($MainLayout/WorkspaceSplit/LeftSidebar, not is_paused)


## Recursively enables or disables input on a container and its children.
## Buttons and draggable controls are disabled; containers have their mouse
## filter set to IGNORE (disabled) or PASS (enabled).
func _set_container_input_state(node: Node, enabled: bool) -> void:
	if node is Control:
		if node is BaseButton or node is LineEdit:
			node.disabled = not enabled

		if not enabled:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			if node is BaseButton:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
			elif node.has_method("_get_drag_data"):
				node.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				node.mouse_filter = Control.MOUSE_FILTER_PASS

	for child: Node in node.get_children():
		_set_container_input_state(child, enabled)


## Updates the play button icon when the wave active/idle status changes.
func _on_wave_status_changed(_is_active: bool) -> void:
	_update_play_button_visuals()


## Updates the speed label when the game speed multiplier changes.
func _on_game_speed_changed(new_speed: float) -> void:
	if speed_label:
		speed_label.text = "Speed: %.2fx" % new_speed


## Sets the play button icon based on the current game and wave state.
## Idle or paused → play icon. Active and playing → pause icon.
func _update_play_button_visuals() -> void:
	if not icon_play or not icon_pause:
		return

	var show_pause_icon: bool = false

	if GameManager.is_wave_active:
		if GameManager.game_state == GameManager.GameState.PLAYING:
			show_pause_icon = true

	play_button.icon = icon_pause if show_pause_icon else icon_play


## Populates the top-bar dropdown menu with Main Menu and Quit options.
func _setup_menu() -> void:
	var popup: PopupMenu = menu_button.get_popup()
	popup.add_item("Main Menu", MenuOptions.MAIN_MENU)
	popup.add_item("Quit", MenuOptions.QUIT)

	popup.id_pressed.connect(_on_menu_item_pressed)


## Connects confirmation dialog signals.
func _setup_confirmations() -> void:
	main_menu_confirm.confirmed.connect(_on_main_menu_confirmed)
	quit_confirm.confirmed.connect(_on_quit_confirmed)


## Routes menu dropdown selections to their confirmation dialogs.
func _on_menu_item_pressed(id: int) -> void:
	match id:
		MenuOptions.MAIN_MENU:
			main_menu_confirm.popup_centered()
		MenuOptions.QUIT:
			quit_confirm.popup_centered()


## Unpauses the tree and returns to the main menu scene.
func _on_main_menu_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


## Quits the application.
func _on_quit_confirmed() -> void:
	get_tree().quit()


## Loads a level scene from a file path into the game SubViewport.
func _load_level(level_path: String) -> void:
	var level_scene: PackedScene = load(level_path)
	if level_scene:
		var level_instance: Node = level_scene.instantiate()
		load_level_instance(level_instance)


## Shows the tower inspector anchored to the selected tower's screen position.
func _on_tower_selected(tower: TemplateTower) -> void:
	_selected_tower = tower

	if _tower_inspector and _tower_inspector.has_method("set_tower"):
		_tower_inspector.set_tower(tower)

		# Convert tower's SubViewport position to main screen space
		if is_instance_valid(tower):
			var viewport_size: Vector2i = game_viewport.size
			var viewport_local_pos: Vector2 = tower.get_global_transform_with_canvas().origin
			var container_offset: Vector2 = Vector2.ZERO

			var container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewContainer
			if container:
				container_offset = container.global_position

			var final_screen_pos: Vector2 = viewport_local_pos + container_offset

			# Calculate map coordinates for inspector grid-side logic
			var map_coords: Vector2i = Vector2i(-1, -1)
			if _build_manager and is_instance_valid(_build_manager.path_layer):
				var layer: TileMapLayer = _build_manager.path_layer
				var tower_local_to_layer: Vector2 = layer.to_local(tower.global_position)
				map_coords = layer.local_to_map(tower_local_to_layer)

			_tower_inspector.update_anchor(viewport_size, final_screen_pos, map_coords)


## Hides the tower inspector and deselects the current tower.
func _on_tower_deselected() -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.deselect()
		_selected_tower = null

	if _tower_inspector and _tower_inspector.has_method("set_tower"):
		_tower_inspector.set_tower(null)


## Clears the SubViewport and loads a new level instance into it.
func load_level_instance(level_instance: Node) -> void:
	for child: Node in game_viewport.get_children():
		child.queue_free()

	game_viewport.add_child(level_instance)
	_wire_up_level(level_instance)


## Connects a level instance's required nodes to the BuildManager and wires
## up opening sequence signals for UI locking.
func _wire_up_level(level_instance: Node) -> void:
	if _build_manager:
		var path_layer: TileMapLayer = level_instance.get_node_or_null("TileMaps/MazeLayer")
		var highlight: TileMapLayer = level_instance.get_node_or_null("TileMaps/HighlightLayer")
		var towers: Node = level_instance.get_node_or_null("Entities/Towers")

		if path_layer and highlight and towers:
			_build_manager.update_level_references(path_layer, highlight, towers)
		else:
			printerr("Failed to find required level nodes for BuildManager.")

	# Wire up opening sequence signals
	if level_instance is TemplateLevel:
		var level: TemplateLevel = level_instance as TemplateLevel
		if not level.opening_sequence_started.is_connected(_on_opening_sequence_started):
			level.opening_sequence_started.connect(_on_opening_sequence_started)
		if not level.opening_sequence_finished.is_connected(_on_opening_sequence_finished):
			level.opening_sequence_finished.connect(_on_opening_sequence_finished)

		if level.play_opening_sequence:
			_set_ui_interaction(false)
		else:
			_set_ui_interaction(true)


## Locks UI interaction when the opening sequence begins.
func _on_opening_sequence_started() -> void:
	_set_ui_interaction(false)


## Restores UI interaction when the opening sequence ends.
func _on_opening_sequence_finished() -> void:
	_set_ui_interaction(true)


## Enables or disables interaction on the top bar and sidebar containers.
func _set_ui_interaction(enabled: bool) -> void:
	var top_bar: PanelContainer = $MainLayout/TopBar
	var left_sidebar: PanelContainer = $MainLayout/WorkspaceSplit/LeftSidebar

	if top_bar:
		_set_container_input_state(top_bar, enabled)
	if left_sidebar:
		_set_container_input_state(left_sidebar, enabled)


## Recursively sets mouse filters on a container tree. Interactive controls
## (buttons, sliders, draggables) keep MOUSE_FILTER_STOP when allow_buttons
## is true; all other containers are set to MOUSE_FILTER_IGNORE.
func _set_container_mouse_ignore_recursive(
	node: Node, allow_buttons: bool = true
) -> void:
	if node is Control:
		var is_interactive: bool = (
			node is BaseButton or node is LineEdit or node is TextEdit
			or node is Tree or node is ItemList or node is Range
		)
		if not is_interactive and node.has_method("_get_drag_data"):
			is_interactive = true

		if is_interactive:
			if allow_buttons:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in node.get_children():
		_set_container_mouse_ignore_recursive(child, allow_buttons)


## Handles drag begin/end notifications. During a drag, all buttons in the
## top bar and sidebar are set to IGNORE so drops fall through to the
## GameViewDropper overlay. Restored on drag end.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var top_bar: PanelContainer = $MainLayout/TopBar
		var left_sidebar: PanelContainer = $MainLayout/WorkspaceSplit/LeftSidebar
		if top_bar: _set_container_mouse_ignore_recursive(top_bar, false)
		if left_sidebar: _set_container_mouse_ignore_recursive(left_sidebar, false)

	elif what == NOTIFICATION_DRAG_END:
		var top_bar: PanelContainer = $MainLayout/TopBar
		var left_sidebar: PanelContainer = $MainLayout/WorkspaceSplit/LeftSidebar
		if top_bar: _set_container_mouse_ignore_recursive(top_bar, true)
		if left_sidebar: _set_container_mouse_ignore_recursive(left_sidebar, true)

		# Ensure buff/drag state is cleaned up
		if _build_manager:
			_build_manager.cancel_drag_buff()


## Updates the wave counter label when the current wave changes.
func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	if is_instance_valid(wave_label):
		wave_label.text = "Track: %d / %d" % [current_wave, total_waves]


## Updates the currency display label.
func _on_gain_changed(new_gain: int) -> void:
	if is_instance_valid(gain_label):
		gain_label.text = "Gain: %d dB" % new_gain


## Updates the peak meter visual target.
func _on_peak_changed(current: float, max_val: float) -> void:
	if max_val > 0.0 and is_instance_valid(gauge_l):
		# We reserve the first 10% for base fill, so map 0-max to 0-90%.
		_target_damage_value = (current / max_val) * (gauge_l.max_value * 0.90)


## Converts the volume slider's 0–100 linear range to dB and applies it to
## the Master audio bus. Syncs the mute icon state.
func _on_volume_changed(value: float) -> void:
	var linear_val: float = value / 100.0
	var db_val: float = linear_to_db(linear_val)

	var master_bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_idx, db_val)

	# Sync mute icon with slider position
	if value <= 0 and not _is_muted:
		_is_muted = true
		if volume_button: volume_button.icon = icon_mute
	elif value > 0 and _is_muted:
		_is_muted = false
		if volume_button: volume_button.icon = icon_volume


## Toggles mute state. Muting saves the current volume and sets the slider
## to 0; unmuting restores the saved volume.
func _on_volume_button_pressed() -> void:
	if _is_muted:
		_is_muted = false
		if volume_button: volume_button.icon = icon_volume

		if _previous_volume <= 0: _previous_volume = 50.0
		if volume_slider: volume_slider.value = _previous_volume
	else:
		_is_muted = true
		if volume_button: volume_button.icon = icon_mute

		if volume_slider:
			_previous_volume = volume_slider.value
			volume_slider.value = 0
