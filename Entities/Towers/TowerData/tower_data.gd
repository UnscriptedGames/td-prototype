extends Resource
class_name TowerData

## Tower Properties
@export var tower_name: String = "Tower"
@export var cost: int = 10
@export var tower_range: int = 1
@export var damage: int = 10
@export var fire_rate: float = 1.0 # Attacks per second

## Scene & Asset References
@export var ghost_texture: Texture2D
@export var placed_tower_scene: PackedScene