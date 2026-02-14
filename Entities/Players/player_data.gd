extends Resource
class_name PlayerData

## Player Stats
@export var max_health: int = 20 # Maximum possible health
@export var health: int = 20 # Player's starting health
@export var currency: int = 100 # Player's starting currency
@export var max_allocation_points: int = 50

## DEPRECATED: Use LoadoutConfig in GameManager instead
@export var deck: DeckData
@export var hand_size: int = 5

func can_afford(cost: int) -> bool:
	return currency >= cost
