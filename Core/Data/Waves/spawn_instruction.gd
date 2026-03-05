## Spawn Instruction Resource
class_name SpawnInstruction
extends Resource

@export_group("Spawn Settings")
## Scene to spawn for this instruction.
@export var enemy_scene: PackedScene

## Number of enemies to spawn.
@export var count: int = 1

## Delay between each enemy spawn.
@export var enemy_delay: float = 1.0

## Delay before this group starts spawning.
@export var start_delay: float = 0.0

@export_group("Pathing")
## Tag identifying which Marker2D spawn point to use in the layout scene.
## Matches the name of a Marker2D node (e.g. "Spawn_0", "Spawn_1").
## Use "Random" or leave empty to pick a random available spawn point.
@export var spawn_location_tag: String = "Random"
