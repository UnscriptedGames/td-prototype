extends Resource
class_name PlayerData

## Player Stats
@export var health: int = 20	# Player's starting health
@export var currency: int = 100	# Player's starting currency

func can_afford(cost: int) -> bool:
	return currency >= cost
