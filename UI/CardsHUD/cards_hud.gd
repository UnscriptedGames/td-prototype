class_name CardsHUD
extends CanvasLayer

# --- CONSTANTS ---

const EXPANDED_SCALE: Vector2 = Vector2(1.0, 1.0)
const CONDENSED_SCALE: Vector2 = Vector2(0.4, 0.4)
const TRANSITION_DURATION: float = 0.5
const CONDENSED_MARGIN: float = 25.0
const CARD_SPACING: int = 20
const BASE_VIEWPORT_WIDTH: float = 1920.0

# --- ONREADY VARIABLES ---

@onready var _hand_container_parent: Control = $HandContainerParent
@onready var _hand_container: HandController = $HandContainerParent/HandContainer

# --- VARIABLES ---

var _card_manager: CardManager
var _is_expanded: bool = true
var _is_transitioning: bool = false

# --- BUILT-IN METHODS ---

func _ready():
	await get_tree().process_frame
	InputManager.register_cards_hud(self)
	GlobalSignals.build_mode_entered.connect(_on_build_mode_entered)
	GlobalSignals.build_mode_exited.connect(_on_build_mode_exited)

	_hand_container.add_theme_constant_override("separation", CARD_SPACING)
	_update_hand_position() # Initial position

# --- PUBLIC METHODS ---

func initialise(manager: CardManager) -> void:
	_card_manager = manager
	if _card_manager == null:
		push_error("A valid CardManager reference was not provided to CardsHUD.")
		return

	_card_manager.hand_changed.connect(_on_card_manager_hand_changed)
	_hand_container.card_played.connect(_on_hand_container_card_played)
	_hand_container.hand_display_updated.connect(on_hand_changed)

	# Initialise the CardManager to draw the hand.
	if GameManager.player_data and GameManager.player_data.deck:
		_card_manager.initialise_deck(GameManager.player_data.deck, GameManager.player_data.hand_size)
	else:
		push_error("GameManager player_data or deck not ready when CardsHUD initialised.")

func on_hand_changed() -> void:
	# Called by HandController when the hand changes.
	# We need to wait one frame for the HBoxContainer to update its size.
	await get_tree().process_frame
	_update_hand_position()
	if not _is_expanded:
		# If the hand was condensed, re-apply the condensed state to the new cards.
		_toggle_cards(false, false) # No animation

func is_position_on_a_card(screen_position: Vector2) -> bool:
	for card in _hand_container.get_children():
		if card is Card:
			if card.get_global_rect().has_point(screen_position):
				return true
	return false

func handle_global_click(event: InputEventMouseButton) -> bool:
	if _is_transitioning:
		return true # Consume clicks during transition

	# If condensed, check for click on the hand to expand
	if not _is_expanded:
		# The user wants to click on the condensed pile to expand.
		# The pile is the _hand_container.
		if _hand_container.get_global_rect().has_point(event.position):
			expand()
			return true # Handled
		# If click was elsewhere, do nothing.
		return false

	# If expanded, check for click on a card
	if is_position_on_a_card(event.position):
		# Click was on a card, let the card handle it.
		return false

	# If we reach here, it was a background click in expanded mode
	condense()
	return false # Not handled, so other UI can process it.

func expand() -> void:
	_toggle_cards(true)

func condense() -> void:
	_toggle_cards(false)

# --- SIGNAL HANDLERS ---

func _on_build_mode_entered() -> void:
	_hand_container_parent.hide()


func _on_build_mode_exited() -> void:
	_hand_container_parent.show()


func _on_card_manager_hand_changed(new_hand: Array[CardData]) -> void:
	_hand_container.display_hand(new_hand)

