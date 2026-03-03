extends Node

## Central manager for global game state, currency, and wave progression.
##
## Handles the core loop (State: PLAYING/PAUSED), economy (Currency),
## and level progression (Waves). Accessed via the `GameManager` autoload.

# Signals for communicating changes to other nodes
signal currency_changed(new_currency: int)
signal wave_changed(current_wave: int, total_waves: int)
signal level_changed(current_level: int)
signal game_state_changed(new_state: GameState)
signal wave_status_changed(is_active: bool)
signal game_speed_changed(new_speed: float)
signal start_wave_requested
signal loadout_stock_changed(tower_data: TowerData, new_stock: int)
signal relic_state_changed(is_available: bool)
signal peak_meter_changed(current: float, max_val: float)
# Emitted when all spawn/enemies are done and the stem should grade and close.
signal stem_completion_requested
# Emitted when the peak meter clips to 100% — triggers immediate fail.
signal stem_failed
# Emitted by the debug force-complete path so template_stage can set the bypass flag.
signal force_complete_stem_requested

enum GameState { PAUSED, PLAYING }
var speed_steps: Array[float] = [1.0, 2.0, 4.0, 12.0]

# Player and level state variables
var _player_data: PlayerData
var _level_data: StemData
var _current_level: int = 0
var _current_wave: int = 0
var _total_waves: int = 0
var _game_state: GameState = GameState.PLAYING
var _is_wave_active: bool = false
var _game_speed_index: int = 0
var _current_peak: float = 0.0
var _current_max_peak: float = 100.0  # Will be updated dynamically per wave

# Loadout System
# Key: TowerData, Value: int (Current Stock in this run)
var _loadout_stock: Dictionary[TowerData, int] = {}

# Relic Logic
var _relic_used_this_level: bool = false

# --- Getters ---

var player_data: PlayerData:
	get:
		return _player_data

var level_data: StemData:
	get:
		return _level_data

var current_level: int:
	get:
		return _current_level

var current_wave: int:
	get:
		return _current_wave

var total_waves: int:
	get:
		return _total_waves

var game_state: GameState:
	get:
		return _game_state

var is_wave_active: bool:
	get:
		return _is_wave_active

var current_peak: float:
	get:
		return _current_peak

var max_peak: float:
	get:
		return _current_max_peak

var loadout_stock: Dictionary:
	get:
		return _loadout_stock

# --- Lifecycle ---


func _ready() -> void:
	if OS.is_debug_build():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	_player_data = load("res://Config/Players/player_config.tres")
	_initialize_loadout_stock()
	if _player_data:
		currency_changed.emit(_player_data.currency)


# --- Loadout Management ---


## Initializes the loadout stock from the player data tower_slots array.
func _initialize_loadout_stock() -> void:
	if _player_data:
		_loadout_stock.clear()
		_player_data._ensure_slots()
		for slot in _player_data.tower_slots:
			if slot != null and slot.has("data") and slot["data"] is TowerData:
				var tower_data: TowerData = slot["data"] as TowerData
				var count: int = slot.get("stock", 1)
				_loadout_stock[tower_data] = count
				loadout_stock_changed.emit(tower_data, count)


## Returns the current stock for a specific tower.
func get_stock(tower_data: TowerData) -> int:
	return _loadout_stock.get(tower_data, 0)


## Attempts to consume one unit of stock for the given tower.
## Returns true if successful, false if out of stock.
func consume_stock(tower_data: TowerData) -> bool:
	var current_stock: int = get_stock(tower_data)
	if current_stock > 0:
		_loadout_stock[tower_data] = current_stock - 1
		loadout_stock_changed.emit(tower_data, current_stock - 1)
		return true
	return false


## Refunds one unit of stock for the given tower (e.g. when selling).
func refund_stock(tower_data: TowerData) -> void:
	var current_stock: int = get_stock(tower_data)
	_loadout_stock[tower_data] = current_stock + 1
	loadout_stock_changed.emit(tower_data, current_stock + 1)


# --- Game State Management ---


## Sets the player data and updates health and currency signals.
func set_player_data(data: PlayerData) -> void:
	_player_data = data
	_initialize_loadout_stock()
	currency_changed.emit(_player_data.currency)


## Sets the current level and total waves, then emits relevant signals.
func set_level(level_index: int, data: StemData) -> void:
	_current_level = level_index
	_level_data = data
	if data and not data.spawns.is_empty():
		_total_waves = 1
	else:
		_total_waves = 0
	level_changed.emit(_current_level)
	wave_changed.emit(_current_wave, _total_waves)


## Updates the current wave and emits the wave_changed signal.
func set_wave(wave_index: int, stem_data: StemData = null) -> void:
	_current_wave = wave_index
	_calculate_wave_max_peak(stem_data)
	_current_peak = 0.0  # Reset peak meter at start of stem per design doc
	peak_meter_changed.emit(_current_peak, _current_max_peak)
	wave_changed.emit(_current_wave, _total_waves)


## Calculates the 100% capacity of the peak meter based on total wave health.
func _calculate_wave_max_peak(stem: StemData) -> void:
	if not stem:
		_current_max_peak = 100.0
		return

	var total_wave_health: int = 0
	for instruction in stem.spawns:
		if instruction and instruction.enemy_scene:
			# Instantiate purely to extract max_health without hardcoding
			var temp_state = instruction.enemy_scene.instantiate()
			if temp_state:
				var hp: int = 0
				if "data" in temp_state and temp_state.data != null:
					hp = temp_state.data.max_health
				elif "max_health" in temp_state:
					hp = temp_state.max_health

				total_wave_health += (hp * instruction.count)
			temp_state.free()

	if total_wave_health > 0:
		_current_max_peak = float(total_wave_health) * stem.clip_tolerance
	else:
		_current_max_peak = 100.0  # Failsafe

	if OS.is_debug_build():
		print("--- Wave Start ---")
		print("Max Peak Capability for Wave: ", _current_max_peak)


