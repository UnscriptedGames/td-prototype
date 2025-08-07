extends Area2D
class_name TemplateProjectile

var speed: float
var damage: int = 0
var _target: TemplateEnemy
var _last_known_position: Vector2
var _is_aoe: bool = false

## Node References
@onready var hitbox: CollisionShape2D = $HitboxShape


func _physics_process(delta: float) -> void:
	# If the target is no longer valid or is already dying, return to the pool.
	if not is_instance_valid(_target) or _target.state != TemplateEnemy.State.MOVING:
		ObjectPoolManager.return_object(self)
		return
	
	# Get the target point's global position, or default to the enemy's origin.
	var target_position := _target.global_position
	var target_point_node = _target.find_child("TargetPoint")
	if is_instance_valid(target_point_node):
		target_position = target_point_node.global_position
	
	# Move towards the target's position.
	global_position = global_position.move_toward(target_position, speed * delta)

	# If we've reached the destination, return to the pool.
	if global_position.is_equal_approx(_last_known_position):
		ObjectPoolManager.return_object(self)


## Called by the tower that fires the projectile.
func initialize(target_enemy: TemplateEnemy, damage_amount: int, projectile_speed: float, use_aoe_behavior: bool) -> void:
	_target = target_enemy
	damage = damage_amount
	speed = projectile_speed
	_is_aoe = use_aoe_behavior
	
	# Set the initial destination
	var target_point_node = _target.find_child("TargetPoint")
	if is_instance_valid(target_point_node):
		_last_known_position = target_point_node.global_position
	else:
		_last_known_position = _target.global_position
	
	hitbox.disabled = false
	area_entered.connect(_on_area_entered)


## Prepares the projectile for reuse in the object pool.
func reset() -> void:
	if area_entered.is_connected(_on_area_entered):
		area_entered.disconnect(_on_area_entered)
	
	_target = null
	damage = 0
	_last_known_position = Vector2.ZERO
	_is_aoe = false
	hitbox.disabled = true


## Called when the projectile collides with another area. Only used for homing projectiles.
func _on_area_entered(area: Area2D) -> void:
	# AOE projectiles do not deal damage on direct impact.
	if _is_aoe:
		return

	var enemy := area.get_parent() as TemplateEnemy
	if enemy == _target:
		hitbox.set_deferred("disabled", true)
		enemy.health -= damage
		ObjectPoolManager.call_deferred("return_object", self)


## Private: Finds all enemies in the blast radius and deals damage.
func _detonate_aoe() -> void:
	# Get a list of all Hurtbox areas currently overlapping our root Area2D
	var overlapping_areas: Array[Area2D] = get_overlapping_areas()
	
	for area in overlapping_areas:
		# The area is the Hurtbox, its parent is the enemy
		var enemy := area.get_parent() as TemplateEnemy
		if is_instance_valid(enemy):
			enemy.health -= damage
			
	# This is where you would also trigger an explosion animation or sound effect


## Called by the tower for a shot when the target is already dead.
func initialize_dud_shot(destination: Vector2, projectile_speed: float, damage_amount: int, use_aoe_behavior: bool) -> void:
	_target = null
	damage = damage_amount
	speed = projectile_speed
	_is_aoe = use_aoe_behavior
	
	_last_known_position = destination
	
	hitbox.disabled = false
	# We don't connect area_entered as there is no specific target to check against
