class_name BuffEffect
extends GameplayEffect

## @description Specialized effect for buffs applied to towers.
## Buffs modify tower stats or behavior for a limited time.

## Executes the buff effect on a target tower.
## @param context: Must contain "tower" (TemplateTower).
func execute(context: Dictionary) -> void:
	var tower: TemplateTower = context.get("tower") as TemplateTower
	if not tower:
		push_error("BuffEffect executed without a valid 'tower' in context.")
		return
	
	_apply_buff(tower)

## Visual override to implement specific buff logic.
func _apply_buff(_tower: TemplateTower) -> void:
	pass
