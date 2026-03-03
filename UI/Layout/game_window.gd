## Root UI controller for the game session.
## Manages the top bar (transport, meters, menus), sidebar HUD, tower inspector,
## and the game SubViewport. Delegates drag-and-drop to GameViewDropper.
class_name GameWindow
extends Control

@onready
var game_viewport: SubViewport = $MainLayout/WorkspaceSplit/GameViewWrapper/GameViewContainer/SubViewport
@onready
var ui_workspace: MarginContainer = $MainLayout/WorkspaceSplit/GameViewWrapper/UIWorkspaceContainer
@export var sidebar_overlay_anim_time: float = 0.4

@onready
var game_view_container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewWrapper/GameViewContainer

@onready var sidebar_overlay: Control = $MainLayout/WorkspaceSplit/SidebarContainer/SidebarOverlay
@onready
var overlay_content: MarginContainer = $MainLayout/WorkspaceSplit/SidebarContainer/SidebarOverlay/OverlayContent
@onready
var status_label: Label = $MainLayout/WorkspaceSplit/SidebarContainer/SidebarOverlay/OverlayContent/StatusLabel

@onready var menu_button: Button = $MainLayout/TopBar/Content/MenuButton
@onready var main_menu_confirm: ConfirmationDialog = $MainMenuConfirmation
@onready var setlist_confirm: ConfirmationDialog = $SetlistConfirmation
@onready var quit_confirm: ConfirmationDialog = $QuitConfirmation

# Transport Controls
@onready var play_button: Button = $MainLayout/TopBar/Content/TransportControls/PlayButton
@onready var restart_button: Button = $MainLayout/TopBar/Content/TransportControls/RestartButton

@onready
var gauge_l: ProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerL/BarL
@onready
var gauge_r: ProgressBar = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerR/BarR
@onready
var peak_line_l: ColorRect = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerL/BarL/PeakLineL
@onready
var peak_line_r: ColorRect = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/MeterVBox/BarContainerR/BarR/PeakLineR
@onready
var integrity_label: Label = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/IntegrityValueLabel
@onready
var performance_meter_container: PanelContainer = $MainLayout/TopBar/Content/PerformanceMeterContainer

# Window Controls
@onready var btn_minimize: Button = $MainLayout/TopBar/Content/WindowControls/MinimizeButton
@onready var btn_maximize: Button = $MainLayout/TopBar/Content/WindowControls/MaximizeButton
@onready var btn_close: Button = $MainLayout/TopBar/Content/WindowControls/CloseButton

@onready var wave_label: Label = $MainLayout/TopBar/Content/WaveInfoPanel/InfoHBox/WaveLabel
@onready var gain_label: Label = $MainLayout/TopBar/Content/WaveInfoPanel/InfoHBox/GainLabel
@onready
var stage_title_label: Label = $MainLayout/TopBar/Content/WaveInfoPanel/InfoHBox/StageTitleLabel
@onready
var setlist_restart_button: Button = $MainLayout/TopBar/Content/WaveInfoPanel/InfoHBox/SetlistRestartButton

# Volume Controls
@onready var volume_button: Button = $MainLayout/TopBar/Content/TransportControls/VolumeButton
@onready var volume_slider: HSlider = $MainLayout/TopBar/Content/TransportControls/VolumeSlider

# Icons
var icon_play: Texture2D = preload("res://UI/Icons/play.svg")
var icon_pause: Texture2D = preload("res://UI/Icons/pause.svg")
var icon_restart: Texture2D = preload("res://UI/Icons/restart.svg")
var icon_volume: Texture2D = preload("res://UI/Icons/volume.svg")
var icon_mute: Texture2D = preload("res://UI/Icons/volume_mute.svg")

# State
var _build_manager: BuildManager
var _selected_tower: TemplateTower = null
var _transport_allowed: bool = false
var _is_sidebar_offline: bool = false
var _tower_inspector: PanelContainer  # Typed loose to avoid cyclic ref with TowerInspector
var _sidebar_hud: Control  # Typed loose to avoid cyclic ref with SidebarHUD
var _current_context: ContextMode = ContextMode.EMPTY
var _is_sidebar_animating: bool = false
@onready var _game_view_wrapper: Control = $MainLayout/WorkspaceSplit/GameViewWrapper

# Meter Animation State
var _target_damage_value: float = 0.0
var _meter_noise_offset_l: float = 0.0
var _meter_noise_offset_r: float = 0.0

# (Peak Hold State removed as it is now pinned strictly to actual damage)
# Jitter Settings
const JITTER_SPEED: float = 20.0  # How fast the noise fluctuates (Higher = Faster)
const JITTER_AMPLITUDE: float = 0.01  # 2% of max value
const STEREO_SEPARATION: float = 0.15  # 0.0 = Mono (Synced), 1.0 = Independent

# Jitter State
var _noise_target_common: float = 0.0
var _noise_val_common: float = 0.0
var _noise_target_diff: float = 0.0
var _noise_val_diff: float = 0.0

# Volume State
var _is_muted: bool = false
var _previous_volume: float = 80.0

const DEFAULT_LEVEL_PATH: String = "res://Stages/_TemplateStage/template_stage.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://UI/MainMenu/main_menu.tscn"
const SETLIST_SCENE_PATH: String = "res://UI/Setlist/setlist_screen.tscn"
const SIDEBAR_MENU_SCENE_PATH: String = "res://UI/HUD/Sidebar/sidebar_main_menu.tscn"
const STUDIO_SCENE_PATH: String = "res://UI/Studio/studio_screen.tscn"

