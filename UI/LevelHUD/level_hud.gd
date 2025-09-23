# res://UI/HUD/level_hud.gd
class_name LevelHUD
extends CanvasLayer

## Announces the player wants to build or sell a tower.
signal sell_tower_requested

## Announces the player has requested the next wave to start from the HUD.
signal next_wave_requested

## Announces the player has changed the target priority.
signal target_priority_changed(priority: TargetPriority.Priority)

@export var bomb_tower_data: TowerData
@export var archer_tower_data: TowerData
@export var magic_tower_data: TowerData

## Node references.
@onready var health_label := $StatsContainer/LabelContainer/HealthLabel as Label
@onready var currency_label := $StatsContainer/LabelContainer/CurrencyLabel as Label
@onready var wave_label := $StatsContainer/LabelContainer/WaveLabel as Label
@onready var next_wave_button := $BuildButtonsGroup/Columns/MainButtons/NextWave as Button

@onready var tower_details_container := $TowerDetails/TowerDetailsContainer as PanelContainer
@onready var tower_name_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/TowerNameLabel as Label
@onready var tower_level_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/TowerLevelLabel as Label
@onready var range_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/RangeLabel as Label
@onready var damage_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/DamageLabel as Label
@onready var fire_rate_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/FireRateLabel as Label
@onready var projectile_speed_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/ProjectileSpeedLabel as Label
@onready var attack_modifier_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/AttackModifierLabel as Label
@onready var status_effects_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/StatusEffectsLabel as Label
@onready var max_targets_label := $TowerDetails/TowerDetailsContainer/VBoxContainer/MaxTargetsLabel as Label
@onready var upgrade_buttons: Array[Button] = [
	$TowerDetails/TowerDetailsContainer/VBoxContainer/UpgradeGrid/UpgradeButton1,
	$TowerDetails/TowerDetailsContainer/VBoxContainer/UpgradeGrid/UpgradeButton2,
	$TowerDetails/TowerDetailsContainer/VBoxContainer/UpgradeGrid/UpgradeButton3,
	$TowerDetails/TowerDetailsContainer/VBoxContainer/UpgradeGrid/UpgradeButton4,
	$TowerDetails/TowerDetailsContainer/VBoxContainer/UpgradeGrid/UpgradeButton5,
	$TowerDetails/TowerDetailsContainer/VBoxContainer/UpgradeGrid/UpgradeButton6
]
@onready var sell_tower_button := $TowerDetails/TowerDetailsContainer/VBoxContainer/SellTowerButton as Button
@onready var target_priority_button := $TowerDetails/TowerDetailsContainer/VBoxContainer/TargetPriorityButton as Button

@onready var target_priority_container := $TowerDetails/TargetPriorityContainer as PanelContainer
@onready var most_progress_check_button := $TowerDetails/TargetPriorityContainer/VBoxContainer/MostProgressCheckButton as CheckButton
@onready var least_progress_check_button := $TowerDetails/TargetPriorityContainer/VBoxContainer/LeastProgressCheckButton as CheckButton
@onready var strongest_enemy_check_button := $TowerDetails/TargetPriorityContainer/VBoxContainer/StrongestEnemyCheckButton as CheckButton
@onready var weakest_enemy_check_button := $TowerDetails/TargetPriorityContainer/VBoxContainer/WeakestEnemyCheckButton as CheckButton
@onready var lowest_health_check_button := $TowerDetails/TargetPriorityContainer/VBoxContainer/LowestHealthCheckButton as CheckButton

@onready var warning_message_label: Label = $WarningMessageLabel
@onready var warning_message_timer: Timer = $WarningMessageTimer

var _selected_tower: TemplateTower


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

	warning_message_timer.timeout.connect(_on_warning_message_timer_timeout)


# --- PUBLIC METHODS ---

