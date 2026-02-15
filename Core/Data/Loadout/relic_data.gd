class_name RelicData
extends LoadoutItem

## @description Represents a global modifier (Passive) and a powerful one-shot ability (Active).

# --- EXPORT VARIABLES ---

## The passive bonus always active while this relic is equipped.
@export var passive_effect: RelicEffect

## The powerful ability triggered by the user.
@export var active_effect: RelicEffect

## Gold required to trigger the active ability.
@export var gold_cost: int = 0
