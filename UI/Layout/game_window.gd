class_name GameWindow
extends Control

@onready var game_viewport: SubViewport = $MainLayout/WorkspaceSplit/GameViewContainer/SubViewport

# Path to the default level
const DEFAULT_LEVEL_PATH: String = "res://Levels/TemplateLevel/template_level.tscn"

func _ready() -> void:
	# If no level is loaded by the time we are ready (and not just in editor), 
	# we could load a default, but SceneManager usually handles this.
	# _load_level(DEFAULT_LEVEL_PATH)
	pass

func _load_level(level_path: String) -> void:
	var level_scene = load(level_path)
	if level_scene:
		var level_instance = level_scene.instantiate()
		load_level_instance(level_instance)

func load_level_instance(level_instance: Node) -> void:
	# Clear any existing children in the viewport
	for child in game_viewport.get_children():
		child.queue_free()
	
	game_viewport.add_child(level_instance)