enum ContextMode { GAMEPLAY, SETLIST, EMPTY, MAIN_MENU, STUDIO }

@onready var restart_confirm: ConfirmationDialog = $RestartConfirmation


func _ready() -> void:
	# Wait for systems to settle
	await get_tree().process_frame

	_setup_confirmations()
	menu_button.pressed.connect(_on_menu_button_pressed)
	_setup_transport()
	_setup_window_controls()
	_setup_build_manager()
	_setup_sidebar_hud()
	_setup_signal_connections()
	_update_play_button_visuals()
	_setup_input_propagation()
	_setup_inspector()
	_setup_level()
	_game_view_wrapper.gui_input.connect(_on_game_view_gui_input)

	# Ensure the overlay's physical state matches its default boolean state behind the loading screen.
	_set_sidebar_offline(_is_sidebar_offline, true)


func _exit_tree() -> void:
	if is_instance_valid(menu_button) and menu_button.pressed.is_connected(_on_menu_button_pressed):
		menu_button.pressed.disconnect(_on_menu_button_pressed)
	if (
		is_instance_valid(_game_view_wrapper)
		and _game_view_wrapper.gui_input.is_connected(_on_game_view_gui_input)
	):
		_game_view_wrapper.gui_input.disconnect(_on_game_view_gui_input)
	if is_instance_valid(_build_manager):
		if _build_manager.tower_selected.is_connected(_on_tower_selected):
			_build_manager.tower_selected.disconnect(_on_tower_selected)
		if _build_manager.tower_deselected.is_connected(_on_tower_deselected):
			_build_manager.tower_deselected.disconnect(_on_tower_deselected)
	if is_instance_valid(GameManager):
		if GameManager.wave_changed.is_connected(_on_wave_changed):
			GameManager.wave_changed.disconnect(_on_wave_changed)
		if GameManager.currency_changed.is_connected(_on_gain_changed):
			GameManager.currency_changed.disconnect(_on_gain_changed)
		if GameManager.game_state_changed.is_connected(_on_game_state_changed):
			GameManager.game_state_changed.disconnect(_on_game_state_changed)
		if GameManager.peak_meter_changed.is_connected(_on_peak_changed):
			GameManager.peak_meter_changed.disconnect(_on_peak_changed)
		if GameManager.wave_status_changed.is_connected(_on_wave_status_changed):
			GameManager.wave_status_changed.disconnect(_on_wave_status_changed)
	if (
		is_instance_valid(volume_slider)
		and volume_slider.value_changed.is_connected(_on_volume_changed)
	):
		volume_slider.value_changed.disconnect(_on_volume_changed)
	if (
		is_instance_valid(volume_button)
		and volume_button.pressed.is_connected(_on_volume_button_pressed)
	):
		volume_button.pressed.disconnect(_on_volume_button_pressed)
	if is_instance_valid(_tower_inspector) and is_instance_valid(_build_manager):
		if _tower_inspector.sell_tower_requested.is_connected(
			_build_manager._on_sell_tower_requested
		):
			_tower_inspector.sell_tower_requested.disconnect(
				_build_manager._on_sell_tower_requested
			)
		if _tower_inspector.target_priority_changed.is_connected(
			_build_manager._on_target_priority_changed
		):
			_tower_inspector.target_priority_changed.disconnect(
				_build_manager._on_target_priority_changed
			)
	if is_instance_valid(btn_minimize) and btn_minimize.pressed.is_connected(_on_minimize_pressed):
		btn_minimize.pressed.disconnect(_on_minimize_pressed)
	if is_instance_valid(btn_maximize) and btn_maximize.pressed.is_connected(_on_maximize_pressed):
		btn_maximize.pressed.disconnect(_on_maximize_pressed)
	if is_instance_valid(btn_close) and btn_close.pressed.is_connected(_on_close_pressed):
		btn_close.pressed.disconnect(_on_close_pressed)
	if is_instance_valid(play_button) and play_button.pressed.is_connected(_on_play_button_pressed):
		play_button.pressed.disconnect(_on_play_button_pressed)
	if (
		is_instance_valid(restart_button)
		and restart_button.pressed.is_connected(_on_restart_button_pressed)
	):
		restart_button.pressed.disconnect(_on_restart_button_pressed)
	if (
		is_instance_valid(setlist_restart_button)
		and setlist_restart_button.pressed.is_connected(_on_setlist_restart_button_pressed)
	):
		setlist_restart_button.pressed.disconnect(_on_setlist_restart_button_pressed)
	if is_instance_valid(main_menu_confirm):
		if main_menu_confirm.confirmed.is_connected(_on_main_menu_confirmed):
			main_menu_confirm.confirmed.disconnect(_on_main_menu_confirmed)
		if main_menu_confirm.canceled.is_connected(_on_dialog_canceled):
			main_menu_confirm.canceled.disconnect(_on_dialog_canceled)
	if is_instance_valid(setlist_confirm):
		if setlist_confirm.confirmed.is_connected(_on_setlist_confirmed):
			setlist_confirm.confirmed.disconnect(_on_setlist_confirmed)
		if setlist_confirm.canceled.is_connected(_on_dialog_canceled):
			setlist_confirm.canceled.disconnect(_on_dialog_canceled)
	if is_instance_valid(quit_confirm):
		if quit_confirm.confirmed.is_connected(_on_quit_confirmed):
			quit_confirm.confirmed.disconnect(_on_quit_confirmed)
		if quit_confirm.canceled.is_connected(_on_dialog_canceled):
			quit_confirm.canceled.disconnect(_on_dialog_canceled)
	if is_instance_valid(restart_confirm):
		if restart_confirm.confirmed.is_connected(_on_restart_confirmed):
			restart_confirm.confirmed.disconnect(_on_restart_confirmed)
		if restart_confirm.canceled.is_connected(_on_dialog_canceled):
			restart_confirm.canceled.disconnect(_on_dialog_canceled)

	# Dynamic ones are harder to reach if not stored, but we can do a general cleanup if we hold refs.
	# The level_instance and menu_instance are usually freed when the game window exits or changes levels.

	if is_instance_valid(_build_manager) and _build_manager.has_method("clear_level_references"):
		_build_manager.clear_level_references()


