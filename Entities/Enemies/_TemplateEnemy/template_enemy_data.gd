## Enemy Data Resource
class_name EnemyData
extends Resource

## Enemy Properties
@export var max_health: int = 10 # Maximum health for this enemy
@export var speed: float = 60.0 # Movement speed
@export var reward: int = 1 # Reward for defeating this enemy
@export var max_path_offset: float = 32.0 # Max distance from path center

# Wave Visuals
@export var wave_texture: Texture2D # 48x240 scrolling strip
@export var scroll_speed: float = 1.0 # Shader scroll speed
