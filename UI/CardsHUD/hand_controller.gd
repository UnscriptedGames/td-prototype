class_name HandController
extends HBoxContainer

## @description Manages the visual display of the player's hand. It instances
## CardUI scenes and emits a signal when a card is played.

# --- SIGNALS ---

## Emitted when a card in the hand is pressed.
signal card_played(card_ui: CardUI)
## Emitted after the hand has been visually updated.
signal hand_display_updated

# --- EXPORT VARIABLES ---

## The scene used to represent a single card in the hand.
@export var card_ui_scene: PackedScene


# --- PUBLIC METHODS ---

## Clears and redraws the hand with new card data.
## @param new_hand: An array of CardData resources to display.
func display_hand(new_hand: Array[CardData]) -> void:
	# First, remove all the old card visuals.
	_clear_hand()

	# Loop through each card in the new hand data.
	for card_data in new_hand:
		# Create a new instance of our CardUI scene.
		var new_card_ui: CardUI = card_ui_scene.instantiate()

		# Add the new card instance as a child of this container FIRST.
		# This ensures its @onready variables are initialised.
		add_child(new_card_ui)
		
		# Connect to the new card's pressed signal.
		new_card_ui.card_pressed.connect(_on_card_ui_pressed.bind(new_card_ui))

		# Now that it's in the scene tree, call the display function.
		new_card_ui.display(card_data)

	# Emit a signal to notify parent that the hand has been updated.
	hand_display_updated.emit()

# --- PRIVATE METHODS ---

## Clears all cards from the hand display.
func _clear_hand() -> void:
	# Loop through all existing card UI nodes in the container.
	for card_node in get_children():
		# Remove the node from the scene and free it from memory.
		card_node.queue_free()

# --- SIGNAL HANDLERS ---

## Called when a specific CardUI instance emits its card_pressed signal.
## @param card_ui: The specific CardUI node that was clicked.
func _on_card_ui_pressed(card_ui: CardUI) -> void:
	# Emit a signal to let the parent controller handle the logic.
	card_played.emit(card_ui)
