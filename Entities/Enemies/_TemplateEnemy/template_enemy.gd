@tool
extends Area2D

## Template Enemy: Common logic for all enemy types
class_name TemplateEnemy

## Signals
signal died(enemy: TemplateEnemy, reward_amount: int)  # Emitted when the enemy dies
signal path_finished(enemy: TemplateEnemy)  # Emitted when the enemy reaches the end of a path


## Enums
enum State { MOVING, DYING, REACHED_GOAL }


## Inner Classes
class ActiveStatusEffect:
	var data: StatusEffectData
	var duration: float
	var initial_duration: float
	var tick_timer: float = 0.0

	func _init(initial_data: StatusEffectData) -> void:
		data = initial_data
		duration = initial_data.duration
		initial_duration = initial_data.duration
		tick_timer = 0.0


## Constants
const CORNER_SMOOTHING: float = 15.0  # How quickly the enemy turns at corners. Higher is sharper.


## Exported Data
@export var data: EnemyData  # Enemy data resource


## Enemy Stats
var max_health: int = 10  # Maximum health
var speed: float = 60.0  # Movement speed
var reward: int = 1  # Reward for defeating this enemy
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
var state: State = State.MOVING  # Current state
var path_follow: Node2D  # Kept for signature compatibility if something expects node.

var _health: int  # Current health
var _variant: String = ""  # Current variant name
var _last_direction: String = "south_west"  # Last animation direction
var _has_reached_end: bool = false  # True if enemy reached end of path
var _wander_offset: Vector2 = Vector2.ZERO  # Organic offset

# AStar Navigation State
var _astar_grid: AStarGrid2D
var _target_tile: Vector2i
var _current_path: PackedVector2Array
var _current_path_index: int = 0
var _velocity: Vector2 = Vector2.ZERO
var _time_lived: float = 0.0  # Time since spawn to drive organic wobble


## Status Effect State
var _active_status_effects: Dictionary[StatusEffectData.EffectType, ActiveStatusEffect] = {}
var _speed_modifier: float = 1.0  # Multiplier for the enemy's speed
var _is_stunned: bool = false  # Is the enemy currently stunned?
var _effect_bars: Dictionary[StatusEffectData.EffectType, ProgressBar] = {}  # Maps EffectType to its ProgressBar


## Node References
@onready var sprite: CanvasItem = ($Sprite as CanvasItem)  # Wave visual node (Sprite2D or TextureRect)
@onready var animation: AnimatedSprite2D = ($Animation as AnimatedSprite2D)  # Death animation node
@onready var hitbox: CollisionShape2D = ($PositionShape as CollisionShape2D)  # Hitbox node
@onready var shadow_panel: Panel = ($Shadow as Panel)  # Shadow visual node
@onready var progress_bar_container: VBoxContainer = ($ProgressBarContainer as VBoxContainer)
@onready var dot_bar: ProgressBar = ($ProgressBarContainer/DotBar as ProgressBar)
@onready var slow_bar: ProgressBar = ($ProgressBarContainer/SlowBar as ProgressBar)
@onready var stun_bar: ProgressBar = ($ProgressBarContainer/StunBar as ProgressBar)
@onready var health_bar: TextureProgressBar = ($ProgressBarContainer/HealthBar as TextureProgressBar)
@onready var target_point: Node2D = ($TargetPoint if has_node("TargetPoint") else self)


# --- LIFECYCLE ---


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
	if data:
		max_health = data.max_health
		speed = data.speed
		reward = data.reward
	else:
		push_error("EnemyData is not assigned!")
		return

	# Set the initial state
	if not Engine.is_editor_hint():
		reset()


func _exit_tree() -> void:
	# Disconnect dynamic signals when the enemy is unexpectedly removed from the tree
	# Note: We do not disconnect 'died' or 'reached_end_of_path' here because they are
	# expected to be connected by the spawn manager and stay assigned unless explicitly disconnected
	# by the listener when cleaning up.
	if animation and animation.animation_finished.is_connected(_on_death_animation_finished):
		animation.animation_finished.disconnect(_on_death_animation_finished)


