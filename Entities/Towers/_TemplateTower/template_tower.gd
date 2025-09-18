extends Node2D
class_name TemplateTower

## The base script for all towers.

enum State { IDLE, ATTACKING }

@export var state: State = State.IDLE
var data: TowerData
var current_level: int = 0
var upgrade_tier: int = 0
var upgrade_path_indices: Array[int] = []
var target_priority: TargetPriority.Priority = TargetPriority.Priority.MOST_PROGRESS

var _highlight_layer: TileMapLayer
var _highlight_tower_source_id: int = -1
var _highlight_range_source_id: int = -1

## Target Management
var _enemies_in_range: Array[TemplateEnemy] = []
var _current_targets: Array[TemplateEnemy] = []
var _targets_last_known_positions: Array[Vector2] = []
var _is_firing: bool = false

## Node References
@onready var sprite: Sprite2D = $Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var range_shape: CollisionPolygon2D = $Range/RangeShape
@onready var hitbox: Area2D = $Hitbox
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var muzzle: Marker2D = $Muzzle
var _projectiles_container: Node2D


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	_projectiles_container = get_tree().get_first_node_in_group("projectiles_container")


func _process(_delta: float) -> void:
	match state:
		State.IDLE:
			pass
		State.ATTACKING:
			_attack()


func initialize(new_tower_data: TowerData, new_highlight_layer: TileMapLayer, tower_highlight_id: int, range_highlight_id: int) -> void:
	data = new_tower_data
	_highlight_layer = new_highlight_layer
	_highlight_tower_source_id = tower_highlight_id
	_highlight_range_source_id = range_highlight_id
	
	if not is_instance_valid(data):
		push_error("Placed tower was initialized without valid TowerData!")
		return
	
	_apply_level_stats()


func select() -> void:
	var center_coords := _highlight_layer.local_to_map(global_position)
	var current_level_data: TowerLevelData = data.levels[current_level]
	HighlightManager.show_selection_highlights(
		_highlight_layer,
		center_coords,
		current_level_data.tower_range,
		_highlight_tower_source_id,
		_highlight_range_source_id
	)


func deselect() -> void:
	HighlightManager.hide_highlights(_highlight_layer)


func set_range_polygon(points: PackedVector2Array) -> void:
	range_shape.polygon = points


func _on_range_area_entered(area: Area2D) -> void:
	if not area is TemplateEnemy:
		return
	var enemy = area as TemplateEnemy
	_enemies_in_range.append(enemy)
	_find_new_target()


func _on_range_area_exited(area: Area2D) -> void:
	if not area is TemplateEnemy:
		return
	var enemy = area as TemplateEnemy
	
	var index = _enemies_in_range.find(enemy)
	if index != -1:
		_enemies_in_range.remove_at(index)

	if _current_targets.has(enemy):
		_current_targets.erase(enemy)
		if enemy.died.is_connected(_on_enemy_died):
			enemy.died.disconnect(_on_enemy_died)
		_find_new_target()


func _on_enemy_died(enemy: TemplateEnemy, _reward: int) -> void:
	if _current_targets.has(enemy):
		_current_targets.erase(enemy)
		if enemy.died.is_connected(_on_enemy_died):
			enemy.died.disconnect(_on_enemy_died)
		_find_new_target()


func set_target_priority(new_priority: TargetPriority.Priority) -> void:
	target_priority = new_priority
	_find_new_target()


func _find_new_target() -> void:
	var current_level_data: TowerLevelData = data.levels[current_level]

	# Filter out invalid enemies
	_enemies_in_range = _enemies_in_range.filter(
		func(enemy: TemplateEnemy) -> bool:
			return is_instance_valid(enemy)
	)

	var valid_targets = _enemies_in_range.filter(
		func(enemy: TemplateEnemy) -> bool:
			if not enemy.state == TemplateEnemy.State.MOVING:
				return false
			if enemy.data.is_flying and not current_level_data.can_attack_flying:
				return false
			return true
	)
	
	if valid_targets.is_empty():
		_clear_targets()
		state = State.IDLE
		return

	_sort_enemies(valid_targets)

	var num_targets_to_find = current_level_data.targets
	var new_targets = valid_targets.slice(0, num_targets_to_find)

	_update_targets(new_targets)

	if not _current_targets.is_empty():
		state = State.ATTACKING
	else:
		state = State.IDLE


func _sort_enemies(enemies: Array) -> void:
	match target_priority:
		TargetPriority.Priority.MOST_PROGRESS:
			enemies.sort_custom(func(a, b): return a.path_follow.progress > b.path_follow.progress)
		TargetPriority.Priority.LEAST_PROGRESS:
			enemies.sort_custom(func(a, b): return a.path_follow.progress < b.path_follow.progress)
		TargetPriority.Priority.STRONGEST_ENEMY:
			enemies.sort_custom(func(a, b): return a.max_health > b.max_health)
		TargetPriority.Priority.WEAKEST_ENEMY:
			enemies.sort_custom(func(a, b): return a.max_health < b.max_health)
		TargetPriority.Priority.LOWEST_HEALTH:
			enemies.sort_custom(func(a, b): return a.health < b.health)


