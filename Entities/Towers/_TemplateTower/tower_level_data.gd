extends Resource
class_name TowerLevelData

## Stats for a single tower level.

@export var cost: int = 10
@export var tower_range: int = 1
@export var damage: int = 1
@export var fire_rate: float = 1.0
@export var projectile_speed: float = 500.0
@export var is_aoe: bool = false
@export var targets: int = 1
@export var projectile_scene: PackedScene
@export var shoot_animation: String = "level_01_shoot"
@export var idle_animation: String = "level_01_idle"
