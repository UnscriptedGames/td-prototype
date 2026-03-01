extends Node

## Manages global scene transitions, including loading screens and level instantiation.
##
## Handles the specific flow of:
## 1. Show Loading Screen
## 2. Load Level Resource
## 3. Swap to Game Window
## 4. Inject Level into Game Window

const LOADING_SCREEN_PATH: String = "res://UI/LoadingScreen/loading_screen.tscn"
const GAME_WINDOW_PATH: String = "res://UI/Layout/game_window.tscn"

enum ViewType { MENU, LEVEL }

## The scene that will be displayed during loading.
var loading_screen_scene: PackedScene = preload(LOADING_SCREEN_PATH)
## The shell window that contains the UI and the SubViewport for the level.
var game_window_scene: PackedScene = preload(GAME_WINDOW_PATH)


## Initiates a scene transition to the specified resource path.
## @param scene_path: The resource path of the scene (.tscn) to load.
## @param view_type: Whether this is a UI MENU or a gameplay LEVEL to route into the correct container.
## @param stem_data: Optional stem configuration for LEVELs.
func load_scene(
	scene_path: String, view_type: ViewType = ViewType.LEVEL, stem_data: StemData = null
) -> void:
	# 1. Show the loading screen and wait for it to draw.
	var loading_screen_instance: Node = loading_screen_scene.instantiate()
	get_tree().root.add_child(loading_screen_instance)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2. Get or instantiate the GameWindow shell.
	var current_scene: Node = get_tree().current_scene
	var game_window_instance: GameWindow = null

	if current_scene is GameWindow:
		game_window_instance = current_scene as GameWindow
	else:
		game_window_instance = game_window_scene.instantiate() as GameWindow
		get_tree().root.add_child(game_window_instance)
		if is_instance_valid(current_scene):
			current_scene.queue_free()
		get_tree().current_scene = game_window_instance

	# 3. Load the requested scene resource.
	var scene_resource: PackedScene = load(scene_path)
	var scene_instance: Node = scene_resource.instantiate()

	# Pass stem data if it's a level
	if view_type == ViewType.LEVEL and stem_data and scene_instance.has_method("set_stem_data"):
		# Using duck typing or specific class check, BaseStage uses stem_data var directly
		scene_instance.set("stem_data", stem_data)

	# 4. Inject into the appropriate workspace layer.
	# We rely on GameWindow.change_workspace() which we are adding next.
	if game_window_instance.has_method("change_workspace"):
		game_window_instance.change_workspace(scene_instance, view_type)
	else:
		push_error("SceneManager: GameWindow is missing change_workspace() method!")

	# 5. Remove the loading screen.
	loading_screen_instance.queue_free()
