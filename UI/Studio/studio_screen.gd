class_name StudioScreen
extends Control

## The Studio screen where the player manages their Loadout (Rack).
## Displays a catalog of available items. Clicking adds to the first empty
## slot in the sidebar. Drag-and-drop to a specific slot is handled by
## the SidebarButton nodes.

@onready var tower_catalog: GridContainer = %TowerCatalog
@onready var module_catalog: GridContainer = %ModuleCatalog
@onready var quick_start_button: Button = %QuickStartButton


func _ready() -> void:
	_populate_catalog()
	
	if is_instance_valid(quick_start_button):
		quick_start_button.pressed.connect(_on_quick_start_pressed)

	# Refresh catalog disable states when the rack changes
	if GlobalSignals.has_signal("loadout_rebuild_requested"):
		GlobalSignals.loadout_rebuild_requested.connect(_refresh_catalog_states)


func _exit_tree() -> void:
	if is_instance_valid(GlobalSignals):
		if GlobalSignals.loadout_rebuild_requested.is_connected(_refresh_catalog_states):
			GlobalSignals.loadout_rebuild_requested.disconnect(_refresh_catalog_states)


func _on_quick_start_pressed() -> void:
	var STAGE_1_PATH: String = "res://Config/Stages/stage01.tres"
	var stage: StageData = load(STAGE_1_PATH) as StageData
	if stage:
		StageManager.load_stage(stage)
		StageManager.prewarm_pools()     # Seed enemy/projectile pools before entering gameplay
		StageManager.start_stem(0)       # Launch the first stem immediately


func _populate_catalog() -> void:
	for child in tower_catalog.get_children():
		child.queue_free()

	var dir = DirAccess.open("res://Config/Towers/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var load_path = "res://Config/Towers/" + file_name.replace(".remap", "")
				var item_data = load(load_path)
				if item_data is TowerData:
					_create_catalog_item(item_data, "tower", tower_catalog)
			file_name = dir.get_next()

	_refresh_catalog_states()


func _create_catalog_item(item_data: Resource, item_type: String, container: Control) -> void:
	var item_scene: PackedScene = preload("res://UI/Studio/catalog_item.tscn")
	var item = item_scene.instantiate()
	container.add_child(item)
	item.setup(item_data, item_type)
	item.item_clicked.connect(_on_catalog_item_clicked)


## Disables catalog items that are already assigned to a sidebar slot.
func _refresh_catalog_states() -> void:
	if not is_instance_valid(GameManager.player_data):
		return

	for child in tower_catalog.get_children():
		if child is CatalogItem and child.data is TowerData:
			var already_in_loadout: bool = GameManager.player_data.is_tower_in_loadout(
				child.data as TowerData
			)
			child.disabled = already_in_loadout


func _on_catalog_item_clicked(item_data: Resource) -> void:
	if item_data is TowerData:
		var td: TowerData = item_data as TowerData

		# Duplicate guard — do nothing if already in the rack
		if GameManager.player_data.is_tower_in_loadout(td):
			return

		# AP Budget check
		var test_cost: int = (
			GameManager.player_data.get_total_allocation_cost() + td.allocation_cost
		)
		if test_cost > GameManager.player_data.max_allocation_points:
			return  # Over budget

		# Find the first empty slot in the rack
		var empty_index: int = GameManager.player_data.find_first_empty_tower_slot()
		if empty_index < 0:
			return  # Rack is full

		# Write the tower into that slot with stock 1
		GameManager.player_data.tower_slots[empty_index] = {"data": td, "stock": 1}
		GameManager._loadout_stock[td] = 1
		GameManager.loadout_stock_changed.emit(td, 1)
		GlobalSignals.loadout_rebuild_requested.emit()
