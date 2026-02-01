class_name TowerInspector
extends PanelContainer

signal sell_tower_requested
signal target_priority_changed(priority: TargetPriority.Priority)

# -- Node References --
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

# Sub-Inspector
# Use PanelContainer to avoid cyclic reference/parser delay
@onready var priority_inspector: PanelContainer = $TargetPriorityInspector

# Layout State
@onready var _tween: Tween

var _selected_tower: TemplateTower
const ANCHOR_MARGIN: int = 80
const GAP: int = 10 # Gap between main inspector and priority inspector
const INSPECTOR_OPACITY: float = 0.85 # 15% Transparency

func _ready() -> void:
	# Set Transparency
	self.self_modulate.a = INSPECTOR_OPACITY
	if is_instance_valid(priority_inspector):
		priority_inspector.self_modulate.a = INSPECTOR_OPACITY

	# Connect Self Actions
	sell_button.pressed.connect(_on_sell_button_pressed)
	priority_button.pressed.connect(_on_priority_button_pressed)
	
	# Connect Upgrade Buttons
	for child in upgrade_buttons_container.get_children():
		if child is Button:
			child.pressed.connect(_on_upgrade_button_pressed.bind(child))
	
	# Connect Sub-Inspector Signal
	if priority_inspector.has_signal("priority_changed"):
		priority_inspector.priority_changed.connect(_on_priority_changed)
	
	# Listen to Global Changes
	GameManager.currency_changed.connect(_on_currency_changed)
	
	# Init State
	visible = false
	priority_inspector.visible = false

# ... (rest of file) ...


func _exit_tree() -> void:
	GameManager.currency_changed.disconnect(_on_currency_changed)

# --- Public API ---

func set_tower(tower: TemplateTower) -> void:
	# Disconnect old
	if is_instance_valid(_selected_tower):
		if _selected_tower.upgraded.is_connected(_update_ui):
			_selected_tower.upgraded.disconnect(_update_ui)
		if _selected_tower.stats_changed.is_connected(_update_ui):
			_selected_tower.stats_changed.disconnect(_update_ui)
			
		var old_buff = _selected_tower.get_node_or_null("BuffManager")
		if is_instance_valid(old_buff):
			if old_buff.buff_started.is_connected(_on_buff_started): old_buff.buff_started.disconnect(_on_buff_started)
			if old_buff.buff_progress.is_connected(_on_buff_progress): old_buff.buff_progress.disconnect(_on_buff_progress)
			if old_buff.buff_ended.is_connected(_on_buff_ended): old_buff.buff_ended.disconnect(_on_buff_ended)

	_selected_tower = tower
	
	# Reset Sub-Inspector
	priority_inspector.visible = false
	
	if is_instance_valid(_selected_tower):
		# Connect new
		_selected_tower.upgraded.connect(_update_ui)
		_selected_tower.stats_changed.connect(_update_ui)
		
		var new_buff = _selected_tower.get_node_or_null("BuffManager")
		if is_instance_valid(new_buff):
			new_buff.buff_started.connect(_on_buff_started)
			new_buff.buff_progress.connect(_on_buff_progress)
			new_buff.buff_ended.connect(_on_buff_ended)
			new_buff.resend_state()
		else:
			buff_bar.visible = false
			
		# Initial Update
		_update_ui()
		visible = true
	else:
		visible = false

func update_anchor(viewport_size: Vector2, tower_global_position: Vector2, map_coords: Vector2i = Vector2i(-1, -1)) -> void:
	if not visible: return
	
	# Determine Direction based on Grid Coordinates (Preferred)
	# Fallback to Screen Center if map_coords are invalid (not provided)
	
	var is_docked_left: bool = false # Inspector on Left (Tower on Right)
	var is_docked_top: bool = false # Inspector anchors Top (Grows Down) (Tower on Top)
	
	if map_coords.x != -1:
		# Grid Logic (0-indexed)
		# Rows 1-8 (Index 0-7) -> Open Down (Anchor Top)
		# Rows 9-16 (Index 8-15) -> Open Up (Anchor Bottom)
		is_docked_top = map_coords.y < 8
		
		# Cols 1-12 (Index 0-11) -> Open Right (Inspector Right of Tower)
		# Cols 13-24 (Index 12-23) -> Open Left (Inspector Left of Tower)
		# Note: is_docked_left means the INSPECTOR is on the left.
		is_docked_left = map_coords.x >= 12
	else:
		# Fallback Screen Logic
		is_docked_left = tower_global_position.x > (viewport_size.x * 0.5)
		is_docked_top = tower_global_position.y < (viewport_size.y * 0.5)
	
	# We need to position 'self' (Tower Inspector)
	# Coordinates must be local to our Parent because we are a Child Control.
	var parent_global_pos = get_parent().global_position
	
	var target_global_x = 0.0
	var target_global_y = 0.0
	
	var my_width = size.x
	var my_height = size.y
	
	# Horizontal Logic
	if is_docked_left:
		# Inspector to LEFT of Tower
		target_global_x = tower_global_position.x - my_width - ANCHOR_MARGIN
	else:
		# Inspector to RIGHT of Tower
		target_global_x = tower_global_position.x + ANCHOR_MARGIN
		
	# Vertical Logic
	if is_docked_top:
		# Grow DOWN (Anchor Top)
		target_global_y = tower_global_position.y
	else:
		# Grow UP (Anchor Bottom)
		target_global_y = tower_global_position.y - my_height
	
	# Convert Global to Local
	var target_pos = Vector2(target_global_x, target_global_y) - parent_global_pos
	
	# Animate Main
	if _tween: _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	
	_tween.tween_property(self, "position", target_pos, 0.3)
	
	# Update Priority Inspector (Global Position)
	if priority_inspector.visible:
		# Sync Height
		priority_inspector.custom_minimum_size.y = size.y
		priority_inspector.size.y = size.y
		
		# Priority placement
		var prio_width = priority_inspector.size.x
		var prio_global_x = 0.0
		
		if is_docked_left:
			# Inspector is LEFT. Priority LEFT of Inspector.
			prio_global_x = target_global_x - prio_width - GAP
		else:
			# Inspector is RIGHT. Priority RIGHT of Inspector.
			prio_global_x = target_global_x + my_width + GAP
			
		_tween.tween_property(priority_inspector, "position", Vector2(prio_global_x, target_global_y), 0.3)


