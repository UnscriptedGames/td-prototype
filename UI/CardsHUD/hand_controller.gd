class_name HandController
extends HBoxContainer

## @description Manages the visual display of the player's hand. It listens for
## changes from the CardManager and instances CardUI scenes accordingly.


# --- EXPORT VARIABLES ---

## The scene used to represent a single card in the hand.
@export var card_ui_scene: PackedScene


# --- VARIABLES ---

## A reference to the main CardManager.
var _card_manager: CardManager


# --- PUBLIC METHODS ---

## Sets up the HandController with a reference to the CardManager.
## This must be called by the parent scene before the game starts.
## @param manager: The CardManager instance for the current level.
func initialise(manager: CardManager) -> void:
	# Store the reference to the CardManager.
	_card_manager = manager

	# A null check to prevent a crash if the reference was not set.
	if _card_manager == null:
		push_error("A valid CardManager reference was not provided to HandController.")
		return

	# Connect to the signal that fires whenever the hand is updated.
	_card_manager.hand_changed.connect(_on_hand_changed)


# --- PRIVATE METHODS ---

## Clears all cards from the hand display.
func _clear_hand() -> void:
	# Loop through all existing card UI nodes in the container.
	for card_node in get_children():
		# Remove the node from the scene and free it from memory.
		card_node.queue_free()


# --- SIGNAL HANDLERS ---

## Called when the CardManager's hand_changed signal is emitted.
## @param new_hand: The array of CardData for the new hand.
func _on_hand_changed(new_hand: Array[CardData]) -> void:
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


## Called when a specific CardUI instance emits its card_pressed signal.
## @param card_ui: The specific CardUI node that was clicked.
func _on_card_ui_pressed(card_ui: CardUI) -> void:
	# First, check if the player can afford to play this card.
	if not GameManager.player_data.can_afford(card_ui.card_data.cost):
		print("Cannot afford card: ", card_ui.card_data.card_name)
		# In a real game, you would play an "error" sound here.
		return

	# Find the index of the clicked card within the hand container.
	var card_index: int = get_children().find(card_ui)

	# A safety check to make sure the card was found.
	if card_index == -1:
		push_error("Clicked card not found in HandController.")
		return

	# Tell the CardManager to play the card at the found index.
	# We pass an empty context dictionary for now.
	_card_manager.play_card(card_index, {})
