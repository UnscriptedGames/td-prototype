extends Node

## @description A temporary script to test the CardManager's logic.


# --- EXPORT VARIABLES ---

## Assign the starter_deck.tres resource to this in the Inspector.
@export var test_deck: DeckData


# --- ONREADY VARIABLES ---

## A reference to the CardManager instance in this scene.
@onready var _card_manager: CardManager = $CardManager


# --- BUILT-IN METHODS ---

func _ready() -> void:
	# Connect to the CardManager's signal to see hand updates.
	_card_manager.hand_changed.connect(_on_hand_changed)

	# Initialise the manager with our test deck and a hand size of 5.
	_card_manager.initialise_deck(test_deck, 5)


func _input(event: InputEvent) -> void:
	# Check if the spacebar was just pressed.
	if event.is_action_pressed("ui_accept"):
		# First, check if there are any cards in the hand to play.
		if _card_manager._hand.is_empty():
			print("Hand is empty, cannot play a card.")
			return

		# Tell the manager to play the first card in the hand.
		# We pass an empty context dictionary for now.
		print("\n--- Playing card 0 ---")
		_card_manager.play_card(0, {})


# --- SIGNAL HANDLERS ---

## Called when the CardManager emits the hand_changed signal.
func _on_hand_changed(new_hand: Array[CardData]) -> void:
	# Create a temporary array to hold just the names of the cards.
	var card_names: Array[String] = []
	for card in new_hand:
		card_names.append(card.card_name)

	# Print the current hand to the output log.
	print("Hand updated: ", card_names)
