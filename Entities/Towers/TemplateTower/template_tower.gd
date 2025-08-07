extends Node2D
class_name TemplateTower

## The base script for all towers.

signal selected(tower)

enum State { IDLE, ATTACKING }

@export var state: State = State.IDLE
var data: TowerData
var current_level: int = 1

var _highlight_layer: TileMapLayer
var _path_layer: TileMapLayer
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


## Called by the BuildManager to set up the tower.
func initialize(new_tower_data: TowerData, p_path_layer: TileMapLayer, new_highlight_layer: TileMapLayer, tower_highlight_id: int, range_highlight_id: int) -> void:
	data = new_tower_data
	_path_layer = p_path_layer # Add this
	_highlight_layer = new_highlight_layer
	_highlight_tower_source_id = tower_highlight_id
	_highlight_range_source_id = range_highlight_id
	
	if not is_instance_valid(data):
		push_error("Placed tower was initialized without valid TowerData!")
		return
	
	if data.fire_rate > 0:
		fire_rate_timer.wait_time = 1.0 / data.fire_rate
	
	animation_player.play(data.idle_animations[current_level - 1])


func select() -> void:
	var center_coords := _highlight_layer.local_to_map(global_position)
	HighlightManager.show_selection_highlights(
		_highlight_layer,
		center_coords,
		data.tower_range,
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
	if not fire_rate_timer.is_stopped() or _is_firing or not data.projectile_scene:
		return
	
	_is_firing = true
	# Store the target's position the moment we decide to attack
	var target_point_node = _current_target.find_child("TargetPoint")
	if is_instance_valid(target_point_node):
		_target_last_known_position = target_point_node.global_position
	else:
		_target_last_known_position = _current_target.global_position
	
	var anim_name: String = data.shoot_animations[current_level - 1]
	
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
	var current_shoot_anim = data.shoot_animations[current_level - 1]
	if animation_player.get_assigned_animation() == current_shoot_anim:
		animation_player.play(data.idle_animations[current_level - 1])
		animation_player.speed_scale = 1.0
		_is_firing = false


func _spawn_projectile() -> void:
	var projectile: TemplateProjectile = ObjectPoolManager.get_object(data.projectile_scene) as TemplateProjectile
	if not is_instance_valid(projectile):
		push_error("ObjectPoolManager failed to provide a projectile.")
		return
	
	projectile.visible = true
	_projectiles_container.add_child(projectile)
	projectile.global_position = muzzle.global_position
	
	# If the original target is still valid, calculate duration and initialize a normal shot.
	if is_instance_valid(_current_target) and _current_target.state == TemplateEnemy.State.MOVING:
		var duration := _calculate_flight_duration(_current_target.global_position)
		projectile.initialize(
			_current_target, data.damage, data.is_aoe, duration
		)
	# Otherwise, calculate duration and initialize a "dud" shot.
	else:
		var duration := _calculate_flight_duration(_target_last_known_position)
		projectile.initialize_dud_shot(
			_target_last_known_position, data.damage, data.is_aoe, duration
		)

## Calculates projectile flight time based on grid distance and a visual correction factor.
func _calculate_flight_duration(target_pos: Vector2) -> float:
	# Use any valid layer for coordinate conversion, since they share the same grid.
	var map_layer: TileMapLayer = _highlight_layer

	# Get start and end positions in tile coordinates
	var start_coords: Vector2i = map_layer.local_to_map(muzzle.global_position)
	var end_coords: Vector2i = map_layer.local_to_map(target_pos)

	# Calculate grid distance (Manhattan distance)
	var distance_in_tiles: int = abs(start_coords.x - end_coords.x) + abs(start_coords.y - end_coords.y)

	# Calculate base duration based on tiles to travel and seconds per tile
	var duration: float = distance_in_tiles * data.seconds_per_tile

	# Apply visual correction for long-screen-distance paths
	var travel_vector: Vector2 = target_pos - muzzle.global_position
	# If the path is more horizontal than vertical, apply the correction
	if abs(travel_vector.x) > abs(travel_vector.y) * 2.0:
		duration *= data.visual_speed_correction

	return duration
		
