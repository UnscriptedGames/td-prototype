extends Area2D
## Base enemy for all enemy types.

class_name BaseEnemy

signal died(reward_amount)
signal reached_end_of_path

## A cache shared between all enemies of the same type.
## It stores a list of valid variants to avoid re-checking every time.
static var _valid_variants_cache: Dictionary = {}

@export var data: EnemyData

## Enemy Stats
var max_health: int = 10
var speed: float = 60.0
var reward: int = 1

## Internal State
var _health: int
var _variant: String = ""
var _last_direction: String = "south_west"
var _last_flip_h: bool = false
var _is_dying: bool = false
var _has_reached_end: bool = false

## Node References
@onready var animation := $Animation as AnimatedSprite2D
@onready var hitbox := $Hitbox as CollisionShape2D
@onready var health_bar := $HealthBar as TextureProgressBar

## Public Properties
var path_follow: PathFollow2D


func _ready() -> void:
	if not data:
		push_error("EnemyData is not assigned!")
		return

	# Configure the enemy's stats from the data resource.
	max_health = data.max_health
	speed = data.speed
	reward = data.reward
	_health = max_health

	# --- New Validation Logic ---
	var data_key: String = data.resource_path
	var valid_variants: Array = []

	# Check the cache first. If we already validated this enemy type, use the cached result.
	if _valid_variants_cache.has(data_key):
		valid_variants = _valid_variants_cache[data_key]
	# Otherwise, run the comprehensive validation and cache the result for next time.
	else:
		valid_variants = _validate_and_cache_variants()

	# If there are any valid variants, pick one at random.
	if not valid_variants.is_empty():
		_variant = valid_variants.pick_random()
	# Otherwise, disable this enemy because no variants are usable.
	else:
		push_error("No valid variants found for '%s'. Disabling enemy." % data_key)
		set_process(false)
		visible = false

	_update_health_bar()


## Validates all variants in the EnemyData resource.
## Reports errors for every missing animation and returns a list of only the valid variants.
func _validate_and_cache_variants() -> Array:
	var valid_variants: Array = []
	
	if not data.animations:
		push_error("EnemyData resource '%s' is missing an animation resource." % data.resource_path)
		return []

	animation.sprite_frames = data.animations

	# Loop through all possible variants (e.g., "green", "purple").
	for variant_name in data.variants:
		var is_variant_fully_valid: bool = true
		# Loop through all required actions for that variant (e.g., "walk", "die").
		for action in data.required_actions:
			# Check for both required directions for each action.
			var anim_sw_name: String = "%s_%s_south_west" % [variant_name, action]
			var anim_nw_name: String = "%s_%s_north_west" % [variant_name, action]

			if not animation.sprite_frames.has_animation(anim_sw_name):
				push_error("Validation failed for '%s': Missing animation '%s'." % [data.resource_path, anim_sw_name])
				is_variant_fully_valid = false

			if not animation.sprite_frames.has_animation(anim_nw_name):
				push_error("Validation failed for '%s': Missing animation '%s'." % [data.resource_path, anim_nw_name])
				is_variant_fully_valid = false
		
		# If after all checks, the variant is still valid, add it to our list.
		if is_variant_fully_valid:
			valid_variants.append(variant_name)
	
	# Store the result in the cache and return it.
	_valid_variants_cache[data.resource_path] = valid_variants
	return valid_variants


## All functions below this point remain unchanged.

func take_damage(amount: int) -> void:
	if _is_dying:
		return
	_health -= amount
	_update_health_bar()
	if _health <= 0:
		die()


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


func _play_animation(action: String, direction: String, flip_h: bool = false) -> void:
	var animation_name: String = _variant + "_" + action + "_" + direction
	if animation:
		animation.play(animation_name)
		animation.flip_h = flip_h


func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = float(_health) / float(max_health) * 100.0
		health_bar.visible = _health < max_health


func reset() -> void:
	_health = max_health
	_update_health_bar()
	_is_dying = false
	_has_reached_end = false
	set_process(true)
	hitbox.set_deferred("disabled", false)


func prepare_for_new_path() -> void:
	_has_reached_end = false


func is_dying() -> bool:
	return _is_dying