# --- UI Updates ---

func _update_ui() -> void:
	if not is_instance_valid(_selected_tower): return
	
	# Stats
	var data = _selected_tower.data
	tower_name_label.text = data.tower_name
	tower_level_label.text = "Level: %s" % (data.levels[_selected_tower.current_level].upgrade_name if _selected_tower.current_level < data.levels.size() else "Max")
	if _selected_tower.current_level == 0:
		tower_level_label.text = "Level: Basic"
	
	range_label.text = "Range: %d" % _selected_tower.tower_range
	damage_label.text = "Damage: %d" % _selected_tower.damage
	fire_rate_label.text = "Fire Rate: %.2f" % _selected_tower.fire_rate
	projectile_speed_label.text = "Projectile Speed: %d" % _selected_tower.projectile_speed
	
	var modifiers = []
	if _selected_tower.has_attack_modifier("aoe_projectile"): modifiers.append("AoE")
	if _selected_tower.has_attack_modifier("attack_flying"): modifiers.append("Flying")
	attack_modifier_label.text = "Attack Modifiers: " + (", ".join(modifiers) if modifiers else "None")
	
	var effects = []
	for effect in _selected_tower.status_effects:
		effects.append(StatusEffectData.EffectType.keys()[effect.effect_type])
	status_effects_label.text = "Status Effects: " + (", ".join(effects) if effects else "None")
		
	max_targets_label.text = "Max Targets: %d" % _selected_tower.targets
	
	# Update Sub-Inspector Data
	priority_inspector.set_priority(_selected_tower.target_priority)
	
	# Updates
	_update_upgrade_buttons()
	_update_sell_button()

func _update_upgrade_buttons() -> void:
	if not is_instance_valid(_selected_tower): return
	
	var tower_data = _selected_tower.data
	var current_tier = _selected_tower.upgrade_tier
	var purchased = _selected_tower.upgrade_path_indices
	
	var children = upgrade_buttons_container.get_children()
	for i in range(children.size()):
		var btn = children[i] as Button
		if not btn: continue
		
		# Assuming 2 buttons per tier logic from original
		var level_index = i + 1
		
		if level_index < tower_data.levels.size():
			var level_data = tower_data.levels[level_index]
			var cost = level_data.cost
			
			btn.text = "%s (%dg)" % [level_data.upgrade_name, cost]
			
			var is_purchased = level_index in purchased
			var is_available = (int(i / 2.0) == current_tier)
			var can_afford = GameManager.player_data.can_afford(cost)
			
			if is_purchased:
				btn.disabled = true
				btn.modulate = Color(0.2, 0.8, 0.2) # Green tint
			elif is_available:
				btn.disabled = not can_afford
				btn.modulate = Color.WHITE
			else:
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5) # Dim
		else:
			btn.text = "-"
			btn.disabled = true

func _update_sell_button() -> void:
	# Basic logic
	var build_manager = get_tree().get_first_node_in_group("build_manager")
	if build_manager:
		var val = build_manager.get_selected_tower_sell_value()
		sell_button.text = "Sell (%dg)" % val

# --- Signal Handlers ---

func _on_priority_button_pressed() -> void:
	priority_inspector.visible = not priority_inspector.visible
	if priority_inspector.visible:
		# Sync Height
		priority_inspector.custom_minimum_size.y = size.y
		priority_inspector.size.y = size.y
		
		# Calculate Position (Global)
		var viewport_width = get_viewport_rect().size.x
		var global_pos = global_position
		var is_docked_left = (global_pos.x < viewport_width * 0.5)
		
		var prio_x = 0.0
		if is_docked_left:
			prio_x = global_pos.x + size.x + GAP
		else:
			prio_x = global_pos.x - priority_inspector.size.x - GAP
			
		priority_inspector.position = Vector2(prio_x, global_pos.y)

func _on_priority_changed(new_priority: TargetPriority.Priority) -> void:
	emit_signal("target_priority_changed", new_priority)

func _on_sell_button_pressed() -> void:
	emit_signal("sell_tower_requested")

func _on_upgrade_button_pressed(button: Button) -> void:
	var index = upgrade_buttons_container.get_children().find(button)
	if index != -1 and is_instance_valid(_selected_tower):
		var level_index = index + 1
		_selected_tower.upgrade_path(level_index)
		# UI updates via signal callback from tower

func _on_currency_changed(_val: int) -> void:
	if visible:
		_update_upgrade_buttons()

func _on_buff_started(duration: float) -> void:
	buff_bar.max_value = duration
	buff_bar.value = duration
	buff_bar.visible = true

func _on_buff_progress(time: float) -> void:
	buff_bar.value = time

func _on_buff_ended() -> void:
	buff_bar.visible = false
