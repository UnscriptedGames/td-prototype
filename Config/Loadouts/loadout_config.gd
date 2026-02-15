class_name LoadoutConfig
extends Resource

## The list of relic cards available for this loadout.
@export var relics: Array[RelicData] = []

## The stock of towers available for this loadout.
@export var towers: Dictionary[TowerData, int] = {}

## The list of spells or buff cards available for this loadout.
@export var buffs: Array[BuffData] = []

## Helper to calculate total allocation cost of this loadout
func get_total_allocation_cost() -> int:
	var total_cost: int = 0
	
	# Calculate Relic Costs
	for card_data in relics:
		total_cost += card_data.allocation_cost
	
	# Calculate Tower Costs
	for tower_data in towers:
		if tower_data is TowerData:
			var quantity = towers[tower_data]
			total_cost += tower_data.allocation_cost * quantity
			
	# Calculate Buff Costs
	for card_data in buffs:
		total_cost += card_data.allocation_cost
	
	return total_cost

## Validates if the loadout fits within a max allocation limit
func is_valid(max_allocation: int) -> bool:
	return get_total_allocation_cost() <= max_allocation
