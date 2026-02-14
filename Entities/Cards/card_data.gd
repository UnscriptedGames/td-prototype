class_name CardData
extends Resource

## @description Stores all the static data for a single card, such as its
## name, cost, and visual representation. It links to a CardEffect resource
## that defines its behaviour.


# --- EXPORT VARIABLES ---

## The texture used for the front face of the card.
@export var front_texture: Texture2D

## A reference to the CardEffect resource that runs when this card is played.
## A reference to the CardEffect resource that runs when this card is played.
@export var effect: CardEffect

## Loadout Properties
@export var allocation_cost: int = 5
@export var is_unlocked: bool = true

## Gameplay Properties
@export var gold_cost: int = 0
@export var cooldown: float = 0.0