## Handles movement and animation each frame
func _process(delta: float) -> void:
	# Keep the shader scrolling accurate inside the editor based on the data!
	if Engine.is_editor_hint():
		if data and sprite and sprite.material is ShaderMaterial:
			var speed_multiplier: float = data.scroll_speed
			var computed_time: float = (float(Time.get_ticks_msec()) / 1_000.0) * speed_multiplier
			var shader_material: ShaderMaterial = sprite.material as ShaderMaterial
			assert(shader_material != null)
			shader_material.set_shader_parameter("use_unscaled_time", true)
			sprite.set_instance_shader_parameter("unscaled_time", computed_time)
		return

	_process_status_effects(delta)
	_time_lived += delta

	if state == State.DYING:
		return

	if _is_stunned:
		# If stunned, do nothing else this frame.
		# We might want to play a "stunned" animation here in the future.
		return

	if _current_path.size() == 0 or _current_path_index >= _current_path.size():
		if not _has_reached_end:
			_has_reached_end = true
			emit_signal("path_finished", self)
		return

	# Determine current target waypoint
	var target_waypoint: Vector2 = _current_path[_current_path_index] + _wander_offset

	# Desired steering velocity
	var desired_velocity: Vector2 = (
		(target_waypoint - global_position).normalized() * speed * _speed_modifier
	)

	# Smoothly interpolate velocity to curve corners (using the existing constant, clamped to 1.0 to prevent high speed extrapolation)
	if _velocity == Vector2.ZERO:
		_velocity = desired_velocity
	else:
		var move_speed: float = speed * _speed_modifier * delta * CORNER_SMOOTHING
		_velocity = _velocity.move_toward(desired_velocity, move_speed)

	# Add a sine-wave wobble perpendicular to the velocity
	var wobble_amplitude: float = data.wobble_amplitude if data else 8.0
	var wobble_frequency: float = data.wobble_frequency if data else 3.0
	var speed_factor: float = _speed_modifier  # Slow down wobble if the enemy is slowed

	# Calculate perpendicular normal (-y, x) of the normalized current velocity
	var movement_direction_normalized: Vector2 = _velocity.normalized()
	var perpendicular_direction: Vector2 = Vector2(
		-movement_direction_normalized.y, movement_direction_normalized.x
	)
	var wobble_offset: Vector2 = (
		perpendicular_direction
		* sin(_time_lived * wobble_frequency * speed_factor)
		* wobble_amplitude
	)

	var frame_velocity: Vector2 = _velocity + wobble_offset
	var distance_to_move: float = frame_velocity.length() * delta
	var move_direction: Vector2 = frame_velocity.normalized()

	var current_position: Vector2 = global_position

	# Sub-stepping loop for fast game speeds
	while distance_to_move > 0.0 and _current_path_index < _current_path.size():
		target_waypoint = _current_path[_current_path_index] + _wander_offset
		var distance_to_target: float = current_position.distance_to(target_waypoint)

		# Sub-step check: Would this move instantly blow past the waypoint?
		if distance_to_move >= distance_to_target:
			# Yes! Move EXACTLY to the waypoint corner to prevent wall clipping
			current_position = target_waypoint
			distance_to_move -= distance_to_target
			_current_path_index += 1
			# For the remaining distance, we must redirect towards the NEXT waypoint
			if _current_path_index < _current_path.size():
				move_direction = (
					(_current_path[_current_path_index] + _wander_offset - current_position)
					. normalized()
				)
		else:
			# Normal movement frame, or the last sub-step of a fast frame
			current_position += move_direction * distance_to_move
			# If distance_to_target is within 12 pixels, we gracefully say it matched for smooth turning next frame (1x speed)
			if current_position.distance_to(target_waypoint) <= 12.0:
				_current_path_index += 1
			distance_to_move = 0.0
			break

	global_position = current_position

	# Determine animation direction based on mathematical velocity
	var animation_direction: String = "north_west" if _velocity.y < 0 else "south_west"

	# Store the last direction for the death animation
	if _current_path_index < _current_path.size() - 1:
		_last_direction = animation_direction

	# Wave Visual: Update unscaled time and enable visibility
	if sprite and sprite.material is ShaderMaterial:
		var shader_material: ShaderMaterial = sprite.material as ShaderMaterial
		assert(shader_material != null)
		shader_material.set_shader_parameter("use_unscaled_time", true)

		var speed_multiplier: float = data.scroll_speed if data else 1.0
		var computed_time: float = (float(Time.get_ticks_msec()) / 1_000.0) * speed_multiplier
		sprite.set_instance_shader_parameter("unscaled_time", computed_time)

		# Enable visibility now that we are positioned correctly
		if not sprite.visible:
			sprite.visible = true
			if shadow_panel:
				shadow_panel.visible = true

	# Play the moving animation
	_play_animation("move", animation_direction)


