extends Node2D
class_name TemplateTower

## The base script for all towers.

@export var data: TowerData

## Node References
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var range_shape: CollisionPolygon2D = $Range/RangeShape