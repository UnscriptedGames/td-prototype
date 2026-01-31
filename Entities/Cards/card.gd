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
var hover_enabled: bool = false

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

## Handles the start of a drag operation.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_playable or not card_data:
		return null
		
	# Create a visual preview of the card being dragged
	var preview_control = Control.new()
	var preview_texture = TextureRect.new()
	
	preview_texture.texture = card_data.front_texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.size = Vector2(162, 224) # Match grid size
	
	# Align the preview so it matches the exact position of the original card relative to the mouse
	# _at_position is the local mouse position within the card control
	preview_texture.position = - _at_position
	
	# User Request: Drag preview should look like the "real" card (Opaque)
	preview_texture.modulate = Color(1, 1, 1, 1.0)
	
	preview_control.add_child(preview_texture)
	set_drag_preview(preview_control)
	
	var card_data_dict = {
		"type": "card_drag",
		"card": self,
		"card_data": card_data,
		"preview": preview_control,
		"drag_id": Time.get_ticks_msec() + get_instance_id() # Unique Session ID
	}
	
	# User Request: Hide mouse cursor during drag
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Ensure preview blocks nothing
	preview_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Hide the card in the hand (visual feedback)
	modulate.a = 0.5
	
	return card_data_dict

func reset_drag_visuals() -> void:
	# Resets the visual state of the card (e.g. if drag is cancelled externally)
	modulate.a = 1.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# --- Drag Fix ---
# Prevent "Forbidden" cursor when hovering other cards
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "card_drag":
		return true
	return false

func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	# Do nothing - just consume the drop to prevent cursor issues
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Reset opacity when drag ends
		if is_playable:
			modulate = Color.WHITE
		else:
			# Restore disabled look if needed
			modulate = Color(0.5, 0.5, 0.5, 0.8)
			
		# User Request: Show mouse cursor after drag
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


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

	# Ensure the ArtContainer fills the control
	if is_instance_valid(art_container):
		art_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		art_container.pivot_offset = size / 2.0


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
