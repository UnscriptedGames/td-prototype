class_name Card
extends Control

## @description Manages the visual representation and interaction of a single card entity.
## It takes CardData and updates its child nodes to display the information.


# --- SIGNALS ---

## Emitted when this card is clicked by the player, passing a reference to itself.
signal card_pressed(card: Card)

# --- ONREADY VARIABLES ---

## A reference to the container that holds the card's artwork.
@onready var art_container: Control = $ArtContainer
## A reference to the node that displays the card's artwork.
@onready var _card_art: TextureRect = $ArtContainer/CardArt
## A reference to the node that plays this card's animations.
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

# --- VARIABLES ---

## Stores the data associated with this specific card instance.
var card_data: CardData

## Determines if the hover animation should play.
var hover_enabled: bool = true

## Determines if the card can be played.
var is_playable: bool = true


# --- BUILT-IN METHODS ---

func _ready() -> void:
	# Connects this node's built-in mouse signals to our handler functions.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Handles mouse clicks and other GUI input on this control node.
func _gui_input(event: InputEvent) -> void:
	# Check if the input event was a left mouse button press.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# If so, emit our custom signal with a reference to this card.
		# The receiver (CardsHUD) will be responsible for checking if it's playable.
		card_pressed.emit(self)

		# If the card was immediately freed by the logic that handles the
		# 'card_pressed' signal, it won't be in the tree anymore.
		if not is_inside_tree():
			return

		# Mark the input as handled so other controls don't receive it.
		get_viewport().set_input_as_handled()


# --- PUBLIC METHODS ---

func set_playable(can_be_played: bool) -> void:
	is_playable = can_be_played
	if is_playable:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
		mouse_filter = Control.MOUSE_FILTER_PASS

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
		var art_size: Vector2 = _card_art.texture.get_size()
		custom_minimum_size = art_size

		# --- NEW LINES ---
		# Set the ArtContainer's size to match the artwork.
		art_container.size = art_size
		# Set the pivot to the center of the container for scaling effects.
		art_container.pivot_offset = art_size / 2.0


# --- SIGNAL HANDLERS ---

## Called when the mouse cursor enters the control's rectangle.
func _on_mouse_entered() -> void:
	# This function is responsible for the hover-on animation.
	if not hover_enabled:
		return

	# Play the animation we created in the editor.
	_animation_player.play("hover_on")


## Called when the mouse cursor exits the control's rectangle.
func _on_mouse_exited() -> void:
	# This function is responsible for the hover-off animation.
	if not hover_enabled:
		return

	# Play the animation we created in the editor.
	_animation_player.play("hover_off")
