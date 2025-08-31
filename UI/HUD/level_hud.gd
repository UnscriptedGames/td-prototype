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
@onready var upgrade_button := $HudRoot/BuildButtonsGroup/Columns/MainButtons/UpgradeButton as Button
@onready var tower_build_menu := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu as VBoxContainer
@onready var next_wave_button := $HudRoot/BuildButtonsGroup/Columns/MainButtons/NextWave as Button
@onready var build_bomb_tower_button := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu/BuildBombTowerButton as Button
@onready var build_archer_tower_button := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu/BuildArcherTowerButton as Button
@onready var build_magic_tower_button := $HudRoot/BuildButtonsGroup/Columns/TowerBuildMenu/BuildMagicTowerButton as Button


## Called when this HUD enters the scene tree.
## Connects to BuildManager (selection state) and GameManager (stats).
func _ready() -> void:
	# This can also be connected from the editor.
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)

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
	upgrade_button.visible = true
	_update_upgrade_button()
	_update_sell_button()


## Hides the Sell button when selection is cleared.
func _on_tower_deselected() -> void:
	sell_tower_button.visible = false
	upgrade_button.visible = false
	sell_tower_button.text = "Sell"


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
	_update_upgrade_button()


func _on_upgrade_button_pressed() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager) and is_instance_valid(build_manager.get_selected_tower()):
		build_manager.get_selected_tower().upgrade()
		# After an upgrade attempt, refresh the button states
		_update_upgrade_button()
		_update_sell_button()


func _update_upgrade_button() -> void:
	if not upgrade_button.visible:
		return

	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager):
		return

	var selected_tower: TemplateTower = build_manager.get_selected_tower()
	if not is_instance_valid(selected_tower):
		return

	var tower_data: TowerData = selected_tower.data
	var current_level: int = selected_tower.current_level

	if current_level >= tower_data.levels.size():
		upgrade_button.text = "Max Level"
		upgrade_button.disabled = true
	else:
		var next_level_data: TowerLevelData = tower_data.levels[current_level]
		var cost: int = next_level_data.cost
		upgrade_button.text = "Upgrade (%dg)" % cost
		upgrade_button.disabled = not GameManager.player_data.can_afford(cost)


func _update_sell_button() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager):
		return

	var sell_value := build_manager.get_selected_tower_sell_value()
	sell_tower_button.text = "Sell (%dg)" % sell_value


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
		if not bomb_tower_data.levels.is_empty():
			var bomb_cost: int = bomb_tower_data.levels[0].cost
			build_bomb_tower_button.text = "Bomb (%dg)" % bomb_cost
			build_bomb_tower_button.disabled = player_gold < bomb_cost
		else:
			build_bomb_tower_button.text = "Bomb (N/A)"
			build_bomb_tower_button.disabled = true

	if is_instance_valid(archer_tower_data) and is_instance_valid(build_archer_tower_button):
		if not archer_tower_data.levels.is_empty():
			var archer_cost: int = archer_tower_data.levels[0].cost
			build_archer_tower_button.text = "Archer (%dg)" % archer_cost
			build_archer_tower_button.disabled = player_gold < archer_cost
		else:
			build_archer_tower_button.text = "Archer (N/A)"
			build_archer_tower_button.disabled = true

	if is_instance_valid(magic_tower_data) and is_instance_valid(build_magic_tower_button):
		if not magic_tower_data.levels.is_empty():
			var magic_cost: int = magic_tower_data.levels[0].cost
			build_magic_tower_button.text = "Magic (%dg)" % magic_cost
			build_magic_tower_button.disabled = player_gold < magic_cost
		else:
			build_magic_tower_button.text = "Magic (N/A)"
			build_magic_tower_button.disabled = true