## Attempts to acquire the BuildManager from InputManager if available.
func _setup_build_manager() -> void:
	if InputManager.has_method("get_build_manager"):
		_build_manager = InputManager.get_build_manager()
		if _build_manager:
			_bind_build_manager()


## Binds the current BuildManager to the viewport, UI signals, and the static DropZone node.
func _bind_build_manager() -> void:
	if not is_instance_valid(_build_manager):
		return

	if not _build_manager.tower_selected.is_connected(_on_tower_selected):
		_build_manager.tower_selected.connect(_on_tower_selected)
	if not _build_manager.tower_deselected.is_connected(_on_tower_deselected):
		_build_manager.tower_deselected.connect(_on_tower_deselected)

	# Bind Viewport
	var viewport: SubViewport = $MainLayout/WorkspaceSplit/GameViewWrapper/GameViewContainer/SubViewport
	var container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewWrapper/GameViewContainer
	_build_manager.bind_to_viewport(viewport, container)

	# Inject BuildManager into the static DropZone node defined in the scene file
	var drop_zone: Control = $MainLayout/WorkspaceSplit/GameViewWrapper.get_node_or_null("DropZone")
	if is_instance_valid(drop_zone) and drop_zone.has_method("setup"):
		drop_zone.setup(_build_manager)

	# Bind Inspector Signals to the new BuildManager
	if is_instance_valid(_tower_inspector):
		if not _tower_inspector.sell_tower_requested.is_connected(
			_build_manager._on_sell_tower_requested
		):
			_tower_inspector.sell_tower_requested.connect(_build_manager._on_sell_tower_requested)
		if not _tower_inspector.target_priority_changed.is_connected(
			_build_manager._on_target_priority_changed
		):
			_tower_inspector.target_priority_changed.connect(
				_build_manager._on_target_priority_changed
			)


## Instantiates the SidebarHUD scene into the left sidebar panel, replacing
## any existing children.
func _setup_sidebar_hud() -> void:
	var sidebar_container: PanelContainer = $MainLayout/WorkspaceSplit/SidebarContainer/LeftSidebar
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
		_on_peak_changed(GameManager.current_peak, GameManager.max_peak)

	if GlobalSignals.has_signal("loadout_rebuild_requested"):
		GlobalSignals.loadout_rebuild_requested.connect(_on_loadout_rebuild_requested)

	# Wave active/idle
	if GameManager.has_signal("wave_status_changed"):
		GameManager.wave_status_changed.connect(_on_wave_status_changed)

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

	var viewport_container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewWrapper/GameViewContainer
	if viewport_container:
		# ALWAYS so clicks reach BuildManager even while paused.
		# Game entities remain PAUSABLE by default via their own process_mode.
		viewport_container.process_mode = Node.PROCESS_MODE_ALWAYS
		viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS

		if viewport_container.get_child_count() > 0:
			var vp: SubViewport = viewport_container.get_child(0) as SubViewport
			assert(vp != null)
			vp.process_mode = Node.PROCESS_MODE_ALWAYS

	# Allow drag data to fall through containers (prevents "Forbidden" cursor)
	var top_bar: PanelContainer = $MainLayout/TopBar
	var left_sidebar: PanelContainer = $MainLayout/WorkspaceSplit/SidebarContainer/LeftSidebar
	var drop_zone: Control = $MainLayout/WorkspaceSplit/GameViewWrapper/DropZone

	if top_bar:
		_set_container_mouse_ignore_recursive(top_bar)
	if left_sidebar:
		_set_container_mouse_ignore_recursive(left_sidebar)

	if drop_zone:
		drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Instantiates the TowerInspector panel inside the game view container and
## connects its action signals to the BuildManager.
func _setup_inspector() -> void:
	var inspector_scene: PackedScene = load("res://UI/Inspector/tower_inspector.tscn")
	if not inspector_scene:
		return

	_tower_inspector = inspector_scene.instantiate()
	game_view_container.add_child(_tower_inspector)
	_tower_inspector.move_to_front()
	_tower_inspector.visible = false

	if _build_manager:
		_tower_inspector.sell_tower_requested.connect(_build_manager._on_sell_tower_requested)
		_tower_inspector.target_priority_changed.connect(_build_manager._on_target_priority_changed)


