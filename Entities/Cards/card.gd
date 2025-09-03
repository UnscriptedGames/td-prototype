class_name Card
extends Control

## @description Manages the visual representation and interaction of a single card entity.
## It takes CardData and updates its child nodes to display the information.


# --- SIGNALS ---

## Emitted when this card is clicked by the player, passing a reference to itself.
signal card_pressed(card: Card)


# --- ONREADY VARIABLES ---

## A reference to the node that displays the card's artwork.
@onready var _card_art: TextureRect = $CardArt


# --- VARIABLES ---

## Stores the data associated with this specific card instance.
var card_data: CardData

## Determines if the hover animation should play.
var hover_enabled: bool = true


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
		card_pressed.emit(self)
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

		# Set the pivot point to the bottom-center of the card for scaling effects.
		pivot_offset = custom_minimum_size * Vector2(0.5, 1.0)


## Animates the card's scale and updates its minimum size for layout.
## @param new_scale: The target scale (e.g., Vector2(0.4, 0.4)).
## @param duration: The time the animation should take.
func animate_scale(new_scale: Vector2, duration: float) -> void:
	var tween: Tween = create_tween().set_parallel()

	# Animate the visual scale of the artwork.
	tween.tween_property(_card_art, "scale", new_scale, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# Animate the layout size of the container.
	if _card_art.texture:
		var target_min_size = _card_art.texture.get_size() * new_scale
		tween.tween_property(self, "custom_minimum_size", target_min_size, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


# --- SIGNAL HANDLERS ---

## Called when the mouse cursor enters the control's rectangle.
func _on_mouse_entered() -> void:
	if not hover_enabled:
		return
	animate_scale(Vector2(1.1, 1.1), 0.1)


## Called when the mouse cursor exits the control's rectangle.
func _on_mouse_exited() -> void:
	if not hover_enabled:
		return
	animate_scale(Vector2(1.0, 1.0), 0.1)
