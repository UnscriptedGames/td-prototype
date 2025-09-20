extends TemplateProjectile

## The vertical height of the bomb's arc.
@export var arc_height: float = 100.0

## Internal State
var _start_position: Vector2
var _progress: float = 0.0


## Overrides the base initialize function to start the arc tween.
func initialize(target_enemy: TemplateEnemy, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool, status_effects: Array[StatusEffectData] = []) -> void:
	super.initialize(target_enemy, damage_amount, projectile_speed, use_aoe_behavior, status_effects)
	_start_arc_tween()


## Overrides the base initialize_dud_shot function to start the arc tween.
func initialize_dud_shot(destination: Vector2, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool, status_effects: Array[StatusEffectData] = []) -> void:
	super.initialize_dud_shot(destination, damage_amount, projectile_speed, use_aoe_behavior, status_effects)
	_start_arc_tween()


## Overrides the base physics process to calculate an arc instead of a straight line.
func _physics_process(_delta: float) -> void:
	# For homing (non-AOE) projectiles, continuously update the destination.
	if not _aoe_projectile and is_instance_valid(_target) and _target.state == TemplateEnemy.State.MOVING:
		var target_point_node = _target.find_child("TargetPoint")
		if is_instance_valid(target_point_node):
			_last_known_position = target_point_node.global_position
		else:
			_last_known_position = _target.global_position
	
	# Calculate the arcing position towards the (fixed or updating) destination.
	var linear_position: Vector2 = _start_position.lerp(_last_known_position, _progress)
	var arc_offset: Vector2 = Vector2.UP * sin(_progress * PI) * arc_height
	
	global_position = linear_position + arc_offset
	
	# Check if the tween has finished and the projectile has arrived.
	if _progress >= 1.0:
		if _aoe_projectile:
			_detonate_aoe()
		
		ObjectPoolManager.return_object(self)
		# Deactivate processing to prevent this from running again before being pooled.
		set_physics_process(false)


## Private: Sets up the tween for the arcing motion.
func _start_arc_tween() -> void:
	_start_position = global_position
	# Reset progress to 0 in case the projectile is being reused from the pool.
	_progress = 0.0
	
	var distance: float = _start_position.distance_to(_last_known_position)
	var duration: float = 0.0
	if speed > 0:
		duration = distance / speed
	
	# Create a tween to animate the _progress variable from 0.0 to 1.0.
	var tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "_progress", 1.0, duration)
