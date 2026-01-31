extends Control

## Signal emitted when a card is successfully dropped and validated.
signal card_dropped(card: Card)

var _buff_cursor_texture: Texture2D

func _ready() -> void:
	print("GameViewDropper: Script ACTIVE and READY on ", name)
	
	# Try loading via ResourceLoader first (standard)
	if ResourceLoader.exists("res://UI/Icons/buff_cursor.png"):
		_buff_cursor_texture = load("res://UI/Icons/buff_cursor.png")
		
	# Fallback: Load raw image directly (bypasses Import system if it's lagging)
	if not _buff_cursor_texture and FileAccess.file_exists("res://UI/Icons/buff_cursor.png"):
		var img = Image.load_from_file("res://UI/Icons/buff_cursor.png")
		if img:
			_buff_cursor_texture = ImageTexture.create_from_image(img)
			print("GameViewDropper: Loaded cursor via raw Image loader.")
		else:
			printerr("GameViewDropper: Failed to load raw image file.")
			
	# Drop Overlay initialized.

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "card_drag":
		# 1. We are inside the game view: Show Ghost Tower
		# We need to access BuildManager - assuming global access
		var build_manager = InputManager.get_build_manager()
		if build_manager:
			var drag_id = data.get("drag_id", -1)
			
			# Universal Banishment Check
			if build_manager.is_drag_banished(drag_id):
				if data.get("preview"):
					data["preview"].visible = false
				return false

			var effect = data["card_data"].effect
			# Check if effect has tower_scene AND tower_data (Build Tower)
			if effect and "tower_scene" in effect and effect.tower_scene and "tower_data" in effect and effect.tower_data:
				var card = data.get("card", null)
				
				# Only start if allowed (BuildManager will check banishment)
				build_manager.start_drag_ghost_with_scene(effect.tower_data, effect.tower_scene, drag_id, card)
				
				# Update position continuously
				build_manager.update_drag_ghost(get_global_mouse_position())
				
			# Check if effect is a Buff (Buff Tower)
			elif effect is BuffTowerEffect:
				var card = data.get("card", null)
				build_manager.start_drag_buff(card, drag_id) # Pass drag_id for ban checking
				build_manager.update_drag_buff(get_global_mouse_position())
				
		
		# 2. Hide the Drag Preview (Ghost Card)
		if data.get("preview"):
			var effect = data["card_data"].effect
			# Hide for Towers AND Buffs (because we spawn world ghosts for both now)
			if (effect and "tower_scene" in effect and effect.tower_scene) or (effect is BuffTowerEffect):
				data["preview"].visible = false
			else:
				data["preview"].visible = true
			
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data["type"] == "card_drag":
		var build_manager = InputManager.get_build_manager()
		if build_manager:
			var effect = data["card_data"].effect
			
			if effect is BuffTowerEffect:
				if build_manager.apply_buff_at(get_global_mouse_position(), effect):
					card_dropped.emit(data["card"])
			
			# Default to Place Tower if not a buff (or check structure explicitly)
			elif build_manager.validate_and_place():
				# Success! Notify GameWindow to consume card.
				card_dropped.emit(data["card"])
			else:
				# Failed (Invalid spot), just cancel.
				build_manager.cancel_drag_ghost()
				
		# Restore preview visibility just in case (though drag end handles destruction)
		if data["preview"]:
			data["preview"].visible = true
