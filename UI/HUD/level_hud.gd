extends CanvasLayer
class_name LevelHUD

## Announces the player wants to build or sell a tower.

signal build_tower_requested(tower_data: TowerData)
signal sell_tower_requested

@export var bomb_tower_data: TowerData
@export var archer_tower_data: TowerData
@export var magic_tower_data: TowerData

## Node References
@onready var health_label := $HealthLabel as Label
@onready var currency_label := $CurrencyLabel as Label
@onready var wave_label := $WaveLabel as Label
@onready var build_tower_button := $BuildTowerButton as Button
@onready var sell_tower_button := $SellTowerButton as Button
@onready var tower_build_menu := $TowerBuildMenu as VBoxContainer


## Called when the node enters the scene tree. Connects to GameManager signals.
func _ready() -> void:
	# Find the BuildManager in the scene tree to connect to its signals.
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		build_manager.tower_selected.connect(_on_tower_selected)
		build_manager.tower_deselected.connect(_on_tower_deselected)

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
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		build_manager.tower_selected.disconnect(_on_tower_selected)
		build_manager.tower_deselected.disconnect(_on_tower_deselected)

	# Disconnect from signals to prevent memory leaks
	GameManager.health_changed.disconnect(_on_health_changed)
	GameManager.currency_changed.disconnect(_on_currency_changed)
	GameManager.wave_changed.disconnect(_on_wave_changed)


## Shows the sell button when a tower is selected.
func _on_tower_selected() -> void:
	sell_tower_button.visible = true


## Hides the sell button when a tower is deselected.
func _on_tower_deselected() -> void:
	sell_tower_button.visible = false


func _on_build_tower_button_pressed() -> void:
	tower_build_menu.visible = not tower_build_menu.visible


func _on_sell_tower_button_pressed() -> void:
	emit_signal("sell_tower_requested")


## Updates the health display when the player's health changes.
func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


## Updates the currency display when the player's currency changes.
func _on_currency_changed(new_currency: int) -> void:
	currency_label.text = "Gold: %d" % new_currency


## Updates the wave display when the wave number changes.
func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current_wave, total_waves]


func _on_build_bomb_tower_button_pressed() -> void:
	if is_instance_valid(bomb_tower_data):
		emit_signal("build_tower_requested", bomb_tower_data)
		tower_build_menu.visible = false


func _on_build_archer_tower_button_pressed() -> void:
	if is_instance_valid(archer_tower_data):
		emit_signal("build_tower_requested", archer_tower_data)
		tower_build_menu.visible = false


func _on_build_magic_tower_button_pressed() -> void:
	if is_instance_valid(magic_tower_data):
		emit_signal("build_tower_requested", magic_tower_data)
		tower_build_menu.visible = false
