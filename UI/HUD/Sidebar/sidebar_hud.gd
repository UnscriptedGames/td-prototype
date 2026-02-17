## Sidebar HUD panel that populates tower, buff, and relic buttons from the
## player's loadout. Supports @tool editor preview via the preview_loadout
## export. At runtime, listens to GameManager for stock and state changes.
@tool
class_name SidebarHUD
extends Control

# UI Nodes
@onready var relic_container: HBoxContainer = %RelicContainer
@onready var tower_grid: GridContainer = %TowerGrid
@onready var buff_container: VBoxContainer = %BuffContainer

# Resources
const SIDEBAR_BUTTON_SCRIPT = preload("res://UI/HUD/Sidebar/sidebar_button.gd")
const SIDEBAR_BUTTON_SCENE = preload("res://UI/HUD/Sidebar/sidebar_button.tscn")

@export var preview_loadout: PlayerData: set = _set_preview_loadout


## Setter for the editor preview loadout. Repopulates the sidebar when the
## export is changed in the inspector.
func _set_preview_loadout(val: PlayerData) -> void:
	preview_loadout = val
	if Engine.is_editor_hint() and is_node_ready():
		populate(preview_loadout)


func _ready() -> void:
	if Engine.is_editor_hint():
		populate(preview_loadout)
		return

	# Runtime: connect to GameManager signals
	if GameManager.has_signal("loadout_stock_changed"):
		GameManager.loadout_stock_changed.connect(_on_loadout_stock_changed)

	GlobalSignals.buff_applied.connect(_on_buff_applied)
	GameManager.relic_state_changed.connect(_on_relic_state_changed)

	populate(GameManager.player_data)


## Clears and rebuilds the relic, tower, and buff button grids from the
## provided player data. Ensures minimum slot counts (3 relics, 6 towers,
## 6 buffs) for visual consistency.
func populate(player_data: Resource) -> void:
	# 1. Relics
	var relic_children: Array[Node] = relic_container.get_children()
	var relic_count: int = 3
	if player_data and "relics" in player_data:
		relic_count = max(player_data.relics.size(), 3)

	for i: int in range(relic_count):
		var btn: Button = null
		if i < relic_children.size():
			btn = relic_children[i]

		var data: RelicData = null
		if player_data and "relics" in player_data and i < player_data.relics.size():
			data = player_data.relics[i]

		_update_or_create_relic(btn, data, i)

	# 2. Towers
	var tower_children: Array[Node] = tower_grid.get_children()
	var tower_items: Array[Dictionary] = []
	if player_data and "towers" in player_data:
		for tower_key: Variant in player_data.towers:
			tower_items.append({"data": tower_key, "stock": player_data.towers[tower_key]})

	var tower_count: int = max(tower_items.size(), 6)

	for i: int in range(tower_count):
		var btn: Button = null
		if i < tower_children.size():
			btn = tower_children[i]

		var info: Dictionary = {}
		if i < tower_items.size():
			info = tower_items[i]

		_update_or_create_tower(btn, info)

	# 3. Buffs
	var buff_children: Array[Node] = buff_container.get_children()
	var buff_items: Array[BuffData] = []
	if player_data and "buffs" in player_data:
		buff_items = player_data.buffs

	var buff_count: int = max(buff_items.size(), 6)

	for i: int in range(buff_count):
		var btn: Button = null
		if i < buff_children.size():
			btn = buff_children[i]

		var data: BuffData = null
		if i < buff_items.size():
			data = buff_items[i]

		_update_or_create_buff(btn, data)


