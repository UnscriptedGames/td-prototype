## Sidebar HUD panel that populates tower, buff, and relic buttons from the
## player's loadout. Supports @tool editor preview via the preview_loadout
## export. At runtime, listens to GameManager for stock and state changes.
@tool
class_name SidebarHUD
extends Control

# Resources
const SIDEBAR_BUTTON_SCRIPT = preload("res://UI/HUD/Sidebar/sidebar_button.gd")
const SIDEBAR_BUTTON_SCENE = preload("res://UI/HUD/Sidebar/sidebar_button.tscn")

@export var preview_loadout: PlayerData:
	set = _set_preview_loadout

var _is_in_studio_context: bool = false

# UI Nodes
@onready var relic_container: HBoxContainer = %RelicContainer
@onready var tower_grid: GridContainer = %TowerGrid
@onready var buff_container: VBoxContainer = %BuffContainer


# --- OVERRIDES ---


func _ready() -> void:
	if Engine.is_editor_hint():
		populate(preview_loadout)
		return

	# Runtime: connect to GameManager signals
	if GameManager.has_signal("loadout_stock_changed"):
		GameManager.loadout_stock_changed.connect(_on_loadout_stock_changed)

	GlobalSignals.buff_applied.connect(_on_buff_applied)
	GameManager.relic_state_changed.connect(_on_relic_state_changed)

	# Initial population
	populate(GameManager.player_data)


func _exit_tree() -> void:
	if is_instance_valid(GameManager):
		if (
			GameManager.has_signal("loadout_stock_changed")
			and GameManager.loadout_stock_changed.is_connected(_on_loadout_stock_changed)
		):
			GameManager.loadout_stock_changed.disconnect(_on_loadout_stock_changed)
		if GameManager.relic_state_changed.is_connected(_on_relic_state_changed):
			GameManager.relic_state_changed.disconnect(_on_relic_state_changed)

	if is_instance_valid(GlobalSignals):
		if GlobalSignals.buff_applied.is_connected(_on_buff_applied):
			GlobalSignals.buff_applied.disconnect(_on_buff_applied)

	if is_instance_valid(relic_container):
		for child in relic_container.get_children():
			var button: TextureButton = child as TextureButton
			if is_instance_valid(button):
				var callables: Array[Dictionary] = button.pressed.get_connections()
				for connection in callables:
					button.pressed.disconnect(connection["callable"])

	if is_instance_valid(tower_grid):
		for child in tower_grid.get_children():
			var button: TextureButton = child as TextureButton
			if is_instance_valid(button):
				var callables: Array[Dictionary] = button.pressed.get_connections()
				for connection in callables:
					button.pressed.disconnect(connection["callable"])

	if is_instance_valid(buff_container):
		for child in buff_container.get_children():
			var button: TextureButton = child as TextureButton
			if is_instance_valid(button):
				var callables: Array[Dictionary] = button.pressed.get_connections()
				for connection in callables:
					button.pressed.disconnect(connection["callable"])


## Clears and rebuilds the relic, tower, and buff button grids from the
## provided player data. Ensures minimum slot counts (3 relics, 6 towers,
## 6 buffs) for visual consistency.
func populate(player_data: Resource) -> void:
	# 1. Relics
	var relic_children: Array[Node] = relic_container.get_children()
	var relic_count: int = 3
	if player_data and "relics" in player_data:
		relic_count = max(player_data.relics.size(), 3)

	for index: int in range(relic_count):
		var button: Button = null
		if index < relic_children.size():
			button = relic_children[index]

		var data: RelicData = null
		if player_data and "relics" in player_data and index < player_data.relics.size():
			data = player_data.relics[index]

		_update_or_create_relic(button, data, index)

	# 2. Towers — always iterate exactly 6 fixed slots
	var tower_children: Array[Node] = tower_grid.get_children()
	if player_data:
		player_data._ensure_slots()

	for slot_index: int in range(PlayerData.TOWER_SLOT_COUNT):
		var button: Button = null
		if slot_index < tower_children.size():
			button = tower_children[slot_index]

		var info: Dictionary = {}
		if player_data and slot_index < player_data.tower_slots.size():
			var slot = player_data.tower_slots[slot_index]
			if slot != null and slot.has("data"):
				info = slot

		_update_or_create_tower(button, info, slot_index)

	# 3. Buffs
	var buff_children: Array[Node] = buff_container.get_children()
	var buff_items: Array[BuffData] = []
	if player_data and "buffs" in player_data:
		buff_items = player_data.buffs

	var buff_count: int = max(buff_items.size(), 6)

	for index: int in range(buff_count):
		var button: Button = null
		if index < buff_children.size():
			button = buff_children[index]

		var data: BuffData = null
		if index < buff_items.size():
			data = buff_items[index]

		_update_or_create_buff(button, data)


## Creates or updates a relic button at the given index. Connects the
## pressed signal and sets availability based on relic usage state.
func _update_or_create_relic(existing_button: Button, relic_data: RelicData, index: int) -> void:
	var button: SidebarButton = existing_button as SidebarButton
	if not button:
		button = SIDEBAR_BUTTON_SCRIPT.new()
		button.custom_minimum_size = Vector2(80, 80)
		relic_container.add_child(button)

	if button.get_script() != SIDEBAR_BUTTON_SCRIPT:
		button.set_script(SIDEBAR_BUTTON_SCRIPT)

	if relic_data:
		button.setup_relic(relic_data)
	else:
		button.text = "R%d" % (index + 1)
		button.disabled = true
		if button.stock_label:
			button.stock_label.visible = false

	if button.has_method("set_studio_context"):
		button.set_studio_context(_is_in_studio_context)

	# Clean existing self-connections before reconnecting
	var connections: Array = button.pressed.get_connections()
	for connection: Dictionary in connections:
		if connection.callable.get_object() == self:
			button.pressed.disconnect(connection.callable)

	button.pressed.connect(func() -> void: _on_relic_pressed(button))

	# Availability
	if Engine.is_editor_hint():
		button.disabled = false
	else:
		button.disabled = (relic_data == null) or GameManager.is_relic_used()


