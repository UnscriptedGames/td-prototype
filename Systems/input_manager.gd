extends Node

enum State { DEFAULT, BUILDING_TOWER, UI_INTERACTION }  # Default gameplay state, interacting with cards and UI.  # The player is currently placing a tower.  # A UI panel is open, gameplay input is blocked.

var current_state: State = State.DEFAULT

var _build_manager: BuildManager = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(_event: InputEvent) -> void:
	# UI/Global shortcuts can go here.
	# Mouse clicks for gameplay are now handled by BuildManager inside the SubViewport.
	pass


func register_build_manager(manager: BuildManager) -> void:
	_build_manager = manager


func get_build_manager() -> BuildManager:
	return _build_manager


func set_state(new_state: State) -> void:
	current_state = new_state
