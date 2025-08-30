extends Resource
class_name TowerData

## Tower Properties
@export var tower_name: String = "Tower"
@export var ghost_texture: Texture2D
@export var visual_offset: Vector2 = Vector2.ZERO
@export var placed_tower_scene: PackedScene

## Level-Based Stats
@export var levels: Array[TowerLevelData] = []
