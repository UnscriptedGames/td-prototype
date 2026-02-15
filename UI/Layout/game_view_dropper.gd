extends Control

var build_manager: BuildManager

func _ready() -> void:
	# Find BuildManager group or wait for injection
	pass

func setup(bm: BuildManager) -> void:
	build_manager = bm
	mouse_filter = Control.MOUSE_FILTER_PASS

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not build_manager: return false
	
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "card_drag":
		# 1. Start Drag if not active
		if not build_manager.is_dragging():
			var item_data = data.get("data")
			var subtype = data.get("subtype")
			
			if subtype == "tower" and item_data is TowerData:
				if item_data.tower_scene_path:
					var scene = load(item_data.tower_scene_path)
					if scene:
						build_manager.start_drag_ghost_with_scene(item_data, scene, data.get("drag_id"), data.get("source"))
			
			elif subtype == "buff":
				build_manager.start_drag_buff(data.get("source"), data.get("drag_id"))
		
		# 2. Update Drag
		if build_manager.is_dragging():
			if data.get("subtype") == "buff":
				build_manager.update_drag_buff(get_global_mouse_position())
			else:
				build_manager.update_drag_ghost(get_global_mouse_position())
		
		# Hide UI Preview while in world
		if data.get("preview"): data.preview.visible = false
		return true
		
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not build_manager: return
	
	if data.get("subtype") == "buff":
		build_manager.apply_buff_at(get_global_mouse_position(), data.get("data"))
	else:
		build_manager.validate_and_place()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if build_manager:
			# If the drag ended and we didn't successfully drop (BuildManager still dragging),
			# then we must cancel. Use specific cancel methods.
			if build_manager.is_dragging():
				build_manager.cancel_drag_ghost()
				build_manager.cancel_drag_buff()
