@tool
extends Control

## GameViewDropper
## A transparent overlay Control that covers the game viewport.
## It is placed as a static sibling of SubViewportContainer in game_window.tscn so that
## it always sits on top and receives drag events *before* the SubViewportContainer.
##
## This node's mouse_filter must be MOUSE_FILTER_PASS so normal clicks fall
## through to the game world underneath.

var build_manager: Node = null


# --- OVERRIDES ---


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_instance_valid(build_manager):
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("type") != "loadout_drag":
		return false

	var subtype: String = data.get("subtype", "")

	if not build_manager.is_dragging():
		var item_data: LoadoutItem = data.get("data")
		if subtype == "tower" and item_data is TowerData:
			if item_data.tower_scene_path:
				var scene: PackedScene = load(item_data.tower_scene_path)
				if scene:
					build_manager.start_drag_ghost_with_scene(
						item_data, scene, data.get("drag_id"), data.get("source")
					)
		elif subtype == "buff":
			build_manager.start_drag_buff(data.get("source"), data.get("drag_id"))

	if build_manager.is_dragging():
		if subtype == "buff":
			build_manager.update_drag_buff(get_local_mouse_position())
		else:
			build_manager.update_drag_ghost(get_local_mouse_position())

	var preview: Node = data.get("preview")
	if preview and is_instance_valid(preview):
		preview.visible = false

	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not is_instance_valid(build_manager):
		return
	if typeof(data) != TYPE_DICTIONARY:
		return

	var subtype: String = data.get("subtype", "")
	if subtype == "buff":
		build_manager.apply_buff_at(get_local_mouse_position(), data.get("data"))
	else:
		build_manager.validate_and_place()


# --- METHODS ---


## Called by GameWindow._bind_build_manager() once a level is loaded.
func setup(new_build_manager: Node) -> void:
	build_manager = new_build_manager
	if OS.is_debug_build():
		print("GameViewDropper setup triggered. Attached and ready.")
