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

## Node references.
@onready var health_label := $StatsContainer/LabelContainer/HealthLabel as Label
@onready var currency_label := $StatsContainer/LabelContainer/CurrencyLabel as Label
@onready var wave_label := $StatsContainer/LabelContainer/WaveLabel as Label
@onready var build_tower_button := $BuildButtonsGroup/Columns/MainButtons/BuildTowerButton as Button
@onready var sell_tower_button := $BuildButtonsGroup/Columns/MainButtons/SellTowerButton as Button
@onready var upgrade_button := $BuildButtonsGroup/Columns/MainButtons/UpgradeButton as Button
@onready var tower_build_menu := $BuildButtonsGroup/Columns/TowerBuildMenu as VBoxContainer
@onready var next_wave_button := $BuildButtonsGroup/Columns/MainButtons/NextWave as Button
@onready var build_bomb_tower_button := $BuildButtonsGroup/Columns/TowerBuildMenu/BuildBombTowerButton as Button
@onready var build_archer_tower_button := $BuildButtonsGroup/Columns/TowerBuildMenu/BuildArcherTowerButton as Button
@onready var build_magic_tower_button := $BuildButtonsGroup/Columns/TowerBuildMenu/BuildMagicTowerButton as Button


## Called when this HUD enters the scene tree.
func _ready() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		build_manager.tower_selected.connect(_on_tower_selected)
		build_manager.tower_deselected.connect(_on_tower_deselected)

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.wave_changed.connect(_on_wave_changed)

	_on_health_changed(GameManager.player_data.health)
	_on_currency_changed(GameManager.player_data.currency)
	_on_wave_changed(GameManager.current_wave, GameManager.total_waves)

	_update_tower_build_buttons(GameManager.player_data.currency)


## Called when this HUD is about to leave the scene tree.
func _exit_tree() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		build_manager.tower_selected.disconnect(_on_tower_selected)
		build_manager.tower_deselected.disconnect(_on_tower_deselected)

	GameManager.health_changed.disconnect(_on_health_changed)
	GameManager.currency_changed.disconnect(_on_currency_changed)
	GameManager.wave_changed.disconnect(_on_wave_changed)


# --- PUBLIC INPUT HANDLER (Called by InputManager) ---

func handle_click(screen_position: Vector2) -> bool:
	# Check buttons in reverse order of visibility/likelihood
	if tower_build_menu.visible:
		if build_bomb_tower_button.get_global_rect().has_point(screen_position):
			if is_instance_valid(bomb_tower_data):
				build_tower_requested.emit(bomb_tower_data)
				tower_build_menu.visible = false
			return true
		if build_archer_tower_button.get_global_rect().has_point(screen_position):
			if is_instance_valid(archer_tower_data):
				build_tower_requested.emit(archer_tower_data)
				tower_build_menu.visible = false
			return true
		if build_magic_tower_button.get_global_rect().has_point(screen_position):
			if is_instance_valid(magic_tower_data):
				build_tower_requested.emit(magic_tower_data)
				tower_build_menu.visible = false
			return true

	if sell_tower_button.visible and sell_tower_button.get_global_rect().has_point(screen_position):
		sell_tower_requested.emit()
		tower_build_menu.visible = false
		return true

	if upgrade_button.visible and upgrade_button.get_global_rect().has_point(screen_position):
		var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
		if is_instance_valid(build_manager) and is_instance_valid(build_manager.get_selected_tower()):
			build_manager.get_selected_tower().upgrade()
			_update_upgrade_button()
			_update_sell_button()
		return true

	if build_tower_button.get_global_rect().has_point(screen_position):
		tower_build_menu.visible = not tower_build_menu.visible
		return true

	if next_wave_button.get_global_rect().has_point(screen_position):
		next_wave_requested.emit()
		return true

	return false # No button was clicked


# --- PRIVATE SIGNAL HANDLERS & UPDATERS ---

func _on_tower_selected() -> void:
	sell_tower_button.visible = true
	upgrade_button.visible = true
	_update_upgrade_button()
	_update_sell_button_state()


func _on_tower_deselected() -> void:
	sell_tower_button.visible = false
	upgrade_button.visible = false
	sell_tower_button.text = "Sell"


func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


func _on_currency_changed(new_currency: int) -> void:
	currency_label.text = "Gold: %d" % new_currency
	_update_tower_build_buttons(new_currency)
	_update_upgrade_button()


func _update_upgrade_button() -> void:
	if not upgrade_button.visible:
		return
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager): return
	var selected_tower: TemplateTower = build_manager.get_selected_tower()
	if not is_instance_valid(selected_tower): return
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


func _update_sell_button_state() -> void:
	if not sell_tower_button.visible: return
	var is_boss_wave := false
	if GameManager.level_data and GameManager.current_wave > 0:
		var wave_index := GameManager.current_wave - 1
		if wave_index < GameManager.level_data.waves.size():
			var current_wave_data: WaveData = GameManager.level_data.waves[wave_index]
			if current_wave_data: is_boss_wave = current_wave_data.is_boss_wave
	if is_boss_wave:
		sell_tower_button.text = "Boss Wave"
		sell_tower_button.disabled = true
	else:
		sell_tower_button.disabled = false
		_update_sell_button()


func _update_sell_button() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager): return
	var sell_value := build_manager.get_selected_tower_sell_value()
	sell_tower_button.text = "Sell (%dg)" % sell_value


func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current_wave, total_waves]
	_update_sell_button_state()


func set_next_wave_enabled(is_enabled: bool) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.disabled = not is_enabled


func set_next_wave_text(text: String) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.text = text


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
