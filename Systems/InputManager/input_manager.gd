extends Node

## Manages all player input and delegates to the appropriate systems based on game state.

enum State {
	DEFAULT,        # Default gameplay state, interacting with cards and UI.
	BUILDING_TOWER, # The player is currently placing a tower.
	UI_INTERACTION  # A UI panel is open, gameplay input is blocked.
}

var current_state: State = State.DEFAULT

var _cards_hud: CardsHUD = null
var _build_manager: BuildManager = null


func _input(event: InputEvent) -> void:
	var handled: bool = false

	match current_state:
		State.DEFAULT:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				# In default state, tower selection has priority over background clicks
				if _build_manager:
					handled = _build_manager.handle_selection_input(event)

				if not handled and _cards_hud:
					handled = _cards_hud.handle_global_click(event)

		State.BUILDING_TOWER:
			if _build_manager:
				handled = _build_manager.handle_build_input(event)

	if handled:
		get_viewport().set_input_as_handled()


func register_cards_hud(hud: CardsHUD) -> void:
	_cards_hud = hud

func register_build_manager(manager: BuildManager) -> void:
	_build_manager = manager

func set_state(new_state: State) -> void:
	current_state = new_state
	print("InputManager state changed to: ", State.keys()[new_state])
