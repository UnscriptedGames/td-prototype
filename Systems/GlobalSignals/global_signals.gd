extends Node

## @description An autoload singleton for broadcasting game-wide signals.
## This allows disconnected systems to communicate with each other.


# --- SIGNALS ---

## Emitted when a card effect requests to build a tower.
## The BuildManager will listen for this.
## @param tower_data: The TowerData resource for the tower to be built.
signal build_tower_requested(tower_data: TowerData)
