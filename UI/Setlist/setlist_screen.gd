class_name SetlistScreen
extends Control

## Setlist Preview screen — the stage hub between the Studio and the Live Set.
##
## Displays all 6 stem cards (5 playable + 1 boss) and allows the player
## to select which stem to play next. Reacts to StageManager signals to
## keep card states synchronised.
## Pre-warms the ObjectPoolManager for all enemy/projectile types in the
## full stage while the player browses, so stem transitions are near-instant.

# --- Constants ---

const STEM_CARD_SCENE: PackedScene = preload("res://UI/Setlist/stem_card.tscn")

# --- VARIABLES ---

## References to the instantiated StemCard nodes, indexed 0-5.
var _stem_cards: Array = []


# --- ONREADY ---

@onready var stem1_slot: Control = $MarginContainer/HBoxContainer/Stem1Slot
@onready var middle_column: VBoxContainer = $MarginContainer/HBoxContainer/MiddleColumn
@onready var boss_slot: Control = $MarginContainer/HBoxContainer/BossSlot

# --- OVERRIDES ---


func _ready() -> void:
	# Connect to StageManager signals.
	StageManager.stem_status_changed.connect(_on_stem_status_changed)
	StageManager.stage_restarted.connect(_on_stage_restarted)

	# Build the UI from the currently loaded stage.
	if StageManager.active_stage:
		_build_setlist(StageManager.active_stage)
		_prewarm_pools()


func _exit_tree() -> void:
	if StageManager.stem_status_changed.is_connected(_on_stem_status_changed):
		StageManager.stem_status_changed.disconnect(_on_stem_status_changed)
	if StageManager.stage_restarted.is_connected(_on_stage_restarted):
		StageManager.stage_restarted.disconnect(_on_stage_restarted)

	for card in _stem_cards:
		if is_instance_valid(card) and card.stem_selected.is_connected(_on_stem_selected):
			card.stem_selected.disconnect(_on_stem_selected)


# --- METHODS ---


## Builds all 6 stem cards from the active StageData.
func _build_setlist(stage_data: StageData) -> void:
	_stem_cards.clear()

	# Phase 1: Instantiate and add cards to the tree so @onready vars resolve.

	# Stem 1 — full height, placed in the left slot.
	var stem1_card: PanelContainer = _instantiate_card()
	stem1_slot.add_child(stem1_card)
	_stem_cards.append(stem1_card)

	# Stems 2-5 — stacked vertically in the middle column.
	for index: int in range(1, StageManager.STEM_COUNT):
		var card: PanelContainer = _instantiate_card()
		middle_column.add_child(card)
		_stem_cards.append(card)

	# Boss stem — full height, placed in the right slot.
	var boss_card: PanelContainer = _instantiate_card()
	boss_slot.add_child(boss_card)
	_stem_cards.append(boss_card)

	# Phase 2: Now that cards are in the tree, configure them with data.
	var stem0: StemData = stage_data.stems[0] if stage_data.stems.size() > 0 else null
	_stem_cards[0].setup(0, stem0)
	_stem_cards[0].stem_selected.connect(_on_stem_selected)

	for index: int in range(1, StageManager.STEM_COUNT):
		var stem: StemData = stage_data.stems[index] if index < stage_data.stems.size() else null
		_stem_cards[index].setup(index, stem)
		_stem_cards[index].stem_selected.connect(_on_stem_selected)

	_stem_cards[StageManager.BOSS_INDEX].setup(StageManager.BOSS_INDEX, stage_data.boss_stem)
	_stem_cards[StageManager.BOSS_INDEX].stem_selected.connect(_on_stem_selected)

	# Apply initial states from StageManager results.
	for card_index: int in range(_stem_cards.size()):
		_stem_cards[card_index].update_state(StageManager.stem_results[card_index])


## Instantiates a blank StemCard without configuring it.
func _instantiate_card() -> PanelContainer:
	return STEM_CARD_SCENE.instantiate()


## Seeds the ObjectPoolManager for every unique enemy and projectile type
## in the full stage (all 5 stems + boss) while the player browses the setlist.
## Uses the same pool sizes as the former SceneManager pre-warming step.
func _prewarm_pools() -> void:
	if not is_instance_valid(StageManager.active_stage):
		return

	# Collect all StemData objects for the full stage including the boss.
	var all_stems: Array[StemData] = []
	for stem_data: StemData in StageManager.active_stage.stems:
		if is_instance_valid(stem_data):
			all_stems.append(stem_data)
	if is_instance_valid(StageManager.active_stage.boss_stem):
		all_stems.append(StageManager.active_stage.boss_stem)

	# Seed enemy pools.
	var unique_enemies: Array[PackedScene] = []
	for stem_data: StemData in all_stems:
		for spawn_instruction: SpawnInstruction in stem_data.spawns:
			if is_instance_valid(spawn_instruction.enemy_scene):
				if not unique_enemies.has(spawn_instruction.enemy_scene):
					unique_enemies.append(spawn_instruction.enemy_scene)
	for enemy_scene: PackedScene in unique_enemies:
		ObjectPoolManager.create_pool(enemy_scene, 20)

	# Seed projectile pools from the locked loadout's tower data.
	var unique_projectiles: Array[PackedScene] = []
	if is_instance_valid(GameManager.player_data):
		GameManager.player_data._ensure_slots()
		for slot in GameManager.player_data.tower_slots:
			if slot == null:
				continue
			var tower_data: TowerData = slot.get("data") as TowerData
			if not tower_data:
				continue
			for tower_level in tower_data.levels:
				if (
					is_instance_valid(tower_level)
					and is_instance_valid(tower_level.projectile_scene)
				):
					if not unique_projectiles.has(tower_level.projectile_scene):
						unique_projectiles.append(tower_level.projectile_scene)
	for projectile_scene: PackedScene in unique_projectiles:
		ObjectPoolManager.create_pool(projectile_scene, 50)


## Updates the "X/5" counter on the boss card.
func _update_boss_counter() -> void:
	var completed_count: int = StageManager.get_completed_stem_count()
	var boss_label: Label = boss_slot.get_node_or_null("BossCounterLabel")
	if boss_label:
		boss_label.text = "%d / %d Stems Complete" % [completed_count, StageManager.STEM_COUNT]


# --- PRIVATE METHODS ---


## Handles stem card click — starts the selected stem via StageManager.
func _on_stem_selected(stem_index: int) -> void:
	StageManager.start_stem(stem_index)


## Reacts to any stem result change by updating the affected card.
func _on_stem_status_changed(stem_index: int, result: StemResult) -> void:
	if stem_index >= 0 and stem_index < _stem_cards.size():
		_stem_cards[stem_index].update_state(result)


## Handles full stage restart — clears and rebuilds the setlist.
func _on_stage_restarted() -> void:
	# Clear existing cards.
	for card in _stem_cards:
		if is_instance_valid(card):
			card.queue_free()
	_stem_cards.clear()

	# Clear containers.
	for child in stem1_slot.get_children():
		if child is PanelContainer:
			child.queue_free()
	for child in middle_column.get_children():
		child.queue_free()
	for child in boss_slot.get_children():
		if child is PanelContainer:
			child.queue_free()

	# Rebuild from the active stage.
	if StageManager.active_stage:
		# Defer rebuild to next frame so freed nodes are cleaned up.
		call_deferred("_build_setlist", StageManager.active_stage)
