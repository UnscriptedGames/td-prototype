## Data resource for a single enemy wave

class_name WaveData
extends Resource

## Wave spawn data
@export var spawns: Array[SpawnInstruction] = []
@export var start_delay: float = 0.0
@export var reward_multiplier: float = 1.0
@export var is_boss_wave: bool = false
