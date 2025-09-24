class_name CardManager
extends Node

## @description Manages the player's deck, hand, and discard pile during a
## level. Handles the logic for drawing, playing, and discarding cards.


# --- SIGNALS ---

## Emitted when the player's hand changes (e.g., a card is drawn or played).
## @param new_hand: An array of CardData resources representing the new hand.
signal hand_changed(new_hand: Array[CardData])
## Emitted when a single card is played and successfully replaced from the deck.
## @param card_index: The index in the hand where the card was replaced.
## @param new_card_data: The CardData for the new card that was drawn.
signal card_replaced(card_index: int, new_card_data: CardData)


# --- VARIABLES ---

## The current maximum number of cards the player can hold.
var _hand_size: int = 0

## An array of CardData representing the cards available to be drawn.
var _draw_pile: Array[CardData] = []

## An array of CardData representing the cards currently in the player's hand.
var hand: Array[CardData] = []

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
	hand.clear()
	_discard_pile.clear()
	
	# Create a copy of the deck's cards to avoid modifying the original resource.
	_draw_pile = deck_data.cards.duplicate()
	
	# Shuffle the draw pile randomly.
	_draw_pile.shuffle()
	
	# Draw cards from the draw pile to fill the initial hand.
	# We use a temporary array to build the hand before assigning it.
	var initial_hand: Array[CardData]
	for i in range(_hand_size):
		var new_card: CardData = _draw_card()
		if new_card:
			initial_hand.append(new_card)
	
	# Assign the fully formed hand and emit the signal.
	hand = initial_hand
	hand_changed.emit(hand)


## Plays a card from the hand, executes its effect, and draws a replacement.
## @param card_index: The index of the card to play in the hand array.
## @param context: A dictionary of contextual data for the card's effect.
func play_card(card_index: int, context: Dictionary) -> void:
	# Check if the card_index is valid to prevent crashes.
	if card_index < 0 or card_index >= hand.size():
		push_error("Invalid card index provided to play_card().")
		return

	# Remove the card from the hand array. Note we don't need the object yet.
	var card_to_play: CardData = hand[card_index]

	# Move the played card to the discard pile.
	_discard_pile.append(card_to_play)

	# Draw a new card to replace the one that was played.
	var new_card: CardData = _draw_card()
	
	if new_card:
		# If a card was drawn, replace it in the hand array
		hand[card_index] = new_card
		# and emit the signal that a single card was replaced.
		card_replaced.emit(card_index, new_card)
	else:
		# If no card was drawn (deck is empty), remove the played card's
		# slot from the hand array.
		hand.pop_at(card_index)
		# and emit the signal that the entire hand has changed.
		hand_changed.emit(hand)


## Discards a card from the hand without playing its effect.
## @param card_index: The index of the card to discard in the hand array.
func discard_card(card_index: int) -> void:
	# Check if the card_index is valid.
	if card_index < 0 or card_index >= hand.size():
		push_error("Invalid card index provided to discard_card().")
		return

	# Remove the card from the hand.
	var card_to_discard: CardData = hand.pop_at(card_index)

	# Move the card to the discard pile.
	_discard_pile.append(card_to_discard)

	# Draw a new card to replace the one that was discarded.
	var new_card: CardData = _draw_card()
	if new_card:
		hand.append(new_card)

	# For simplicity, a discard always triggers a full hand redraw.
	hand_changed.emit(hand)


func get_draw_pile_count() -> int:
	## Returns the number of cards currently in the draw pile.
	return _draw_pile.size()


# --- PRIVATE METHODS ---

## Draws a single card from the draw pile.
## @return CardData if a card was drawn, null if the deck is empty.
func _draw_card() -> CardData:
	# If the draw pile is empty, return null.
	if _draw_pile.is_empty():
		return null
	
	# Take the top card from the draw pile and return it.
	var card_to_draw: CardData = _draw_pile.pop_front()
	return card_to_draw
