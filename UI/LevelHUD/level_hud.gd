# res://UI/HUD/level_hud.gd
class_name LevelHUD
extends CanvasLayer

## Announces the player wants to build or sell a tower.
signal sell_tower_requested

## Announces the player has requested the next wave to start from the HUD.
signal next_wave_requested

## Announces the player has changed the target priority.
signal target_priority_changed(priority: TargetingPriority.Priority)

@export var bomb_tower_data: TowerData
@export var archer_tower_data: TowerData
@export var magic_tower_data: TowerData

## Node references.
@onready var health_label := $StatsContainer/LabelContainer/HealthLabel as Label
@onready var currency_label := $StatsContainer/LabelContainer/CurrencyLabel as Label
@onready var wave_label := $StatsContainer/LabelContainer/WaveLabel as Label
@onready var next_wave_button := $BuildButtonsGroup/Columns/MainButtons/NextWave as Button

@onready var tower_details_container := $TowerDetailsContainer as PanelContainer
@onready var tower_name_label := $TowerDetailsContainer/VBoxContainer/TowerNameLabel as Label
@onready var tower_level_label := $TowerDetailsContainer/VBoxContainer/TowerLevelLabel as Label
@onready var range_label := $TowerDetailsContainer/VBoxContainer/RangeLabel as Label
@onready var damage_label := $TowerDetailsContainer/VBoxContainer/DamageLabel as Label
@onready var fire_rate_label := $TowerDetailsContainer/VBoxContainer/FireRateLabel as Label
@onready var projectile_speed_label := $TowerDetailsContainer/VBoxContainer/ProjectileSpeedLabel as Label
@onready var aoe_label := $TowerDetailsContainer/VBoxContainer/AoELabel as Label
@onready var max_targets_label := $TowerDetailsContainer/VBoxContainer/MaxTargetsLabel as Label
@onready var upgrade_button := $TowerDetailsContainer/VBoxContainer/UpgradeButton as Button
@onready var sell_tower_button := $TowerDetailsContainer/VBoxContainer/SellTowerButton as Button
@onready var target_priority_button := $TowerDetailsContainer/VBoxContainer/TargetPriorityButton as Button

@onready var target_priority_container := $TargetPriorityContainer as PanelContainer
@onready var most_progress_check_button := $TargetPriorityContainer/VBoxContainer/MostProgressCheckButton as CheckButton
@onready var least_progress_check_button := $TargetPriorityContainer/VBoxContainer/LeastProgressCheckButton as CheckButton
@onready var strongest_enemy_check_button := $TargetPriorityContainer/VBoxContainer/StrongestEnemyCheckButton as CheckButton
@onready var weakest_enemy_check_button := $TargetPriorityContainer/VBoxContainer/WeakestEnemyCheckButton as CheckButton
@onready var lowest_health_check_button := $TargetPriorityContainer/VBoxContainer/LowestHealthCheckButton as CheckButton


