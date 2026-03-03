extends Resource
class_name PlayerData

## Player Stats
@export var currency: int = 100  # Player's starting currency
@export var max_allocation_points: int = 50

## Loadout Data
## The list of relic cards available for this loadout (null = empty slot).
@export var relics: Array[RelicData] = []

## Ordered tower slots (always 6). Each entry is either null (empty) or a
## Dictionary of the form { "data": TowerData, "stock": int }.
@export var tower_slots: Array = []

## The list of spells or buff cards available for this loadout (null = empty slot).
@export var buffs: Array[BuffData] = []

const TOWER_SLOT_COUNT: int = 6


func _init() -> void:
	# Ensure tower_slots is always pre-sized to TOWER_SLOT_COUNT
	if tower_slots.size() < TOWER_SLOT_COUNT:
		tower_slots.resize(TOWER_SLOT_COUNT)


## Helper to calculate total allocation cost of this loadout
func get_total_allocation_cost() -> int:
	var total_cost: int = 0

	# Calculate Relic Costs
	for loadout_data in relics:
		if loadout_data is RelicData:
			total_cost += loadout_data.allocation_cost

	# Calculate Tower Costs
	for slot in tower_slots:
		if slot != null and slot.has("data") and slot["data"] is TowerData:
			var quantity: int = slot.get("stock", 1)
			total_cost += (slot["data"] as TowerData).allocation_cost * quantity

	# Calculate Buff Costs
	for loadout_data in buffs:
		if loadout_data is BuffData:
			total_cost += loadout_data.allocation_cost

	return total_cost


## Validates if the loadout fits within a max allocation limit
func is_valid(max_allocation: int) -> bool:
	return get_total_allocation_cost() <= max_allocation


func can_afford(cost: int) -> bool:
	return currency >= cost


## Returns the first empty slot index, or -1 if the rack is full.
func find_first_empty_tower_slot() -> int:
	_ensure_slots()
	for slot_index: int in range(TOWER_SLOT_COUNT):
		if tower_slots[slot_index] == null:
			return slot_index
	return -1


## Returns true if the given TowerData is already in any slot.
func is_tower_in_loadout(tower_data: TowerData) -> bool:
	_ensure_slots()
	for slot in tower_slots:
		if slot != null and slot.get("data") == tower_data:
			return true
	return false


## Returns the slot index that holds this TowerData, or -1 if not found.
func find_tower_slot(tower_data: TowerData) -> int:
	_ensure_slots()
	for slot_index: int in range(tower_slots.size()):
		var slot = tower_slots[slot_index]
		if slot != null and slot.get("data") == tower_data:
			return slot_index
	return -1


## Ensures tower_slots is always TOWER_SLOT_COUNT in length.
func _ensure_slots() -> void:
	while tower_slots.size() < TOWER_SLOT_COUNT:
		tower_slots.append(null)