## Creates or updates a relic button at the given index. Connects the
## pressed signal and sets availability based on relic usage state.
func _update_or_create_relic(existing_btn: Button, relic_data: RelicData, index: int) -> void:
	var btn: SidebarButton = existing_btn as SidebarButton
	if not btn:
		btn = SIDEBAR_BUTTON_SCRIPT.new()
		btn.custom_minimum_size = Vector2(80, 80)
		relic_container.add_child(btn)

	if btn.get_script() != SIDEBAR_BUTTON_SCRIPT:
		btn.set_script(SIDEBAR_BUTTON_SCRIPT)

	if relic_data:
		btn.setup_relic(relic_data)
	else:
		btn.text = "R%d" % (index + 1)
		btn.disabled = true
		if btn.stock_label: btn.stock_label.visible = false

	# Clean existing self-connections before reconnecting
	var conns: Array = btn.pressed.get_connections()
	for connection: Dictionary in conns:
		if connection.callable.get_object() == self:
			btn.pressed.disconnect(connection.callable)

	btn.pressed.connect(func() -> void: _on_relic_pressed(btn))

	# Availability
	if Engine.is_editor_hint():
		btn.disabled = false
	else:
		btn.disabled = (relic_data == null) or GameManager.is_relic_used()


## Creates or updates a tower button. Replaces non-SidebarButton nodes with
## a fresh instance from the scene. Populates icon, stock, and drag metadata.
func _update_or_create_tower(existing_btn: Button, info: Dictionary) -> void:
	var btn: SidebarButton = existing_btn as SidebarButton
	if not btn:
		btn = SIDEBAR_BUTTON_SCENE.instantiate()
		btn.custom_minimum_size = Vector2(100, 100)
		tower_grid.add_child(btn)

	if not btn is SidebarButton:
		var new_btn: SidebarButton = SIDEBAR_BUTTON_SCENE.instantiate()
		new_btn.custom_minimum_size = Vector2(100, 100)
		existing_btn.replace_by(new_btn)
		btn = new_btn
		existing_btn.queue_free()

	if not info.is_empty():
		var tower_data: TowerData = info.data
		var stock: int = info.stock
		btn.setup_tower(tower_data)
		btn.set_stock(stock)
		btn.set_meta("tower_data", tower_data)
		btn.disabled = false
	else:
		btn.text = ""
		btn.data = null
		btn.disabled = true
		btn.flat = false
		if btn.stock_label: btn.stock_label.visible = false


## Creates or updates a buff button. Replaces non-SidebarButton nodes with
## a fresh instance from the scene.
func _update_or_create_buff(existing_btn: Button, buff_data: BuffData) -> void:
	var btn: SidebarButton = existing_btn as SidebarButton
	if not btn:
		btn = SIDEBAR_BUTTON_SCENE.instantiate()
		btn.custom_minimum_size = Vector2(0, 64)
		buff_container.add_child(btn)

	if not btn is SidebarButton:
		var new_btn: SidebarButton = SIDEBAR_BUTTON_SCENE.instantiate()
		new_btn.custom_minimum_size = Vector2(0, 64)
		existing_btn.replace_by(new_btn)
		btn = new_btn
		existing_btn.queue_free()

	if buff_data:
		btn.setup_buff(buff_data)
		btn.disabled = false
	else:
		btn.text = "Empty"
		btn.icon = null
		btn.data = null
		btn.disabled = true
		if btn.buff_cost_label: btn.buff_cost_label.visible = false
		if btn.stock_label: btn.stock_label.visible = false


## Updates the stock count label and disabled state for a tower button when
## the loadout stock changes at runtime.
func _on_loadout_stock_changed(tower_data: TowerData, new_stock: int) -> void:
	for child: Node in tower_grid.get_children():
		if child.has_meta("tower_data") and child.get_meta("tower_data") == tower_data:
			var lbl: Label = child.get_node_or_null("StockLabel")
			if lbl: lbl.text = str(new_stock)
			if child is Button:
				child.disabled = (new_stock <= 0)


## Triggers the cooldown visual on the matching buff button when a buff is
## applied.
func _on_buff_applied(buff_data: BuffData) -> void:
	for child: Node in buff_container.get_children():
		var btn_data: BuffData = child.get("data") as BuffData
		if btn_data == buff_data:
			if child.has_method("show_cooldown"):
				child.show_cooldown(buff_data.cooldown)
			return


## Activates the pressed relic and executes its active effect.
func _on_relic_pressed(btn: Button) -> void:
	var data: RelicData = btn.data as RelicData
	if not data: return

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
