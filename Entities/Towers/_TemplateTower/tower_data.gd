extends Resource
class_name TowerData

## Tower Properties
@export var tower_name: String = "Tower"
@export var ghost_texture: Texture2D
@export var visual_offset: Vector2 = Vector2.ZERO

## Level-Based Stats
## Level-Based Stats
@export var levels: Array[TowerLevelData] = []

## Loadout Properties
@export var allocation_cost: int = 10
@export var is_unlocked: bool = true
