@tool
extends TemplateEnemy
class_name BasicEnemy

## A dead-simple test enemy: a solid coloured square.
##
## Skips variant/animation validation entirely. Uses a runtime-generated
## PlaceholderTexture2D as its sprite and frees immediately on death
## (no death animation).


func _ready() -> void:
	super ()
	if Engine.is_editor_hint(): return
	
	# Hide the AnimatedSprite2D — we never use it.
	animation.visible = false

## Override: skip variant animation entirely
func _play_animation(_action: String, _direction: String) -> void:
	pass


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
