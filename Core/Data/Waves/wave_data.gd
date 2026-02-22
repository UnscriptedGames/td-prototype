## Wave Data Resource
class_name WaveData
extends Resource

@export_group("Wave Settings")
## Delay before wave starts.
@export var start_delay: float = 0.0

## Multiplies rewards for this wave.
@export var reward_multiplier: float = 1.0

## The percentage of the wave's total enemy health required to fill the peak meter.
## e.g., 0.20 means 20% of the wave leaking causes failure.
@export var clip_tolerance: float = 0.20

## True if this is a boss wave.
@export var is_boss_wave: bool = false

## List of enemy spawn instructions.
@export var spawns: Array[SpawnInstruction] = []