## Creates or updates a tower button. Replaces non-SidebarButton nodes with
## a fresh instance from the scene. Populates icon, stock, and drag metadata.
func _update_or_create_tower(existing_button: Button, info: Dictionary, slot_index: int) -> void:
	var button: SidebarButton = existing_button as SidebarButton
	if not button:
		button = SIDEBAR_BUTTON_SCENE.instantiate()
		button.custom_minimum_size = Vector2(100, 100)
		tower_grid.add_child(button)

	if not button is SidebarButton:
		var new_button: SidebarButton = SIDEBAR_BUTTON_SCENE.instantiate()
		new_button.custom_minimum_size = Vector2(100, 100)
		existing_button.replace_by(new_button)
		button = new_button
		existing_button.queue_free()

	# Always assign the slot index so the button knows its rack position
	button.slot_index = slot_index

	if not info.is_empty():
		var tower_data: TowerData = info.data
		var stock: int = info.get("stock", 1)
		button.setup_tower(tower_data)
		button.set_stock(stock)
		button.set_meta("tower_data", tower_data)
		button.disabled = false
	else:
		button.reset_to_empty()

	if button.has_method("set_studio_context"):
		button.set_studio_context(_is_in_studio_context)


## Creates or updates a buff button. Replaces non-SidebarButton nodes with
## a fresh instance from the scene.
func _update_or_create_buff(existing_button: Button, buff_data: BuffData) -> void:
	var button: SidebarButton = existing_button as SidebarButton
	if not button:
		button = SIDEBAR_BUTTON_SCENE.instantiate()
		button.custom_minimum_size = Vector2(0, 64)
		buff_container.add_child(button)

	if not button is SidebarButton:
		var new_button: SidebarButton = SIDEBAR_BUTTON_SCENE.instantiate()
		new_button.custom_minimum_size = Vector2(0, 64)
		existing_button.replace_by(new_button)
		button = new_button
		existing_button.queue_free()

	if buff_data:
		button.setup_buff(buff_data)
		button.disabled = false
	else:
		button.text = "Empty"
		button.icon = null
		button.data = null
		button.disabled = true
		if button.cost_label:
			button.cost_label.visible = false
		if button.stock_label:
			button.stock_label.visible = false

	if button.has_method("set_studio_context"):
		button.set_studio_context(_is_in_studio_context)


## Updates the stock count label and disabled state for a tower button when
## the loadout stock changes at runtime.
func _on_loadout_stock_changed(tower_data: TowerData, new_stock: int) -> void:
	for child: Node in tower_grid.get_children():
		if child.has_meta("tower_data") and child.get_meta("tower_data") == tower_data:
			var button: SidebarButton = child as SidebarButton
			if button:
				button.set_stock(new_stock)


## Triggers the cooldown visual on the matching buff button when a buff is
## applied.
func _on_buff_applied(buff_data: BuffData) -> void:
	for child: Node in buff_container.get_children():
		var button_data: BuffData = child.get("data") as BuffData
		if button_data == buff_data:
			if child.has_method("show_cooldown"):
				child.show_cooldown(buff_data.cooldown)
			return


## Activates the pressed relic and executes its active effect.
func _on_relic_pressed(button: Button) -> void:
	var data: RelicData = button.data as RelicData
	if not data:
		return

	if GameManager.try_use_relic(data):
		if OS.is_debug_build():
			print("Relic Activated: %s" % data.display_name)
		if data.active_effect:
			data.active_effect.execute({"source": self, "player_data": GameManager.player_data})


## Enables or disables all relic buttons based on the global relic
## availability state.
func _on_relic_state_changed(is_available: bool) -> void:
	for child: Node in relic_container.get_children():
		if child is Button:
			child.disabled = not is_available


# --- METHODS ---


## Sets the current context (called by GameWindow) to update child display logic.
func set_context(mode: GameWindow.ContextMode) -> void:
	var is_studio: bool = mode == GameWindow.ContextMode.STUDIO
	_is_in_studio_context = is_studio
	for child in tower_grid.get_children():
		if child.has_method("set_studio_context"):
			child.set_studio_context(is_studio)
	for child in buff_container.get_children():
		if child.has_method("set_studio_context"):
			child.set_studio_context(is_studio)
	for child in relic_container.get_children():
		if child.has_method("set_studio_context"):
			child.set_studio_context(is_studio)


# --- PRIVATE METHODS ---


## Setter for the editor preview loadout. Repopulates the sidebar when the
## export is changed in the inspector.
func _set_preview_loadout(new_preview_loadout: PlayerData) -> void:
	preview_loadout = new_preview_loadout
	if Engine.is_editor_hint() and is_node_ready():
		populate(preview_loadout)


## Animates a progress bar from full to empty over the given duration for
## cooldown feedback.
func _start_cooldown_visual(bar: ProgressBar, duration: float) -> void:
	bar.max_value = 100
	bar.value = 100
	var tween: Tween = create_tween()
	tween.tween_property(bar, "value", 0, duration)


## Removes all children from a container node.
func _clear_container(container: Control) -> void:
	for child: Node in container.get_children():
		child.queue_free()
