class_name BuildTowerEffect
extends CardEffect

## @description An effect that requests the BuildManager to start the tower
## placement process for a specific tower.


# --- EXPORT VARIABLES ---

## The data for the tower that this effect will build.
@export var tower_data: TowerData

## The scene for the tower that this effect will build.
@export var tower_scene: PackedScene


# --- VIRTUAL METHOD OVERRIDES ---

## Returns the cost of the tower's first level.
## @return The cost of the tower, or 0 if data is invalid.
func get_cost() -> int:
	# Check if the tower data is valid and has at least one level defined.
	if not tower_data or tower_data.levels.is_empty():
		# If data is missing, log an error and return 0 to be safe.
		push_error("BuildTowerEffect is missing TowerData or it has no levels.")
		return 0
	
	# Return the cost from the first level's data resource.
	return tower_data.levels[0].cost


## Executes the build tower effect by emitting a global signal.
## The BuildManager listens for this signal to enter build mode.
## @param context: A dictionary (unused in this specific effect).
func execute(_context: Dictionary) -> void:
	# A safety check to ensure a tower has been assigned in the editor.
	if not tower_data:
		# Pushes an error if no TowerData is assigned to this effect.
		push_error("BuildTowerEffect has no TowerData assigned.")
		# Stop the function to prevent further errors.
		return

	# Emit the global signal, passing along both the data and the scene.
	GlobalSignals.build_tower_requested.emit(tower_data, tower_scene)
