class_name BuffEffectStandard
extends BuffEffect

## @description Standard implementation of a buff effect that applies stat modifiers and status effects.

# --- EXPORT VARIABLES ---

@export_group("Stats")
## The duration of the buff in seconds.
@export var duration: float = 5.0

## The flat increase in the tower's attack range.
@export var range_increase: int = 0

## The flat increase in the tower's attack damage.
@export var damage_increase: int = 0

## The flat increase in the tower's fire rate (attacks per second).
@export var fire_rate_increase: float = 0.0

## The number of additional targets the tower can attack simultaneously.
@export var extra_targets: int = 0

@export_group("Status")
## An array of status effects to be temporarily applied to the tower's attacks.
@export var status_effects: Array[StatusEffectData] = []

## Visual override to implement specific buff logic.
func _apply_buff(tower: TemplateTower) -> void:
	if not is_instance_valid(tower):
		return
		
	# Pass self (BuffEffectStandard) to the tower's BuffManager
	if tower.has_method("apply_buff"):
		tower.apply_buff(self)
