## Inspector panel for the currently selected tower. Displays stats, upgrade
## buttons, sell action, target priority sub-inspector, and buff progress bar.
## Anchors itself relative to the tower's screen position.
class_name TowerInspector
extends PanelContainer

signal sell_tower_requested
signal target_priority_changed(priority: TargetPriority.Priority)

# Stat Labels
@onready var tower_name_label: Label = $Content/VBox/Stats/TowerNameLabel
@onready var tower_level_label: Label = $Content/VBox/Stats/TowerLevelLabel
@onready var range_label: Label = $Content/VBox/Stats/RangeLabel
@onready var damage_label: Label = $Content/VBox/Stats/DamageLabel
@onready var fire_rate_label: Label = $Content/VBox/Stats/FireRateLabel
@onready var projectile_speed_label: Label = $Content/VBox/Stats/ProjectileSpeedLabel
@onready var attack_modifier_label: Label = $Content/VBox/Stats/AttackModifiersLabel
@onready var status_effects_label: Label = $Content/VBox/Stats/StatusEffectsLabel
@onready var max_targets_label: Label = $Content/VBox/Stats/MaxTargetsLabel

@onready var buff_bar: ProgressBar = $Content/VBox/Stats/BuffBar

# Actions & Logic
@onready var priority_button: Button = $Content/VBox/Stats/TargetPriorityButton
@onready var upgrade_buttons_container: GridContainer = $Content/VBox/Stats/UpgradeGrid
@onready var sell_button: Button = $Content/VBox/Stats/SellButton

# Sub-Inspector (typed loose to avoid cyclic reference)
@onready var priority_inspector: PanelContainer = $TargetPriorityInspector

# Layout State
@onready var _tween: Tween

var _selected_tower: TemplateTower
const ANCHOR_MARGIN: int = 80
const GAP: int = 10
const INSPECTOR_OPACITY: float = 0.85

var _is_docked_left: bool = false


func _ready() -> void:
	# Set transparency
	self.self_modulate.a = INSPECTOR_OPACITY
	if is_instance_valid(priority_inspector):
		priority_inspector.self_modulate.a = INSPECTOR_OPACITY
		# Detach from layout to allow manual positioning
		priority_inspector.set_as_top_level(true)

	# Connect actions
	sell_button.pressed.connect(_on_sell_button_pressed)
	priority_button.pressed.connect(_on_priority_button_pressed)

	# Connect upgrade buttons
	for child: Node in upgrade_buttons_container.get_children():
		if child is Button:
			child.pressed.connect(_on_upgrade_button_pressed.bind(child))

	# Connect sub-inspector signal
	if priority_inspector.has_signal("priority_changed"):
		priority_inspector.priority_changed.connect(_on_priority_changed)

	# Listen to currency changes for upgrade affordability
	GameManager.currency_changed.connect(_on_currency_changed)

	# Init state
	visible = false
	priority_inspector.visible = false


## Disconnects the currency signal to prevent orphan connections.
func _exit_tree() -> void:
	GameManager.currency_changed.disconnect(_on_currency_changed)


## Sets the inspected tower, connecting/disconnecting upgrade and buff
## signals as needed. Pass null to hide the inspector.
func set_tower(tower: TemplateTower) -> void:
	# Disconnect old tower signals
	if is_instance_valid(_selected_tower):
		if _selected_tower.upgraded.is_connected(_update_ui):
			_selected_tower.upgraded.disconnect(_update_ui)
		if _selected_tower.stats_changed.is_connected(_update_ui):
			_selected_tower.stats_changed.disconnect(_update_ui)

		var old_buff: Node = _selected_tower.get_node_or_null("BuffManager")
		if is_instance_valid(old_buff):
			if old_buff.buff_started.is_connected(_on_buff_started):
				old_buff.buff_started.disconnect(_on_buff_started)
			if old_buff.buff_progress.is_connected(_on_buff_progress):
				old_buff.buff_progress.disconnect(_on_buff_progress)
			if old_buff.buff_ended.is_connected(_on_buff_ended):
				old_buff.buff_ended.disconnect(_on_buff_ended)

	_selected_tower = tower
	priority_inspector.visible = false

	if is_instance_valid(_selected_tower):
		# Connect new tower signals
		_selected_tower.upgraded.connect(_update_ui)
		_selected_tower.stats_changed.connect(_update_ui)

		var new_buff: Node = _selected_tower.get_node_or_null("BuffManager")
		if is_instance_valid(new_buff):
			new_buff.buff_started.connect(_on_buff_started)
			new_buff.buff_progress.connect(_on_buff_progress)
			new_buff.buff_ended.connect(_on_buff_ended)
			new_buff.resend_state()
		else:
			buff_bar.visible = false

		_update_ui()
		visible = true
	else:
		visible = false


