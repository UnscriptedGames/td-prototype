extends Node

## The scene that will be displayed during loading.
var loading_screen_scene: PackedScene = preload("res://UI/LoadingScreen/loading_screen.tscn")
## The shell window that contains the UI and the SubViewport for the level.
var game_window_scene: PackedScene = preload("res://UI/Layout/game_window.tscn")


func load_scene(scene_path: String) -> void:
	# 1. Show the loading screen and wait for it to draw.
	var loading_screen_instance := loading_screen_scene.instantiate()
	get_tree().root.add_child(loading_screen_instance)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2. Instantiate the GameWindow shell.
	var game_window_instance := game_window_scene.instantiate() as GameWindow
	
	# 3. Load the ACTUAL Level scene.
	var level_resource: PackedScene = load(scene_path)
	var level_instance := level_resource.instantiate() as TemplateLevel

	# 4. Get the level data from the instance and create all the necessary object pools.
	#    This is the heavy, synchronous work that will freeze the game on the loading screen.
	if is_instance_valid(level_instance.level_data):
		var level_data := level_instance.level_data
		
		# Create enemy pools
		var unique_enemies: Array[PackedScene] = []
		for wave in level_data.waves:
			for spawn_instruction in (wave as WaveData).spawns:
				if not unique_enemies.has(spawn_instruction.enemy_scene):
					unique_enemies.append(spawn_instruction.enemy_scene)
		for enemy_scene in unique_enemies:
			ObjectPoolManager.create_pool(enemy_scene, 20)
			
		# Create projectile pools
		var unique_projectiles: Array[PackedScene] = []
		
		# Use the player data to determine which towers (and thus projectiles) are needed
		if GameManager.player_data and GameManager.player_data.towers:
			for tower_data in GameManager.player_data.towers:
				if tower_data is TowerData:
					for level in tower_data.levels:
						if is_instance_valid(level) and is_instance_valid(level.projectile_scene):
							if not unique_projectiles.has(level.projectile_scene):
								unique_projectiles.append(level.projectile_scene)

		for projectile_scene in unique_projectiles:
			ObjectPoolManager.create_pool(projectile_scene, 50)
	
	# 5. Add the GameWindow (containing the level) to the root.
	get_tree().root.add_child(game_window_instance)
	
	# 6. Inject the prepared Level into the GameWindow.
	#    We do this AFTER adding to tree so GameWindow._ready() has run and nodes are valid.
	game_window_instance.load_level_instance(level_instance)

	# 7. Access and free the OLD current scene (e.g. MainMenu).
	if is_instance_valid(get_tree().current_scene):
		get_tree().current_scene.queue_free()
	
	# 8. Set the new scene as the current scene.
	get_tree().current_scene = game_window_instance

	# 8. Remove the loading screen.
	loading_screen_instance.queue_free()
