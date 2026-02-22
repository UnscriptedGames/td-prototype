class_name WeightedTarget
extends Resource

## The exact end tile for AStar calculation
@export var goal_tile: Vector2i

## The relative probability of this target being chosen
@export var weight: float = 1.0