# --- METHODS ---


## Handles enemy death, gives a reward, and plays death animation
func die() -> void:
	if state == State.DYING:
		return
	state = State.DYING

	emit_signal("died", self, reward)

	if not animation.animation_finished.is_connected(_on_death_animation_finished):
		animation.animation_finished.connect(_on_death_animation_finished)

	_play_death_sequence("die")


## Handles the enemy reaching the goal without giving a reward
func reached_goal() -> void:
	if state == State.DYING or state == State.REACHED_GOAL:
		return
	state = State.REACHED_GOAL

	if not animation.animation_finished.is_connected(_on_death_animation_finished):
		animation.animation_finished.connect(_on_death_animation_finished)

	# For now, we reuse the "die" animation. This can be changed to "goal" later.
	_play_death_sequence("die")


## Assigns the navigation context so the enemy can calculate its path
func set_navigation_context(
	navigation_grid: AStarGrid2D, start_tile: Vector2i, target: Vector2i
) -> void:
	_astar_grid = navigation_grid
	_target_tile = target

	if _astar_grid:
		var grid_region: Rect2i = _astar_grid.region

		# Clamp points to the grid's strictly defined region to prevent out of bounds crashes
		var safe_start: Vector2i = Vector2i(
			clampi(start_tile.x, grid_region.position.x, grid_region.end.x - 1),
			clampi(start_tile.y, grid_region.position.y, grid_region.end.y - 1)
		)

		var safe_target: Vector2i = Vector2i(
			clampi(_target_tile.x, grid_region.position.x, grid_region.end.x - 1),
			clampi(_target_tile.y, grid_region.position.y, grid_region.end.y - 1)
		)

		_current_path = _astar_grid.get_point_path(safe_start, safe_target)

		# Skip first point if it's the tile we're already standing on
		_current_path_index = 0
		if _current_path.size() > 0 and global_position.distance_to(_current_path[0]) < 10.0:
			_current_path_index = 1

		# Assign a random wander offset to keep movement organic but firmly inside the tile
		var cell_size = _astar_grid.cell_size
		_wander_offset = Vector2(
			randf_range(-cell_size.x * 0.15, cell_size.x * 0.15),
			randf_range(-cell_size.y * 0.15, cell_size.y * 0.15)
		)


## Returns the estimated total distance remaining to reach the end of the path
func get_remaining_distance() -> float:
	if _current_path.size() == 0:
		return 0.0

	var remaining: float = 0.0

	if _current_path_index < _current_path.size():
		# Distance to the next waypoint
		remaining += global_position.distance_to(_current_path[_current_path_index])

	# Distance of all subsequent waypoints
	for index: int in range(_current_path_index, _current_path.size() - 1):
		remaining += _current_path[index].distance_to(_current_path[index + 1])

	return remaining


## Plays the specified animation for the current variant
func _play_animation(action: String, direction: String) -> void:
	var animation_name: String = _variant + "_" + action + "_" + direction
	if animation:
		# ONLY play the animation if it's not already the current one.
		if animation.animation != animation_name:
			animation.play(animation_name)


