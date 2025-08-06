extends Area2D

## Template Enemy: Common logic for all enemy types
class_name TemplateEnemy

## Signals
signal died(reward_amount)	# Emitted when the enemy dies
signal reached_end_of_path	# Emitted when the enemy reaches the end of a path


## Enums
enum State {
	MOVING,
	DYING,
	REACHED_GOAL
}


## Static Caches
static var _valid_variants_cache: Dictionary = {}	# Cache for valid variants per enemy type


## Exported Data
@export var data: EnemyData	# Enemy data resource


## Enemy Stats
var max_health: int = 10	# Maximum health
var speed: float = 60.0	# Movement speed
var reward: int = 1	# Reward for defeating this enemy
var health: int:
	get:
		return _health
	set(value):
		if state == State.DYING:
			return
		_health = max(0, value)
		_update_health_bar()
		if _health == 0:
			die()


## Internal State
var state: State = State.MOVING	# Current state
var _health: int	# Current health
var _variant: String = ""	# Current variant name
var _last_direction: String = "south_west"	# Last animation direction
var _last_flip_h: bool = false	# Last horizontal flip state
var _has_reached_end: bool = false	# True if enemy reached end of path

## Node References
@onready var animation := $Animation as AnimatedSprite2D	# Animation node
@onready var hitbox := $PositionShape as CollisionShape2D	# Hitbox node
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


## Handles enemy death, gives a reward, and plays death animation
func die() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	emit_signal("died", reward)
	await _play_death_sequence("die")
	_return_to_pool_and_cleanup()


## Handles the enemy reaching the goal without giving a reward
func reached_goal() -> void:
	if state == State.DYING or state == State.REACHED_GOAL:
		return
	state = State.REACHED_GOAL
	# For now, we reuse the "die" animation. This can be changed to "goal" later.
	await _play_death_sequence("die")
	_return_to_pool_and_cleanup()


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


## Plays the common death sequence and returns a signal for when it's finished.
func _play_death_sequence(action_name: String) -> Signal:
	set_process(false)
	# We don't stop processing here, as it needs to finish the animation
	
	hitbox.set_deferred("disabled", true)
	if health_bar:
		health_bar.visible = false
	
	# Play the death animation based on the last known direction
	var animation_name: String = "%s_%s_%s" % [_variant, action_name, _last_direction]
	if animation and animation.sprite_frames.has_animation(animation_name):
		animation.play(animation_name)
		animation.flip_h = _last_flip_h
		return animation.animation_finished
	
	# If no animation is found, return a signal that finishes instantly
	var timer := get_tree().create_timer(0.0)
	return timer.timeout


## Updates the health bar display
func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = float(_health) / float(max_health) * 100.0
		health_bar.visible = _health < max_health


## Resets the enemy to its initial state
func reset() -> void:
	_health = max_health
	_update_health_bar()
	state = State.MOVING
	_has_reached_end = false
	# Process is enabled by the spawner when ready
	set_process(false) 
	hitbox.set_deferred("disabled", false)


## Prepares the enemy for a new path
func prepare_for_new_path() -> void:
	_has_reached_end = false


## Returns true if the enemy is dying
func is_dying() -> bool:
	return state == State.DYING


## Handles returning the object to the pool and cleaning up its temporary parent
func _return_to_pool_and_cleanup() -> void:
	# Store a reference to the temporary PathFollow2D parent
	var temp_path_follow := path_follow
	
	# Return this enemy to the pool (which will reparent it)
	ObjectPoolManager.return_object(self)
	
	# Now that the enemy has been reparented, we can safely free the old PathFollow2D
	if is_instance_valid(temp_path_follow):
		temp_path_follow.queue_free()
