class_name DebugToolbar
extends MarginContainer

# --- Node References ---

@onready var speed_down_button: Button = $Panel/Controls/SpeedDownButton
@onready var speed_up_button: Button = $Panel/Controls/SpeedUpButton
@onready var speed_label: Label = $Panel/Controls/SpeedLabel

@onready var peak_slider: HSlider = $Panel/Controls/PeakSlider

@onready var spawn_wave_button: Button = $Panel/Controls/SpawnWaveButton
@onready var complete_stem_button: Button = $Panel/Controls/CompleteStemButton
@onready var complete_all_stems_button: Button = $Panel/Controls/CompleteAllStemsButton

@onready var add_gold_button: Button = $Panel/Controls/AddGoldButton

@onready var pool_stats_button: Button = $Panel/Controls/PoolStatsButton
@onready var debug_button: Button = $Panel/Controls/DebugButton
@onready var controls: HBoxContainer = $Panel/Controls

# --- Lifecycle ---


func _ready() -> void:
	# Hide in production builds.
	if not OS.is_debug_build():
		hide()

	# Speed controls.
	speed_down_button.pressed.connect(GameManager.step_speed_down)
	speed_up_button.pressed.connect(GameManager.step_speed_up)
	if GameManager.has_signal("game_speed_changed"):
		GameManager.game_speed_changed.connect(_on_speed_changed)
		_on_speed_changed(Engine.time_scale)

	# Peak slider — bidirectional: slider drives GameManager, GameManager drives slider.
	peak_slider.value_changed.connect(_on_peak_slider_changed)
	GameManager.peak_meter_changed.connect(_on_peak_meter_changed)

	# Wave controls.
	spawn_wave_button.pressed.connect(_on_spawn_wave_pressed)
	complete_stem_button.pressed.connect(_on_complete_stem_pressed)
	complete_all_stems_button.pressed.connect(func() -> void: StageManager.cheat_complete_all_stems())

	# Economy.
	add_gold_button.pressed.connect(func() -> void: GameManager.add_gold_debug(500))

	# Pool stats toggle.
	pool_stats_button.toggled.connect(_on_pool_stats_toggled)

	# Debug toolbar collapse.
	debug_button.toggled.connect(_on_debug_toggled)
	# Set initial state (Sync with scene default if needed, though button_pressed=true in scene)
	_on_debug_toggled(debug_button.button_pressed)


func _exit_tree() -> void:
	if is_instance_valid(GameManager):
		if GameManager.peak_meter_changed.is_connected(_on_peak_meter_changed):
			GameManager.peak_meter_changed.disconnect(_on_peak_meter_changed)
		if GameManager.game_speed_changed.is_connected(_on_speed_changed):
			GameManager.game_speed_changed.disconnect(_on_speed_changed)

	if is_instance_valid(speed_down_button) and speed_down_button.pressed.is_connected(GameManager.step_speed_down):
		speed_down_button.pressed.disconnect(GameManager.step_speed_down)
	if is_instance_valid(speed_up_button) and speed_up_button.pressed.is_connected(GameManager.step_speed_up):
		speed_up_button.pressed.disconnect(GameManager.step_speed_up)
	if is_instance_valid(peak_slider) and peak_slider.value_changed.is_connected(_on_peak_slider_changed):
		peak_slider.value_changed.disconnect(_on_peak_slider_changed)
	if is_instance_valid(spawn_wave_button) and spawn_wave_button.pressed.is_connected(_on_spawn_wave_pressed):
		spawn_wave_button.pressed.disconnect(_on_spawn_wave_pressed)
	if is_instance_valid(complete_stem_button) and complete_stem_button.pressed.is_connected(_on_complete_stem_pressed):
		complete_stem_button.pressed.disconnect(_on_complete_stem_pressed)
	if is_instance_valid(complete_all_stems_button):
		for connection in complete_all_stems_button.pressed.get_connections():
			complete_all_stems_button.pressed.disconnect(connection["callable"])
	if is_instance_valid(add_gold_button):
		for connection in add_gold_button.pressed.get_connections():
			add_gold_button.pressed.disconnect(connection["callable"])
	if is_instance_valid(pool_stats_button) and pool_stats_button.toggled.is_connected(_on_pool_stats_toggled):
		pool_stats_button.toggled.disconnect(_on_pool_stats_toggled)
	if is_instance_valid(debug_button) and debug_button.toggled.is_connected(_on_debug_toggled):
		debug_button.toggled.disconnect(_on_debug_toggled)


# --- Callbacks ---


func _on_speed_changed(new_speed: float) -> void:
	speed_label.text = "%.1fx" % new_speed


func _on_peak_slider_changed(ratio: float) -> void:
	# Guard against infinite feedback loop when the meter updates the slider.
	GameManager.set_peak_ratio(ratio)


func _on_peak_meter_changed(current_volume: float, max_volume: float) -> void:
	# Keep slider in sync with live gameplay changes (e.g. enemy leaks).
	if max_volume <= 0.0:
		return
	var new_ratio: float = current_volume / max_volume
	# Block the slider's value_changed from firing while we update it programmatically.
	peak_slider.set_block_signals(true)
	peak_slider.value = new_ratio
	peak_slider.set_block_signals(false)


func _on_spawn_wave_pressed() -> void:
	if not GameManager.is_wave_active:
		GameManager.toggle_game_state()


func _on_complete_stem_pressed() -> void:
	GameManager.force_complete_stem()


func _on_pool_stats_toggled(pressed: bool) -> void:
	var monitor: Node = get_tree().get_first_node_in_group("pool_monitor")
	if is_instance_valid(monitor):
		monitor.visible = pressed
	elif pressed and OS.is_debug_build():
		push_warning("DebugToolbar: ObjectPoolMonitor not found in group 'pool_monitor'.")


func _on_debug_toggled(should_be_visible: bool) -> void:
	for child in controls.get_children():
		if child != debug_button:
			child.visible = should_be_visible