## Positions the inspector relative to the tower's screen position. Uses
## grid coordinates to determine left/right and top/bottom docking, with a
## screen-centre fallback when map_coords are unavailable.
func update_anchor(
	viewport_size: Vector2,
	tower_global_position: Vector2,
	map_coords: Vector2i = Vector2i(-1, -1)
) -> void:
	if not visible: return

	var is_docked_left: bool = false
	var is_docked_top: bool = false

	if map_coords.x != -1:
		# Grid: rows 0–7 → dock top, rows 8–15 → dock bottom
		is_docked_top = map_coords.y < 8
		# Grid: cols 0–11 → dock right, cols 12–23 → dock left
		is_docked_left = map_coords.x >= 12
	else:
		# Fallback: screen-centre split
		is_docked_left = tower_global_position.x > (viewport_size.x * 0.5)
		is_docked_top = tower_global_position.y < (viewport_size.y * 0.5)

	var parent_global_pos: Vector2 = get_parent().global_position

	var target_global_x: float = 0.0
	var target_global_y: float = 0.0
	var my_width: float = size.x
	var my_height: float = size.y

	_is_docked_left = is_docked_left

	# Horizontal: place inspector on the opposite side of the tower
	if is_docked_left:
		target_global_x = tower_global_position.x - my_width - ANCHOR_MARGIN
	else:
		target_global_x = tower_global_position.x + ANCHOR_MARGIN

	# Vertical: grow downward from top or upward from bottom
	if is_docked_top:
		target_global_y = tower_global_position.y
	else:
		target_global_y = tower_global_position.y - my_height

	# Convert global to parent-local coordinates
	var target_pos: Vector2 = Vector2(target_global_x, target_global_y) - parent_global_pos

	# Animate slide
	if _tween: _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", target_pos, 0.3)

	# Update priority inspector position if visible
	if priority_inspector.visible:
		_update_popup_position(true, Vector2(target_global_x, target_global_y))


## Positions the priority sub-inspector adjacent to the main inspector.
## Uses global coordinates since the sub-inspector is set as top-level.
func _update_popup_position(
	animate: bool, override_base_pos: Variant = null
) -> void:
	var base_pos: Vector2 = global_position
	if override_base_pos != null:
		base_pos = override_base_pos

	# Sync height with main inspector
	priority_inspector.custom_minimum_size.y = size.y
	priority_inspector.size.y = size.y

	var offset_x: float = 0.0

	if _is_docked_left:
		# Popup extends further left (outward)
		offset_x = - priority_inspector.size.x - GAP
	else:
		# Popup extends further right (outward)
		offset_x = size.x + GAP

	var target_global_pos: Vector2 = base_pos + Vector2(offset_x, 0)

	if animate and _tween:
		_tween.tween_property(priority_inspector, "position", target_global_pos, 0.3)
	else:
		priority_inspector.position = target_global_pos