## Plays the common death sequence.
func _play_death_sequence(action_name: String) -> void:
	set_process(false)

	hitbox.set_deferred("disabled", true)
	if progress_bar_container:
		progress_bar_container.visible = false

	# Swap visuals: Hide Wave, Show Animation
	sprite.visible = false
	if shadow_panel:
		shadow_panel.visible = false
	animation.visible = true

	# Play the death animation based on the last known direction
	var animation_name: String = "%s_%s_%s" % [_variant, action_name, _last_direction]
	if animation and animation.sprite_frames.has_animation(animation_name):
		animation.play(animation_name)
	else:
		# If no animation is found, cleanup immediately.
		_return_to_pool_and_cleanup()


## Updates the health bar display
func _update_health_bar() -> void:
	if not health_bar:
		return

	var ratio: float = float(_health) / float(max_health)

	if sprite:
		sprite.set_instance_shader_parameter("health_ratio", ratio)


## Resets the enemy to its initial state
func reset() -> void:
	# Reset health and hide the progress bar container
	_health = max_health
	if progress_bar_container:
		progress_bar_container.visible = false

	# Reset Visuals
	if sprite:
		sprite.visible = false  # Logic in _process will enable it once positioned
		sprite.set_instance_shader_parameter("health_ratio", 1.0)
	if shadow_panel:
		shadow_panel.visible = false
	if animation:
		animation.visible = false
		animation.stop()

	# Reset state and pathing
	state = State.MOVING
	_has_reached_end = false
	_current_path.clear()
	_current_path_index = 0
	_velocity = Vector2.ZERO
	_wander_offset = Vector2.ZERO
	_time_lived = 0.0

	# Reset status effects
	_active_status_effects.clear()
	_speed_modifier = 1.0
	_is_stunned = false

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
		pass  # Disabled while testing shader health visuals
		# progress_bar_container.visible = true
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
		_active_status_effects[effect_type] = ActiveStatusEffect.new(effect)

		# Handle initial application for certain effects
		match effect_type:
			StatusEffectData.EffectType.SLOW:
				_recalculate_speed()
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
			# This block is now unreachable for STUN effects due to the guard clause above,
			# but we leave the structure in case of future changes.
			# The stun is now applied only when it's a new effect.
			pass


func _process_status_effects(delta: float) -> void:
	if _active_status_effects.is_empty():
		return

	var effects_to_remove: Array[StatusEffectData.EffectType] = []
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
				StatusEffectData.EffectType.DOT:
					_handle_dot_effect(effect, delta)
				StatusEffectData.EffectType.SLOW:
					_handle_slow_effect(effect, delta)
				StatusEffectData.EffectType.STUN:
					_handle_stun_effect(effect, delta)

	# Remove expired effects
	for effect_type in effects_to_remove:
		if _effect_bars.has(effect_type) and is_instance_valid(_effect_bars[effect_type]):
			_effect_bars[effect_type].visible = false

		_active_status_effects.erase(effect_type)

		# Handle effect removal logic
		match effect_type:
			StatusEffectData.EffectType.SLOW:
				_recalculate_speed()
			StatusEffectData.EffectType.STUN:
				_is_stunned = false
				animation.play()


func _handle_dot_effect(effect: ActiveStatusEffect, delta: float) -> void:
	effect.tick_timer += delta
	if effect.tick_timer >= effect.data.tick_rate:
		effect.tick_timer -= effect.data.tick_rate
		health -= effect.data.damage_per_tick


func _handle_slow_effect(_effect: ActiveStatusEffect, _delta: float) -> void:
	# The effect is applied on addition/removal, so nothing to do here per frame.
	pass


func _handle_stun_effect(_effect: ActiveStatusEffect, _delta: float) -> void:
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


## Handles returning the object to the pool and cleaning up
func _return_to_pool_and_cleanup() -> void:
	# Return this enemy to the pool using call_deferred to avoid physics frame flushes
	ObjectPoolManager.call_deferred("return_object", self)
