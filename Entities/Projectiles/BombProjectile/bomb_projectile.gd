extends TemplateProjectile

@export var arc_height: float = 100.0

## Overrides the base physics process to add a vertical arc.
func _physics_process(_delta: float) -> void:
	# Run the original linear movement logic from the parent script first.
	super._physics_process(_delta)
	
	# Then, add our arc offset on top of the position calculated by the parent.
	var arc_offset: Vector2 = Vector2.UP * sin(_progress * PI) * arc_height
	global_position += arc_offset