## Loads or wires up the initial level. If a level already exists in the
## SubViewport (e.g. from the Editor), it is wired up directly.
func _setup_level() -> void:
	if game_viewport.get_child_count() > 0:
		_wire_up_level(game_viewport.get_child(0))


## Animates performance meters with smoothed jitter and peak-hold indicators.
func _process(delta: float) -> void:
	if not is_instance_valid(gauge_l) or not is_instance_valid(gauge_r):
		return

	# We want UI meters to animate smoothly even if the game is fast-forwarding,
	# so we get the raw, unscaled delta time by removing the time_scale multiplier.
	var time_scale: float = Engine.time_scale
	var unscaled_delta: float = delta / time_scale if time_scale > 0.0 else 0.0

	var target_val: float = _target_damage_value

	# Context-Aware Meter Logic
	if _current_context == ContextMode.STUDIO:
		# AP/CPU Budget Mode
		var player: PlayerData = GameManager.player_data
		if is_instance_valid(player):
			var current_cost: float = float(player.get_total_allocation_cost())
			var max_ap: float = float(player.max_allocation_points)

			# Map to 0-100% logic for the progress bar shader
			if max_ap > 0.0:
				target_val = (current_cost / max_ap) * 100.0
			else:
				target_val = 0.0
		else:
			target_val = 0.0
	else:
		# Distortion Mode (Default)
		if GameManager.max_peak > 0:
			target_val = (GameManager.current_peak / GameManager.max_peak) * 100.0
		else:
			target_val = 0.0

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

	# 2. Lerp towards target value
	# The bar fill targets 2.5% below the true value, with +/- 2.5% jitter.
	var bar_target: float = target_val - 2.5
	var smooth_speed: float = 7.0 * unscaled_delta

	# L Channel
	var smoothed_l: float = lerp(gauge_l.value, bar_target, smooth_speed)
	var final_l: float = clamp(smoothed_l + _meter_noise_offset_l, -5.0, target_val)
	gauge_l.value = final_l
	_update_peak_hold(target_val, true)

	# R Channel
	var smoothed_r: float = lerp(gauge_r.value, bar_target, smooth_speed)
	var final_r: float = clamp(smoothed_r + _meter_noise_offset_r, -5.0, target_val)
	gauge_r.value = final_r
	_update_peak_hold(target_val, false)


## Updates peak-hold indicator position for one channel.
## This is now strictly pinned to the actual damage taken.
func _update_peak_hold(target_val: float, is_left: bool) -> void:
	var line: ColorRect = peak_line_l if is_left else peak_line_r

	if not is_instance_valid(gauge_l):
		return

	# Update visual position of peak line
	# Progress bar physical range is -5 to 100 (total span 105).
	# To place the line correctly, map target_val (-5 to 100) to 0.0 - 1.0 physical width.
	if is_instance_valid(line) and is_instance_valid(line.get_parent()):
		var width: float = line.get_parent().size.x - line.size.x
		if width > 0:
			var pct: float = clamp((target_val + 5.0) / 105.0, 0.0, 1.0)
			line.position.x = width * pct


## Connects window chrome buttons (minimise, maximise, close).
func _setup_window_controls() -> void:
	if btn_minimize:
		btn_minimize.pressed.connect(_on_minimize_pressed)
	if btn_maximize:
		btn_maximize.pressed.connect(_on_maximize_pressed)
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)


## Connects transport bar buttons (play/pause, restart).
func _setup_transport() -> void:
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)

	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)

	if setlist_restart_button:
		setlist_restart_button.pressed.connect(_on_setlist_restart_button_pressed)


## Automatically hides the sidebar menu if we are in a gameplay level.
func _auto_hide_sidebar() -> void:
	if _current_context == ContextMode.MAIN_MENU and _transport_allowed:
		set_context_mode(ContextMode.GAMEPLAY)


## Toggles the game between playing and paused states.
func _on_play_button_pressed() -> void:
	# If the menu is open and we click play, just close the menu (which unpauses).
	if _current_context == ContextMode.MAIN_MENU and _transport_allowed:
		set_context_mode(ContextMode.GAMEPLAY)
		return

	# Normal toggle
	GameManager.toggle_game_state()

	# If we just switched to paused, open the menu and deselect towers.
	if _transport_allowed and GameManager.game_state == GameManager.GameState.PAUSED:
		if is_instance_valid(_build_manager):
			_build_manager.deselect_current_tower()
		set_context_mode(ContextMode.MAIN_MENU)


## Pauses the game (if playing) and opens the restart confirmation dialog.
func _on_restart_button_pressed() -> void:
	# Ensure the menu is visible for confirmation, but don't toggle it closed.
	if _current_context != ContextMode.MAIN_MENU and _transport_allowed:
		set_context_mode(ContextMode.MAIN_MENU)

	# Deselect towers to clear the view for the confirmation dialog
	if is_instance_valid(_build_manager):
		_build_manager.deselect_current_tower()

	if GameManager.is_wave_active and GameManager.game_state == GameManager.GameState.PLAYING:
		GameManager.set_game_state(GameManager.GameState.PAUSED)  # Explicitly pause, don't toggle

	if restart_confirm:
		restart_confirm.title = "Abort Stem?"
		restart_confirm.dialog_text = "Restart the current stem? All progress will be lost."
		restart_confirm.popup_centered()


## Minimises the application window.
func _on_minimize_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


