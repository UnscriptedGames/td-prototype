extends Node
class_name BuffManager

## @description Manages the application, tracking, and removal of temporary
## buffs on a tower.

# A dictionary to keep track of active buffs and their associated timers.
# The key is the BuffTowerEffect resource instance, and the value is the Timer node.
var _active_buffs: Dictionary = {}

# A dictionary to store the original status effects that were replaced by a buff.
# The key is the BuffTowerEffect, and the value is the original StatusEffectData.
var _stashed_status_effects: Dictionary = {}


## Applies a buff to the parent tower.
## @param buff_effect: The BuffTowerEffect resource to apply.
func apply_buff(buff_effect: BuffTowerEffect) -> void:
	var tower: TemplateTower = get_parent()
	if not is_instance_valid(tower):
		push_error("BuffManager cannot find a valid parent tower.")
		return

	# Apply stat increases
	tower.damage += buff_effect.damage_increase
	tower.tower_range += buff_effect.range_increase
	tower.fire_rate += buff_effect.fire_rate_increase
	tower.targets += buff_effect.extra_targets

	# Handle status effects
	for new_effect in buff_effect.status_effects:
		var existing_effect_index = -1
		for i in range(tower.status_effects.size()):
			if tower.status_effects[i].effect_type == new_effect.effect_type:
				existing_effect_index = i
				break

		# If a status effect of the same type exists, stash it before replacing.
		if existing_effect_index != -1:
			# We only stash the *first* time a buff of this type is applied.
			if not _stashed_status_effects.has(new_effect.effect_type):
				_stashed_status_effects[new_effect.effect_type] = tower.status_effects[existing_effect_index]
			tower.status_effects[existing_effect_index] = new_effect
		else:
			tower.status_effects.append(new_effect)

	# The tower needs to re-evaluate its stats (like fire rate timer)
	tower._apply_level_stats()
	# The tower range display needs to be updated
	if tower.is_selected():
		tower.select()

	# Create a timer to handle the buff's expiration
	var timer := Timer.new()
	timer.wait_time = buff_effect.duration
	timer.one_shot = true
	# We pass the buff_effect resource to the timeout signal
	timer.timeout.connect(_on_buff_expired.bind(buff_effect))
	add_child(timer)
	timer.start()

	# Track the active buff and its timer
	_active_buffs[buff_effect] = timer


## Called when a buff's timer runs out.
## @param buff_effect: The BuffTowerEffect resource that has expired.
func _on_buff_expired(buff_effect: BuffTowerEffect) -> void:
	var tower: TemplateTower = get_parent()
	if not is_instance_valid(tower):
		# Tower might have been destroyed, so just clean up.
		_cleanup_buff(buff_effect)
		return

	# Revert stat increases
	tower.damage -= buff_effect.damage_increase
	tower.tower_range -= buff_effect.range_increase
	tower.fire_rate -= buff_effect.fire_rate_increase
	tower.targets -= buff_effect.extra_targets

	# Revert status effects
	for buff_status_effect in buff_effect.status_effects:
		# Check if we have a stashed (original) status effect to restore
		if _stashed_status_effects.has(buff_status_effect.effect_type):
			var original_effect = _stashed_status_effects[buff_status_effect.effect_type]
			var was_restored = false
			# Find the buff's effect and replace it with the original one
			for i in range(tower.status_effects.size()):
				if tower.status_effects[i] == buff_status_effect:
					tower.status_effects[i] = original_effect
					was_restored = true
					break
			# If for some reason it wasn't found, just ensure the stashed one is there
			if not was_restored:
				tower.status_effects.append(original_effect)

			_stashed_status_effects.erase(buff_status_effect.effect_type)
		else:
			# If there was no stashed effect, the buff added a new one, so we remove it.
			var effect_to_remove_idx = -1
			for i in range(tower.status_effects.size()):
				if tower.status_effects[i] == buff_status_effect:
					effect_to_remove_idx = i
					break
			if effect_to_remove_idx != -1:
				tower.status_effects.remove_at(effect_to_remove_idx)

	# Re-apply tower stats and update range display
	tower._apply_level_stats()
	if tower.is_selected():
		tower.select()

	_cleanup_buff(buff_effect)


## Cleans up the buff from the tracking dictionaries and frees the timer.
func _cleanup_buff(buff_effect: BuffTowerEffect) -> void:
	if _active_buffs.has(buff_effect):
		var timer = _active_buffs[buff_effect]
		if is_instance_valid(timer):
			timer.queue_free()
		_active_buffs.erase(buff_effect)
