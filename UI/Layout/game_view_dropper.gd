extends Control

## Drop handler overlay for the game viewport.
##
## Attached at runtime as a child of the SubViewportContainer.
## Translates Godot drag-and-drop events into [BuildManager] calls
## for tower placement and buff application.

var build_manager: BuildManager

func _ready() -> void:
	pass

func setup(bm: BuildManager) -> void:
	# Binds this handler to the given BuildManager and enables mouse passthrough.
	build_manager = bm
	mouse_filter = Control.MOUSE_FILTER_PASS

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Evaluates whether the dragged payload is a valid card_drag and forwards
	# hover updates to BuildManager. Returns true while a drag is active.
	if not build_manager:
		return false
	
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "card_drag":
		# Initialise the drag ghost on first entry.
		if not build_manager.is_dragging():
			var item_data: LoadoutItem = data.get("data")
			var subtype: String = data.get("subtype")
			
			if subtype == "tower" and item_data is TowerData:
				if item_data.tower_scene_path:
					var scene: PackedScene = load(item_data.tower_scene_path)
					if scene:
						build_manager.start_drag_ghost_with_scene(
							item_data, scene, data.get("drag_id"), data.get("source")
						)
			
			elif subtype == "buff":
				build_manager.start_drag_buff(data.get("source"), data.get("drag_id"))
		
		# Update ghost/buff cursor position each frame.
		if build_manager.is_dragging():
			if data.get("subtype") == "buff":
				build_manager.update_drag_buff(get_global_mouse_position())
			else:
				build_manager.update_drag_ghost(get_global_mouse_position())
		
		# Hide the UI preview while hovering the game viewport.
		if data.get("preview"):
			data.preview.visible = false
		return true
	
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Finalises the drag: places a tower or applies a buff at the drop location.
	if not build_manager:
		return
	
	if data.get("subtype") == "buff":
		build_manager.apply_buff_at(get_global_mouse_position(), data.get("data"))
	else:
		build_manager.validate_and_place()

func _notification(what: int) -> void:
	# Cancels any active drag when the drag operation ends without a valid drop.
	if what == NOTIFICATION_DRAG_END:
		if build_manager and build_manager.is_dragging():
			build_manager.cancel_drag_ghost()
			build_manager.cancel_drag_buff()
