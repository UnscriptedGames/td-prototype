extends Node2D
class_name TemplateTower

## The base script for all towers.

signal selected(tower)

enum State { IDLE, ATTACKING }

@export var state: State = State.IDLE
var data: TowerData
var current_level: int = 1

var _highlight_layer: TileMapLayer
var _highlight_tower_source_id: int = -1
var _highlight_range_source_id: int = -1

## Target Management
var _enemies_in_range: Array[TemplateEnemy] = []
var _current_target: TemplateEnemy
var _target_last_known_position: Vector2
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
	hitbox.input_event.connect(_on_hitbox_input_event)
	animation_player.animation_finished.connect(_on_animation_finished)
	_projectiles_container = get_tree().get_first_node_in_group("projectiles_container")


func _process(_delta: float) -> void:
	match state:
		State.IDLE:
			if not _enemies_in_range.is_empty():
				_find_new_target()
		State.ATTACKING:
			# If the target is no longer valid, just update the state.
			# Do NOT interrupt the animation here. Let it finish.
			if not is_instance_valid(_current_target):
				_current_target = null
				state = State.IDLE
				return
			
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


func _on_hitbox_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("selected", self)
		get_viewport().set_input_as_handled()


func _on_range_area_entered(area: Area2D) -> void:
	if not area is TemplateEnemy:
		return
	_enemies_in_range.append(area)


func _on_range_area_exited(area: Area2D) -> void:
	if not area is TemplateEnemy:
		return
	
	var index = _enemies_in_range.find(area)
	if index != -1:
		_enemies_in_range.remove_at(index)
	
	if area == _current_target:
		_current_target = null
		state = State.IDLE


func _find_new_target() -> void:
	_enemies_in_range = _enemies_in_range.filter(
		func(enemy: TemplateEnemy) -> bool:
			return is_instance_valid(enemy) and enemy.state == TemplateEnemy.State.MOVING
	)
	
	if not _enemies_in_range.is_empty():
		_current_target = _enemies_in_range[0]
		state = State.ATTACKING
	else:
		_current_target = null


## Private: Fires a projectile at the current target if the cooldown is ready.
func _attack() -> void:
	var current_level_data: TowerLevelData = data.levels[current_level - 1]
	if not fire_rate_timer.is_stopped() or _is_firing or not current_level_data.projectile_scene:
		return
	
	_is_firing = true
	# Store the target's position the moment we decide to attack
	var target_point_node = _current_target.find_child("TargetPoint")
	if is_instance_valid(target_point_node):
		_target_last_known_position = target_point_node.global_position
	else:
		_target_last_known_position = _current_target.global_position
	
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
	var current_level_data: TowerLevelData = data.levels[current_level - 1]
	var projectile: TemplateProjectile = ObjectPoolManager.get_object(current_level_data.projectile_scene) as TemplateProjectile
	if not is_instance_valid(projectile):
		push_error("ObjectPoolManager failed to provide a projectile.")
		return
	
	projectile.visible = true
	_projectiles_container.add_child(projectile)
	projectile.global_position = muzzle.global_position
	
	# If the original target is still valid, initialize a normal shot.
	if is_instance_valid(_current_target) and _current_target.state == TemplateEnemy.State.MOVING:
		if OS.is_debug_build():
			print("Tower: Firing NORMAL shot.")
		projectile.initialize(
			_current_target,
			current_level_data.damage,
			current_level_data.projectile_speed,
			current_level_data.is_aoe
		)
	# Otherwise, initialize a "dud" shot to the last known position.
	else:
		if OS.is_debug_build():
			print("Tower: Firing DUD shot to ", _target_last_known_position)
		projectile.initialize_dud_shot(
			_target_last_known_position,
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

	GameManager.player_data.deduct_currency(next_level_data.cost)
	current_level += 1
	_apply_level_stats()


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
