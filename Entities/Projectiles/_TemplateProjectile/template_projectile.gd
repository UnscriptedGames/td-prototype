extends Area2D
class_name TemplateProjectile

## Base class for all projectiles in the game.
## Handles movement to target, collision detection, and applying damage/effects.

## Public Properties
var speed: float
var damage: int = 0

## Internal State
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

	var target_position: Vector2 = _last_known_position
	
	# If the target is still valid and moving, update its last known position.
	if is_instance_valid(_target) and _target.state == TemplateEnemy.State.MOVING:
		# Optimization: Use the cached target_point node directly.
		if is_instance_valid(_target.target_point):
			target_position = _target.target_point.global_position
		else:
			target_position = _target.global_position
		_last_known_position = target_position
	
	# Always move towards the last known position.
	global_position = global_position.move_toward(target_position, speed * delta)

	# If we've reached the destination...
	if global_position.is_equal_approx(_last_known_position):
		if _aoe_projectile:
			# If it's an AOE projectile, we trigger the explosion here.
			_detonate_aoe()
			_return_to_pool()
		else:
			# Standard projectiles just disappear if they reach the point without hitting anything 
			# (e.g. target died or moved too fast, though homing usually handles moving).
			# For homing projectiles, area_entered handles the hit.
			# If we reach here, we missed or target is gone.
			_return_to_pool()


## Called by the tower that fires the projectile.
func initialize(target_enemy: TemplateEnemy, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool, status_effects: Array[StatusEffectData] = []) -> void:
	_target = target_enemy
	
	# Set simple properties
	damage = damage_amount
	speed = projectile_speed
	_aoe_projectile = use_aoe_behavior
	_status_effects.assign(status_effects if status_effects else [])
	_is_returning = false
	
	# Set the initial destination from the target enemy using the optimized lookup.
	if is_instance_valid(_target.target_point):
		_last_known_position = _target.target_point.global_position
	else:
		_last_known_position = _target.global_position
	
	# Activation
	set_physics_process(true)
	hitbox.disabled = false
	
	# Connect the signal for direct hits.
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


## Called by the tower for a "dud" shot when the target is already dead.
func initialize_dud_shot(destination: Vector2, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool, status_effects: Array[StatusEffectData] = []) -> void:
	_target = null
	
	# Set simple properties
	damage = damage_amount
	speed = projectile_speed
	_aoe_projectile = use_aoe_behavior
	_status_effects.assign(status_effects if status_effects else [])
	_is_returning = false
	
	# Set the destination directly.
	_last_known_position = destination
	
	# Activation
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


## Called when the projectile collides with another area. Only used for single-target impacts.
## AOE projectiles ignore this lookup and detonate on arrival.
func _on_area_entered(area: Area2D) -> void:
	if _aoe_projectile or _is_returning:
		return

	var enemy := area.get_parent() as TemplateEnemy
	
	# Only hit the specific target we were aiming for
	if enemy == _target:
		_apply_damage_and_effects(enemy)
		_return_to_pool()


## Private: Finds all enemies in the blast radius and deals damage.
func _detonate_aoe() -> void:
	var overlapping_areas: Array[Area2D] = get_overlapping_areas()
	
	for area in overlapping_areas:
		var enemy := area.get_parent() as TemplateEnemy
		if is_instance_valid(enemy):
			_apply_damage_and_effects(enemy)


## Helper logic to apply damage and effects to a single enemy.
func _apply_damage_and_effects(enemy: TemplateEnemy) -> void:
	# Do not apply effects or damage to enemies that are not in the MOVING state.
	if enemy.state != TemplateEnemy.State.MOVING:
		return

	# Only single-target projectiles disable their hitbox on impact here.
	# AOE projectiles keep it open to find all overlaps, then deactivate when returning to pool.
	if not _aoe_projectile:
		hitbox.set_deferred("disabled", true)
	
	enemy.health -= damage

	# If dead, don't apply status effects.
	if enemy.state == TemplateEnemy.State.DYING:
		return

	for effect in _status_effects:
		enemy.apply_status_effect(effect)


func _return_to_pool() -> void:
	if _is_returning:
		return

	_is_returning = true
	set_physics_process(false)
	ObjectPoolManager.call_deferred("return_object", self)