func _on_hand_container_card_played(card: Card) -> void:
	# Safely check if the card and its effect are valid before proceeding.
	if not is_instance_valid(card.card_data) or not is_instance_valid(card.card_data.effect):
		# Log an error if the card is improperly configured.
		push_error("Card is missing its CardData or a CardEffect resource.")
		return

	# Get the cost by calling the new function on the card's effect.
	var card_cost: int = card.card_data.effect.get_cost()

	# Check if the player has enough currency to play the card.
	if not GameManager.player_data.can_afford(card_cost):
		# In a debug build, print a message that the card is unaffordable.
		if OS.is_debug_build():
			print("Cannot afford card. Cost: %d, Player Gold: %d" % [card_cost, GameManager.player_data.currency])
		return

	# Find the index of the played card within the hand container.
	var card_index: int = _hand_container.get_children().find(card)
	# If the card isn't found, log an error.
	if card_index == -1:
		push_error("Clicked card not found in HandController.")
		return

	# If all checks pass, tell the CardManager to play the card.
	_card_manager.play_card(card_index, {})

# --- PRIVATE METHODS ---

func _update_hand_position() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_hand_container.position.x = (viewport_size.x - _hand_container.size.x) / 2
	_hand_container.position.y = (viewport_size.y - _hand_container.size.y) / 2


func _toggle_cards(should_expand: bool, animate: bool = true) -> void:
	"""
	Toggles the card display using a hybrid Tween (for layout) and
	AnimationPlayer (for visuals) to ensure stability and synchronization.
	"""
	if _is_transitioning or _hand_container.get_child_count() == 0:
		return

	_is_transitioning = true
	var duration: float = 0.4 if animate else 0.0

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var cards: Array[Node] = _hand_container.get_children()
	var card_original_size: Vector2 = cards[0].card_data.front_texture.get_size()

	# This Tween will be the master conductor for all LAYOUT properties.
	var tween: Tween = create_tween().set_parallel()

	if should_expand:
		var target_separation: float = float(CARD_SPACING)
		var final_container_width: float = (cards.size() * card_original_size.x) + ((cards.size() - 1) * target_separation)
		var final_container_height: float = card_original_size.y
		
		var container_target_size: Vector2 = Vector2(final_container_width, final_container_height)
		var container_target_pos: Vector2 = Vector2(
			(viewport_size.x - final_container_width) / 2.0,
			(viewport_size.y - final_container_height) / 2.0
		)
		
		# Animate the container's layout properties.
		tween.tween_property(_hand_container, "global_position", container_target_pos, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(_hand_container, "size", container_target_size, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_method(
			func(value: float): _hand_container.add_theme_constant_override("separation", int(value)),
			_hand_container.get_theme_constant("separation", "separation"), target_separation, duration
		)

		for i in range(cards.size()):
			var card: Card = cards[i]
			card.hover_enabled = true
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.z_index = i
			
			# Animate this card's LAYOUT property with the Tween.
			tween.tween_property(card, "custom_minimum_size", card_original_size, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			
			# Trigger this card's VISUAL animation with the AnimationPlayer.
			card.get_node("AnimationPlayer").play("expand")
	else: # Condense
		var final_card_size: Vector2 = card_original_size * CONDENSED_SCALE
		var target_separation: int = int(-final_card_size.x * 0.9)
		var final_container_width: float = (cards.size() - 1) * (final_card_size.x + target_separation) + final_card_size.x
		
		var container_target_size: Vector2 = Vector2(final_container_width, final_card_size.y)
		var relative_margin: float = (CONDENSED_MARGIN / BASE_VIEWPORT_WIDTH) * viewport_size.x
		
		var container_target_pos: Vector2 = Vector2(
			relative_margin,
			viewport_size.y - final_card_size.y - relative_margin
		)
		
		# Animate the container's layout properties.
		tween.tween_property(_hand_container, "global_position", container_target_pos, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(_hand_container, "size", container_target_size, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_method(
			func(value: float): _hand_container.add_theme_constant_override("separation", int(value)),
			_hand_container.get_theme_constant("separation", "separation"), target_separation, duration
		)
		
		for i in range(cards.size()):
			var card: Card = cards[i]
			card.hover_enabled = false
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.z_index = cards.size() - i
			
			# Animate this card's LAYOUT property with the Tween.
			tween.tween_property(card, "custom_minimum_size", final_card_size, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			
			# Trigger this card's VISUAL animation with the AnimationPlayer.
			card.get_node("AnimationPlayer").play("condense")

	await tween.finished
	
	_is_expanded = should_expand
	_is_transitioning = false
	_hand_container_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE if should_expand else Control.MOUSE_FILTER_STOP
