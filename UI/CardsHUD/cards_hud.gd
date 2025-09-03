class_name CardsHUD
extends CanvasLayer

# --- CONSTANTS ---

const EXPANDED_SCALE: Vector2 = Vector2(1.0, 1.0)
const CONDENSED_SCALE: Vector2 = Vector2(0.4, 0.4)
const TRANSITION_DURATION: float = 0.5
const CONDENSED_MARGIN: float = 25.0
const CARD_SPACING: int = 20

# --- ONREADY VARIABLES ---

@onready var _background_click_detector: Control = $BackgroundClickDetector
@onready var _hand_container_parent: Control = $HandContainerParent
@onready var _hand_container: HBoxContainer = $HandContainerParent/HandContainer

# --- VARIABLES ---

var _card_manager: CardManager
var _is_expanded: bool = true
var _is_transitioning: bool = false

# --- BUILT-IN METHODS ---

func _ready() -> void:
	_background_click_detector.gui_input.connect(
		func(event):
			print("Background received input event: ", event.as_text())
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				print("Mouse button pressed on background.")
				if _is_expanded and not _is_transitioning:
					print("Condensing cards...")
					_condense_cards()
				else:
					print("State check failed: is_expanded=", _is_expanded, ", is_transitioning=", _is_transitioning)
	)
	_hand_container.gui_input.connect(
		func(event):
			print("Hand container received input event: ", event.as_text())
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				print("Mouse button pressed on hand container.")
				if not _is_expanded and not _is_transitioning:
					print("Expanding cards...")
					_expand_cards()
				else:
					print("State check failed: is_expanded=", _is_expanded, ", is_transitioning=", _is_transitioning)
	)
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
	if GameManager.player_data.deck:
		_card_manager.initialise_deck(GameManager.player_data.deck, GameManager.player_data.hand_size)

func on_hand_changed() -> void:
	# Called by HandController when the hand changes.
	# We need to wait one frame for the HBoxContainer to update its size.
	await get_tree().process_frame
	_update_hand_position()
	if not _is_expanded:
		# If the hand was condensed, re-apply the condensed state to the new cards.
		_toggle_cards(false, false) # No animation

# --- SIGNAL HANDLERS ---

func _on_card_manager_hand_changed(new_hand: Array[CardData]) -> void:
	_hand_container.display_hand(new_hand)

func _on_hand_container_card_played(card_ui: CardUI) -> void:
	if not GameManager.player_data.can_afford(card_ui.card_data.cost):
		print("Cannot afford card")
		return

	var card_index: int = _hand_container.get_children().find(card_ui)
	if card_index == -1:
		push_error("Clicked card not found in HandController.")
		return

	_card_manager.play_card(card_index, {})

# --- PRIVATE METHODS ---

func _update_hand_position() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_hand_container.position.x = (viewport_size.x - _hand_container.size.x) / 2
	_hand_container.position.y = (viewport_size.y - _hand_container.size.y) / 2

func _toggle_cards(expand: bool, animate: bool = true) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	var tween: Tween = create_tween().set_parallel()

	var duration = TRANSITION_DURATION if animate else 0.0

	var target_scale = CONDENSED_SCALE if not expand else EXPANDED_SCALE
	var target_separation: float
	var target_position: Vector2

	if expand:
		target_separation = float(CARD_SPACING)
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var container_width = _hand_container.size.x
		target_position = Vector2((viewport_size.x - container_width) / 2, (viewport_size.y - _hand_container.size.y) / 2)
	else:
		var card_width = 0
		if _hand_container.get_child_count() > 0:
			var first_card = _hand_container.get_child(0)
			if first_card is CardUI:
				card_width = first_card.size.x

		target_separation = -card_width * 0.9

		var condensed_width = (_hand_container.get_child_count() - 1) * (card_width + target_separation) + card_width
		condensed_width *= target_scale.x
		var condensed_height = _hand_container.size.y * target_scale.y

		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		target_position = Vector2(
			viewport_size.x - condensed_width - CONDENSED_MARGIN,
			viewport_size.y - condensed_height - CONDENSED_MARGIN
		)

	tween.tween_property(_hand_container, "position", target_position, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# There is no "theme_override_constants/separation" property to tween.
	# I will tween a dummy property and use a callback to set the separation.
	tween.tween_method(
		func(value): _hand_container.add_theme_constant_override("separation", value),
		_hand_container.get_theme_constant("separation"),
		target_separation,
		duration
	)

	for i in range(_hand_container.get_child_count()):
		var card = _hand_container.get_child(i)
		if card is CardUI:
			card.hover_enabled = expand
			card.z_index = _hand_container.get_child_count() - i if not expand else 0
			tween.tween_property(card, "scale", target_scale, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	await tween.finished
	_is_expanded = expand
	_is_transitioning = false
	_hand_container_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE if expand else Control.MOUSE_FILTER_STOP

func _expand_cards() -> void:
	_toggle_cards(true)

func _condense_cards() -> void:
	_toggle_cards(false)
