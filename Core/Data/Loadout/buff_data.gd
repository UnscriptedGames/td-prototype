class_name BuffData
extends LoadoutItem

## @description Represents a temporary power-up for towers.

# --- EXPORT VARIABLES ---

## Time in seconds before the buff can be used again.
@export var cooldown: float = 10.0

## Gold required to trigger the buff (if any).
@export var gold_cost: int = 0

## The logic executed when the buff is applied.
@export var effect: BuffEffect
