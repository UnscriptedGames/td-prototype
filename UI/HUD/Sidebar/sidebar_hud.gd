@tool
class_name SidebarHUD
extends Control

# Signals


# UI Nodes
@onready var relic_container: HBoxContainer = %RelicContainer
@onready var tower_grid: GridContainer = %TowerGrid
@onready var buff_container: VBoxContainer = %BuffContainer

# Resources
# Resources
const SIDEBAR_BUTTON_SCRIPT = preload("res://UI/HUD/Sidebar/sidebar_button.gd")
const SIDEBAR_BUTTON_SCENE = preload("res://UI/HUD/Sidebar/sidebar_button.tscn")

@export var preview_loadout: PlayerData: set = _set_preview_loadout

func _set_preview_loadout(val):
	preview_loadout = val
	if Engine.is_editor_hint() and is_node_ready():
		populate(preview_loadout)

func _ready() -> void:
	if Engine.is_editor_hint():
		# Editor Preview
		populate(preview_loadout)
		return
	
	# Runtime Only: Connect to GameManager
	if GameManager.has_signal("loadout_stock_changed"):
		GameManager.loadout_stock_changed.connect(_on_loadout_stock_changed)
		
	# Buff Cooldowns
	GlobalSignals.buff_applied.connect(_on_buff_applied)
	
	# Relic State
	GameManager.relic_state_changed.connect(_on_relic_state_changed)
	
	# Initial Populate - Runtime always clears and rebuilds for now
	# To support "linked nodes", we would need to map slots to logic.
	# For this step, runtime will still act as dynamic generation until we refactor further.
	populate(GameManager.player_data)

func populate(player_data: Resource) -> void:
	# Runtime specific: Clear and rebuild. 
	# Editor specific: Check if empty before populating?
	# 1. Relics
	var relic_children = relic_container.get_children()
	var relic_count = 3
	if player_data and "relics" in player_data:
		relic_count = max(player_data.relics.size(), 3)
	
	for i in range(relic_count):
		var btn: Button = null
		if i < relic_children.size():
			btn = relic_children[i]
		
		var data = null
		if player_data and "relics" in player_data and i < player_data.relics.size():
			data = player_data.relics[i]
			
		_update_or_create_relic(btn, data, i)

	# 2. Towers
	var tower_children = tower_grid.get_children()
	var tower_items = []
	if player_data and "towers" in player_data:
		for t in player_data.towers:
			tower_items.append({"data": t, "stock": player_data.towers[t]})
	
	# Ensure min 6 slots
	var tower_count = max(tower_items.size(), 6)
	
	for i in range(tower_count):
		var btn: Button = null
		if i < tower_children.size():
			btn = tower_children[i]
			
		var info = null
		if i < tower_items.size():
			info = tower_items[i]
		
		_update_or_create_tower(btn, info)

	# 3. Buffs
	var buff_children = buff_container.get_children()
	var buff_items = []
	if player_data and "buffs" in player_data: # Corrected from "spells"
		buff_items = player_data.buffs
		
	var buff_count = max(buff_items.size(), 6)
	
	for i in range(buff_count):
		var btn: Button = null
		if i < buff_children.size():
			btn = buff_children[i]
			
		var data = null
		if i < buff_items.size():
			data = buff_items[i]
			
		_update_or_create_buff(btn, data)

func _update_or_create_relic(existing_btn: Button, relic_data: RelicData, index: int) -> void:
	var btn = existing_btn
	if not btn:
		btn = SIDEBAR_BUTTON_SCRIPT.new()
		btn.custom_minimum_size = Vector2(80, 80)
		relic_container.add_child(btn)
	
	if btn.get_script() != SIDEBAR_BUTTON_SCRIPT:
		btn.set_script(SIDEBAR_BUTTON_SCRIPT)

	# Use the new setup method
	if relic_data:
		btn.setup_relic(relic_data)
	else:
		btn.text = "R%d" % (index + 1)
		btn.disabled = true
		if btn.stock_label: btn.stock_label.visible = false
	
	# Clean signals
	var conns = btn.pressed.get_connections()
	for c in conns:
		if c.callable.get_object() == self:
			btn.pressed.disconnect(c.callable)
			
	btn.pressed.connect(func(): _on_relic_pressed(btn))
	
	# Availability
	if Engine.is_editor_hint():
		btn.disabled = false
	else:
		# Only enable if we have data AND it's not used
		btn.disabled = (relic_data == null) or GameManager.is_relic_used()

func _update_or_create_tower(existing_btn: Button, info) -> void:
	var btn = existing_btn
	if not btn:
		btn = SIDEBAR_BUTTON_SCENE.instantiate()
		btn.custom_minimum_size = Vector2(100, 100)
		tower_grid.add_child(btn)
		
	if not btn is SidebarButton:
		var new_btn = SIDEBAR_BUTTON_SCENE.instantiate()
		new_btn.custom_minimum_size = Vector2(100, 100)
		existing_btn.replace_by(new_btn)
		btn = new_btn
		existing_btn.queue_free()
		

	if info:
		var tower_data = info.data
		var stock = info.stock
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


func _update_or_create_buff(existing_btn: Button, buff_data: BuffData) -> void:
	var btn = existing_btn
	if not btn:
		btn = SIDEBAR_BUTTON_SCENE.instantiate()
		# Adjust size for buffs (e.g. smaller or different aspect ratio?)
		# Let's keep consistent for now or use what was there (height 48)
		# But sidebar buttons usually square? 
		# Previous code used HBox 48 height.
		# Let's try 64x64 or just fit width
		btn.custom_minimum_size = Vector2(0, 64)
		buff_container.add_child(btn)
	
	if not btn is SidebarButton:
		var new_btn = SIDEBAR_BUTTON_SCENE.instantiate()
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
		# Ensure labels are hidden

		if btn.buff_cost_label: btn.buff_cost_label.visible = false
		if btn.stock_label: btn.stock_label.visible = false

func _on_loadout_stock_changed(tower_data: TowerData, new_stock: int) -> void:
	for child in tower_grid.get_children():
		if child.has_meta("tower_data") and child.get_meta("tower_data") == tower_data:
			var lbl = child.get_node_or_null("StockLabel")
			if lbl: lbl.text = str(new_stock)
			if child is Button:
				child.disabled = (new_stock <= 0)

func _on_buff_applied(buff_data: BuffData) -> void:
	# Find matching button by data reference
	for child in buff_container.get_children():
		var btn_data = child.get("data") as BuffData
		if btn_data == buff_data:
			if child.has_method("show_cooldown"):
				child.show_cooldown(buff_data.cooldown)
			return

func _on_relic_pressed(btn: Button) -> void:
	var data = btn.data as RelicData
	if not data: return
	
	if GameManager.try_use_relic(data):
		print("Relic Activated: %s" % data.display_name)
		if data.active_effect:
			data.active_effect.execute({"source": self, "player_data": GameManager.player_data})
		
func _on_relic_state_changed(is_available: bool) -> void:
	for child in relic_container.get_children():
		if child is Button:
			child.disabled = not is_available

func _start_cooldown_visual(bar: ProgressBar, duration: float) -> void:
	bar.max_value = 100
	bar.value = 100
	var tween = create_tween()
	tween.tween_property(bar, "value", 0, duration)

func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()