func _update_targets(new_targets: Array[TemplateEnemy]) -> void:
	var old_targets = _current_targets.duplicate()

	# Remove old targets that are not in the new list
	for target in old_targets:
		if not new_targets.has(target):
			if target.died.is_connected(_on_enemy_died):
				target.died.disconnect(_on_enemy_died)
			_current_targets.erase(target)

	# Add new targets that were not in the old list
	for target in new_targets:
		if not old_targets.has(target):
			_current_targets.append(target)
			if not target.died.is_connected(_on_enemy_died):
				target.died.connect(_on_enemy_died)


func _clear_targets() -> void:
	for target in _current_targets:
		if is_instance_valid(target) and target.died.is_connected(_on_enemy_died):
			target.died.disconnect(_on_enemy_died)
	_current_targets.clear()


func _attack() -> void:
	if _current_targets.is_empty():
		state = State.IDLE
		return

	var current_level_data: TowerLevelData = data.levels[current_level]
	if not fire_rate_timer.is_stopped() or _is_firing or not current_level_data.projectile_scene:
		return
	
	_is_firing = true
	# Store the targets' positions the moment we decide to attack
	_targets_last_known_positions.clear()
	for target in _current_targets:
		if is_instance_valid(target):
			var target_point_node = target.find_child("TargetPoint")
			if is_instance_valid(target_point_node):
				_targets_last_known_positions.append(target_point_node.global_position)
			else:
				_targets_last_known_positions.append(target.global_position)
	
	var anim_name: String = current_level_data.shoot_animation
	
	var animation: Animation = animation_player.get_animation(anim_name)
	if not animation:
		push_error("Animation '%s' not found in AnimationPlayer." % anim_name)
		_is_firing = false # Reset firing state to avoid getting stuck
		return
		
	var anim_duration: float = animation.length
	var cooldown_duration: float = fire_rate_timer.wait_time
	
	if cooldown_duration < anim_duration:
		animation_player.speed_scale = anim_duration / cooldown_duration
	else:
		animation_player.speed_scale = 1.0
	
	animation_player.play(anim_name)
	fire_rate_timer.start()


func _on_animation_finished(_anim_name: StringName) -> void:
	var current_level_data: TowerLevelData = data.levels[current_level]
	if animation_player.get_assigned_animation() == current_level_data.shoot_animation:
		animation_player.play(current_level_data.idle_animation)
		animation_player.speed_scale = 1.0
		_is_firing = false


func _spawn_projectile() -> void:
	_spawn_projectiles()


func _spawn_projectiles() -> void:
	var current_level_data: TowerLevelData = data.levels[current_level]
	for i in range(min(_current_targets.size(), _targets_last_known_positions.size())):
		var target = _current_targets[i]
		var projectile: TemplateProjectile = ObjectPoolManager.get_object(current_level_data.projectile_scene) as TemplateProjectile
		if not is_instance_valid(projectile):
			push_error("ObjectPoolManager failed to provide a projectile.")
			continue

		projectile.visible = true
		_projectiles_container.add_child(projectile)
		projectile.global_position = muzzle.global_position

		# If the original target is still valid, initialize a normal shot.
		if is_instance_valid(target) and target.state == TemplateEnemy.State.MOVING:
			projectile.initialize(
				target,
				current_level_data.damage,
				current_level_data.projectile_speed,
				current_level_data.is_aoe
			)
		# Otherwise, initialize a "dud" shot to the last known position.
		else:
			var last_known_pos = _targets_last_known_positions[i]
			projectile.initialize_dud_shot(
				last_known_pos,
				current_level_data.damage,
				current_level_data.projectile_speed,
				current_level_data.is_aoe
			)


func upgrade_path(level_index: int) -> void:
	if level_index >= data.levels.size():
		push_error("Invalid level index passed to upgrade_path.")
		return

	var next_level_data: TowerLevelData = data.levels[level_index]
	if not GameManager.player_data.can_afford(next_level_data.cost):
		return # Cannot afford upgrade

	GameManager.remove_currency(next_level_data.cost)
	upgrade_path_indices.append(level_index)
	current_level = level_index
	upgrade_tier += 1
	_is_firing = false
	_apply_level_stats()
	_update_range_polygon()
	select()
	_find_new_target()


func _update_range_polygon() -> void:
	var points: PackedVector2Array = []
	var full_tile_size := Vector2(192, 96)
	var tower_range: int = data.levels[current_level].tower_range
	var range_multiplier: float = tower_range + 0.5

	points.append(Vector2(0, -full_tile_size.y * range_multiplier))
	points.append(Vector2(full_tile_size.x * range_multiplier, 0))
	points.append(Vector2(0, full_tile_size.y * range_multiplier))
	points.append(Vector2(-full_tile_size.x * range_multiplier, 0))

	range_shape.polygon = points


func _apply_level_stats() -> void:
	if not is_instance_valid(data) or data.levels.is_empty():
		push_error("Tower data is invalid or has no levels defined.")
		return

	if current_level >= data.levels.size():
		push_error("Attempted to apply stats for a level that does not exist.")
		return

	var current_level_data: TowerLevelData = data.levels[current_level]

	# Apply fire rate
	if current_level_data.fire_rate > 0:
		fire_rate_timer.wait_time = 1.0 / current_level_data.fire_rate
	else:
		# If fire rate is 0 or less, disable the timer to prevent division by zero
		fire_rate_timer.stop()

	# Play idle animation
	if not current_level_data.idle_animation.is_empty():
		animation_player.play(current_level_data.idle_animation)
