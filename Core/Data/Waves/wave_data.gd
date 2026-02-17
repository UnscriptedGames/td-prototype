## Wave Data Resource
class_name WaveData
extends Resource

@export_group("Wave Settings")
## Delay before wave starts.
@export var start_delay: float = 0.0

## Multiplies rewards for this wave.
@export var reward_multiplier: float = 1.0

## True if this is a boss wave.
@export var is_boss_wave: bool = false

## List of enemy spawn instructions.
@export var spawns: Array[SpawnInstruction] = []
