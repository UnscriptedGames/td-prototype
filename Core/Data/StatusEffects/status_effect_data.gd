extends Resource
class_name StatusEffectData

enum EffectType {
	DOT,
	SLOW,
	STUN
}

@export_group("Status Settings")
@export var effect_type: EffectType

## The duration of the effect in seconds.
@export var duration: float = 0.0

## The strength of the effect (e.g., slow percentage).
@export var magnitude: float = 0.0

## The damage applied per tick (for DOT effects).
@export var damage_per_tick: int = 0

## How often the effect applies damage in seconds (e.g., 0.5 for twice a second).
@export var tick_rate: float = 0.0