## Adds currency to the player and emits the currency_changed signal.
func add_currency(amount: int) -> void:
	if _player_data:
		_player_data.currency += amount
		currency_changed.emit(_player_data.currency)


## Removes currency from the player (clamped to 0) and emits the signal.
func remove_currency(amount: int) -> void:
	if _player_data:
		_player_data.currency = max(0, _player_data.currency - amount)
		currency_changed.emit(_player_data.currency)


## Adds volume to the peak meter, representing leaked enemies.
func add_peak_volume(amount: float) -> void:
	_current_peak += amount
	if _current_peak >= _current_max_peak:
		_current_peak = _current_max_peak
		peak_meter_changed.emit(_current_peak, _current_max_peak)
		stem_failed.emit()
		return
	peak_meter_changed.emit(_current_peak, _current_max_peak)

	if OS.is_debug_build():
		print("Enemy Reached Goal! Current Peak: ", _current_peak, " / ", _current_max_peak)


## Sets the peak meter to a specific ratio of the current max peak.
## Used by the debug toolbar quality buttons and peak slider.
func set_peak_ratio(ratio: float) -> void:
	_current_peak = clampf(ratio, 0.0, 1.0) * _current_max_peak

	if _current_peak >= _current_max_peak:
		peak_meter_changed.emit(_current_peak, _current_max_peak)
		stem_failed.emit()
		return

	peak_meter_changed.emit(_current_peak, _current_max_peak)


## Debug helper: adds a fixed amount of currency without gameplay side-effects.
func add_gold_debug(amount: int) -> void:
	add_currency(amount)


## Debug shortcut: completes the current stem immediately at the current peak
## meter value, bypassing the track-end enemy penalty.
## Intended for use by the debug toolbar only.
func force_complete_stem() -> void:
	if OS.is_debug_build():
		print("DEBUG: force_complete_stem() called — bypassing track-end penalty.")
	force_complete_stem_requested.emit()
	_is_wave_active = false
	wave_status_changed.emit(_is_wave_active)
	stem_completion_requested.emit()


# --- Transport Controls ---


## Toggles the game state between PAUSED and PLAYING.
## Also handles starting the next wave if one is not active.
func toggle_game_state() -> void:
	if not _is_wave_active:
		# If no wave is active, this button acts as "Next Wave"
		set_game_state(GameState.PLAYING)
		start_wave_requested.emit()
		_is_wave_active = true
		wave_status_changed.emit(_is_wave_active)
	else:
		# If a wave IS active, this button acts as Pause/Resume
		if _game_state == GameState.PAUSED:
			set_game_state(GameState.PLAYING)
		else:
			set_game_state(GameState.PAUSED)


## Sets the game state and updates the tree pause status.
func set_game_state(new_state: GameState) -> void:
	_game_state = new_state
	get_tree().paused = (_game_state == GameState.PAUSED)
	game_state_changed.emit(_game_state)


## Increases game speed to the next step.
func step_speed_up() -> void:
	if _game_speed_index < speed_steps.size() - 1:
		_game_speed_index += 1
		_update_time_scale()


## Decreases game speed to the previous step.
func step_speed_down() -> void:
	if _game_speed_index > 0:
		_game_speed_index -= 1
		_update_time_scale()


func _update_time_scale() -> void:
	var new_speed: float = speed_steps[_game_speed_index]
	Engine.time_scale = new_speed
	game_speed_changed.emit(new_speed)


## Marks the current wave as completed and signals for stem grading.
func wave_completed() -> void:
	_is_wave_active = false
	wave_status_changed.emit(_is_wave_active)
	stem_completion_requested.emit()


## Resets the game state to default values (e.g. for restarting level).
func reset_state() -> void:
	# NOTE: We no longer reload Player Data from disk here, as it wipes
	# Studio Loadout changes. We preserve the in-memory '_player_data'
	# but reset its per-run currency.
	if _player_data:
		# Reset to the baseline starting currency defined in the resource class
		_player_data.currency = 100
		currency_changed.emit(_player_data.currency)

	_initialize_loadout_stock()

	# Reset Wave counters
	_current_wave = 0
	_total_waves = 0
	_is_wave_active = false

	# Reset Game State
	_game_state = GameState.PLAYING
	_game_speed_index = 0
	_current_peak = 0.0
	_current_max_peak = 100.0
	if speed_steps.size() > 0:
		Engine.time_scale = speed_steps[0]
	else:
		Engine.time_scale = 1.0
	get_tree().paused = false

	# Emit updates
	currency_changed.emit(_player_data.currency)
	wave_changed.emit(_current_wave, _total_waves)
	wave_status_changed.emit(_is_wave_active)
	peak_meter_changed.emit(_current_peak, _current_max_peak)
	_reset_relic_state()


# --- Relic Logic ---


## Attempts to use a relic. Returns true if successful.
## Relics can only be used once per level.
func try_use_relic(_relic_data: Resource) -> bool:
	if _relic_used_this_level:
		return false

	_relic_used_this_level = true
	relic_state_changed.emit(false)
	return true


func is_relic_used() -> bool:
	return _relic_used_this_level


func _reset_relic_state() -> void:
	_relic_used_this_level = false
	relic_state_changed.emit(true)
