## Spawn Instruction Resource
class_name SpawnInstruction
extends Resource

@export_group("Spawn Settings")
## Scene to spawn for this instruction.
@export var enemy_scene: PackedScene

## Path node where enemies will spawn.
@export var path: NodePath

## Number of enemies to spawn.
@export var count: int = 1

## Delay between each enemy spawn.
@export var enemy_delay: float = 1.0

## Delay before this group starts spawning.
@export var start_delay: float = 0.0
