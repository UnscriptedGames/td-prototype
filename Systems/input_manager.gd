extends Node

enum State {
	DEFAULT, # Default gameplay state, interacting with cards and UI.
	BUILDING_TOWER, # The player is currently placing a tower.
	UI_INTERACTION # A UI panel is open, gameplay input is blocked.
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
				# --- INPUT PRIORITY FIX ---
				# Priority 1: Check for click on CONDENSED hand to expand it.
				# This must happen BEFORE tower selection check to prevent deselection.
				if _cards_hud and _cards_hud.is_click_on_condensed_hand(event.position):
					_cards_hud.expand()
					handled = true

				# Priority 2: Check for clicks on an EXPANDED card.
				# We just return, as the card's own _gui_input will handle it.
				elif _cards_hud and _cards_hud.is_expanded() and _cards_hud.is_position_on_a_card(event.position):
					return

				# Priority 3: Check for tower selection/deselection.
				elif _build_manager:
					handled = _build_manager.handle_selection_input(event)

				# Priority 4: If nothing else was clicked, process background clicks (e.g., to condense hand).
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


func get_build_manager() -> BuildManager:
	return _build_manager


func get_level_hud() -> LevelHUD:
	return _level_hud


func set_state(new_state: State) -> void:
	current_state = new_state
