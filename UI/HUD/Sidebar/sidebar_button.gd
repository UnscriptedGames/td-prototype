@tool
class_name SidebarButton
extends Button

var data: LoadoutItem
var type: String = "tower" # "tower", "buff", "relic"

func setup_tower(tower_data: TowerData) -> void:
	data = tower_data
	type = "tower"
	icon = tower_data.icon
	text = ""
	tooltip_text = tower_data.display_name
@onready var buff_cost_label: Label = $BuffCostLabel
@onready var stock_label: Label = $StockLabel
@onready var cooldown_overlay: TextureProgressBar = $CooldownOverlay

const COOLDOWN_TINT = Color(0, 0, 0, 0.75)

func _ready() -> void:
	# Ensure overlay is set up correctly (in case scene defaults are different)
	if cooldown_overlay:
		cooldown_overlay.visible = false
		cooldown_overlay.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		
		# Create the texture if not present (runtime generation for simple solid color)
		if not cooldown_overlay.texture_progress:
			var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			cooldown_overlay.texture_progress = ImageTexture.create_from_image(img)
			
		cooldown_overlay.tint_progress = COOLDOWN_TINT

# Old setup_tower removed

	
	# Hide buff labels
	if buff_cost_label: buff_cost_label.visible = false
	
	# Show stock label (will need to update value separate via set_stock)
	if stock_label:
		stock_label.visible = true
		stock_label.text = "0" # Default

func set_stock(amount: int) -> void:
	if stock_label:
		stock_label.text = str(amount)

func setup_buff(buff_data: BuffData) -> void:
	data = buff_data
	type = "buff"
	
	# Use icon if available, otherwise just text
	if buff_data.icon:
		icon = buff_data.icon
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Always set text to display name (user request)
	text = buff_data.display_name
	
	tooltip_text = "%s\n%s" % [buff_data.display_name, buff_data.description]
	
	if buff_cost_label:
		buff_cost_label.text = str(buff_data.gold_cost)
		buff_cost_label.visible = true
		
	if stock_label:
		stock_label.visible = false

func setup_relic(relic_data: RelicData) -> void:
	data = relic_data
	type = "relic"
	if relic_data.icon:
		icon = relic_data.icon
		text = ""
	else:
		text = "R"
	
	# Hide buff specific labels
	if buff_cost_label: buff_cost_label.visible = false
	if stock_label: stock_label.visible = false

var _is_on_cooldown: bool = false

func show_cooldown(duration: float) -> void:
	if not cooldown_overlay: return
	
	_is_on_cooldown = true
	cooldown_overlay.max_value = 100
	cooldown_overlay.value = 100
	cooldown_overlay.visible = true
	
	var tween = create_tween()
	tween.tween_property(cooldown_overlay, "value", 0, duration)
	tween.tween_callback(func():
		cooldown_overlay.visible = false
		_is_on_cooldown = false
		print("SidebarButton: Cooldown finished.")
	)

func _get_drag_data(_at_position: Vector2) -> Variant:
	print("SidebarButton: Drag Started")
	if not data: return null
	if _is_on_cooldown:
		print("SidebarButton: Drag prevented (Cooldown active).")
		return null
	
	# Create Ghost Button Preview
	var preview = Panel.new()
	var btn_size = self.size
	preview.custom_minimum_size = btn_size
	preview.size = btn_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Style the background
	var style = StyleBoxFlat.new()
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
	
	# Add the Icon
	var icon_rect = TextureRect.new()
	# Fill the panel (with slight padding if desired, but button usually fills)
	# Let's match the button exactly.
	icon_rect.custom_minimum_size = btn_size
	icon_rect.size = btn_size
	icon_rect.position = Vector2.ZERO
	
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # Allow us to set size
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if data.icon:
		icon_rect.texture = data.icon
	elif data is TowerData and data.ghost_texture:
		icon_rect.texture = data.ghost_texture
		
	preview.add_child(icon_rect)
	
	# Create a container to handle the offset
	var offset_root = Control.new()
	offset_root.z_index = 100
	offset_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_root.add_child(preview)
	
	# Offset the preview so the mouse cursor stays relative to the click point
	# set_drag_preview centers the control (offset_root) on the mouse.
	# So offset_root (0,0) is at mouse.
	# We want the mouse to satisfy: Mouse = TopLeft + _at_position
	# So TopLeft = Mouse - _at_position.
	# Since Mouse is 0,0 locally, TopLeft = -_at_position.
	preview.position = - _at_position
	
	set_drag_preview(offset_root)
	
	# Hide the cursor during the drag
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	var drag_id = Time.get_ticks_msec() + get_instance_id()
	
	return {
		"type": "card_drag", # Keeping legacy type for compatibility
		"subtype": type,
		"data": data,
		"drag_id": drag_id,
		"source": self,
		"preview": preview
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
