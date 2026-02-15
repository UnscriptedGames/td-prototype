extends LoadoutItem
class_name TowerData

## @description Represents a buildable entity in the Loadout.

## Tower Properties
## Note: display_name (from LoadoutItem) replaces tower_name.

@export var ghost_texture: Texture2D
@export var visual_offset: Vector2 = Vector2.ZERO

## Level-Based Stats
@export var levels: Array[TowerLevelData] = []
@export_file("*.tscn") var tower_scene_path: String

## Compatibility Getter for legacy code accessing tower_name
var tower_name: String:
	get:
		return display_name
	set(value):
		display_name = value
