extends Node

enum State {
	DEFAULT, # Default gameplay state, interacting with cards and UI.
	BUILDING_TOWER, # The player is currently placing a tower.
	UI_INTERACTION # A UI panel is open, gameplay input is blocked.
}

var current_state: State = State.DEFAULT

var _build_manager: BuildManager = null


func _unhandled_input(event: InputEvent) -> void:
	var handled: bool = false

	# If no UI button was clicked, proceed to game state logic.
	match current_state:
		State.DEFAULT:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				# Priority 1: Check for tower selection/deselection.
				if _build_manager:
					handled = _build_manager.handle_selection_input(event)

		State.BUILDING_TOWER:
			if _build_manager:
				handled = _build_manager.handle_build_input(event)

	if handled:
		get_viewport().set_input_as_handled()


func register_build_manager(manager: BuildManager) -> void:
	_build_manager = manager


func get_build_manager() -> BuildManager:
	return _build_manager


func set_state(new_state: State) -> void:
	current_state = new_state
