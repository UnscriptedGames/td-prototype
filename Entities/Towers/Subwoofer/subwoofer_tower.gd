extends TemplateTower
class_name SubwooferTower

func _spawn_projectiles() -> void:
	if not is_instance_valid(data):
		return
		
	# Apply Status effects to all enemies currently in range
	for target in _current_targets:
		if is_instance_valid(target) and target.state == TemplateEnemy.State.MOVING:
			for effect in status_effects:
				target.apply_status_effect(effect)

	_is_firing = false
