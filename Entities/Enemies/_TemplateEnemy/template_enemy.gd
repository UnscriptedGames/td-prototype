extends Area2D

## Template Enemy: Common logic for all enemy types
class_name TemplateEnemy

## Signals
signal died(enemy, reward_amount)	# Emitted when the enemy dies
signal reached_end_of_path(enemy)	# Emitted when the enemy reaches the end of a path


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
const CORNER_SMOOTHING: float = 5.0 # How quickly the enemy turns at corners. Higher is sharper.

var state: State = State.MOVING	# Current state
var _health: int	# Current health
var _variant: String = ""	# Current variant name
var _path_offset: float = 0.0	# Personal offset from the path center
var _smoothed_right_vector: Vector2 = Vector2.RIGHT # The smoothed perpendicular vector for cornering
var _last_direction: String = "south_west"	# Last animation direction
var _last_flip_h: bool = false	# Last horizontal flip state
var _has_reached_end: bool = false	# True if enemy reached end of path


## Status Effect State
var _active_status_effects: Dictionary = {} # Key: EffectType, Value: Dictionary of effect data
var _speed_modifier: float = 1.0 # Multiplier for the enemy's speed
var _is_stunned: bool = false # Is the enemy currently stunned?


## Node References
@onready var animation := $Animation as AnimatedSprite2D	# Animation node
@onready var hitbox := $PositionShape as CollisionShape2D	# Hitbox node
@onready var progress_bar_container := $ProgressBarContainer as VBoxContainer
@onready var health_bar := $ProgressBarContainer/HealthBar as TextureProgressBar	# Health bar node
@onready var dot_bar := $ProgressBarContainer/DotBar as ProgressBar
@onready var slow_bar := $ProgressBarContainer/SlowBar as ProgressBar
@onready var stun_bar := $ProgressBarContainer/StunBar as ProgressBar


## Private Properties
var _effect_bars: Dictionary = {} # Maps EffectType to its ProgressBar


## Public Properties
var path_follow: PathFollow2D	# PathFollow2D node for movement


## Called when the enemy enters the scene tree
func _ready() -> void:
	# Initial setup
	if not data:
		push_error("EnemyData is not assigned!")
		return

	# Map effect types to their progress bars
	_effect_bars = {
		StatusEffectData.EffectType.DOT: dot_bar,
		StatusEffectData.EffectType.SLOW: slow_bar,
		StatusEffectData.EffectType.STUN: stun_bar
	}

	# Hide all bars by default on spawn to guarantee a clean initial state.
	# This is important even though reset() also hides the container,
	# as reset() is also used for object pooling.
	progress_bar_container.visible = false
	health_bar.visible = false
	for bar in _effect_bars.values():
		if is_instance_valid(bar):
			bar.visible = false

	# Configure stats
	max_health = data.max_health
	speed = data.speed
	reward = data.reward

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

	# Animation always processes so death animations can play
	animation.process_mode = Node.PROCESS_MODE_ALWAYS

	# Set the initial state
	reset()


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

	# If stunned, the animation will be paused. We need to unpause it so the
	# death animation can play. Calling play() without arguments resumes the
	# current animation, which is what we want before switching to the death animation.
	if animation.is_paused():
		animation.play()

	# If the enemy is a flying type, make it "fall" to the ground for its death animation
	if data and data.is_flying:
		z_index = 0

	emit_signal("died", self, reward)

	if not animation.animation_finished.is_connected(_on_death_animation_finished):
		animation.animation_finished.connect(_on_death_animation_finished)

	_play_death_sequence("die")


## Handles the enemy reaching the goal without giving a reward
func reached_goal() -> void:
	if state == State.DYING or state == State.REACHED_GOAL:
		return
	state = State.REACHED_GOAL
	
	# If the enemy is a flying type, make it "fall" to the ground
	if data and data.is_flying:
		z_index = 0
		
	if not animation.animation_finished.is_connected(_on_death_animation_finished):
		animation.animation_finished.connect(_on_death_animation_finished)

	# For now, we reuse the "die" animation. This can be changed to "goal" later.
	_play_death_sequence("die")


