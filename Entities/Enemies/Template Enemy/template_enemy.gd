extends Area2D

## Template Enemy: Common logic for all enemy types
class_name TemplateEnemy

## Signals
signal died(reward_amount)	# Emitted when the enemy dies
signal reached_end_of_path	# Emitted when the enemy reaches the end of a path

## Static Caches
static var _valid_variants_cache: Dictionary = {}	# Cache for valid variants per enemy type

## Exported Data
@export var data: EnemyData	# Enemy data resource

## Enemy Stats
var max_health: int = 10	# Maximum health
var speed: float = 60.0	# Movement speed
var reward: int = 1	# Reward for defeating this enemy

## Internal State
var _health: int	# Current health
var _variant: String = ""	# Current variant name
var _last_direction: String = "south_west"	# Last animation direction
var _last_flip_h: bool = false	# Last horizontal flip state
var _is_dying: bool = false	# True if enemy is dying
var _has_reached_end: bool = false	# True if enemy reached end of path

## Node References
@onready var animation := $Animation as AnimatedSprite2D	# Animation node
@onready var hitbox := $Hitbox as CollisionShape2D	# Hitbox node
@onready var health_bar := $HealthBar as TextureProgressBar	# Health bar node

## Public Properties
var path_follow: PathFollow2D	# PathFollow2D node for movement


## Called when the enemy enters the scene tree
func _ready() -> void:
	if not data:
		push_error("EnemyData is not assigned!")
		return

	# Configure the enemy's stats from the data resource
	max_health = data.max_health
	speed = data.speed
	reward = data.reward
	_health = max_health

	# Validate and select a variant
	var data_key: String = data.resource_path
	var valid_variants: Array = []

	if _valid_variants_cache.has(data_key):
		valid_variants = _valid_variants_cache[data_key]
	else:
		valid_variants = _validate_and_cache_variants()

	if not valid_variants.is_empty():
		_variant = valid_variants.pick_random()
	else:
		push_error("No valid variants found for '%s'. Disabling enemy." % data_key)
		set_process(false)
		visible = false

	_update_health_bar()


## Validates all variants in the EnemyData resource
func _validate_and_cache_variants() -> Array:
	var valid_variants: Array = []
	
	if not data.animations:
		push_error("EnemyData resource '%s' is missing an animation resource." % data.resource_path)
		return []

	animation.sprite_frames = data.animations

	# Loop through all possible variants (e.g., "green", "purple")
	for variant_name in data.variants:
		var is_variant_fully_valid: bool = true
		# Loop through all required actions for that variant
		for action in data.required_actions:
			# Check for both required directions for each action
			var anim_sw_name: String = "%s_%s_south_west" % [variant_name, action]
			var anim_nw_name: String = "%s_%s_north_west" % [variant_name, action]

			if not animation.sprite_frames.has_animation(anim_sw_name):
				push_error("Validation failed for '%s': Missing animation '%s'." % [data.resource_path, anim_sw_name])
				is_variant_fully_valid = false

			if not animation.sprite_frames.has_animation(anim_nw_name):
				push_error("Validation failed for '%s': Missing animation '%s'." % [data.resource_path, anim_nw_name])
				is_variant_fully_valid = false
		# If after all checks, the variant is still valid, add it to our list
		if is_variant_fully_valid:
			valid_variants.append(variant_name)
	# Store the result in the cache and return it
	_valid_variants_cache[data.resource_path] = valid_variants
	return valid_variants


## Applies damage to the enemy
func take_damage(amount: int) -> void:
	if _is_dying:
		return
	_health -= amount
	_update_health_bar()
	if _health <= 0:
		die()


## Handles enemy death and plays death animation
func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	set_process(false)
	hitbox.set_deferred("disabled", true)
	if health_bar:
		health_bar.visible = false
	emit_signal("died", reward)
	var animation_name: String = _variant + "_die_" + _last_direction
	if animation and animation.sprite_frames.has_animation(animation_name):
		animation.play(animation_name)
		animation.flip_h = _last_flip_h
		await animation.animation_finished
	queue_free()


## Handles the enemy reaching the goal without giving a reward
func reached_goal() -> void:
	if _is_dying:
		return
	
	_is_dying = true
	set_process(false)
	hitbox.set_deferred("disabled", true)
	if health_bar:
		health_bar.visible = false
	
	# Play the death animation based on the last known direction
	var animation_name: String = _variant + "_die_" + _last_direction
	if animation and animation.sprite_frames.has_animation(animation_name):
		animation.play(animation_name)
		animation.flip_h = _last_flip_h
		await animation.animation_finished
	
	# Clean up the parent PathFollow2D node, which also removes this enemy
	if is_instance_valid(path_follow):
		path_follow.queue_free()
	else:
		# Fallback in case the path_follow node is already gone
		queue_free()


## Handles movement and animation each frame
func _process(delta: float) -> void:
	if path_follow and is_instance_valid(path_follow.get_parent()):
		path_follow.progress += speed * delta
		global_position = path_follow.global_position
		var path: Path2D = path_follow.get_parent() as Path2D
		var current_pos: Vector2 = path.curve.sample_baked(path_follow.progress)
		var next_progress = min(path_follow.progress + 1.0, path.curve.get_baked_length())
		var future_pos: Vector2 = path.curve.sample_baked(next_progress)
		var direction: Vector2 = (future_pos - current_pos).normalized()
		var anim_dir: String = "north_west" if direction.y < 0 else "south_west"
		var flip_h: bool = direction.x > 0
		if path_follow.progress < path.curve.get_baked_length() - 0.1:
			_last_direction = anim_dir
			_last_flip_h = flip_h
		_play_animation("walk", anim_dir, flip_h)
		if not _has_reached_end and path_follow.progress >= path.curve.get_baked_length():
			_has_reached_end = true
			emit_signal("reached_end_of_path")


## Plays the specified animation for the current variant
func _play_animation(action: String, direction: String, flip_h: bool = false) -> void:
	var animation_name: String = _variant + "_" + action + "_" + direction
	if animation:
		animation.play(animation_name)
		animation.flip_h = flip_h


## Updates the health bar display
func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = float(_health) / float(max_health) * 100.0
		health_bar.visible = _health < max_health


## Resets the enemy to its initial state
func reset() -> void:
	_health = max_health
	_update_health_bar()
	_is_dying = false
	_has_reached_end = false
	set_process(true)
	hitbox.set_deferred("disabled", false)


## Prepares the enemy for a new path
func prepare_for_new_path() -> void:
	_has_reached_end = false


## Returns true if the enemy is dying
func is_dying() -> bool:
	return _is_dying