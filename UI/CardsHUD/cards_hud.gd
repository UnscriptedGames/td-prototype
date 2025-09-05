class_name CardsHUD
extends CanvasLayer

# --- CONSTANTS ---

const EXPANDED_SCALE: Vector2 = Vector2(1.0, 1.0)
const CONDENSED_SCALE: Vector2 = Vector2(0.4, 0.4)
const TRANSITION_DURATION: float = 0.5
const CONDENSED_MARGIN: float = 25.0
const CARD_SPACING: int = 20
const BASE_VIEWPORT_WIDTH: float = 1920.0

# --- ONREADY VARIABLES ---

@onready var _hand_container: HandController = $HandContainer

# --- VARIABLES ---

var _card_manager: CardManager
var _is_expanded: bool = true
var _is_transitioning: bool = false
var _card_in_play: Card = null ## Stores a reference to the card being used.


# --- BUILT-IN METHODS ---

func _ready() -> void:
	# Wait a frame for nodes to be ready.
	await get_tree().process_frame
	
	# Register with the InputManager for handling clicks.
	InputManager.register_cards_hud(self)
	
	# Connect to the new generic signals for card effects.
	GlobalSignals.card_effect_completed.connect(_on_card_effect_completed)
	GlobalSignals.card_effect_cancelled.connect(_on_card_effect_cancelled)


# --- PUBLIC METHODS ---

func initialise(manager: CardManager) -> void:
	# Sets the reference to the card manager.
	_card_manager = manager
	
	# Check if the manager reference is valid.
	if _card_manager == null:
		push_error("A valid CardManager reference was not provided to CardsHUD.")
		return

	# Connect to the manager's signal to know when the hand data changes.
	_card_manager.hand_changed.connect(_on_card_manager_hand_changed)
	_card_manager.card_replaced.connect(_on_card_replaced)
	
	# Connect to the hand controller's signals for user actions.
	_hand_container.card_played.connect(_on_hand_container_card_played)
	_hand_container.hand_display_updated.connect(on_hand_changed)

	# Initialise the CardManager to draw the starting hand.
	if GameManager.player_data and GameManager.player_data.deck:
		_card_manager.initialise_deck(GameManager.player_data.deck, GameManager.player_data.hand_size)
	else:
		push_error("GameManager player_data or deck not ready when CardsHUD initialised.")


func on_hand_changed() -> void:
	# This function is called after the HandController has created the new card nodes.
	# We must wait one frame before calculating positions to ensure any nodes
	# that were queue_free()'d have been fully processed and removed.
	await get_tree().process_frame

	# Now that we are sure the old card nodes are gone, we can safely update.
	# The 'false' argument means the repositioning should be instant (no animation).
	_hand_container.update_card_positions(_is_expanded, false)


func is_position_on_a_card(screen_position: Vector2) -> bool:
	# Checks if the given screen coordinate is over any card in the hand.
	for card in _hand_container.get_children():
		if card is Card:
			if card.get_global_rect().has_point(screen_position):
				return true
	return false


func handle_global_click(event: InputEventMouseButton) -> bool:
	# Handles clicks that were not on other UI elements.
	if _is_transitioning:
		return true # Consume clicks while cards are animating.

	# If the hand is condensed, any click on it should expand it.
	if not _is_expanded:
		if _hand_container.get_global_rect().has_point(event.position):
			expand()
			return true # Input was handled.
		return false

	# If the hand is expanded, a click on a card is handled by the card itself.
	if is_position_on_a_card(event.position):
		return false # Let the card's input handler run.

	# If we reach here, it was a background click while expanded, so condense the hand.
	condense()
	return false # Not handled, so other systems can process it (like deselecting a tower).


func expand() -> void:
	# Public method to start the expand animation.
	_toggle_cards(true)


func condense() -> void:
	# Public method to start the condense animation.
	# First, ensure all cards are in their non-hovered state.
	for card in _hand_container.get_children():
		if card is Card:
			card.play_hover_off_animation()

	_toggle_cards(false)


# --- SIGNAL HANDLERS ---

func _on_card_effect_completed() -> void:
	# This is called on SUCCESS (e.g., tower placed).
	# If a card was in play, we now tell the CardManager to officially play it.
	if is_instance_valid(_card_in_play):
		var card_index: int = _hand_container.get_children().find(_card_in_play)
		if card_index != -1:
			# This call will now trigger either 'card_replaced' or 'hand_changed'.
			_card_manager.play_card(card_index, {})
		
		# Clear the reference.
		_card_in_play = null


func _on_card_effect_cancelled() -> void:
	# This is called on CANCELLATION.
	# We just need to make the hand visible again.
	if is_instance_valid(_card_in_play):
		_card_in_play = null
		_hand_container.visible = true


func _on_card_manager_hand_changed(new_hand: Array[CardData]) -> void:
	# This is now only called for a FULL redraw:
	# 1. On initial hand draw.
	# 2. When the hand size changes (e.g., deck runs out).
	_hand_container.display_hand(new_hand)
	_hand_container.visible = true


func _on_card_replaced(card_index: int, new_card_data: CardData) -> void:
	# This is called when a single card is replaced.
	# We tell the hand controller to replace the card visual.
	_hand_container.replace_card_at_index(card_index, new_card_data)
	# And then we make the hand visible again.
	_hand_container.visible = true


func _on_hand_container_card_played(card: Card) -> void:
	# This function now only INITIATES an action.
	
	# Prevent starting a new action if one is already in progress.
	if is_instance_valid(_card_in_play):
		return

	# First, check if the card is properly configured with data and an effect.
	if not is_instance_valid(card.card_data) or not is_instance_valid(card.card_data.effect):
		push_error("Card is missing its CardData or a CardEffect resource.")
		return

	# Get the cost from the card's effect resource.
	var card_cost: int = card.card_data.effect.get_cost()

	# Check if the player can afford to play the card.
	if not GameManager.player_data.can_afford(card_cost):
		if OS.is_debug_build():
			print("Cannot afford card. Cost: %d, Player Gold: %d" % [card_cost, GameManager.player_data.currency])
		return

	# Set this card as the one "in play".
	_card_in_play = card
	
	# Hide the entire hand container.
	_hand_container.visible = false
	
	# Execute the card's effect (which will trigger build mode, etc.).
	if card.card_data.effect:
		card.card_data.effect.execute({})


# --- PRIVATE METHODS ---


func _toggle_cards(should_expand: bool, animate: bool = true) -> void:
	# This function is a simple wrapper that delegates the work.
	
	# Don't start a new transition if one is already in progress.
	if _is_transitioning:
		return

	# Update the state immediately.
	_is_expanded = should_expand
	_is_transitioning = true
	
	# Tell the HandController to animate the cards to their new layout.
	# We 'await' its completion signal before allowing another transition.
	await _hand_container.update_card_positions(_is_expanded, animate)
	
	# The transition is complete.
	_is_transitioning = false
