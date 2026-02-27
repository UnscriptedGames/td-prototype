class_name DebugToolbar
extends MarginContainer

# --- Node References ---

@onready var speed_down_btn: Button = $Panel/Controls/SpeedDownButton
@onready var speed_up_btn: Button = $Panel/Controls/SpeedUpButton
@onready var speed_label: Label = $Panel/Controls/SpeedLabel


@onready var peak_slider: HSlider = $Panel/Controls/PeakSlider

@onready var spawn_wave_btn: Button = $Panel/Controls/SpawnWaveButton
@onready var complete_stem_btn: Button = $Panel/Controls/CompleteStemButton

@onready var add_gold_btn: Button = $Panel/Controls/AddGoldButton

@onready var pool_stats_btn: Button = $Panel/Controls/PoolStatsButton

# --- Lifecycle ---

func _ready() -> void:
	# Hide in production builds.
	if not OS.is_debug_build():
		hide()

	# Speed controls.
	speed_down_btn.pressed.connect(GameManager.step_speed_down)
	speed_up_btn.pressed.connect(GameManager.step_speed_up)
	if GameManager.has_signal("game_speed_changed"):
		GameManager.game_speed_changed.connect(_on_speed_changed)
		_on_speed_changed(Engine.time_scale)


	# Peak slider — bidirectional: slider drives GameManager, GameManager drives slider.
	peak_slider.value_changed.connect(_on_peak_slider_changed)
	GameManager.peak_meter_changed.connect(_on_peak_meter_changed)

	# Wave controls.
	spawn_wave_btn.pressed.connect(_on_spawn_wave_pressed)
	complete_stem_btn.pressed.connect(_on_complete_stem_pressed)

	# Economy.
	add_gold_btn.pressed.connect(func() -> void: GameManager.add_gold_debug(500))

	# Pool stats toggle.
	pool_stats_btn.toggled.connect(_on_pool_stats_toggled)


func _exit_tree() -> void:
	if GameManager.peak_meter_changed.is_connected(_on_peak_meter_changed):
		GameManager.peak_meter_changed.disconnect(_on_peak_meter_changed)
	if GameManager.game_speed_changed.is_connected(_on_speed_changed):
		GameManager.game_speed_changed.disconnect(_on_speed_changed)


# --- Callbacks ---

func _on_speed_changed(new_speed: float) -> void:
	speed_label.text = "%.1fx" % new_speed


func _on_peak_slider_changed(ratio: float) -> void:
	# Guard against infinite feedback loop when the meter updates the slider.
	GameManager.set_peak_ratio(ratio)


func _on_peak_meter_changed(current: float, max_val: float) -> void:
	# Keep slider in sync with live gameplay changes (e.g. enemy leaks).
	if max_val <= 0.0:
		return
	var new_ratio: float = current / max_val
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
