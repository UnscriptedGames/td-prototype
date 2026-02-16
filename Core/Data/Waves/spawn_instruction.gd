## Spawn Instruction Resource
class_name SpawnInstruction
extends Resource

## Spawn Properties
@export var enemy_scene: PackedScene	# Scene to spawn for this instruction
@export var path: NodePath	# Path node where enemies will spawn
@export var count: int = 1	# Number of enemies to spawn
@export var enemy_delay: float = 1.0	# Delay between each enemy spawn
@export var start_delay: float = 0.0	# Delay before this group starts spawning
