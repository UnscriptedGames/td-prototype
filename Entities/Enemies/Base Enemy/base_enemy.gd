extends Area2D
## Base enemy for all enemy types

class_name BaseEnemy

signal death
signal reached_end_of_path

@export var data: EnemyData

var max_health: int = 10
var speed: float = 60.0
var reward: int = 1
var _health: int
var _variant: String = ""
var last_direction: String = "south_west"

var last_flip_h: bool = false
var is_dying: bool = false
var _has_reached_end: bool = false # Add this new flag

@onready var animation := $Animation as AnimatedSprite2D
@onready var hitbox := $Hitbox as CollisionShape2D
@onready var health_bar := $HealthBar as TextureProgressBar
var path_follow: PathFollow2D


func _ready():
	if data:
		max_health = data.max_health
		speed = data.speed
		reward = data.reward

		var random_variant: String = data.variants[randi() % data.variants.size()]
		var has_valid_variant: bool = false
		var valid_variant: String = ""
		if animation and animation.sprite_frames:
			for variant_name in data.variants:
				var test_animation_name: String = variant_name + "_walk_south_west"
				if animation.sprite_frames.has_animation(test_animation_name):
					has_valid_variant = true
					valid_variant = variant_name
					break
		if has_valid_variant and not animation.sprite_frames.has_animation(random_variant + "_walk_south_west"):
			_variant = valid_variant
		else:
			_variant = random_variant

		_health = max_health
		_update_health_bar()


func play_animation(action: String, direction: String, flip_h: bool = false):
	var animation_name = _variant + "_" + action + "_" + direction
	if animation and animation.sprite_frames and animation.sprite_frames.has_animation(animation_name):
		animation.play(animation_name)
		animation.flip_h = flip_h


# This new function is the single point of entry for killing an enemy.
func die() -> void:
	# 1. Guard against this function running more than once.
	if is_dying:
		return

	# 2. Set the state and disable further processing and collision.
	is_dying = true
	set_process(false)
	hitbox.set_deferred("disabled", true)

	# 3. Play the animation and wait for it to finish.
	var animation_name: String = _variant + "_die_" + last_direction
	if animation and animation.sprite_frames and animation.sprite_frames.has_animation(animation_name):
		animation.play(animation_name)
		animation.flip_h = last_flip_h
		await animation.animation_finished
	
	# 4. Once the animation is done (or if there was none), remove the enemy.
	queue_free()



func reset():
	_health = max_health
	_update_health_bar()
	is_dying = false
	_has_reached_end = false


## Call this when the enemy is moved to a new path.
func prepare_for_new_path():
	_has_reached_end = false


func take_damage(amount: int):
	if is_dying:
		return

	_health -= amount
	_update_health_bar()
	
	if _health <= 0 and not is_dying:
		is_dying = true
		emit_signal("death")


func _update_health_bar():
	if health_bar:
		health_bar.value = float(_health) / float(max_health) * 100.0
		health_bar.visible = _health < max_health


func _process(delta):
	if path_follow and path_follow.get_parent() and path_follow.get_parent() is Path2D:
		path_follow.progress += speed * delta
		global_position = path_follow.global_position

		var path: Path2D = path_follow.get_parent() as Path2D
		var current_pos: Vector2 = path.curve.sample_baked(path_follow.progress)
		var next_progress = min(path_follow.progress + 1.0, path.curve.get_baked_length())
		var future_pos: Vector2 = path.curve.sample_baked(next_progress)
		var direction: Vector2 = (future_pos - current_pos).normalized()

		var anim_dir: String = "north_west" if direction.y < 0 else "south_west"
		var flip_h: bool = direction.x > 0

		# Only update last_direction if not at the very end
		if path_follow.progress < path.curve.get_baked_length() - 0.1:
			last_direction = anim_dir
			last_flip_h = flip_h

		play_animation("walk", anim_dir, flip_h)

		# Only emit the signal if the end is reached AND we haven't already signalled it.
		if not _has_reached_end and path_follow.progress >= path.curve.get_baked_length():
			_has_reached_end = true # Mark that we have now signalled.
			emit_signal("reached_end_of_path")
