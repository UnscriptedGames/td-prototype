class_name HandController
extends HBoxContainer

## @description Manages the visual display of the player's hand. It instances
## Card scenes and emits a signal when a card is played.

# --- SIGNALS ---

## Emitted when a card in the hand is pressed.
signal card_played(card: Card)
## Emitted after the hand has been visually updated.
signal hand_display_updated

# --- CONSTANTS ---

## The scene used to represent a single card in the hand.
const CARD_SCENE: PackedScene = preload("res://Entities/Cards/card.tscn")


# --- PUBLIC METHODS ---

## Clears and redraws the hand with new card data.
## @param new_hand: An array of CardData resources to display.
func display_hand(new_hand: Array[CardData]) -> void:
	# First, remove all the old card visuals.
	_clear_hand()

	# Loop through each card in the new hand data.
	for card_data in new_hand:
		# Create a new instance of our Card scene.
		var new_card: Card = CARD_SCENE.instantiate()

		# Add the new card instance as a child of this container FIRST.
		# This ensures its @onready variables are initialised.
		add_child(new_card)
		
		# Connect to the new card's pressed signal.
		new_card.card_pressed.connect(_on_card_pressed)

		# Now that it's in the scene tree, call the display function.
		new_card.display(card_data)

	# Emit a signal to notify parent that the hand has been updated.
	hand_display_updated.emit()

# --- PRIVATE METHODS ---

## Clears all cards from the hand display.
func _clear_hand() -> void:
	# Loop through all existing card nodes in the container.
	for card_node in get_children():
		# Remove the node from the scene and free it from memory.
		card_node.queue_free()

# --- SIGNAL HANDLERS ---

## Called when a specific Card instance emits its card_pressed signal.
## @param card: The specific Card node that was clicked.
func _on_card_pressed(card: Card) -> void:
	# Emit a signal to let the parent controller handle the logic.
	card_played.emit(card)