## Called when this HUD enters the scene tree.
func _ready() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		build_manager.tower_selected.connect(_on_tower_selected)
		build_manager.tower_deselected.connect(_on_tower_deselected)

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.wave_changed.connect(_on_wave_changed)

	target_priority_button.pressed.connect(_on_target_priority_button_pressed)
	most_progress_check_button.toggled.connect(_on_target_priority_changed)
	least_progress_check_button.toggled.connect(_on_target_priority_changed)
	strongest_enemy_check_button.toggled.connect(_on_target_priority_changed)
	weakest_enemy_check_button.toggled.connect(_on_target_priority_changed)
	lowest_health_check_button.toggled.connect(_on_target_priority_changed)

	_on_health_changed(GameManager.player_data.health)
	_on_currency_changed(GameManager.player_data.currency)
	_on_wave_changed(GameManager.current_wave, GameManager.total_waves)




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
	# If the priority panel is visible, any click inside it should be consumed by the UI
	if target_priority_container.visible and target_priority_container.get_global_rect().has_point(screen_position):
		# The individual check buttons already handle their logic via signals,
		# we just need to consume the input event here to prevent deselection.
		return true

	# Check buttons in reverse order of visibility/likelihood
	if sell_tower_button.visible and sell_tower_button.get_global_rect().has_point(screen_position):
		sell_tower_requested.emit()
		GlobalSignals.hand_condense_requested.emit()
		return true

	if upgrade_button.visible and upgrade_button.get_global_rect().has_point(screen_position):
		var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
		if is_instance_valid(build_manager) and is_instance_valid(build_manager.get_selected_tower()):
			build_manager.get_selected_tower().upgrade()
			_update_tower_details()
			GlobalSignals.hand_condense_requested.emit()
		return true

	if target_priority_button.visible and target_priority_button.get_global_rect().has_point(screen_position):
		# The button's pressed signal will handle the logic. We just consume the event.
		return true

	if next_wave_button.get_global_rect().has_point(screen_position):
		next_wave_requested.emit()
		GlobalSignals.hand_condense_requested.emit()
		return true

	return false # No button was clicked


# --- PRIVATE SIGNAL HANDLERS & UPDATERS ---

func _on_tower_selected() -> void:
	tower_details_container.visible = true
	target_priority_container.visible = false
	_update_tower_details()
	GlobalSignals.hand_condense_requested.emit()


func _on_tower_deselected() -> void:
	tower_details_container.visible = false
	target_priority_container.visible = false


func _on_target_priority_button_pressed() -> void:
	target_priority_container.visible = not target_priority_container.visible


func _on_target_priority_changed(toggled_on: bool) -> void:
	if not toggled_on:
		# This prevents the signal from firing when a button is turned off.
		# The ButtonGroup ensures another button will be toggled on, firing its own signal.
		return

	var priority: TargetingPriority.Priority

	if most_progress_check_button.button_pressed:
		priority = TargetingPriority.Priority.MOST_PROGRESS
	elif least_progress_check_button.button_pressed:
		priority = TargetingPriority.Priority.LEAST_PROGRESS
	elif strongest_enemy_check_button.button_pressed:
		priority = TargetingPriority.Priority.STRONGEST_ENEMY
	elif weakest_enemy_check_button.button_pressed:
		priority = TargetingPriority.Priority.WEAKEST_ENEMY
	elif lowest_health_check_button.button_pressed:
		priority = TargetingPriority.Priority.LOWEST_HEALTH

	emit_signal("target_priority_changed", priority)


func _update_tower_details() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager): return
	var selected_tower: TemplateTower = build_manager.get_selected_tower()
	if not is_instance_valid(selected_tower): return

	var tower_data: TowerData = selected_tower.data
	var current_level_index: int = selected_tower.current_level -1
	var level_data: TowerLevelData = tower_data.levels[current_level_index]

	tower_name_label.text = tower_data.tower_name
	tower_level_label.text = "Level: %d" % selected_tower.current_level
	range_label.text = "Range: %d" % level_data.tower_range
	damage_label.text = "Damage: %d" % level_data.damage
	fire_rate_label.text = "Fire Rate: %.2f" % level_data.fire_rate
	projectile_speed_label.text = "Projectile Speed: %d" % level_data.projectile_speed
	aoe_label.text = "AoE: %s" % ("Yes" if level_data.is_aoe else "No")
	max_targets_label.text = "Max Targets: %d" % level_data.targets

	_update_upgrade_button()
	_update_sell_button_state()


func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


func _on_currency_changed(new_currency: int) -> void:
	currency_label.text = "Gold: %d" % new_currency
	if tower_details_container.visible:
		_update_upgrade_button()


func _update_upgrade_button() -> void:
	if not tower_details_container.visible:
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
	if not tower_details_container.visible: return
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
	if tower_details_container.visible:
		_update_sell_button_state()


func set_next_wave_enabled(is_enabled: bool) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.disabled = not is_enabled


func set_next_wave_text(text: String) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.text = text
