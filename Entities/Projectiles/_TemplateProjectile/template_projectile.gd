extends Area2D
class_name TemplateProjectile

var speed: float
var damage: int = 0
var _target: TemplateEnemy
var _last_known_position: Vector2
var _aoe_projectile: bool = false
var _status_effects: Array[StatusEffectData] = []
var _is_returning: bool = false

## Node References
@onready var hitbox: CollisionShape2D = $HitboxShape


func _physics_process(delta: float) -> void:
	# Guard clause: Do not run physics if the projectile has not been initialized.
	if speed <= 0:
		return

	var target_position := _last_known_position
	
	# If the target is still valid and moving, update its last known position.
	if is_instance_valid(_target) and _target.state == TemplateEnemy.State.MOVING:
		var target_point_node = _target.find_child("TargetPoint")
		if is_instance_valid(target_point_node):
			target_position = target_point_node.global_position
		else:
			target_position = _target.global_position
		_last_known_position = target_position
	
	# Always move towards the last known position.
	global_position = global_position.move_toward(target_position, speed * delta)

	# If we've reached the destination, return to the pool.
	if global_position.is_equal_approx(_last_known_position):
		_return_to_pool()


## Called by the tower that fires the projectile.
func initialize(target_enemy: TemplateEnemy, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool, status_effects: Array[StatusEffectData] = []) -> void:
	_target = target_enemy
	# Call the helper function to set up common properties.
	_initialize_common(damage_amount, projectile_speed, use_aoe_behavior, status_effects)
	
	# Set the initial destination from the target enemy.
	var target_point_node = _target.find_child("TargetPoint")
	if is_instance_valid(target_point_node):
		_last_known_position = target_point_node.global_position
	else:
		_last_known_position = _target.global_position
	
	# Connect the signal for direct hits.
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


## Called by the tower for a "dud" shot when the target is already dead.
func initialize_dud_shot(destination: Vector2, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool, status_effects: Array[StatusEffectData] = []) -> void:
	_target = null
	# Call the helper function to set up common properties.
	_initialize_common(damage_amount, projectile_speed, use_aoe_behavior, status_effects)
	# Set the destination directly.
	_last_known_position = destination


## Private: Handles setup tasks common to both initialize functions.
func _initialize_common(damage_amount: int, projectile_speed: float, use_aoe_behavior: bool, status_effects: Array[StatusEffectData] = []) -> void:
	damage = damage_amount
	speed = projectile_speed
	_aoe_projectile = use_aoe_behavior
	# We must duplicate the array to prevent modifying the tower's original array
	# when this projectile is reset in the object pool.
	if status_effects:
		_status_effects = status_effects.duplicate()
	else:
		_status_effects = []
	_is_returning = false
	
	set_physics_process(true)
	hitbox.disabled = false


## Prepares the projectile for reuse in the object pool.
func reset() -> void:
	if area_entered.is_connected(_on_area_entered):
		area_entered.disconnect(_on_area_entered)
	
	_target = null
	damage = 0
	_last_known_position = Vector2.ZERO
	_aoe_projectile = false
	_status_effects.clear()
	_is_returning = false
	# Disable physics until the projectile is initialized again.
	set_physics_process(false)
	hitbox.disabled = true


## Called when the projectile collides with another area. Only used for homing projectiles.
func _on_area_entered(area: Area2D) -> void:
	if _aoe_projectile or _is_returning:
		return

	var enemy := area.get_parent() as TemplateEnemy
	if enemy == _target:
		# Do not apply effects or damage to enemies that are not in the MOVING state.
		# This prevents hitting enemies that are already dying or have reached the goal.
		if enemy.state != TemplateEnemy.State.MOVING:
			return

		hitbox.set_deferred("disabled", true)
		enemy.health -= damage

		# If the damage just dealt killed the enemy, its state will now be DYING.
		# We must not apply status effects to a dying enemy, as this can interrupt
		# and pause their death animation.
		if enemy.state == TemplateEnemy.State.DYING:
			return

		for effect in _status_effects:
			enemy.apply_status_effect(effect)
		_return_to_pool()


## Private: Finds all enemies in the blast radius and deals damage.
func _detonate_aoe() -> void:
	var overlapping_areas: Array[Area2D] = get_overlapping_areas()
	
	for area in overlapping_areas:
		var enemy := area.get_parent() as TemplateEnemy
		if is_instance_valid(enemy):
			enemy.health -= damage

func _return_to_pool() -> void:
	if _is_returning:
		return

	_is_returning = true
	set_physics_process(false)
	ObjectPoolManager.call_deferred("return_object", self)
