class_name CardData
extends Resource

## @description Stores all the static data for a single card, such as its
## name, cost, and visual representation. It links to a CardEffect resource
## that defines its behaviour.


# --- EXPORT VARIABLES ---

## The currency cost to play this card.
@export var cost: int = 1

## The texture used for the front face of the card.
@export var front_texture: Texture2D

## A reference to the CardEffect resource that runs when this card is played.
@export var effect: CardEffect
