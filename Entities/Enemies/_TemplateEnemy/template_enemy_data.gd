## Enemy Data Resource
class_name EnemyData
extends Resource

## Enemy Properties
@export var max_health: int = 10 # Maximum health for this enemy
@export var speed: float = 60.0 # Movement speed
@export var reward: int = 1 # Reward for defeating this enemy

@export_group("Movement Variance")
## Max sway amplitude from the path center (pixels)
@export var wobble_amplitude: float = 8.0
## Speed of the swaying motion
@export var wobble_frequency: float = 3.0

@export_group("Visuals")
# Wave Visuals
@export var wave_texture: Texture2D # 48x240 scrolling strip
@export var scroll_speed: float = 1.0 # Shader scroll speed
