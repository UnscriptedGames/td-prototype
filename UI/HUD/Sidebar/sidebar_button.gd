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
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

func setup_buff(buff_data: BuffData) -> void:
	data = buff_data
	type = "buff"
	# Icon is handled by parent container (SidebarHUD) for buffs currently,
	# but we should support it here too.

func setup_relic(relic_data: RelicData) -> void:
	data = relic_data
	type = "relic"
	if relic_data.icon:
		icon = relic_data.icon
		text = ""
	else:
		text = "R"

func _get_drag_data(_at_position: Vector2) -> Variant:
	print("SidebarButton: Drag Started")
	if not data: return null
	
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
