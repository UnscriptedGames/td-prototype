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

@onready var icon_rect: TextureRect = $IconRect
@onready var background_rect: TextureRect = $BackgroundRect
@onready var cost_label: Label = $CostLabel
@onready var stock_label: Label = $StockLabel
@onready var cooldown_overlay: TextureProgressBar = $CooldownOverlay

const COOLDOWN_TINT: Color = Color(0, 0, 0, 0.75)


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
	
	# Set default label visibility.
	if cost_label:
		cost_label.visible = false
	if stock_label:
		stock_label.visible = true
		stock_label.text = "0"
	
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


func set_stock(amount: int) -> void:
	# Updates the stock count label.
	_current_stock = amount
	
	if stock_label:
		stock_label.text = str(amount)
	
	# Visually dim the button if out of stock?
	modulate.a = 0.5 if amount <= 0 else 1.0


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
	if stock_label:
		stock_label.visible = false


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
	if stock_label:
		stock_label.visible = false


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
	tween.tween_callback(func() -> void:
		cooldown_overlay.visible = false
		_is_on_cooldown = false
	)


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Builds a ghost preview showing only the icon texture (semi-transparent)
	# then returns the card_drag payload dictionary.
	if not data:
		return null
	if _is_on_cooldown:
		return null
	
	# Prevent dragging if out of stock (only applies to towers).
	if type == "tower" and _current_stock <= 0:
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
	preview.position = - _at_position
	
	set_drag_preview(offset_root)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	var drag_id: int = Time.get_ticks_msec() + get_instance_id()
	
	return {
		"type": "card_drag",
		"subtype": type,
		"data": data,
		"drag_id": drag_id,
		"source": self,
		"preview": preview
	}


func _notification(what: int) -> void:
	# Restores the mouse cursor when a drag operation ends.
	if what == NOTIFICATION_DRAG_END:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