func show_warning_message(message: String, duration: float = 2.0) -> void:
	warning_message_label.text = message
	warning_message_label.visible = true
	warning_message_timer.wait_time = duration
	warning_message_timer.start()


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
	# If the priority panel is visible, we must handle its buttons manually.
	if target_priority_container.visible and target_priority_container.get_global_rect().has_point(screen_position):
		# Manually check each check button and set its state.
		# The ButtonGroup ensures others are turned off and the 'toggled' signal is emitted.
		if most_progress_check_button.get_global_rect().has_point(screen_position):
			most_progress_check_button.button_pressed = true
		elif least_progress_check_button.get_global_rect().has_point(screen_position):
			least_progress_check_button.button_pressed = true
		elif strongest_enemy_check_button.get_global_rect().has_point(screen_position):
			strongest_enemy_check_button.button_pressed = true
		elif weakest_enemy_check_button.get_global_rect().has_point(screen_position):
			weakest_enemy_check_button.button_pressed = true
		elif lowest_health_check_button.get_global_rect().has_point(screen_position):
			lowest_health_check_button.button_pressed = true
		# Consume the event regardless of whether a button was hit, as long as the click was in the container.
		return true

	# If the tower details panel is visible, handle its buttons and consume clicks within its bounds.
	if tower_details_container.visible and tower_details_container.get_global_rect().has_point(screen_position):
		if sell_tower_button.visible and not sell_tower_button.disabled and sell_tower_button.get_global_rect().has_point(screen_position):
			sell_tower_requested.emit()
			GlobalSignals.hand_condense_requested.emit()
			return true

		for i in range(upgrade_buttons.size()):
			var button = upgrade_buttons[i]
			if button.visible and not button.disabled and button.get_global_rect().has_point(screen_position):
				var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
				if is_instance_valid(build_manager) and is_instance_valid(build_manager.get_selected_tower()):
					var level_index = i + 1
					build_manager.get_selected_tower().upgrade_path(level_index)
					GlobalSignals.hand_condense_requested.emit()
				return true

		if target_priority_button.visible and not target_priority_button.disabled and target_priority_button.get_global_rect().has_point(screen_position):
			_on_target_priority_button_pressed()
			return true

		# If the click was inside the container but not on a button, consume it.
		return true


	if next_wave_button.get_global_rect().has_point(screen_position):
		next_wave_requested.emit()
		GlobalSignals.hand_condense_requested.emit()
		return true

	return false # No button was clicked


# --- PRIVATE SIGNAL HANDLERS & UPDATERS ---

func _on_warning_message_timer_timeout() -> void:
	warning_message_label.visible = false


func _on_tower_selected() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if is_instance_valid(build_manager):
		_selected_tower = build_manager.get_selected_tower()
		if is_instance_valid(_selected_tower):
			if not _selected_tower.upgraded.is_connected(_update_tower_details):
				_selected_tower.upgraded.connect(_update_tower_details)
			if not _selected_tower.stats_changed.is_connected(_update_tower_details):
				_selected_tower.stats_changed.connect(_update_tower_details)

	tower_details_container.visible = true
	target_priority_container.visible = false
	_update_tower_details()
	_update_target_priority_display()
	GlobalSignals.hand_condense_requested.emit()


func _on_tower_deselected() -> void:
	if is_instance_valid(_selected_tower):
		if _selected_tower.upgraded.is_connected(_update_tower_details):
			_selected_tower.upgraded.disconnect(_update_tower_details)
		if _selected_tower.stats_changed.is_connected(_update_tower_details):
			_selected_tower.stats_changed.disconnect(_update_tower_details)
	_selected_tower = null

	tower_details_container.visible = false
	target_priority_container.visible = false


func _on_target_priority_button_pressed() -> void:
	target_priority_container.visible = not target_priority_container.visible


func _on_target_priority_changed(toggled_on: bool) -> void:
	if not toggled_on:
		# This prevents the signal from firing when a button is turned off.
		# The ButtonGroup ensures another button will be toggled on, firing its own signal.
		return

	var priority: TargetPriority.Priority

	if most_progress_check_button.button_pressed:
		priority = TargetPriority.Priority.MOST_PROGRESS
	elif least_progress_check_button.button_pressed:
		priority = TargetPriority.Priority.LEAST_PROGRESS
	elif strongest_enemy_check_button.button_pressed:
		priority = TargetPriority.Priority.STRONGEST_ENEMY
	elif weakest_enemy_check_button.button_pressed:
		priority = TargetPriority.Priority.WEAKEST_ENEMY
	elif lowest_health_check_button.button_pressed:
		priority = TargetPriority.Priority.LOWEST_HEALTH

	emit_signal("target_priority_changed", priority)


