@tool
class_name SidebarHUD
extends Control

# Signals


# UI Nodes
@onready var relic_container: HBoxContainer = %RelicContainer
@onready var tower_grid: GridContainer = %TowerGrid
@onready var buff_container: VBoxContainer = %BuffContainer

# Resources
const SIDEBAR_BUTTON_SCRIPT = preload("res://UI/HUD/Sidebar/sidebar_button.gd")

func _ready() -> void:
	if Engine.is_editor_hint():
		# Editor Preview: Ensure we don't clear manual nodes, but verify count
		# Actually, if manual nodes exist, we might not want to touch them at all unless explicit
		# populate(null) # Let's NOT auto-populate in editor for now to allow manual edits, 
		# OR make populate smart enough to not destroy manual nodes.
		# For now, let's just make sure we don't clear if there are children.
		if relic_container.get_child_count() == 0:
			populate(null)
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
	populate(GameManager.active_loadout)

func populate(loadout: Resource) -> void:
	# Runtime specific: Clear and rebuild. 
	# Editor specific: Check if empty before populating?
	# 1. Relics
	var relic_children = relic_container.get_children()
	var relic_count = 3
	if loadout and "relics" in loadout:
		relic_count = max(loadout.relics.size(), 3)
	
	for i in range(relic_count):
		var btn: Button = null
		if i < relic_children.size():
			btn = relic_children[i]
		
		var data = null
		if loadout and "relics" in loadout and i < loadout.relics.size():
			data = loadout.relics[i]
			
		_update_or_create_relic(btn, data, i)

	# 2. Towers
	var tower_children = tower_grid.get_children()
	var tower_items = []
	if loadout and "towers" in loadout:
		for t in loadout.towers:
			tower_items.append({"data": t, "stock": loadout.towers[t]})
	
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
	if loadout and "spells" in loadout:
		buff_items = loadout.spells
		
	var buff_count = max(buff_items.size(), 6)
	
	for i in range(buff_count):
		var btn: Button = null
		if i < buff_children.size():
			btn = buff_children[i]
			
		var data = null
		if i < buff_items.size():
			data = buff_items[i]
			
		_update_or_create_buff(btn, data)

func _update_or_create_relic(existing_btn: Button, relic_data: Resource, index: int) -> void:
	var btn = existing_btn
	if not btn:
		btn = SIDEBAR_BUTTON_SCRIPT.new()
		btn.custom_minimum_size = Vector2(80, 80)
		relic_container.add_child(btn)
	
	# Update Properties (Only if script attached or compatible)
	if btn.get_script() != SIDEBAR_BUTTON_SCRIPT:
		btn.set_script(SIDEBAR_BUTTON_SCRIPT)

	btn.text = "R%d" % (index + 1)
	btn.type = "relic"
	btn.data = relic_data
	
	# Connect Click (Disconnect first to avoid dupes if reused?)
	if btn.pressed.is_connected(_on_relic_pressed_wrapper):
		btn.pressed.disconnect(_on_relic_pressed_wrapper)
	
	# Use a wrapper or bind? Bind creates a new callable, so checks might fail.
	# Let's rely on functional connection.
	# Actually, safely disconnecting anonymous lambdas is hard.
	# Let's clean signals:
	var conns = btn.pressed.get_connections()
	for c in conns:
		if c.callable.get_object() == self:
			btn.pressed.disconnect(c.callable)
			
	btn.pressed.connect(func(): _on_relic_pressed(btn))
	
	# Availability
	if Engine.is_editor_hint():
		btn.disabled = false
	else:
		btn.disabled = GameManager.is_relic_used()

func _on_relic_pressed_wrapper(): pass # Dummy for signal check logic if needed

