## Data resource for a single enemy spawn instruction

class_name SpawnInstruction
extends Resource

@export var enemy_scene: PackedScene
@export var path: NodePath
@export var count: int = 1
@export var enemy_delay: float = 1.0
@export var start_delay: float = 0.0
