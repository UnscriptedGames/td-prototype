@tool
extends EditorScript

# --- CONFIGURATION ---
# The scene we want to bake.
const SCENE_PATH: String = "res://Entities/Towers/Turntable/turntable_tower.tscn"
# The node name of the root sprite container in that scene.
const SPRITE_NODE_NAME: String = "Sprite"
# The output path for the baked image.
const OUTPUT_PATH: String = "res://Entities/Towers/Turntable/Assets/turntable_composite.png"
# The resolution of the bake canvas (should cover the sprite + children at 1.0 scale).
const BAKE_SIZE: Vector2i = Vector2i(1024, 1024)

func _run() -> void:
	# 1. Load the tower scene
	var scene_resource = load(SCENE_PATH)
	if not scene_resource:
		push_error("Could not load scene at: %s" % SCENE_PATH)
		return
		
	var instance = scene_resource.instantiate()
	
	# 2. Extract the Sprite hierarchy
	var original_sprite = instance.get_node_or_null(SPRITE_NODE_NAME)
	if not original_sprite:
		push_error("Could not find '%s' node in scene." % SPRITE_NODE_NAME)
		instance.free()
		return
		
	# Duplicate the entire Sprite branch (Deck + Vinyl + ToneArm + any children)
	# flags=7 (DUPLICATE_SIGNALS | DUPLICATE_GROUPS | DUPLICATE_SCRIPTS) 
	# Note: This copies children recursively by default.
	var sprite_copy = original_sprite.duplicate(7)
	
	# 3. Setup the Visuals for Baking
	# Reset scale to 1.0 to get full resolution (instead of the 0.075 game scale)
	sprite_copy.scale = Vector2.ONE
	# Position it in the center of our viewport
	sprite_copy.position = Vector2(BAKE_SIZE) / 2.0
	
	# Clean up the instance, we only needed the sprite copy
	instance.free()
	
	# 4. Create the Baking Viewport
	var sub_viewport = SubViewport.new()
	sub_viewport.size = BAKE_SIZE
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.msaa_2d = Viewport.MSAA_4X # Enable MSAA for smooth edges
	
	# Add the sprite to the viewport
	sub_viewport.add_child(sprite_copy)
	
	# 5. Perform the Capture
	# To capture a viewport in an EditorScript (headlessish), we need to add it to the tree momentarily.
	# We use the EditorInterface's base control as a temporary parent.
	var base_control = EditorInterface.get_base_control()
	base_control.add_child(sub_viewport)
	
	# Force the rendering server to draw the frame
	# This ensures the texture is ready before we grab it.
	# Just adding it might not be enough in a single synchronous frame, so we force update.
	# However, EditorScript is tricky. 
	# A safe way is to wait or force a draw. 
	# Since we can't await nicely in _run, we'll try immediate capture after add.
	# If this results in a blank image, we might need a small dirty hack or plugin.
	# But generally, for simple 2D, this often works if we force update.
	
	# Force a draw?
	# RenderingServer.force_draw() # Not available in GDScript API directly in 4.x usually exposed differently?
	# Actually, usually just `get_texture().get_image()` triggers a readback.
	# Let's try to just capture.
	
	var texture = sub_viewport.get_texture()
	var image = texture.get_image()
	
	# 6. Cleanup
	base_control.remove_child(sub_viewport)
	sub_viewport.free()
	
	# 7. Save the Result
	if image:
		var error = image.save_png(OUTPUT_PATH)
		if error == OK:
			print("Successfully baked composite to: %s" % OUTPUT_PATH)
			# Refresh the filesystem so Godot sees the new file immediately
			EditorInterface.get_resource_filesystem().scan()
		else:
			push_error("Failed to save image. Error code: %s" % error)
	else:
		push_error("Failed to capture image from viewport.")