## Refreshes all stat labels, modifiers, effects, and upgrade button states
## from the selected tower's current data.
func _update_ui() -> void:
	if not is_instance_valid(_selected_tower): return

	var data: TowerData = _selected_tower.data
	tower_name_label.text = data.tower_name

	if _selected_tower.current_level == 0:
		tower_level_label.text = "Level: Basic"
	elif _selected_tower.current_level < data.levels.size():
		tower_level_label.text = "Level: %s" % data.levels[_selected_tower.current_level].upgrade_name
	else:
		tower_level_label.text = "Level: Max"

	range_label.text = "Range: %d" % _selected_tower.tower_range
	damage_label.text = "Damage: %d" % _selected_tower.damage
	fire_rate_label.text = "Fire Rate: %.2f" % _selected_tower.fire_rate
	projectile_speed_label.text = "Projectile Speed: %d" % _selected_tower.projectile_speed

	var modifiers: Array[String] = []
	if _selected_tower.has_attack_modifier("aoe_projectile"): modifiers.append("AoE")
	if _selected_tower.has_attack_modifier("attack_flying"): modifiers.append("Flying")
	attack_modifier_label.text = "Attack Modifiers: " + (", ".join(modifiers) if modifiers else "None")

	var effects: Array[String] = []
	for effect: Variant in _selected_tower.status_effects:
		effects.append(StatusEffectData.EffectType.keys()[effect.effect_type])
	status_effects_label.text = "Status Effects: " + (", ".join(effects) if effects else "None")

	max_targets_label.text = "Max Targets: %d" % _selected_tower.targets

	# Update sub-inspector data
	priority_inspector.set_priority(_selected_tower.target_priority)

	_update_upgrade_buttons()
	_update_sell_button()


## Updates upgrade button labels, enabled states, and colour tints based on
## the tower's current tier, purchased upgrades, and player currency.
func _update_upgrade_buttons() -> void:
	if not is_instance_valid(_selected_tower): return

	var tower_data: TowerData = _selected_tower.data
	var current_tier: int = _selected_tower.upgrade_tier
	var purchased: Array = _selected_tower.upgrade_path_indices

	var children: Array[Node] = upgrade_buttons_container.get_children()
	for i: int in range(children.size()):
		var btn: Button = children[i] as Button
		if not btn: continue

		var level_index: int = i + 1

		if level_index < tower_data.levels.size():
			var level_data: Resource = tower_data.levels[level_index]
			var cost: int = level_data.cost

			btn.text = "%s (%dg)" % [level_data.upgrade_name, cost]

			var is_purchased: bool = level_index in purchased
			var is_available: bool = (int(i / 2.0) == current_tier)
			var can_afford: bool = GameManager.player_data.can_afford(cost)

			if is_purchased:
				btn.disabled = true
				btn.modulate = Color(0.2, 0.8, 0.2)
			elif is_available:
				btn.disabled = not can_afford
				btn.modulate = Color.WHITE
			else:
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = "-"
			btn.disabled = true


## Updates the sell button label with the tower's current sell value.
func _update_sell_button() -> void:
	var build_manager: Node = get_tree().get_first_node_in_group("build_manager")
	if build_manager:
		var val: int = build_manager.get_selected_tower_sell_value()
		sell_button.text = "Sell (%dg)" % val


## Toggles the target priority sub-inspector visibility.
func _on_priority_button_pressed() -> void:
	priority_inspector.visible = not priority_inspector.visible
	if priority_inspector.visible:
		_update_popup_position(false)


## Forwards the priority change from the sub-inspector to listeners.
func _on_priority_changed(new_priority: TargetPriority.Priority) -> void:
	target_priority_changed.emit(new_priority)


## Emits the sell signal for the BuildManager to handle.
func _on_sell_button_pressed() -> void:
	sell_tower_requested.emit()


## Triggers an upgrade on the selected tower at the button's index.
func _on_upgrade_button_pressed(button: Button) -> void:
	var index: int = upgrade_buttons_container.get_children().find(button)
	if index != -1 and is_instance_valid(_selected_tower):
		var level_index: int = index + 1
		_selected_tower.upgrade_path(level_index)


## Refreshes upgrade button affordability when the player's currency changes.
func _on_currency_changed(_val: int) -> void:
	if visible:
		_update_upgrade_buttons()


## Shows the buff bar and sets its max value when a buff begins.
func _on_buff_started(duration: float) -> void:
	buff_bar.max_value = duration
	buff_bar.value = duration
	buff_bar.visible = true


## Updates the buff bar progress as the buff ticks.
func _on_buff_progress(time: float) -> void:
	buff_bar.value = time


## Hides the buff bar when the buff expires.
func _on_buff_ended() -> void:
	buff_bar.visible = false
