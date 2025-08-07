extends Node

## The scene that will be displayed during loading.
var loading_screen_scene: PackedScene = preload("res://UI/LoadingScreen/loading_screen.tscn")


func load_scene(scene_path: String) -> void:
	# 1. Show the loading screen and wait for it to draw.
	var loading_screen_instance := loading_screen_scene.instantiate()
	get_tree().root.add_child(loading_screen_instance)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2. Load the scene resource and create an instance, but DO NOT add it to the tree yet.
	var new_scene_resource: PackedScene = load(scene_path)
	var new_scene_instance := new_scene_resource.instantiate() as TemplateLevel

	# 3. Get the level data from the instance and create all the necessary object pools.
	#    This is the heavy, synchronous work that will freeze the game on the loading screen.
	if is_instance_valid(new_scene_instance.level_data):
		var level_data := new_scene_instance.level_data
		
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
		for tower_data in level_data.available_towers:
			if tower_data.projectile_scene and not unique_projectiles.has(tower_data.projectile_scene):
				unique_projectiles.append(tower_data.projectile_scene)
		for projectile_scene in unique_projectiles:
			ObjectPoolManager.create_pool(projectile_scene, 50)
	
	# 4. Now that all work is done, free the old scene.
	get_tree().current_scene.queue_free()

	# 5. Add the fully prepared new scene to the game.
	get_tree().root.add_child(new_scene_instance)

	# 6. Remove the loading screen.
	loading_screen_instance.queue_free()
