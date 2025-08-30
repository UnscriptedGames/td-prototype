extends Resource
class_name TowerData

## Tower Properties
@export var tower_name: String = "Tower"
@export var cost: int = 10
@export var tower_range: int = 1
@export var damage: int = 10
@export var fire_rate: float = 1.0 # Attacks per second
@export var projectile_speed: float = 800.0
@export var is_aoe: bool = false

## Scene & Asset References
@export var ghost_texture: Texture2D
@export var visual_offset: Vector2 = Vector2.ZERO
@export var placed_tower_scene: PackedScene
@export var projectile_scene: PackedScene
@export var shoot_animations: Array[String] = []
@export var idle_animations: Array[String] = []
