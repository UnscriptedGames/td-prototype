# res://UI/HUD/level_hud.gd
class_name LevelHUD
extends CanvasLayer

## Announces the player wants to build or sell a tower.
signal build_tower_requested(tower_data: TowerData)
signal sell_tower_requested

## Announces the player has requested the next wave to start from the HUD.
signal next_wave_requested

@export var bomb_tower_data: TowerData
@export var archer_tower_data: TowerData
@export var magic_tower_data: TowerData

## Node references (kept to your current scene paths).
@onready var health_label := $HudRoot/StatsContainer/LabelContainer/HealthLabel as Label
@onready var currency_label := $HudRoot/StatsContainer/LabelContainer/CurrencyLabel as Label
@onready var wave_label := $HudRoot/StatsContainer/LabelContainer/WaveLabel as Label
@onready var build_tower_button := $HudRoot/BuildButtonsGroup/Columns/MainButtons/BuildTowerButton as Button
@onready var sell_tower_button := $HudRoot/BuildButtonsGroup/Columns/MainButtons/SellTowerButton as Button
@onready var tower_build_menu := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu as VBoxContainer
@onready var next_wave_button := $HudRoot/BuildButtonsGroup/Columns/MainButtons/NextWave as Button
@onready var build_bomb_tower_button := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu/BuildBombTowerButton as Button
@onready var build_archer_tower_button := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu/BuildArcherTowerButton as Button
@onready var build_magic_tower_button := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu/BuildMagicTowerButton as Button


## Called when this HUD enters the scene tree.
## Connects to BuildManager (selection state) and GameManager (stats).
func _ready() -> void:
	# Connect to the BuildManager in the active level (group ensures decoupling).
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		build_manager.tower_selected.connect(_on_tower_selected)
		build_manager.tower_deselected.connect(_on_tower_deselected)

	# Subscribe to GameManager updates for labels and button affordances.
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.wave_changed.connect(_on_wave_changed)

	# Initialise the labels once so the HUD is correct before any signals fire.
	_on_health_changed(GameManager.player_data.health)
	_on_currency_changed(GameManager.player_data.currency)
	_on_wave_changed(GameManager.current_wave, GameManager.total_waves)

	# Refresh the build buttons’ labels and enabled state based on current gold.
	_update_tower_build_buttons(GameManager.player_data.currency)



## Called when this HUD is about to leave the scene tree.
## Disconnects to avoid dangling references in pooled scenes.
func _exit_tree() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		build_manager.tower_selected.disconnect(_on_tower_selected)
		build_manager.tower_deselected.disconnect(_on_tower_deselected)

	GameManager.health_changed.disconnect(_on_health_changed)
	GameManager.currency_changed.disconnect(_on_currency_changed)
	GameManager.wave_changed.disconnect(_on_wave_changed)


## Shows the Sell button when a tower is selected.
func _on_tower_selected() -> void:
	sell_tower_button.visible = true


## Hides the Sell button when selection is cleared.
func _on_tower_deselected() -> void:
	sell_tower_button.visible = false


## Toggles the tower build menu when the Build button is pressed.
func _on_build_tower_button_pressed() -> void:
	tower_build_menu.visible = not tower_build_menu.visible


## Emits a sell request when the Sell button is pressed and hides the menu.
func _on_sell_tower_button_pressed() -> void:
	sell_tower_requested.emit()
	tower_build_menu.visible = false


## Updates the Health label from GameManager.
func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


## Updates the Gold label and refreshes build button states.
func _on_currency_changed(new_currency: int) -> void:
	currency_label.text = "Gold: %d" % new_currency
	_update_tower_build_buttons(new_currency)


## Updates the Wave label from GameManager.
func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current_wave, total_waves]


## Enables or disables the Next Wave button for external control (e.g., Level script).
func set_next_wave_enabled(is_enabled: bool) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.disabled = not is_enabled


## Updates the Next Wave button’s text.
func set_next_wave_text(text: String) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.text = text


## Inspector-wired handler: fired when Next Wave is pressed.
func _on_next_wave_pressed() -> void:
	next_wave_requested.emit()


## Inspector-wired: build Bomb tower request; hides the menu after selection.
func _on_build_bomb_tower_button_pressed() -> void:
	if is_instance_valid(bomb_tower_data):
		build_tower_requested.emit(bomb_tower_data)
		tower_build_menu.visible = false


## Inspector-wired: build Archer tower request; hides the menu after selection.
func _on_build_archer_tower_button_pressed() -> void:
	if is_instance_valid(archer_tower_data):
		build_tower_requested.emit(archer_tower_data)
		tower_build_menu.visible = false


## Inspector-wired: build Magic tower request; hides the menu after selection.
func _on_build_magic_tower_button_pressed() -> void:
	if is_instance_valid(magic_tower_data):
		build_tower_requested.emit(magic_tower_data)
		tower_build_menu.visible = false


## Refreshes build-button labels and enabled state based on current gold.
func _update_tower_build_buttons(player_gold: int) -> void:
	if is_instance_valid(bomb_tower_data) and is_instance_valid(build_bomb_tower_button):
		var bomb_cost: int = bomb_tower_data.cost
		build_bomb_tower_button.text = "Bomb (%dg)" % bomb_cost
		build_bomb_tower_button.disabled = player_gold < bomb_cost

	if is_instance_valid(archer_tower_data) and is_instance_valid(build_archer_tower_button):
		var archer_cost: int = archer_tower_data.cost
		build_archer_tower_button.text = "Archer (%dg)" % archer_cost
		build_archer_tower_button.disabled = player_gold < archer_cost

	if is_instance_valid(magic_tower_data) and is_instance_valid(build_magic_tower_button):
		var magic_cost: int = magic_tower_data.cost
		build_magic_tower_button.text = "Magic (%dg)" % magic_cost
		build_magic_tower_button.disabled = player_gold < magic_cost