## Toggles between windowed and fullscreen modes.
func _on_maximize_pressed() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	if (
		current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	):
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

	var is_paused: bool = new_state == GameManager.GameState.PAUSED

	if has_node("MainLayout/WorkspaceSplit/SidebarContainer/LeftSidebar"):
		_set_container_input_state(
			$MainLayout/WorkspaceSplit/SidebarContainer/LeftSidebar, not is_paused
		)


## Recursively enables or disables input on a container and its children.
## Buttons and draggable controls are disabled; containers have their mouse
## filter set to IGNORE (disabled) or PASS (enabled).
func _set_container_input_state(node: Node, enabled: bool) -> void:
	if node is Control:
		if node is BaseButton or node is LineEdit:
			var can_interact: bool = enabled

			# Transport buttons are further restricted by the _transport_allowed flag
			if node == play_button or node == restart_button:
				can_interact = enabled and _transport_allowed

			node.disabled = not can_interact

	for child: Node in node.get_children():
		_set_container_input_state(child, enabled)


## Updates the play button icon when the wave active/idle status changes.
func _on_wave_status_changed(_is_active: bool) -> void:
	_update_play_button_visuals()


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


## Connects confirmation dialog signals.
func _setup_confirmations() -> void:
	if main_menu_confirm:
		main_menu_confirm.confirmed.connect(_on_main_menu_confirmed)
		main_menu_confirm.canceled.connect(_on_dialog_canceled)
	if setlist_confirm:
		setlist_confirm.confirmed.connect(_on_setlist_confirmed)
		setlist_confirm.canceled.connect(_on_dialog_canceled)
	if quit_confirm:
		quit_confirm.confirmed.connect(_on_quit_confirmed)
		quit_confirm.canceled.connect(_on_dialog_canceled)
	if restart_confirm:
		restart_confirm.confirmed.connect(_on_restart_confirmed)
		restart_confirm.canceled.connect(_on_dialog_canceled)


func _on_menu_button_pressed() -> void:
	if _is_sidebar_animating:
		return

	# Toggle logic: if we are already in MAIN_MENU context showing the sidebar, close it.
	if _current_context == ContextMode.MAIN_MENU:
		# Only allow closing if we are in a state that has "Gameplay" to return to
		if _transport_allowed:
			set_context_mode(ContextMode.GAMEPLAY)
		else:
			# If in Title/Setlist, we don't 'toggle' it closed because
			# the menu IS the main interaction layer here.
			pass
	else:
		# Otherwise, open the menu.
		# If we are in gameplay, pause the game while the menu is open.
		if _transport_allowed:
			GameManager.set_game_state(GameManager.GameState.PAUSED)
			# Deselect any tower when opening the menu to keep UI clean.
			# We go through BuildManager to ensure source-of-truth is updated.
			if is_instance_valid(_build_manager):
				_build_manager.deselect_current_tower()

		set_context_mode(ContextMode.MAIN_MENU)


func _on_game_view_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Only auto-close if we are in gameplay (transport allowed)
		# We don't want to close the sidebar on world-click during Title/Setlist
		if _current_context == ContextMode.MAIN_MENU and _transport_allowed:
			set_context_mode(ContextMode.GAMEPLAY)


## Unpauses the tree and returns to the main menu scene.
func _on_main_menu_confirmed() -> void:
	get_tree().paused = false
	if StageManager.has_method("_stop_current_stem_audio"):
		StageManager._stop_current_stem_audio()
	# Ensure timing vars are reset when returning entirely to main menu
	GameManager.reset_state()
	SceneManager.load_scene(MAIN_MENU_SCENE_PATH, SceneManager.ViewType.MENU)


## Loads the Studio scene and switches context.
func _on_sidebar_studio() -> void:
	_load_menu(STUDIO_SCENE_PATH)


## Rebuilds the Sidebar HUD (e.g., when buying a new item in the Studio).
func _on_loadout_rebuild_requested() -> void:
	if is_instance_valid(_sidebar_hud) and is_instance_valid(GameManager.player_data):
		_sidebar_hud.populate(GameManager.player_data)
		_sidebar_hud.set_context(_current_context)


## Unpauses the tree and returns to the setlist ui screen.
func _on_setlist_confirmed() -> void:
	get_tree().paused = false
	if StageManager.has_method("_stop_current_stem_audio"):
		StageManager._stop_current_stem_audio()
	# Ensure timing vars are reset when returning
	GameManager.reset_state()
	SceneManager.load_scene(SETLIST_SCENE_PATH, SceneManager.ViewType.MENU)


## Quits the application.
func _on_quit_confirmed() -> void:
	get_tree().quit()


## Restarts the current stem by reloading the active level scene, OR restarts the full stage if in setlist.
func _on_restart_confirmed() -> void:
	get_tree().paused = false

	if restart_confirm.title == "Restart Stage?":
		# We are performing a full stage restart from the setlist
		GameManager.reset_state()
		if StageManager.has_method("restart_stage"):
			StageManager.restart_stage()
		SceneManager.load_scene(SETLIST_SCENE_PATH, SceneManager.ViewType.MENU)
		return

	# Normal single-stem restart
	if StageManager.current_stem_index >= 0:
		StageManager.restart_stem()
	else:
		GameManager.reset_state()  # Ensure timing variables reset
		var current_path: String = DEFAULT_LEVEL_PATH

		_load_level(current_path)  # Reload logic; later mapped to current level path


