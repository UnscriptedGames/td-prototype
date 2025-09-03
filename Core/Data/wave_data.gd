## Wave Data Resource
class_name WaveData
extends Resource

## Wave Properties
@export var start_delay: float = 0.0	# Delay before wave starts
@export var reward_multiplier: float = 1.0	# Multiplies rewards for this wave
@export var is_boss_wave: bool = false	# True if this is a boss wave
@export var spawns: Array[SpawnInstruction] = []	# List of enemy spawn instructions
