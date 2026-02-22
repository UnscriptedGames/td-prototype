## Spawn Instruction Resource
class_name SpawnInstruction
extends Resource

@export_group("Spawn Settings")
## Scene to spawn for this instruction.
@export var enemy_scene: PackedScene

## Grid coordinate (Vector2i) where enemies will spawn.
@export var spawn_tile: Vector2i = Vector2i(0, 8)

## Number of enemies to spawn.
@export var count: int = 1

## Delay between each enemy spawn.
@export var enemy_delay: float = 1.0

## Delay before this group starts spawning.
@export var start_delay: float = 0.0

@export_group("Pathing")
## Array of weighted goal tiles. If empty, defaults to the closest valid goal.
@export var weighted_targets: Array[WeightedTarget] = []
