@tool
class_name SidebarButton
extends Button

## Draggable loadout button used in the sidebar HUD.
##
## Supports three item types — towers, buffs, and relics — each configured
## via their respective [code]setup_*[/code] method. Generates a ghost
## preview on drag and manages a cooldown overlay for buffs.

## Loadout item backing this button (TowerData, BuffData, or RelicData).
var data: LoadoutItem
var type: String = "tower"
var _is_on_cooldown: bool = false
var _current_stock: int = 0
## The fixed rack index this button occupies (set by SidebarHUD).
var slot_index: int = -1

@onready var icon_rect: TextureRect = $IconRect
@onready var background_rect: TextureRect = $BackgroundRect
@onready var cost_label: Label = $CostLabel
@onready var stock_label: Label = $StockLabel
@onready var adjuster_box: HBoxContainer = $AdjusterBox
@onready var minus_button: Button = $AdjusterBox/MinusButton
@onready var plus_button: Button = $AdjusterBox/PlusButton
@onready var cooldown_overlay: TextureProgressBar = $CooldownOverlay

const COOLDOWN_TINT: Color = Color(0, 0, 0, 0.75)
var _is_in_studio_context: bool = false


func _ready() -> void:
	# Initialise the cooldown overlay with a solid-white progress texture.
	if cooldown_overlay:
		cooldown_overlay.visible = false
		cooldown_overlay.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT

		if not cooldown_overlay.texture_progress:
			var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			cooldown_overlay.texture_progress = ImageTexture.create_from_image(img)

		cooldown_overlay.tint_progress = COOLDOWN_TINT

	# Set default label visibility and ensure they don't block mouse input for drag/drop
	if cost_label:
		cost_label.visible = false
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.move_to_front()
	if adjuster_box:
		adjuster_box.visible = false
	if stock_label:
		stock_label.text = "0"
		stock_label.visible = false
		stock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Ensure labels are on top of the icon/background
		stock_label.move_to_front()

	if minus_button:
		minus_button.pressed.connect(_on_minus_pressed)
	if plus_button:
		plus_button.pressed.connect(_on_plus_pressed)

	# Clear the button's built-in icon to avoid duplication/offset issues.
	icon = null


func setup_tower(tower_data: TowerData) -> void:
	# Configures this button for a tower item.
	data = tower_data
	type = "tower"
	if icon_rect:
		# Use the ghost texture (composite image) for the tower icon in the sidebar.
		if tower_data.ghost_texture:
			icon_rect.texture = tower_data.ghost_texture
		else:
			icon_rect.texture = tower_data.icon
	text = ""
	tooltip_text = tower_data.display_name

	if background_rect:
		background_rect.texture = preload("res://UI/HUD/Sidebar/Assets/sidebar_tower_button.png")

	if cost_label and not tower_data.levels.is_empty():
		cost_label.text = str(tower_data.levels[0].cost)
		cost_label.visible = true
	elif cost_label:
		cost_label.visible = false

	# Update visibility of the adjusters based on context
	if adjuster_box:
		adjuster_box.visible = _is_in_studio_context
	if stock_label and _is_in_studio_context:
		stock_label.text = str(_current_stock)


func set_stock(amount: int) -> void:
	# Updates the stock count label.
	_current_stock = amount

	if stock_label:
		stock_label.text = str(amount)
		# Always show label while it's a tower
		stock_label.visible = true
		stock_label.move_to_front()

	# Visually dim the button if out of stock, but not in the studio
	if not _is_in_studio_context:
		modulate.a = 0.5 if amount <= 0 else 1.0
	else:
		modulate.a = 1.0


func reset_to_empty() -> void:
	# Fully resets the button to its "Empty Slot" state
	data = null
	type = "tower"  # Default to tower slot behavior
	_current_stock = 0

	if icon_rect:
		icon_rect.texture = null
	if background_rect:
		background_rect.texture = null
	if cost_label:
		cost_label.visible = false
	if stock_label:
		stock_label.visible = false
		stock_label.text = "0"
	if adjuster_box:
		adjuster_box.visible = false

	text = ""
	tooltip_text = ""
	set_meta("tower_data", null)

	disabled = false
	modulate.a = 1.0
	flat = false


