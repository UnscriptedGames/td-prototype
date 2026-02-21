extends SceneTree

func _init():
	var data = load("res://Config/Enemies/basic_enemy_data.tres")
	print("--- BASIC ENEMY DATA ---")
	print("wave_texture: ", data.wave_texture)
	print("scroll_speed: ", data.scroll_speed)
	
	var mat = load("res://Entities/Enemies/BasicEnemy/basic_enemy_material.tres")
	print("--- BASIC ENEMY MATERIAL ---")
	print("resource_local_to_scene: ", mat.resource_local_to_scene)
	print("scroll_speed param: ", mat.get_shader_parameter("scroll_speed"))
	
	quit()
