extends TemplateProjectile

@export var arc_height: float = 100.0

var _start_position: Vector2
var _progress: float = 0.0


## Overrides the base initialize function to start the tween.
func initialize(target_enemy: TemplateEnemy, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool) -> void:
	# Run the original initialize function from the parent script, passing all arguments
	super.initialize(target_enemy, damage_amount, projectile_speed, use_aoe_behavior)
	
	# Store our starting position
	_start_position = global_position
	
	# Calculate flight duration and create a tween to animate our _progress
	var distance: float = _start_position.distance_to(_target.global_position)
	var duration: float = distance / speed
	if speed <= 0: # Prevent division by zero if speed is not set
		duration = 0
	
	var tween: Tween = create_tween()
	
	# Animate the _progress variable from 0.0 to 1.0 over the flight duration
	tween.tween_property(self, "_progress", 1.0, duration).set_trans(Tween.TRANS_LINEAR)

## Called by the tower for a "dud" shot when the target is already dead.
func initialize_dud_shot(destination: Vector2, projectile_speed: float, damage_amount: int, use_aoe_behavior: bool) -> void:
	# Run the original initialize_dud_shot function from the parent script
	super.initialize_dud_shot(destination, projectile_speed, damage_amount, use_aoe_behavior)
	
	# Store our starting position
	_start_position = global_position
	
	# Calculate flight duration and create a tween to animate our _progress
	var distance: float = _start_position.distance_to(_last_known_position)
	var duration: float = 0
	if speed > 0:
		duration = distance / speed
	
	var tween: Tween = create_tween()
	
	# Animate the _progress variable from 0.0 to 1.0 over the flight duration
	tween.tween_property(self, "_progress", 1.0, duration).set_trans(Tween.TRANS_LINEAR)



## Overrides the base physics process to calculate an arc instead of a straight line.
func _physics_process(_delta: float) -> void:
	# If the target is no longer valid, return to the pool.
	if not is_instance_valid(_target) and not _is_aoe: # For dud shots, _target is null, so skip this check
		ObjectPoolManager.return_object(self)
		return
	
	# For homing (non-AOE) projectiles, continuously update the destination.
	if not _is_aoe and is_instance_valid(_target) and _target.state == TemplateEnemy.State.MOVING:
		var target_point_node = _target.find_child("TargetPoint")
		if is_instance_valid(target_point_node):
			_last_known_position = target_point_node.global_position
		else:
			_last_known_position = _target.global_position
	
	# Calculate the arcing position towards the (fixed or updating) destination
	var linear_position: Vector2 = _start_position.lerp(_last_known_position, _progress)
	var arc_offset: Vector2 = Vector2.UP * sin(_progress * PI) * arc_height
	
	global_position = linear_position + arc_offset
	
	# Check if the tween has finished and the projectile has arrived.
	if _progress >= 1.0:
		if OS.is_debug_build():
			print("Bomb Projectile: Arrived at destination.")
		if _is_aoe:
			_detonate_aoe()
		ObjectPoolManager.return_object(self)
		# Deactivate processing to prevent this from running again before being pooled
		set_physics_process(false)
