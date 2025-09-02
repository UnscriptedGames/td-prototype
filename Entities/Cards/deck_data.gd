class_name DeckData
extends Resource

## @description A resource that holds a collection of CardData resources,
## representing a complete deck.


# --- EXPORT VARIABLES ---

## The array of cards that make up this deck.
@export var cards: Array[CardData]

## The texture used for the back of all cards in this deck.
@export var card_back_texture: Texture2D
