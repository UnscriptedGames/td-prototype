extends Area2D
class_name TemplateProjectile

var damage: int = 0
var _target: TemplateEnemy
var _last_known_position: Vector2
var _is_aoe: bool = false
var _start_position: Vector2
var _progress: float = 0.0

## Node References
@onready var hitbox: CollisionShape2D = $HitboxShape


func _physics_process(_delta: float) -> void:
	# If this is a HOMING projectile and its target is still alive, update the destination.
	if not _is_aoe and is_instance_valid(_target) and _target.state == TemplateEnemy.State.MOVING:
		var target_point_node = _target.find_child("TargetPoint")
		if is_instance_valid(target_point_node):
			_last_known_position = target_point_node.global_position
		else:
			_last_known_position = _target.global_position
	
	# The tween handles the progress, we just calculate the position
	var linear_position: Vector2 = _start_position.lerp(_last_known_position, _progress)
	global_position = linear_position


## Called by the tower that fires the projectile.
func initialize(target_enemy: TemplateEnemy, damage_amount: int, use_aoe_behavior: bool, flight_duration: float) -> void:
	_target = target_enemy
	damage = damage_amount
	_is_aoe = use_aoe_behavior
	_start_position = global_position
	
	var target_point_node = _target.find_child("TargetPoint")
	if is_instance_valid(target_point_node):
		_last_known_position = target_point_node.global_position
	else:
		_last_known_position = _target.global_position
	
	_start_tween(flight_duration)
	
	hitbox.disabled = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


## Called by the tower for a "dud" shot.
func initialize_dud_shot(destination: Vector2, damage_amount: int, use_aoe_behavior: bool, flight_duration: float) -> void:
	_target = null
	damage = damage_amount
	_is_aoe = use_aoe_behavior
	_start_position = global_position
	_last_known_position = destination
	
	_start_tween(flight_duration)
	hitbox.disabled = false


## Prepares the projectile for reuse in the object pool.
func reset() -> void:
	if area_entered.is_connected(_on_area_entered):
		area_entered.disconnect(_on_area_entered)
	_target = null
	damage = 0
	_last_known_position = Vector2.ZERO
	_is_aoe = false
	_progress = 0.0
	hitbox.disabled = true


## Called when the projectile collides with another area.
func _on_area_entered(area: Area2D) -> void:
	if _is_aoe:
		return

	var enemy := area.get_parent() as TemplateEnemy
	if enemy == _target:
		hitbox.set_deferred("disabled", true)
		enemy.health -= damage
		# The tween callback will now handle returning the object to the pool
		# ObjectPoolManager.call_deferred("return_object", self)


## Creates and starts the movement tween.
func _start_tween(duration: float) -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "_progress", 1.0, duration)
	tween.tween_callback(
		func():
			if _is_aoe:
				_detonate_aoe()
			ObjectPoolManager.return_object(self)
	)


## Private: Finds all enemies in the blast radius and deals damage.
func _detonate_aoe() -> void:
	var overlapping_areas: Array[Area2D] = get_overlapping_areas()
	for area in overlapping_areas:
		var enemy := area.get_parent() as TemplateEnemy
		if is_instance_valid(enemy):
			enemy.health -= damage