## Handles movement and animation each frame
func _process(delta: float) -> void:
	_process_status_effects(delta)

	if state == State.DYING:
		return

	if _is_stunned:
		# If stunned, do nothing else this frame.
		# We might want to play a "stunned" animation here in the future.
		return

	if path_follow and is_instance_valid(path_follow.get_parent()):
		# Move the follower along the path
		path_follow.progress += speed * _speed_modifier * delta
		
		# Smooth the perpendicular vector to create nice arcs around corners
		_smoothed_right_vector = _smoothed_right_vector.lerp(path_follow.transform.x, CORNER_SMOOTHING * delta)

		# Calculate the final position using the path position and the smoothed offset
		var path_position: Vector2 = path_follow.global_position
		global_position = path_position + (_smoothed_right_vector.normalized() * _path_offset)

		# Get current and next positions to determine visual animation direction
		var path: Path2D = path_follow.get_parent() as Path2D
		var current_pos: Vector2 = path.curve.sample_baked(path_follow.progress)
		var next_progress: float = min(path_follow.progress + 1.0, path.curve.get_baked_length())
		var future_pos: Vector2 = path.curve.sample_baked(next_progress)
		var direction: Vector2 = (future_pos - current_pos).normalized()

		# Determine animation direction based on movement
		var anim_dir: String = "north_west" if direction.y < 0 else "south_west"
		var flip_h: bool = direction.x > 0

		# Store the last direction for the death animation
		if path_follow.progress < path.curve.get_baked_length() - 0.1:
			_last_direction = anim_dir
			_last_flip_h = flip_h
 
		# Play the moving animation
		_play_animation("move", anim_dir, flip_h)

		# Check if the enemy has reached the end of the path
		if not _has_reached_end and path_follow.progress >= path.curve.get_baked_length():
			_has_reached_end = true
			emit_signal("reached_end_of_path", self)


## Plays the specified animation for the current variant
func _play_animation(action: String, direction: String, flip_h: bool = false) -> void:
	var animation_name: String = _variant + "_" + action + "_" + direction
	if animation:
		# ONLY play the animation if it's not already the current one.
		if animation.animation != animation_name:
			animation.play(animation_name)
		
		# We can still update the flip value every frame.
		animation.flip_h = flip_h


## Plays the common death sequence.
func _play_death_sequence(action_name: String) -> void:
	set_process(false)
	
	hitbox.set_deferred("disabled", true)
	if progress_bar_container:
		progress_bar_container.visible = false
	
	# Play the death animation based on the last known direction
	var animation_name: String = "%s_%s_%s" % [_variant, action_name, _last_direction]
	if animation and animation.sprite_frames.has_animation(animation_name):
		animation.play(animation_name)
		animation.flip_h = _last_flip_h
	else:
		# If no animation is found, cleanup immediately.
		_return_to_pool_and_cleanup()


## Updates the health bar display
func _update_health_bar() -> void:
	if not health_bar:
		return
	_ensure_bar_is_visible(health_bar)
	health_bar.value = float(_health) / float(max_health) * 100.0


## Resets the enemy to its initial state
func reset() -> void:
	# Reset health and hide the progress bar container
	_health = max_health
	if progress_bar_container:
		progress_bar_container.visible = false

	# Reset state and pathing
	state = State.MOVING
	_has_reached_end = false
	if is_instance_valid(path_follow):
		path_follow.progress = 0.0
	_smoothed_right_vector = Vector2.RIGHT

	# Reset status effects
	_active_status_effects.clear()
	_speed_modifier = 1.0
	_is_stunned = false

	# Assign a random path offset
	if data:
		_path_offset = randf_range(-data.max_path_offset, data.max_path_offset)
		z_index = 10 if data.is_flying else 0

	# Process is enabled by the spawner when ready
	set_process(false)
	hitbox.set_deferred("disabled", false)


## Prepares the enemy for a new path
func prepare_for_new_path() -> void:
	_has_reached_end = false


## Returns true if the enemy is dying
func is_dying() -> bool:
	return state == State.DYING


## Status Effect Handling ##

func _ensure_bar_is_visible(bar: Control) -> void:
	# Helper to ensure the container and the specific bar are visible.
	if not progress_bar_container.visible:
		progress_bar_container.visible = true
	if not bar.visible:
		bar.visible = true