func setup_buff(buff_data: BuffData) -> void:
	# Configures this button for a buff item with icon, label, and cost.
	data = buff_data
	type = "buff"

	if buff_data.icon and icon_rect:
		icon_rect.texture = buff_data.icon
		# Buff icons might need different alignment/scaling if they aren't square?
		# For now, we assume they fit the same slot.

	text = buff_data.display_name
	tooltip_text = "%s\n%s" % [buff_data.display_name, buff_data.description]

	if background_rect:
		background_rect.texture = null

	if cost_label:
		cost_label.text = str(buff_data.gold_cost)
		cost_label.visible = true
	if adjuster_box:
		adjuster_box.visible = false


func setup_relic(relic_data: RelicData) -> void:
	# Configures this button for a relic item.
	data = relic_data
	type = "relic"
	if relic_data.icon and icon_rect:
		icon_rect.texture = relic_data.icon
		text = ""
	else:
		if icon_rect:
			icon_rect.texture = null
		text = "R"

	if background_rect:
		background_rect.texture = null

	if cost_label:
		cost_label.visible = false
	if adjuster_box:
		adjuster_box.visible = false


func show_cooldown(duration: float) -> void:
	# Displays an animated cooldown sweep that blocks dragging until complete.
	if not cooldown_overlay:
		return

	_is_on_cooldown = true
	cooldown_overlay.max_value = 100
	cooldown_overlay.value = 100
	cooldown_overlay.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(cooldown_overlay, "value", 0, duration)
	tween.tween_callback(
		func() -> void:
			cooldown_overlay.visible = false
			_is_on_cooldown = false
	)


func set_studio_context(is_studio: bool) -> void:
	_is_in_studio_context = is_studio

	if stock_label and stock_label.visible:
		stock_label.text = str(_current_stock)

	if type == "tower" and data != null:
		if adjuster_box:
			adjuster_box.visible = is_studio
		if stock_label:
			# Show stock label always if it's a tower, even in gameplay
			stock_label.visible = true
			stock_label.move_to_front()
		if cost_label:
			cost_label.move_to_front()

	if data == null:
		if adjuster_box:
			adjuster_box.visible = false
		if stock_label:
			stock_label.visible = false
	else:
		modulate.a = 1.0 if is_studio else (0.5 if _current_stock <= 0 else 1.0)


func _on_minus_pressed() -> void:
	if not data or type != "tower" or not _is_in_studio_context:
		return

	var td: TowerData = data as TowerData
	if _current_stock <= 0:
		return

	# Write directly into the canonical tower_slots array
	if slot_index >= 0 and slot_index < GameManager.player_data.tower_slots.size():
		var current_slot = GameManager.player_data.tower_slots[slot_index]
		if current_slot != null:
			var new_stock: int = current_slot.get("stock", 1) - 1
			if new_stock <= 0:
				# Erase the slot entirely
				GameManager.player_data.tower_slots[slot_index] = null
				GameManager._loadout_stock.erase(td)
				GameManager.loadout_stock_changed.emit(td, 0)
				GlobalSignals.loadout_rebuild_requested.emit()
			else:
				current_slot["stock"] = new_stock
				GameManager._loadout_stock[td] = new_stock
				GameManager.loadout_stock_changed.emit(td, new_stock)
				set_stock(new_stock)


