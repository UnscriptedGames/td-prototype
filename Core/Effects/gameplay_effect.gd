class_name GameplayEffect
extends Resource

## @description Base class for all effects triggered by game items.
## Effects can be instant (one-shot) or sustained (status/buffs).

## Executes the effect.
## @param context: A Dictionary containing relevant objects for the effect.
## Expected keys depend on the specific effect implementation (e.g., "tower", "target", "player_data").
func execute(_context: Dictionary) -> void:
	pass
