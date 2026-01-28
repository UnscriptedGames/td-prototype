extends Node

## @description An autoload singleton for broadcasting game-wide signals.
## This allows disconnected systems to communicate with each other.


# --- SIGNALS ---

## Emitted when a card effect requests to build a tower.
## The BuildManager will listen for this.
## @param tower_data: The TowerData resource for the tower to be built.
@warning_ignore("unused_signal")
signal build_tower_requested(tower_data: TowerData, tower_scene: PackedScene)

## Emitted by the BuildManager when it enters build mode.
## The CardsHUD will listen for this to hide the cards.
@warning_ignore("unused_signal")
signal build_mode_entered

## Emitted by the BuildManager when it exits build mode.
## The CardsHUD will listen for this to show the cards again.
@warning_ignore("unused_signal")
signal build_mode_exited

## Emitted when an action occurs that should condense the hand.
@warning_ignore("unused_signal")
signal hand_condense_requested

## Emitted by a card-handling system (e.g., BuildManager) when the player
## SUCCESSFULLY completes the card's action.
@warning_ignore("unused_signal")
signal card_effect_completed

## Emitted by a card-handling system (e.g., BuildManager) when the player
## ABORTS the card's action.
@warning_ignore("unused_signal")
signal card_effect_cancelled