func _update_tower_details() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager): return
	var selected_tower: TemplateTower = build_manager.get_selected_tower()
	if not is_instance_valid(selected_tower): return

	tower_name_label.text = selected_tower.data.tower_name
	tower_level_label.text = "Level: %s" % selected_tower.tower_level
	range_label.text = "Range: %d" % selected_tower.tower_range
	damage_label.text = "Damage: %d" % selected_tower.damage
	fire_rate_label.text = "Fire Rate: %.2f" % selected_tower.fire_rate
	projectile_speed_label.text = "Projectile Speed: %d" % selected_tower.projectile_speed

	var modifiers = []
	if selected_tower.has_attack_modifier("aoe_projectile"):
		modifiers.append("AoE")
	if selected_tower.has_attack_modifier("attack_flying"):
		modifiers.append("Flying")

	if not modifiers.is_empty():
		attack_modifier_label.text = "Attack Modifiers: " + ", ".join(modifiers)
	else:
		attack_modifier_label.text = "Attack Modifiers: None"

	var status_effects_text = []
	for effect in selected_tower.status_effects:
		status_effects_text.append(StatusEffectData.EffectType.keys()[effect.effect_type])

	if not status_effects_text.is_empty():
		status_effects_label.text = "Status Effects: " + ", ".join(status_effects_text)
	else:
		status_effects_label.text = "Status Effects: None"

	max_targets_label.text = "Max Targets: %d" % selected_tower.targets

	_update_upgrade_buttons()
	_update_sell_button_state()


func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


func _on_currency_changed(new_currency: int) -> void:
	currency_label.text = "Gold: %d" % new_currency
	if tower_details_container.visible:
		_update_upgrade_buttons()


func _update_upgrade_buttons() -> void:
	if not tower_details_container.visible:
		return

	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager): return
	var selected_tower: TemplateTower = build_manager.get_selected_tower()
	if not is_instance_valid(selected_tower): return

	var tower_data: TowerData = selected_tower.data
	var current_upgrade_tier: int = selected_tower.upgrade_tier
	var purchased_upgrades: Array[int] = selected_tower.upgrade_path_indices

	for i in range(upgrade_buttons.size()):
		var button: Button = upgrade_buttons[i]
		var button_tier: int = int(i / 2.0)
		var level_index: int = i + 1

		# Reset modulation color at the start of each update.
		button.self_modulate = Color.WHITE
		button.visible = true

		if level_index < tower_data.levels.size():
			var level_data: TowerLevelData = tower_data.levels[level_index]
			var cost: int = level_data.cost
			button.text = "%s (%dg)" % [level_data.upgrade_name, cost]

			var is_purchased: bool = level_index in purchased_upgrades
			var is_current_tier: bool = button_tier == current_upgrade_tier
			var can_afford: bool = GameManager.player_data.can_afford(cost)

			if is_purchased:
				button.self_modulate = Color.from_string("#286643", Color.WHITE)
				button.disabled = true
			elif is_current_tier:
				button.disabled = not can_afford
			else:
				button.disabled = true
		else:
			button.text = "N/A"
			button.disabled = true

	if current_upgrade_tier >= 3:
		for i in range(upgrade_buttons.size()):
			var button: Button = upgrade_buttons[i]
			var level_index: int = i + 1
			# Keep purchased buttons green, disable the rest.
			if not level_index in purchased_upgrades:
				button.disabled = true


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


func _update_target_priority_display() -> void:
	var build_manager: BuildManager = get_tree().get_first_node_in_group("build_manager")
	if not is_instance_valid(build_manager): return
	var selected_tower: TemplateTower = build_manager.get_selected_tower()
	if not is_instance_valid(selected_tower): return

	var priority = selected_tower.target_priority

	# Block signals to prevent `toggled` from firing and creating a loop
	# when we programmatically change the button state.
	most_progress_check_button.set_block_signals(true)
	least_progress_check_button.set_block_signals(true)
	strongest_enemy_check_button.set_block_signals(true)
	weakest_enemy_check_button.set_block_signals(true)
	lowest_health_check_button.set_block_signals(true)

	match priority:
		TargetPriority.Priority.MOST_PROGRESS:
			most_progress_check_button.button_pressed = true
		TargetPriority.Priority.LEAST_PROGRESS:
			least_progress_check_button.button_pressed = true
		TargetPriority.Priority.STRONGEST_ENEMY:
			strongest_enemy_check_button.button_pressed = true
		TargetPriority.Priority.WEAKEST_ENEMY:
			weakest_enemy_check_button.button_pressed = true
		TargetPriority.Priority.LOWEST_HEALTH:
			lowest_health_check_button.button_pressed = true

	# Unblock signals so the user can interact with them again.
	most_progress_check_button.set_block_signals(false)
	least_progress_check_button.set_block_signals(false)
	strongest_enemy_check_button.set_block_signals(false)
	weakest_enemy_check_button.set_block_signals(false)
	lowest_health_check_button.set_block_signals(false)


func set_next_wave_enabled(is_enabled: bool) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.disabled = not is_enabled


func set_next_wave_text(text: String) -> void:
	if is_instance_valid(next_wave_button):
		next_wave_button.text = text