func _on_plus_pressed() -> void:
	if not data or type != "tower" or not _is_in_studio_context:
		return

	var td: TowerData = data as TowerData

	# Check AP budget
	var current_cost: int = GameManager.player_data.get_total_allocation_cost()
	var test_cost: int = current_cost + td.allocation_cost
	if test_cost > GameManager.player_data.max_allocation_points:
		return  # Over budget

	if slot_index >= 0 and slot_index < GameManager.player_data.tower_slots.size():
		var current_slot = GameManager.player_data.tower_slots[slot_index]
		if current_slot != null:
			var new_stock: int = current_slot.get("stock", 1) + 1
			current_slot["stock"] = new_stock
			GameManager._loadout_stock[td] = new_stock
			GameManager.loadout_stock_changed.emit(td, new_stock)
			set_stock(new_stock)


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Builds a ghost preview showing only the icon texture (semi-transparent)
	# then returns the loadout_drag payload dictionary.
	if not data:
		return null
	if _is_on_cooldown:
		return null

	# Prevent dragging if out of stock (only applies to towers).
	if type == "tower" and _current_stock <= 0 and not _is_in_studio_context:
		return null

	# Determine the drag texture from the IconRect (same source as the sidebar display).
	var drag_texture: Texture2D = null
	if icon_rect and icon_rect.texture:
		drag_texture = icon_rect.texture
	elif data.icon:
		drag_texture = data.icon
	elif data is TowerData and data.ghost_texture:
		drag_texture = data.ghost_texture

	if not drag_texture:
		return null

	# Ghost icon — just the icon texture, semi-transparent, matching the IconRect size.
	var icon_size: Vector2 = icon_rect.size if icon_rect else self.size
	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = icon_size
	preview.size = icon_size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = drag_texture
	preview.modulate = Color(1.0, 1.0, 1.0, 0.75)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Offset container — keeps the cursor aligned to where the user clicked.
	var offset_root: Control = Control.new()
	offset_root.z_index = 100
	offset_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_root.add_child(preview)
	preview.position = -_at_position

	set_drag_preview(offset_root)

	var drag_id: int = Time.get_ticks_msec() + get_instance_id()

	return {
		"type": "loadout_drag",
		"subtype": type,
		"data": data,
		"drag_id": drag_id,
		"source": self,
		"preview": preview
	}


func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if typeof(drag_data) != TYPE_DICTIONARY or not drag_data.has("type"):
		return false

	if drag_data["type"] == "catalog_drag":
		# Only accept drops of matching resource types!
		if type == "tower" and drag_data["data"] is TowerData:
			return true
		if type == "buff" and drag_data["data"] is BuffData:
			return true
		if type == "relic" and drag_data["data"] is RelicData:
			return true

	if drag_data["type"] == "loadout_drag" and _is_in_studio_context:
		# Accept drops from other sidebar buttons of the same type
		if drag_data["subtype"] == type and drag_data["source"] != self:
			return true

	return false


func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	if not _can_drop_data(_at_position, drag_data):
		return

	var incoming_data: Resource = drag_data["data"]

	if drag_data["type"] == "catalog_drag":
		# Drop a catalog item directly into this specific slot
		if incoming_data is TowerData:
			var td: TowerData = incoming_data as TowerData

			# Validate AP budget
			var test_cost: int = (
				GameManager.player_data.get_total_allocation_cost() + td.allocation_cost
			)
			if test_cost <= GameManager.player_data.max_allocation_points:
				# Erase any existing tower that was in this slot from the stock dict
				var old_slot = GameManager.player_data.tower_slots[slot_index]
				if old_slot != null and old_slot.get("data") is TowerData:
					GameManager._loadout_stock.erase(old_slot["data"] as TowerData)

				# Write the new item into this slot with stock 1
				GameManager.player_data.tower_slots[slot_index] = {"data": td, "stock": 1}
				GameManager._loadout_stock[td] = 1
				GameManager.loadout_stock_changed.emit(td, 1)
				GlobalSignals.loadout_rebuild_requested.emit()

	elif drag_data["type"] == "loadout_drag":
		var source_btn: SidebarButton = drag_data["source"] as SidebarButton
		if source_btn and source_btn.slot_index >= 0 and source_btn.slot_index != slot_index:
			var source_idx: int = source_btn.slot_index
			var target_idx: int = slot_index
			var slots: Array = GameManager.player_data.tower_slots

			# Swap the two slot entries in the canonical array
			var temp = slots[source_idx]
			slots[source_idx] = slots[target_idx]
			slots[target_idx] = temp

			# Rebuild the sidebar so buttons reflect the updated order
			GlobalSignals.loadout_rebuild_requested.emit()

	# NOTE: Buff and Relic slot swapping will be handled similarly when implemented.
