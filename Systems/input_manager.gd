extends Node

enum State {
	DEFAULT,        # Default gameplay state, interacting with cards and UI.
	BUILDING_TOWER, # The player is currently placing a tower.
	UI_INTERACTION  # A UI panel is open, gameplay input is blocked.
}

var current_state: State = State.DEFAULT

var _cards_hud: CardsHUD = null
var _build_manager: BuildManager = null
var _level_hud: LevelHUD = null


func _input(event: InputEvent) -> void:
	var handled: bool = false

	# Priority 1: Always check for UI button clicks first.
	if _level_hud and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		handled = _level_hud.handle_click(event.position)
		if handled:
			# If a UI button was clicked, consume the event and do nothing else.
			get_viewport().set_input_as_handled()
			return

	# If no UI button was clicked, proceed to game state logic.
	match current_state:
		State.DEFAULT:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				# If the click is on an expanded card, let the card handle it and stop further processing.
				if _cards_hud and _cards_hud.is_expanded() and _cards_hud.is_position_on_a_card(event.position):
					return

				# In default state, tower selection has priority over background clicks
				if _build_manager:
					handled = _build_manager.handle_selection_input(event)

				# Note: handle_selection_input returns false for empty space clicks,
				# allowing the global click to be processed by the CardsHUD.
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

func register_level_hud(hud: LevelHUD) -> void:
	_level_hud = hud

func set_state(new_state: State) -> void:
	current_state = new_state
	print("InputManager state changed to: ", State.keys()[new_state])
