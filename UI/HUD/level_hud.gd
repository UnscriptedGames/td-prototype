extends CanvasLayer

## Manages and displays player information like health, currency, and wave count.


## Announces the player wants to build a tower
signal build_tower_requested

## Node References
@onready var health_label := $HealthLabel as Label
@onready var currency_label := $CurrencyLabel as Label
@onready var wave_label := $WaveLabel as Label


## Called when the node enters the scene tree. Connects to GameManager signals.
func _ready() -> void:
	# Connect to signals from the global GameManager
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	
	# Manually update labels once on startup
	_on_health_changed(GameManager.player_data.health)
	_on_currency_changed(GameManager.player_data.currency)
	_on_wave_changed(GameManager.current_wave, GameManager.total_waves)


## Called before the node is removed from the scene tree. Disconnects signals.
func _exit_tree() -> void:
	# Disconnect from signals to prevent memory leaks
	GameManager.health_changed.disconnect(_on_health_changed)
	GameManager.currency_changed.disconnect(_on_currency_changed)
	GameManager.wave_changed.disconnect(_on_wave_changed)


## Updates the health display when the player's health changes.
func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


## Updates the currency display when the player's currency changes.
func _on_currency_changed(new_currency: int) -> void:
	currency_label.text = "Gold: %d" % new_currency


## Updates the wave display when the wave number changes.
func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current_wave, total_waves]

func _on_build_tower_button_pressed() -> void:
	emit_signal("build_tower_requested")
