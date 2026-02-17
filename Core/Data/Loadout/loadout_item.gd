class_name LoadoutItem
extends Resource

## @description Base class for any item that can be equipped in a Loadout.
## This includes Towers, Buffs, and Relics.

# --- EXPORT VARIABLES ---

@export_group("Display")
## The user-facing name of the item.
@export var display_name: String = "Item Name"

## The icon displayed in the sidebar button.
@export var icon: Texture2D

## A brief description for tooltips.
@export_multiline var description: String = ""

@export_group("Settings")
## The "Loadout Points" required to equip this item.
@export var allocation_cost: int = 10

## Whether the player has access to this item in their collection.
@export var is_unlocked: bool = true
