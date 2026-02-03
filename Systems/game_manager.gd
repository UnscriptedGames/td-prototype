extends Node


# Signals for communicating changes to other nodes
signal health_changed(new_health)
signal currency_changed(new_currency)
signal wave_changed(current_wave, total_waves)
signal level_changed(current_level)
signal game_state_changed(new_state)
signal wave_status_changed(is_active: bool)
signal game_speed_changed(new_speed: float)
signal start_wave_requested

enum GameState {PAUSED, PLAYING}
const SPEED_STEPS: Array[float] = [1.0, 1.25, 1.5, 2.0, 4.0]

# Player and level state variables
var _player_data: PlayerData
var _level_data: LevelData
var _current_level: int = 0
var _current_wave: int = 0
var _total_waves: int = 0
var _game_state: GameState = GameState.PLAYING
var _is_wave_active: bool = false
var _game_speed_index: int = 0

var player_data: PlayerData:
	get: return _player_data

var level_data: LevelData:
	get: return _level_data

var current_level: int:
	get: return _current_level

var current_wave: int:
	get: return _current_wave

var total_waves: int:
	get: return _total_waves

var game_state: GameState:
	get: return _game_state

var is_wave_active: bool:
	get: return _is_wave_active


# Loads player data and emits initial signals when the game starts
func _ready() -> void:
	_player_data = load("res://Config/Players/player_data.tres")
	health_changed.emit(_player_data.health)
	currency_changed.emit(_player_data.currency)


# Sets the player data and updates health and currency signals
func set_player_data(data: PlayerData) -> void:
	_player_data = data
	health_changed.emit(_player_data.health)
	currency_changed.emit(_player_data.currency)


# Sets the current level and total waves, then emits relevant signals
func set_level(level: int, data: LevelData) -> void:
	_current_level = level
	_level_data = data
	if data and not data.waves.is_empty():
		_total_waves = data.waves.size()
	else:
		_total_waves = 0
	level_changed.emit(_current_level)
	wave_changed.emit(_current_wave, _total_waves)


# Updates the current wave and emits the wave_changed signal
func set_wave(wave: int) -> void:
	_current_wave = wave
	wave_changed.emit(_current_wave, _total_waves)


# Adds currency to the player and emits the currency_changed signal
func add_currency(amount: int) -> void:
	if _player_data:
		_player_data.currency += amount
		currency_changed.emit(_player_data.currency)


# Removes currency from the player (not below zero) and emits the currency_changed signal
func remove_currency(amount: int) -> void:
	if _player_data:
		_player_data.currency = max(0, _player_data.currency - amount)
		currency_changed.emit(_player_data.currency)


# Damages the player (not below zero) and emits the health_changed signal
func damage_player(amount: int) -> void:
	if _player_data:
		_player_data.health = max(0, _player_data.health - amount)
		health_changed.emit(_player_data.health)


# Heals the player and emits the health_changed signal
func heal_player(amount: int) -> void:
	if _player_data:
		_player_data.health += amount
		health_changed.emit(_player_data.health)


# Toggles the game state between PAUSED and PLAYING
func toggle_game_state() -> void:
	if not _is_wave_active:
		# If no wave is active, this button acts as "Next Wave"
		set_game_state(GameState.PLAYING) # Ensure we are playing
		start_wave_requested.emit()
		_is_wave_active = true
		wave_status_changed.emit(_is_wave_active)
	else:
		# If a wave IS active, this button acts as Pause/Resume
		if _game_state == GameState.PAUSED:
			set_game_state(GameState.PLAYING)
		else:
			set_game_state(GameState.PAUSED)


# Sets the game state and updates the tree pause status
func set_game_state(new_state: GameState) -> void:
	_game_state = new_state
	get_tree().paused = (_game_state == GameState.PAUSED)
	game_state_changed.emit(_game_state)


func step_speed_up() -> void:
	if _game_speed_index < SPEED_STEPS.size() - 1:
		_game_speed_index += 1
		_update_time_scale()

func step_speed_down() -> void:
	if _game_speed_index > 0:
		_game_speed_index -= 1
		_update_time_scale()

func _update_time_scale() -> void:
	var new_speed = SPEED_STEPS[_game_speed_index]
	Engine.time_scale = new_speed
	game_speed_changed.emit(new_speed)


func wave_completed() -> void:
	_is_wave_active = false
	wave_status_changed.emit(_is_wave_active)


func reset_state() -> void:
	# Resets the game state to default values
	# Reload Player Data to reset health/currency (Ignore Cache to get fresh values)
	_player_data = ResourceLoader.load("res://Config/Players/player_data.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	
	# Reset Wave counters
	_current_wave = 0
	_total_waves = 0
	_is_wave_active = false
	
	# Reset Game State
	_game_state = GameState.PLAYING
	_game_speed_index = 0
	Engine.time_scale = SPEED_STEPS[0]
	get_tree().paused = false
	
	# Emit updates
	health_changed.emit(_player_data.health)
	currency_changed.emit(_player_data.currency)
	wave_changed.emit(_current_wave, _total_waves)
	wave_status_changed.emit(_is_wave_active)
