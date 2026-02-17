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

@onready var buff_cost_label: Label = $BuffCostLabel
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
	if buff_cost_label:
		buff_cost_label.visible = false
	if stock_label:
		stock_label.visible = true
		stock_label.text = "0"


func setup_tower(tower_data: TowerData) -> void:
	# Configures this button for a tower item.
	data = tower_data
	type = "tower"
	icon = tower_data.icon
	text = ""
	tooltip_text = tower_data.display_name


func set_stock(amount: int) -> void:
	# Updates the stock count label.
	if stock_label:
		stock_label.text = str(amount)


func setup_buff(buff_data: BuffData) -> void:
	# Configures this button for a buff item with icon, label, and cost.
	data = buff_data
	type = "buff"
	
	if buff_data.icon:
		icon = buff_data.icon
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	text = buff_data.display_name
	tooltip_text = "%s\n%s" % [buff_data.display_name, buff_data.description]
	
	if buff_cost_label:
		buff_cost_label.text = str(buff_data.gold_cost)
		buff_cost_label.visible = true
	if stock_label:
		stock_label.visible = false


func setup_relic(relic_data: RelicData) -> void:
	# Configures this button for a relic item.
	data = relic_data
	type = "relic"
	if relic_data.icon:
		icon = relic_data.icon
		text = ""
	else:
		text = "R"
	
	if buff_cost_label:
		buff_cost_label.visible = false
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
	# Builds a ghost preview Panel matching this button's size and icon,
	# then returns the card_drag payload dictionary.
	if not data:
		return null
	if _is_on_cooldown:
		return null
	
	# Ghost Panel — mimics the button's appearance during the drag.
	var preview: Panel = Panel.new()
	var btn_size: Vector2 = self.size
	preview.custom_minimum_size = btn_size
	preview.size = btn_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Style: dark rounded rect with a thin border.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	preview.add_theme_stylebox_override("panel", style)
	
	# Icon texture — fills the panel, centred and aspect-preserved.
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = btn_size
	icon_rect.size = btn_size
	icon_rect.position = Vector2.ZERO
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if data.icon:
		icon_rect.texture = data.icon
	elif data is TowerData and data.ghost_texture:
		icon_rect.texture = data.ghost_texture
	
	preview.add_child(icon_rect)
	
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
