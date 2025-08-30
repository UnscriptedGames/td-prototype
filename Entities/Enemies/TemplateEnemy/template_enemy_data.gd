## Enemy Data Resource
class_name EnemyData
extends Resource

## Enemy Properties
@export var max_health: int = 10	# Maximum health for this enemy
@export var speed: float = 60.0	# Movement speed
@export var reward: int = 1	# Reward for defeating this enemy
@export var damage: int = 1	# Damage dealt to player
@export var variants: Array[String] = []	# List of variant names (e.g., colours)
@export var required_actions: Array[String] = []	# Required animation actions
@export var animations: SpriteFrames	# Animation frames for this enemy
