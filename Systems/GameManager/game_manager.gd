extends Node

## Signals for communicating changes to other nodes
signal health_changed(new_health)
signal currency_changed(new_currency)
signal wave_changed(current_wave, total_waves)
signal level_changed(current_level)

## Player and level state variables
var player_data: PlayerData
var current_level: int = 0
var current_wave: int = 0
var total_waves: int = 0

## Loads player data and emits initial signals when the game starts
func _ready():
	player_data = load("res://Systems/GameManager/player_data.tres")
	emit_signal("health_changed", player_data.health)
	emit_signal("currency_changed", player_data.currency)


## Sets the player data and updates health and currency signals
func set_player_data(data: PlayerData) -> void:
	player_data = data
	emit_signal("health_changed", player_data.health)
	emit_signal("currency_changed", player_data.currency)


## Sets the current level and total waves, then emits relevant signals
func set_level(level: int, wave_count: int) -> void:
	current_level = level
	total_waves = wave_count
	emit_signal("level_changed", current_level)
	emit_signal("wave_changed", current_wave, total_waves)


## Updates the current wave and emits the wave_changed signal
func set_wave(wave: int) -> void:
	current_wave = wave
	emit_signal("wave_changed", current_wave, total_waves)


## Adds currency to the player and emits the currency_changed signal
func add_currency(amount: int) -> void:
	if player_data:
		player_data.currency += amount
		emit_signal("currency_changed", player_data.currency)


## Removes currency from the player (not below zero) and emits the currency_changed signal
func remove_currency(amount: int) -> void:
	if player_data:
		player_data.currency = max(0, player_data.currency - amount)
		emit_signal("currency_changed", player_data.currency)


## Damages the player (not below zero) and emits the health_changed signal
func damage_player(amount: int) -> void:
	if player_data:
		player_data.health = max(0, player_data.health - amount)
		emit_signal("health_changed", player_data.health)


## Heals the player and emits the health_changed signal
func heal_player(amount: int) -> void:
	if player_data:
		player_data.health += amount
		emit_signal("health_changed", player_data.health)