## Pauses the game (if currently playing) before showing a system modal.
func _pause_game_for_dialog() -> void:
	if GameManager.is_wave_active and GameManager.game_state == GameManager.GameState.PLAYING:
		GameManager.set_game_state(GameManager.GameState.PAUSED)


## Resums gameplay context (hides sidebar, unpauses) when a confirmation dialog is canceled.
func _on_dialog_canceled() -> void:
	if _current_context == ContextMode.MAIN_MENU and _transport_allowed:
		set_context_mode(ContextMode.GAMEPLAY)
	elif GameManager.is_wave_active and GameManager.game_state == GameManager.GameState.PAUSED:
		GameManager.set_game_state(GameManager.GameState.PLAYING)


## Loads a level scene from a file path into the game SubViewport.
func _load_level(level_path: String) -> void:
	var level_scene: PackedScene = load(level_path)
	if level_scene:
		var level_instance: Node = level_scene.instantiate()
		change_workspace(level_instance, 1)  # 1 = LEVEL


## Loads a menu scene from a file path into the ui workspace.
func _load_menu(menu_path: String) -> void:
	var menu_scene: PackedScene = load(menu_path)
	if menu_scene:
		var menu_instance: Node = menu_scene.instantiate()
		change_workspace(menu_instance, 0)  # 0 = MENU


## Shows the tower inspector anchored to the selected tower's screen position.
func _on_tower_selected(tower: TemplateTower) -> void:
	_auto_hide_sidebar()
	_selected_tower = tower

	if _tower_inspector and _tower_inspector.has_method("set_tower"):
		_tower_inspector.set_tower(tower)

		# Convert tower's SubViewport position to main screen space
		if is_instance_valid(tower):
			var viewport_size: Vector2i = game_viewport.size
			var viewport_local_pos: Vector2 = tower.get_global_transform_with_canvas().origin
			var container_offset: Vector2 = Vector2.ZERO

			var container: SubViewportContainer = $MainLayout/WorkspaceSplit/GameViewWrapper/GameViewContainer
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


## Clears the workspace and loads a new scene into the correct container.
func change_workspace(scene_instance: Node, view_type: int) -> void:
	# Purge loose level references before destroying previous scene
	if is_instance_valid(_build_manager) and _build_manager.has_method("clear_level_references"):
		_build_manager.clear_level_references()

	# Clear both workspaces
	for child: Node in game_viewport.get_children():
		child.queue_free()
	for child: Node in ui_workspace.get_children():
		child.queue_free()

	# SceneManager.ViewType.LEVEL = 1, MENU = 0
	# (using int to avoid circular typing if necessary)
	if view_type == 1:  # LEVEL
		ui_workspace.hide()
		game_view_container.show()
		game_viewport.add_child(scene_instance)
		_wire_up_level(scene_instance)
		_set_transport_controls_enabled(true)
		if is_instance_valid(_sidebar_hud) and is_instance_valid(GameManager.player_data):
			_sidebar_hud.populate(GameManager.player_data)
	else:  # MENU
		game_view_container.hide()
		ui_workspace.show()
		ui_workspace.add_child(scene_instance)
		_set_transport_controls_enabled(false)

		# Context detection for menus (using duck-typing to avoid circular class_name issues)
		if scene_instance.has_method("_build_setlist"):
			set_context_mode(ContextMode.SETLIST)
		elif scene_instance.has_method("is_main_menu"):
			set_context_mode(ContextMode.MAIN_MENU)
		elif scene_instance.has_method("_populate_catalog"):  # Duck-typing for StudioScreen
			set_context_mode(ContextMode.STUDIO)
			if is_instance_valid(_sidebar_hud) and is_instance_valid(GameManager.player_data):
				_sidebar_hud.populate(GameManager.player_data)
			# Defer context propagation so sidebar buttons exist before context is set
			if is_instance_valid(_sidebar_hud):
				_sidebar_hud.call_deferred("set_context", ContextMode.STUDIO)
		else:
			set_context_mode(ContextMode.EMPTY)


## Temporarily enables/disables transport buttons (play, restart)
## when navigating menus vs playing levels.
func _set_transport_controls_enabled(enabled: bool) -> void:
	_transport_allowed = enabled

	if play_button:
		play_button.disabled = not enabled
	if restart_button:
		restart_button.disabled = not enabled

	# Sync the sidebar menu if needed or handle other state sync
	# (Sidebar menu currently handles its own logic or is updated via contexts)

	# Always ensure the top bar isn't orphaned in a locked state when entering a menu
	if not enabled:
		_set_ui_interaction(true)

	if enabled:
		set_context_mode(ContextMode.GAMEPLAY)
	else:
		# We no longer default to SETLIST here.
		# Context is now explicitly set in change_workspace() or other state transitions.
		pass


