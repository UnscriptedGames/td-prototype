extends "res://addons/gut/test.gd"

## Unit tests for PlayerData logic.
## Focuses on allocation cost calculations and manual cache invalidation.

func test_get_total_allocation_cost_empty() -> void:
	var player_data: PlayerData = PlayerData.new()
	assert_eq(player_data.get_total_allocation_cost(), 0, "Empty player data should have 0 allocation cost.")


func test_get_total_allocation_cost_with_relics() -> void:
	var player_data: PlayerData = PlayerData.new()

	var relic1: RelicData = RelicData.new()
	relic1.allocation_cost = 5

	var relic2: RelicData = RelicData.new()
	relic2.allocation_cost = 10

	player_data.relics.append(relic1)
	player_data.relics.append(relic2)

	assert_eq(player_data.get_total_allocation_cost(), 15, "Total cost should include all relics.")


func test_get_total_allocation_cost_with_buffs() -> void:
	var player_data: PlayerData = PlayerData.new()

	var buff1: BuffData = BuffData.new()
	buff1.allocation_cost = 3

	var buff2: BuffData = BuffData.new()
	buff2.allocation_cost = 7

	player_data.buffs.append(buff1)
	player_data.buffs.append(buff2)

	assert_eq(player_data.get_total_allocation_cost(), 10, "Total cost should include all buffs.")


func test_get_total_allocation_cost_with_towers() -> void:
	var player_data: PlayerData = PlayerData.new()

	var tower1: TowerData = TowerData.new()
	tower1.allocation_cost = 8

	var tower2: TowerData = TowerData.new()
	tower2.allocation_cost = 12

	# Mock tower slots structure: { "data": TowerData, "stock": int }
	player_data.tower_slots[0] = {"data": tower1, "stock": 2} # 8 * 2 = 16
	player_data.tower_slots[1] = {"data": tower2, "stock": 1} # 12 * 1 = 12

	assert_eq(player_data.get_total_allocation_cost(), 28, "Total cost should include all towers with stock.")


func test_get_total_allocation_cost_mixed() -> void:
	var player_data: PlayerData = PlayerData.new()

	var relic: RelicData = RelicData.new()
	relic.allocation_cost = 5
	player_data.relics.append(relic)

	var buff: BuffData = BuffData.new()
	buff.allocation_cost = 3
	player_data.buffs.append(buff)

	var tower: TowerData = TowerData.new()
	tower.allocation_cost = 10
	player_data.tower_slots[0] = {"data": tower, "stock": 1}

	assert_eq(player_data.get_total_allocation_cost(), 18, "Total cost should sum relics, buffs, and towers.")


func test_update_total_cost_manual_invalidation() -> void:
	var player_data: PlayerData = PlayerData.new()
	assert_eq(player_data.total_cost, 0, "Initial total_cost should be 0.")

	var relic: RelicData = RelicData.new()
	relic.allocation_cost = 15
	player_data.relics.append(relic)

	assert_eq(player_data.total_cost, 0, "total_cost cache should be stale until manually updated.")

	player_data.update_total_cost()
	assert_eq(player_data.total_cost, 15, "total_cost should be updated after calling update_total_cost().")


func test_is_valid() -> void:
	var player_data: PlayerData = PlayerData.new()

	var relic: RelicData = RelicData.new()
	relic.allocation_cost = 20
	player_data.relics.append(relic)

	# We call update_total_cost to ensure consistency if is_valid ever changes to use the cache.
	player_data.update_total_cost()

	assert_true(player_data.is_valid(50), "Should be valid if cost <= max_allocation.")
	assert_true(player_data.is_valid(20), "Should be valid if cost == max_allocation.")
	assert_false(player_data.is_valid(10), "Should be invalid if cost > max_allocation.")


func test_tower_slots_initialization() -> void:
	var player_data: PlayerData = PlayerData.new()
	assert_eq(player_data.tower_slots.size(), PlayerData.TOWER_SLOT_COUNT, "Tower slots should be pre-sized.")
	for i in range(PlayerData.TOWER_SLOT_COUNT):
		assert_null(player_data.tower_slots[i], "Tower slot %d should be null initially." % i)
