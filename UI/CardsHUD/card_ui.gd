class_name CardUI
extends Control

## @description Manages the visual representation of a single card in the hand.
## It takes CardData and updates its child nodes to display the information.


# --- SIGNALS ---

## Emitted when this card is clicked by the player.
signal card_pressed


# --- ONREADY VARIABLES ---

## A reference to the node that displays the card's artwork.
@onready var _card_art: TextureRect = $CardArt


# --- VARIABLES ---

## Stores the data associated with this specific card instance.
var card_data: CardData


# --- BUILT-IN METHODS ---

func _ready() -> void:
	# Connects this node's built-in mouse signals to our handler functions.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Handles mouse clicks and other GUI input on this control node.
func _gui_input(event: InputEvent) -> void:
	# Check if the input event was a left mouse button press.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# If so, emit our custom signal.
		emit_signal("card_pressed")
		# Mark the input as handled so other controls don't receive it.
		get_viewport().set_input_as_handled()


# --- PUBLIC METHODS ---

## Populates the card's visual elements based on a CardData resource.
## @param new_card_data: The resource containing the data to display.
func display(new_card_data: CardData) -> void:
	# Store the card's data for later reference.
	card_data = new_card_data
	
	# Set the texture for the card's main art.
	_card_art.texture = card_data.front_texture
	
	# Set the minimum size of this entire control node to match the art size.
	# This allows the HBoxContainer to arrange it correctly.
	if _card_art.texture:
		custom_minimum_size = _card_art.texture.get_size()

		# Set the pivot point to the bottom-center of the card.
		# This makes the hover scaling animation expand from that point.
		pivot_offset = custom_minimum_size * Vector2(0.5, 1.0)


# --- SIGNAL HANDLERS ---

## Called when the mouse cursor enters the control's rectangle.
func _on_mouse_entered() -> void:
	# Create a tween to animate a property change smoothly.
	var tween: Tween = create_tween()
	# Animate the 'scale' property from its current value to 1.1 over 0.1 seconds.
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)


## Called when the mouse cursor exits the control's rectangle.
func _on_mouse_exited() -> void:
	# Create a tween to animate the card back to its original size.
	var tween: Tween = create_tween()
	# Animate the 'scale' property back to 1.0.
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
