class_name RelicEffect
extends GameplayEffect

## @description Specialized effect for Relics (Global modifiers or Active abilities).

## Executes the relic effect.
## @param context: Should contain "player_data" and/or "game_manager".
func execute(context: Dictionary) -> void:
	# Base implementation just passes through, specific relics will cast context
	_apply_relic(context)

## Virtual override to implement specific relic logic.
func _apply_relic(_context: Dictionary) -> void:
	pass
