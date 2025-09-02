class_name CardManager
extends Node

## @description Manages the player's deck, hand, and discard pile during a
## level. Handles the logic for drawing, playing, and discarding cards.


# --- SIGNALS ---

## Emitted when the player's hand changes (e.g., a card is drawn or played).
## The UI will listen to this to redraw the cards.
## @param new_hand: An array of CardData resources representing the new hand.
signal hand_changed(new_hand: Array[CardData])


# --- VARIABLES ---

## The current maximum number of cards the player can hold.
var _hand_size: int = 0

## An array of CardData representing the cards available to be drawn.
var _draw_pile: Array[CardData] = []

## An array of CardData representing the cards currently in the player's hand.
var _hand: Array[CardData] = []

## An array of CardData representing cards that have been played or discarded.
var _discard_pile: Array[CardData] = []

# --- PUBLIC METHODS ---

## Sets up the CardManager for a new level.
## @param deck_data: The DeckData resource containing all the cards.
## @param new_hand_size: The maximum number of cards for the hand.
func initialise_deck(deck_data: DeckData, new_hand_size: int) -> void:
	# Store the hand size for this level.
	_hand_size = new_hand_size
	
	# Clear any data from a previous level.
	_draw_pile.clear()
	_hand.clear()
	_discard_pile.clear()
	
	# Create a copy of the deck's cards to avoid modifying the original resource.
	_draw_pile = deck_data.cards.duplicate()
	
	# Shuffle the draw pile randomly.
	_draw_pile.shuffle()
	
	# Draw cards from the draw pile to fill the initial hand.
	for i in range(_hand_size):
		_draw_card()


## Plays a card from the hand, executes its effect, and draws a replacement.
## @param card_index: The index of the card to play in the _hand array.
## @param context: A dictionary of contextual data for the card's effect.
func play_card(card_index: int, context: Dictionary) -> void:
	# Check if the card_index is valid to prevent crashes.
	if card_index < 0 or card_index >= _hand.size():
		push_error("Invalid card index provided to play_card().")
		return

	# Remove the card from the hand.
	var card_to_play: CardData = _hand.pop_at(card_index)

	# Execute the card's effect with the provided context.
	if card_to_play.effect:
		card_to_play.effect.execute(context)

	# Move the played card to the discard pile.
	_discard_pile.append(card_to_play)

	# Draw a new card to replace the one that was played.
	_draw_card()


## Discards a card from the hand without playing its effect.
## @param card_index: The index of the card to discard in the _hand array.
func discard_card(card_index: int) -> void:
	# Check if the card_index is valid.
	if card_index < 0 or card_index >= _hand.size():
		push_error("Invalid card index provided to discard_card().")
		return

	# Remove the card from the hand.
	var card_to_discard: CardData = _hand.pop_at(card_index)

	# Move the card to the discard pile.
	_discard_pile.append(card_to_discard)

	# Draw a new card to replace the one that was discarded.
	_draw_card()

# --- PRIVATE METHODS ---

## Draws a single card from the draw pile and adds it to the hand.
func _draw_card() -> void:
	# Do nothing if the draw pile is empty.
	if _draw_pile.is_empty():
		return
	
	# Take the top card from the draw pile.
	var card_to_draw: CardData = _draw_pile.pop_front()
	
	# Add the card to the hand.
	_hand.append(card_to_draw)
	
	# Emit a signal to notify the UI that the hand has changed.
	hand_changed.emit(_hand)
