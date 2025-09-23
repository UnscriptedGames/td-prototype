class_name HandController
extends Control

## @description Manages the visual display and layout of the player's hand.
## It instances Card scenes, calculates their positions, and animates them.

# --- SIGNALS ---

## Emitted when a card in the hand is pressed.
signal card_played(card: Card)
## Emitted after the hand has been visually updated.
signal hand_display_updated

# --- CONSTANTS ---

## The scene used to represent a single card in the hand.
const CARD_SCENE: PackedScene = preload("res://Entities/Cards/card.tscn")

## Visual layout constants, moved from CardsHUD.
const EXPANDED_SCALE: Vector2 = Vector2(1.0, 1.0)
const CONDENSED_SCALE: Vector2 = Vector2(0.4, 0.4)
const TRANSITION_DURATION: float = 0.4
const CONDENSED_MARGIN: float = 25.0
const CARD_SPACING: int = 20
const BASE_VIEWPORT_WIDTH: float = 1920.0


# --- PUBLIC METHODS ---

func display_hand(new_hand: Array[CardData]) -> void:
	# First, remove all the old card visuals.
	clear_hand()

	# Loop through each card in the new hand data.
	for card_data in new_hand:
		# Create a new instance of our Card scene.
		var new_card: Card = CARD_SCENE.instantiate()

		# Add the new card instance as a child of this container.
		add_child(new_card)
		
		# Connect to the new card's pressed signal.
		new_card.card_pressed.connect(_on_card_pressed)

		# Now that it's in the scene tree, populate it with data.
		new_card.display(card_data)

	# CORRECTED: Emit the signal only ONCE, after the loop is finished.
	hand_display_updated.emit()


func update_card_positions(is_expanded: bool, animate: bool) -> Signal:
	## Calculates and applies card layouts by sizing and positioning this container.
	var cards: Array[Node] = get_children()

	# --- START DEBUGGING BLOCK ---
	if OS.is_debug_build() and not cards.is_empty():
		print("--- Running Card Layout Calculation ---")
		print("Number of cards: ", cards.size())
		var first_card: Card = cards[0]
		if is_instance_valid(first_card) and is_instance_valid(first_card.card_data):
			var card_texture: Texture2D = first_card.card_data.front_texture
			if is_instance_valid(card_texture):
				print("Card texture resource path: ", card_texture.resource_path)
				print("REPORTED CARD SIZE: ", card_texture.get_size())
			else:
				print("ERROR: Card texture is not valid.")
		else:
			print("ERROR: First card or its data is not valid.")
		print("------------------------------------")
	# --- END DEBUGGING BLOCK ---
	
	# Get required nodes and screen dimensions.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# If there are no cards, return an instantly-finished signal.
	if cards.is_empty():
		var timer := get_tree().create_timer(0.0)
		return timer.timeout

	# Create a parallel tween to animate all nodes at once.
	var tween: Tween = create_tween().set_parallel()
	var duration: float = TRANSITION_DURATION if animate else 0.0

	# Get the base size of a card from its texture.
	var card_original_size: Vector2 = cards[0].card_data.front_texture.get_size()

	# --- LAYOUT CALCULATION ---
	if is_expanded:
		# 1. Calculate the required size for this container based on its children.
		var total_hand_width: float = (cards.size() * card_original_size.x) + ((cards.size() - 1) * CARD_SPACING)
		var container_target_size := Vector2(total_hand_width, card_original_size.y)
		
		# 2. Calculate the centered position based on the container's new size.
		var container_target_pos: Vector2 = Vector2(
			(viewport_size.x - container_target_size.x) / 2.0,
			(viewport_size.y - container_target_size.y) / 2.0
		)
		
		# 3. Animate this container's size and local position.
		tween.tween_property(self, "size", container_target_size, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", container_target_pos, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

		# 4. Loop through each card and position it locally within this container.
		for i in range(cards.size()):
			var card: Card = cards[i]
			card.hover_enabled = true
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.z_index = i
			
			# Card's local position starts at (0, 0) for the first card.
			var card_target_pos := Vector2(i * (card_original_size.x + CARD_SPACING), 0)
			
			tween.tween_property(card, "position", card_target_pos, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", EXPANDED_SCALE, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			card.get_node("AnimationPlayer").play("expand")
	else: # Condense
		# 1. Calculate the required size for the condensed pile.
		var final_card_size: Vector2 = card_original_size * CONDENSED_SCALE
		var target_separation: int = int(-final_card_size.x * 0.9)
		var total_hand_width: float = (cards.size() - 1) * (final_card_size.x + target_separation) + final_card_size.x
		var container_target_size := Vector2(total_hand_width, final_card_size.y)
		
		# 2. Animate this container's size. Its position is now set by CardsHUD.
		tween.tween_property(self, "size", container_target_size, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
		# 4. Loop through each card and position it locally.
		for i in range(cards.size()):
			var card: Card = cards[i]
			card.hover_enabled = false
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.z_index = cards.size() - i
			
			var card_target_pos := Vector2(i * (final_card_size.x + target_separation), 0)
			
			tween.tween_property(card, "position", card_target_pos, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", CONDENSED_SCALE, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			card.get_node("AnimationPlayer").play("condense")

	# Return the 'finished' signal from the tween for CardsHUD to await.
	return tween.finished


func replace_card_at_index(index: int, new_card_data: CardData) -> void:
	## Replaces a single card at a specific index without disturbing the others.
	var card_nodes: Array[Node] = get_children()

	# 1. Validate the index.
	if index < 0 or index >= card_nodes.size():
		push_error("Invalid index passed to replace_card_at_index().")
		return

	# 2. Get the old card and store its position.
	var old_card: Card = card_nodes[index]
	var old_position: Vector2 = old_card.position

	# 3. Remove the old card.
	old_card.queue_free()

	# 4. Create and configure the new card.
	var new_card: Card = CARD_SCENE.instantiate()
	add_child(new_card)
	new_card.card_pressed.connect(_on_card_pressed)
	new_card.display(new_card_data) # Populate with data.

	# 5. Position and order the new card.
	new_card.position = old_position
	move_child(new_card, index)


func get_condensed_size() -> Vector2:
	## Calculates and returns the target size of the container for the condensed layout.
	var cards: Array[Node] = get_children()
	if cards.is_empty():
		return Vector2.ZERO

	# This calculation must stay in sync with the one in update_card_positions().
	var card_original_size: Vector2 = cards[0].card_data.front_texture.get_size()
	var final_card_size: Vector2 = card_original_size * CONDENSED_SCALE
	var target_separation: int = int(-final_card_size.x * 0.9)
	var total_hand_width: float = (cards.size() - 1) * (final_card_size.x + target_separation) + final_card_size.x
	return Vector2(total_hand_width, final_card_size.y)


# --- PUBLIC METHODS ---

func update_buff_cards_state(tower_is_selected: bool) -> void:
	for card in get_children():
		if not card is Card:
			continue

		if card.card_data and card.card_data.effect is BuffTowerEffect:
			card.set_playable(tower_is_selected)
		else:
			card.set_playable(true)


func clear_hand() -> void:
	# Loop through all existing card nodes in the container.
	for card_node in get_children():
		# Immediately remove the node from the scene tree's list of children.
		remove_child(card_node)
		# Then, queue the node to be freed from memory at the end of the frame.
		card_node.queue_free()


# --- SIGNAL HANDLERS ---

func _on_card_pressed(card: Card) -> void:
	# Pass the signal up to the parent (CardsHUD) to handle the game logic.
	card_played.emit(card)
