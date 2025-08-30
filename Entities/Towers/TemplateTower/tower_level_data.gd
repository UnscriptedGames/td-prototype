extends Resource
class_name TowerLevelData

## Stats for a single tower level.

@export var cost: int = 100
@export var tower_range: int = 150
@export var damage: int = 10
@export var fire_rate: float = 1.0
@export var projectile_speed: float = 800.0
@export var is_aoe: bool = false
@export var projectile_scene: PackedScene
@export var shoot_animation: String = ""
@export var idle_animation: String = ""
