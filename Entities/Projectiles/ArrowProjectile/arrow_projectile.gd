extends TemplateProjectile

func _physics_process(delta: float) -> void:
	# The parent script reliably tracks the destination in _last_known_position.
	# We just need to look at it, even if the original target is gone.
	look_at(_last_known_position)
	
	# Call the parent script's physics process to handle the actual movement.
	super._physics_process(delta)