func _update_or_create_tower(existing_btn: Button, info) -> void:
	var btn = existing_btn
	if not btn:
		btn = SIDEBAR_BUTTON_SCRIPT.new()
		btn.custom_minimum_size = Vector2(100, 100)
		tower_grid.add_child(btn)
		
	if btn.get_script() != SIDEBAR_BUTTON_SCRIPT:
		btn.set_script(SIDEBAR_BUTTON_SCRIPT)
		
	btn.type = "tower"
	btn.expand_icon = true
	
	var lbl = btn.get_node_or_null("StockLabel")
	if not lbl:
		lbl = Label.new()
		lbl.name = "StockLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lbl.position = Vector2(70, 75)
		btn.add_child(lbl)
	
	if info:
		var tower_data = info.data
		var stock = info.stock
		btn.data = tower_data
		btn.text = "T"
		lbl.text = str(stock)
		btn.set_meta("tower_data", tower_data)
		btn.disabled = false
	else:
		btn.text = ""
		btn.data = null
		btn.disabled = true
		btn.flat = false
		lbl.text = ""

func _update_or_create_buff(existing_btn: Button, card_data: Resource) -> void:
	var btn = existing_btn
	if not btn:
		btn = SIDEBAR_BUTTON_SCRIPT.new()
		btn.custom_minimum_size = Vector2(0, 48)
		buff_container.add_child(btn)
	
	if btn.get_script() != SIDEBAR_BUTTON_SCRIPT:
		btn.set_script(SIDEBAR_BUTTON_SCRIPT)

	btn.type = "buff"
	
	# Structure Check
	var hbox = btn.get_node_or_null("HBox")
	if not hbox:
		# If recreating structure, verify existing children
		# For manual nodes, we might rely on them having this structure.
		# If procedural, create it.
		if btn.get_child_count() > 0:
			# Assume manually created structure, find components
			hbox = btn.get_child(0) # Assume first child is container
			if not hbox is HBoxContainer: hbox = null
			
		if not hbox:
			hbox = HBoxContainer.new()
			hbox.name = "HBox"
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.add_child(hbox)

	# Ensure internal nodes exists (Icon, Label, Prog)
	# This part is getting complex for procedural generation vs manual.
	# Simplification: If manual, assume nodes exist. If procedural, create.
	
	var icon = hbox.get_node_or_null("Icon")
	if not icon:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)
		
	var lbl = hbox.get_node_or_null("Label")
	if not lbl:
		lbl = Label.new()
		lbl.name = "Label"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
		
	var prog = hbox.get_node_or_null("CooldownBar")
	if not prog:
		prog = ProgressBar.new()
		prog.name = "CooldownBar"
		prog.show_percentage = false
		prog.custom_minimum_size = Vector2(100, 10)
		prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(prog)

	if card_data:
		lbl.text = "Buff Name"
		btn.data = card_data
		btn.disabled = false
	else:
		lbl.text = "Empty Slot"
		btn.data = null
		btn.disabled = true

func _on_loadout_stock_changed(tower_data: Resource, new_stock: int) -> void:
	# Find button with this tower_data
	for child in tower_grid.get_children():
		if child.get_meta("tower_data", null) == tower_data:
			var lbl = child.get_node_or_null("StockLabel")
			if lbl: lbl.text = str(new_stock)
			
			# Disable if stock 0?
			if child is Button:
				child.disabled = (new_stock <= 0)

func _on_buff_applied(buff_data: Resource) -> void:
	# Find matching button
	for child in buff_container.get_children():
		if child.get("data") == buff_data:
			var bar = child.find_child("CooldownBar", true, false)
			if bar and bar is ProgressBar:
				_start_cooldown_visual(bar, 5.0) # Fixed 5s for now

func _on_relic_pressed(btn: Button) -> void:
	var data = btn.data
	
	if GameManager.try_use_relic(data):
		print("Relic Activated!")
		if data and data.get("effect"): # Use loose get to checking property existence safely
			var effect = data.effect
			if effect and effect.has_method("execute"):
				effect.execute({"source": self, "player_data": GameManager.player_data})
		
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