func apply_status_effect(effect: StatusEffectData) -> void:
	if not is_instance_valid(effect) or not _effect_bars.has(effect.effect_type):
		return

	var effect_type = effect.effect_type
	var effect_bar = _effect_bars[effect_type]

	# Ensure the health bar and the specific effect bar are visible.
	_ensure_bar_is_visible(health_bar)
	_ensure_bar_is_visible(effect_bar)

	# If the effect is not already active, add it.
	if not _active_status_effects.has(effect_type):
		_active_status_effects[effect_type] = {
			"data": effect,
			"duration": effect.duration,
			"initial_duration": effect.duration, # Store for progress bar calculation
			"tick_timer": 0.0
		}
		# Handle initial application for certain effects
		match effect_type:
			StatusEffectData.EffectType.SLOW: _recalculate_speed()
			StatusEffectData.EffectType.STUN:
				_is_stunned = true
				animation.pause()
		return

	# --- Stacking Logic for existing effects ---
	var existing_effect = _active_status_effects[effect_type]

	# For STUN, if already stunned, do nothing.
	if effect_type == StatusEffectData.EffectType.STUN and _is_stunned:
		return

	# If the new effect has a longer duration, reset the timer and initial duration.
	if effect.duration > existing_effect.duration:
		existing_effect.duration = effect.duration
		existing_effect.initial_duration = effect.duration

	# For some effects, we might want to stack properties even if the duration isn't longer.
	match effect_type:
		StatusEffectData.EffectType.DOT:
			if effect.damage_per_tick > existing_effect.data.damage_per_tick:
				existing_effect.data.damage_per_tick = effect.damage_per_tick
			if effect.tick_rate < existing_effect.data.tick_rate:
				existing_effect.data.tick_rate = effect.tick_rate

		StatusEffectData.EffectType.SLOW:
			if effect.magnitude > existing_effect.data.magnitude:
				existing_effect.data.magnitude = effect.magnitude
				_recalculate_speed()

		StatusEffectData.EffectType.STUN:
			# Stun duration is refreshed by the logic above. No other properties to stack.
			_is_stunned = true # Re-apply stun state in case it wore off on the same frame
			animation.pause()
			pass


func _process_status_effects(delta: float) -> void:
	if _active_status_effects.is_empty():
		return

	var effects_to_remove = []
	for effect_type in _active_status_effects:
		var effect = _active_status_effects[effect_type]
		var effect_bar = _effect_bars[effect_type]

		effect.duration -= delta

		if effect.duration <= 0:
			effects_to_remove.append(effect_type)
		else:
			# Update progress bar
			if effect_bar:
				effect_bar.value = (effect.duration / effect.initial_duration) * 100.0

			# Process effect logic
			match effect_type:
				StatusEffectData.EffectType.DOT: _handle_dot_effect(effect, delta)
				StatusEffectData.EffectType.SLOW: _handle_slow_effect(effect, delta)
				StatusEffectData.EffectType.STUN: _handle_stun_effect(effect, delta)

	# Remove expired effects
	for effect_type in effects_to_remove:
		if _effect_bars.has(effect_type) and _effect_bars[effect_type]:
			_effect_bars[effect_type].visible = false

		_active_status_effects.erase(effect_type)

		# Handle effect removal logic
		match effect_type:
			StatusEffectData.EffectType.SLOW: _recalculate_speed()
			StatusEffectData.EffectType.STUN:
				_is_stunned = false
				animation.play()


func _handle_dot_effect(effect_data, delta) -> void:
	effect_data.tick_timer += delta
	if effect_data.tick_timer >= effect_data.data.tick_rate:
		effect_data.tick_timer -= effect_data.data.tick_rate
		health -= effect_data.data.damage_per_tick


func _handle_slow_effect(_effect_data, _delta) -> void:
	# The effect is applied on addition/removal, so nothing to do here per frame.
	pass


func _handle_stun_effect(_effect_data, _delta) -> void:
	# The effect is handled by checking _is_stunned in _process.
	pass


func _recalculate_speed() -> void:
	_speed_modifier = 1.0
	if _active_status_effects.has(StatusEffectData.EffectType.SLOW):
		var slow_effect = _active_status_effects[StatusEffectData.EffectType.SLOW]
		_speed_modifier -= slow_effect.data.magnitude


func _on_death_animation_finished() -> void:
	if animation.animation_finished.is_connected(_on_death_animation_finished):
		animation.animation_finished.disconnect(_on_death_animation_finished)
	_return_to_pool_and_cleanup()


## Handles returning the object to the pool and cleaning up its temporary parent
func _return_to_pool_and_cleanup() -> void:
	# Store a reference to the temporary PathFollow2D parent
	var temp_path_follow := path_follow
	
	# Return this enemy to the pool (which will reparent it)
	ObjectPoolManager.return_object(self)
	
	# Now that the enemy has been reparented, we can return the old PathFollow2D to its pool
	if is_instance_valid(temp_path_follow):
		ObjectPoolManager.return_node(temp_path_follow)
