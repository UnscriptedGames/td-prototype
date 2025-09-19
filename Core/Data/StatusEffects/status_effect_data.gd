extends Resource
class_name StatusEffectData

enum EffectType {
	DOT,
	SLOW,
	STUN
}

@export var effect_type: EffectType
@export var duration: float = 0.0
@export var magnitude: float = 0.0
@export var damage_per_tick: int = 0
@export var tick_rate: float = 0.0