## Updates the Top Bar layout based on the current context (e.g. gameplay vs menu).
func set_context_mode(mode: ContextMode) -> void:
	# If we are returning to gameplay from a menu, unpause the game.
	if mode == ContextMode.GAMEPLAY and _current_context == ContextMode.MAIN_MENU:
		if _transport_allowed:
			GameManager.set_game_state(GameManager.GameState.PLAYING)

	_current_context = mode

	@warning_ignore("unsafe_property_access")
	var health_label: Label = $MainLayout/TopBar/Content/PerformanceMeterContainer/MeterHBox/HealthLabel
	if is_instance_valid(health_label):
		if mode == ContextMode.STUDIO:
			health_label.text = "CPU Usage:"
		else:
			health_label.text = "Distortion:"

	match mode:
		ContextMode.GAMEPLAY:
			wave_label.show()
			gain_label.show()
			stage_title_label.hide()
			if setlist_restart_button:
				setlist_restart_button.hide()
			_set_sidebar_offline(false)

		ContextMode.SETLIST:
			wave_label.hide()
			gain_label.hide()
			stage_title_label.show()
			if setlist_restart_button:
				setlist_restart_button.show()
			_set_sidebar_offline(true)
			_update_sidebar_content(ContextMode.MAIN_MENU)

			if StageManager.active_stage:
				stage_title_label.text = StageManager.active_stage.stage_name
			else:
				stage_title_label.text = "Setlist"

		ContextMode.EMPTY:
			wave_label.hide()
			gain_label.hide()
			stage_title_label.hide()
			if setlist_restart_button:
				setlist_restart_button.hide()
			_set_sidebar_offline(true)
		ContextMode.STUDIO:
			wave_label.hide()
			gain_label.hide()
			# Can repurpose the stage title to say 'The Studio' for now
			stage_title_label.text = "The Studio"
			stage_title_label.show()
			if setlist_restart_button:
				setlist_restart_button.hide()
			# Specifically keep the sidebar online so players can drag into it
			_set_sidebar_offline(false)
			_update_sidebar_content(ContextMode.EMPTY)

		ContextMode.MAIN_MENU:
			wave_label.hide()
			gain_label.hide()
			stage_title_label.text = "Main Menu"
			stage_title_label.show()
			if setlist_restart_button:
				setlist_restart_button.hide()
			_set_sidebar_offline(true)
			_update_sidebar_content(ContextMode.MAIN_MENU)

	if is_instance_valid(_sidebar_hud):
		_sidebar_hud.set_context(mode)


## Triggers the confirmation to restart the ENTIRE stage from the Setlist screen.
func _on_setlist_restart_button_pressed() -> void:
	# Show a different confirmation dialog for stage restart if desired, or reuse a generic one
	if restart_confirm:
		restart_confirm.title = "Restart Stage?"
		restart_confirm.dialog_text = "Are you sure you want to restart the entire stage? All stem progress will be wiped."
		restart_confirm.popup_centered()


## Updates the content of the Sidebar Overlay based on current context.
func _update_sidebar_content(mode: ContextMode) -> void:
	if not is_instance_valid(overlay_content):
		return

	# Clear existing dynamic content
	for child in overlay_content.get_children():
		if child != status_label:
			child.queue_free()

	match mode:
		ContextMode.EMPTY:
			status_label.show()
			status_label.text = "[ OFFLINE ]"
		ContextMode.MAIN_MENU:
			status_label.hide()
			var menu_scene: PackedScene = load(SIDEBAR_MENU_SCENE_PATH)
			if menu_scene:
				var menu_instance: Node = menu_scene.instantiate()
				overlay_content.add_child(menu_instance)
				# Connect signals
				if menu_instance.has_signal("studio_pressed"):
					menu_instance.studio_pressed.connect(_on_sidebar_studio)
				menu_instance.setlist_pressed.connect(_on_sidebar_setlist)
				menu_instance.quit_pressed.connect(_on_close_pressed)
		_:
			status_label.show()
			status_label.text = "[ OFFLINE ]"

	pass


func _on_sidebar_setlist() -> void:
	# If we are in a level, show a confirmation dialog
	if _transport_allowed and setlist_confirm:
		setlist_confirm.dialog_text = "Are you sure you want to return to the setlist? All progress in the current stem will be lost."
		setlist_confirm.popup_centered()
		return

	# If no stage is loaded, default to Stage 1
	if StageManager.active_stage == null:
		var STAGE_1_PATH: String = "res://Config/Stages/stage01.tres"
		var stage: StageData = load(STAGE_1_PATH) as StageData
		if stage:
			StageManager.load_stage(stage)

	SceneManager.load_scene(SETLIST_SCENE_PATH, SceneManager.ViewType.MENU)


## Connects a level instance's required nodes to the BuildManager and wires
## up opening sequence signals for UI locking.
func _wire_up_level(level_instance: Node) -> void:
	if InputManager.has_method("get_build_manager"):
		_build_manager = InputManager.get_build_manager()
		if _build_manager:
			_bind_build_manager()

	if _build_manager:
		var path_layer: TileMapLayer = level_instance.get_node_or_null("TileMaps/MazeLayer")
		var highlight: TileMapLayer = level_instance.get_node_or_null("TileMaps/HighlightLayer")
		var towers: Node = level_instance.get_node_or_null("Entities/Towers")

		if path_layer and highlight and towers:
			_build_manager.update_level_references(path_layer, highlight, towers)
		else:
			printerr("Failed to find required level nodes for BuildManager.")

	# Wire up opening sequence signals using duck-typing to avoid cyclical reference errors
	if level_instance.has_signal("opening_sequence_started"):
		if not level_instance.opening_sequence_started.is_connected(_on_opening_sequence_started):
			level_instance.opening_sequence_started.connect(_on_opening_sequence_started)
		if not level_instance.opening_sequence_finished.is_connected(_on_opening_sequence_finished):
			level_instance.opening_sequence_finished.connect(_on_opening_sequence_finished)

		if "play_opening_sequence" in level_instance and level_instance.play_opening_sequence:
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
	var left_sidebar: PanelContainer = $MainLayout/WorkspaceSplit/SidebarContainer/LeftSidebar

	if top_bar:
		_set_container_input_state(top_bar, enabled)
	if left_sidebar:
		_set_container_input_state(left_sidebar, enabled)


