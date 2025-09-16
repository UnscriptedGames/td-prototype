extends Node2D
class_name TemplateTower

## The base script for all towers.

var TargetingPriority = preload("res://Core/targeting_priority.gd")

enum State { IDLE, ATTACKING }

@export var state: State = State.IDLE
var data: TowerData
var current_level: int = 1
var target_priority: TargetingPriority.Priority = TargetingPriority.Priority.MOST_PROGRESS

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
			# The _find_new_target function is now called by signals when enemies enter/exit range.
			# We can add a timer here to periodically search for new targets as a fallback.
			pass
		State.ATTACKING:
			var has_valid_target = _current_targets.any(func(t): return is_instance_valid(t))
			if not has_valid_target:
				_find_new_target()
				return # _find_new_target will update the state to IDLE if needed

			var current_level_data: TowerLevelData = data.levels[current_level - 1]
			if _current_targets.size() < current_level_data.targets:
				_find_new_target()

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
	var current_level_data: TowerLevelData = data.levels[current_level - 1]
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
	_enemies_in_range.append(area)
	_find_new_target()


func _on_range_area_exited(area: Area2D) -> void:
	if not area is TemplateEnemy:
		return
	
	var index = _enemies_in_range.find(area)
	if index != -1:
		_enemies_in_range.remove_at(index)

	var target_index = _current_targets.find(area)
	if target_index != -1:
		_current_targets.remove_at(target_index)
	
	_find_new_target()


func set_target_priority(new_priority: TargetingPriority.Priority) -> void:
	target_priority = new_priority
	# When priority changes, immediately try to find a new target based on the new rules.
	_find_new_target()


func _find_new_target() -> void:
	var valid_targets = _enemies_in_range.filter(
		func(enemy: TemplateEnemy) -> bool:
			return is_instance_valid(enemy) and enemy.state == TemplateEnemy.State.MOVING
	)
	
	if valid_targets.is_empty():
		_current_targets.clear()
		return

	# Sort the valid targets based on the current priority
	match target_priority:
		TargetingPriority.Priority.MOST_PROGRESS:
			valid_targets.sort_custom(func(a, b): return a.path_follow.progress > b.path_follow.progress)
		TargetingPriority.Priority.LEAST_PROGRESS:
			valid_targets.sort_custom(func(a, b): return a.path_follow.progress < b.path_follow.progress)
		TargetingPriority.Priority.STRONGEST_ENEMY:
			valid_targets.sort_custom(func(a, b): return a.max_health > b.max_health)
		TargetingPriority.Priority.WEAKEST_ENEMY:
			valid_targets.sort_custom(func(a, b): return a.max_health < b.max_health)
		TargetingPriority.Priority.LOWEST_HEALTH:
			valid_targets.sort_custom(func(a, b): return a.health < b.health)

	var current_level_data: TowerLevelData = data.levels[current_level - 1]
	var num_targets_to_find = current_level_data.targets
	
	_current_targets.clear()
	var enemies_to_add = valid_targets.slice(0, num_targets_to_find)
	for enemy in enemies_to_add:
		_current_targets.append(enemy)

	if not _current_targets.is_empty():
		state = State.ATTACKING
	else:
		state = State.IDLE


## Private: Fires a projectile at the current target if the cooldown is ready.
func _attack() -> void:
	var current_level_data: TowerLevelData = data.levels[current_level - 1]
	if not fire_rate_timer.is_stopped() or _is_firing or not current_level_data.projectile_scene:
		return
	
	_is_firing = true
	# Store the targets' positions the moment we decide to attack
	_targets_last_known_positions.clear()
	print("Attack function: processing %d targets" % _current_targets.size())
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
	var current_level_data: TowerLevelData = data.levels[current_level - 1]
	if animation_player.get_assigned_animation() == current_level_data.shoot_animation:
		animation_player.play(current_level_data.idle_animation)
		animation_player.speed_scale = 1.0
		_is_firing = false


func _spawn_projectile() -> void:
	_spawn_projectiles()


func _spawn_projectiles() -> void:
	var current_level_data: TowerLevelData = data.levels[current_level - 1]
	print("Spawn projectiles function: iterating through %d targets" % _current_targets.size())
	for i in range(_current_targets.size()):
		print("Spawning projectile for target %d" % i)
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
			if OS.is_debug_build():
				print("Tower: Firing NORMAL shot.")
			projectile.initialize(
				target,
				current_level_data.damage,
				current_level_data.projectile_speed,
				current_level_data.is_aoe
			)
		# Otherwise, initialize a "dud" shot to the last known position.
		else:
			# Ensure we have a last known position for this target index
			if i < _targets_last_known_positions.size():
				var last_known_pos = _targets_last_known_positions[i]
				if OS.is_debug_build():
					print("Tower: Firing DUD shot to ", last_known_pos)
				projectile.initialize_dud_shot(
					last_known_pos,
					current_level_data.damage,
					current_level_data.projectile_speed,
					current_level_data.is_aoe
				)


func upgrade() -> void:
	if current_level >= data.levels.size():
		return # Already at max level

	var next_level_data: TowerLevelData = data.levels[current_level]
	if not GameManager.player_data.can_afford(next_level_data.cost):
		return # Cannot afford upgrade

	GameManager.remove_currency(next_level_data.cost)
	current_level += 1
	_is_firing = false
	_apply_level_stats()
	_update_range_polygon()
	select()


func _update_range_polygon() -> void:
	var points: PackedVector2Array = []
	var full_tile_size := Vector2(192, 96)
	var tower_range: int = data.levels[current_level - 1].tower_range
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

	if current_level > data.levels.size():
		push_error("Attempted to apply stats for a level that does not exist.")
		return

	var current_level_data: TowerLevelData = data.levels[current_level - 1]

	# Apply fire rate
	if current_level_data.fire_rate > 0:
		fire_rate_timer.wait_time = 1.0 / current_level_data.fire_rate
	else:
		# If fire rate is 0 or less, disable the timer to prevent division by zero
		fire_rate_timer.stop()

	# Play idle animation
	if not current_level_data.idle_animation.is_empty():
		animation_player.play(current_level_data.idle_animation)

	# Note: Damage, projectile speed, etc., are read directly from the data
	# when spawning projectiles, so they don't need to be stored in variables here.
	# The tower's range is also read directly when needed for selection highlights.
