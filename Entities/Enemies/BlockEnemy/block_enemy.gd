extends TemplateEnemy
class_name BlockEnemy

## A dead-simple test enemy: a solid coloured square.
##
## Skips variant/animation validation entirely. Uses a runtime-generated
## PlaceholderTexture2D as its sprite and frees immediately on death
## (no death animation).


func _ready() -> void:
	if not data:
		push_error("EnemyData is not assigned!")
		return

	# Configure stats from data.
	max_health = data.max_health
	speed = data.speed
	reward = data.reward

	# Map effect types to their progress bars.
	_effect_bars = {
		StatusEffectData.EffectType.DOT: dot_bar,
		StatusEffectData.EffectType.SLOW: slow_bar,
		StatusEffectData.EffectType.STUN: stun_bar,
	}

	# Hide all bars on spawn.
	progress_bar_container.visible = false
	health_bar.visible = false
	for bar: ProgressBar in _effect_bars.values():
		if is_instance_valid(bar):
			bar.visible = false

	# Generate a solid-colour placeholder sprite at runtime.
	var placeholder: PlaceholderTexture2D = PlaceholderTexture2D.new()
	placeholder.size = Vector2(32, 32)
	sprite.texture = placeholder
	sprite.self_modulate = Color(0.9, 0.15, 0.15) # Red block

	# Hide the AnimatedSprite2D — we never use it.
	animation.visible = false

	reset()


## Override: skip variant animation entirely. Just flip based on direction.
func _play_animation(_action: String, _direction: String, flip_h: bool = false) -> void:
	if sprite:
		sprite.flip_h = flip_h


## Override: skip death animation, just clean up immediately.
func _play_death_sequence(_action_name: String) -> void:
	set_process(false)
	hitbox.set_deferred("disabled", true)
	if progress_bar_container:
		progress_bar_container.visible = false
	if sprite:
		sprite.visible = false
	if shadow_panel:
		shadow_panel.visible = false
	_return_to_pool_and_cleanup()