## Recursively sets mouse filters on a container tree. Interactive controls
## (buttons, sliders, draggables) keep MOUSE_FILTER_STOP when allow_buttons
## is true; all other containers are set to MOUSE_FILTER_IGNORE.
func _set_container_mouse_ignore_recursive(node: Node, allow_buttons: bool = true) -> void:
	if node is Control:
		var is_interactive: bool = (
			node is BaseButton
			or node is LineEdit
			or node is TextEdit
			or node is Tree
			or node is ItemList
			or node is Range
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
	if what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_DRAG_END:
		var top_bar: PanelContainer = get_node_or_null("MainLayout/TopBar") as PanelContainer
		var left_sidebar: PanelContainer = (
			get_node_or_null("MainLayout/WorkspaceSplit/SidebarContainer/LeftSidebar")
			as PanelContainer
		)
		var drop_zone: Control = (
			get_node_or_null("MainLayout/WorkspaceSplit/GameViewWrapper/DropZone") as Control
		)

		if what == NOTIFICATION_DRAG_BEGIN:
			if top_bar:
				_set_container_mouse_ignore_recursive(top_bar, false)

			# ONLY lock the sidebar if we are NOT in the Studio.
			# In the Studio, we need the sidebar to remain interactive for drag-and-drop.
			if left_sidebar and _current_context != ContextMode.STUDIO:
				_set_container_mouse_ignore_recursive(left_sidebar, false)

			if drop_zone:
				drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS

		elif what == NOTIFICATION_DRAG_END:
			if top_bar:
				_set_container_mouse_ignore_recursive(top_bar, true)
			if left_sidebar:
				_set_container_mouse_ignore_recursive(left_sidebar, true)
			if drop_zone:
				drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE

			# Ensure buff/drag state is cleaned up
			if is_instance_valid(_build_manager) and _build_manager.is_dragging():
				_build_manager.cancel_drag_ghost()
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
	if not _transport_allowed:
		_target_damage_value = 0.0
		if is_instance_valid(integrity_label):
			integrity_label.text = "0%"
		return

	if max_val > 0.0 and is_instance_valid(gauge_l):
		var true_pct: float = min(100.0, (current / max_val) * 100.0)
		_target_damage_value = true_pct

		if is_instance_valid(integrity_label):
			var distortion_pct: int = max(0, floor(true_pct))
			integrity_label.text = "%d%%" % distortion_pct


## Updates the GameManager volume and refreshes UI icons.
func _on_volume_changed(value: float) -> void:
	var linear_val: float = value / 100.0
	var db_val: float = linear_to_db(linear_val)

	var master_bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_idx, db_val)

	# Sync mute icon with slider position
	if value <= 0 and not _is_muted:
		_is_muted = true
		if volume_button:
			volume_button.icon = icon_mute
	elif value > 0 and _is_muted:
		_is_muted = false
		if volume_button:
			volume_button.icon = icon_volume


## Toggles the mute state via GameManager.
func _on_volume_button_pressed() -> void:
	if _is_muted:
		_is_muted = false
		if volume_button:
			volume_button.icon = icon_volume

		if _previous_volume <= 0:
			_previous_volume = 80.0
		if volume_slider:
			volume_slider.value = _previous_volume
	else:
		_is_muted = true
		if volume_button:
			volume_button.icon = icon_mute

		if volume_slider:
			_previous_volume = volume_slider.value
			volume_slider.value = 0


## Animates the Sidebar Overlay in or out to block loadout interaction during menus.
func _set_sidebar_offline(is_offline: bool, instant: bool = false) -> void:
	if not is_instance_valid(sidebar_overlay):
		return

	if _is_sidebar_offline == is_offline and not instant:
		return

	_is_sidebar_offline = is_offline

	# For nodes with anchors, animating offsets is safer than position.x.
	# Positive target (0.0) covers the sidebar; negative (-size.x) hides it.
	var target_offset: float = 0.0 if is_offline else -sidebar_overlay.size.x

	if is_offline:
		sidebar_overlay.visible = true

	if instant:
		sidebar_overlay.offset_left = target_offset
		sidebar_overlay.offset_right = target_offset
		sidebar_overlay.visible = is_offline
		return

	# Delay the animation by one frame to allow the layout to settle after large scene changes
	_is_sidebar_animating = true
	call_deferred("_start_sidebar_tween", target_offset, is_offline)


func _start_sidebar_tween(target_offset: float, is_offline: bool) -> void:
	if not is_instance_valid(sidebar_overlay):
		_is_sidebar_animating = false
		return

	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(sidebar_overlay, "offset_left", target_offset, sidebar_overlay_anim_time)
	tween.tween_property(sidebar_overlay, "offset_right", target_offset, sidebar_overlay_anim_time)

	tween.set_parallel(false)
	tween.tween_callback(func(): _is_sidebar_animating = false)

	if not is_offline:
		tween.tween_callback(sidebar_overlay.hide)
