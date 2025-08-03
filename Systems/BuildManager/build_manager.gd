extends Node

## Manages the tower building process, including ghost towers and placement validation.

@export var ghost_tower_scene: PackedScene ## Set this in the Inspector!

## Internal State
var _is_in_build_mode: bool = false
var _active_ghost_tower: Node2D
const TOWER_DATA_PLACEHOLDER = preload("res://Entities/Towers/TowerData/placeholder_tower_data.tres")

## Node References
@onready var hud: CanvasLayer = get_node("../LevelHUD")
@onready var towers_container: Node2D = get_node("../Entities/Towers")
@onready var grass_layer: TileMapLayer = get_node("../TileMaps/GrassLayer")
@onready var objects_layer: TileMapLayer = get_node("../TileMaps/ObjectsLayer")


## Called when the node enters the scene tree.
func _ready() -> void:
	# Connect to the HUD's signal to know when the player wants to build.
	if is_instance_valid(hud):
		hud.build_tower_requested.connect(_on_build_tower_requested)


## Listens for player input during build mode.
func _unhandled_input(event: InputEvent) -> void:
	# Only run this logic if we are actively in build mode.
	if not _is_in_build_mode or not is_instance_valid(_active_ghost_tower):
		return

	# If Right Mouse Button or Escape is pressed, cancel the build.
	var is_cancel_key: bool = event.is_action_pressed("ui_cancel")
	var is_right_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed()

	if is_cancel_key or is_right_click:
		_exit_build_mode()
		get_viewport().set_input_as_handled() # Stop the event from propagating
		return

	# If Left Mouse Button is pressed, try to place the tower.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Check if the ghost tower says the location is valid.
		if _active_ghost_tower.is_placement_valid:
			var tower_data: TowerData = TOWER_DATA_PLACEHOLDER
			
			place_tower(tower_data, _active_ghost_tower.global_position)
			
			_exit_build_mode()
		
		get_viewport().set_input_as_handled()


## Toggles build mode when the button is pressed.
func _on_build_tower_requested() -> void:
	# If we are already in build mode, cancel it.
	if _is_in_build_mode:
		_exit_build_mode()
		return

	# If we are not in build mode, start it.
	_is_in_build_mode = true

	# Create and configure the ghost tower
	if ghost_tower_scene:
		_active_ghost_tower = ghost_tower_scene.instantiate()
		add_child(_active_ghost_tower)
		_active_ghost_tower.initialize(TOWER_DATA_PLACEHOLDER, grass_layer, objects_layer)


## Cleans up and exits the build mode state.
func _exit_build_mode() -> void:
	_is_in_build_mode = false
	if is_instance_valid(_active_ghost_tower):
		_active_ghost_tower.queue_free()
		_active_ghost_tower = null


## Instantiates and places the final tower.
func place_tower(tower_data: TowerData, position: Vector2) -> void:
	if not tower_data.placed_tower_scene:
		push_error("Attempted to place an invalid tower scene. Check the TowerData resource.")
		return

	var new_tower := tower_data.placed_tower_scene.instantiate()
	new_tower.global_position = position
	towers_container.add_child(new_tower)
	
	# Deduct cost from player's currency
	GameManager.remove_currency(tower_data.cost)
