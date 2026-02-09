@tool
extends SceneTree

func _init():
	print("Building Matte UI Material...")
	
	var shader = load("res://Levels/Components/matte_surface.gdshader")
	if not shader:
		print("Error: Shader not found at res://Levels/Components/matte_surface.gdshader")
		quit()
		return

	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise_strength", 0.05)
	mat.set_shader_parameter("gradient_strength", 0.1)
	
	var err = ResourceSaver.save(mat, "res://Assets/Theme/matte_ui.tres")
	if err == OK:
		print("Material saved successfully to res://Assets/Theme/matte_ui.tres")
	else:
		print("Error saving material: ", err)
	
	quit()
