class_name BuildTowerEffect
extends CardEffect

## @description An effect that requests the BuildManager to start the tower
## placement process for a specific tower.


# --- EXPORT VARIABLES ---

## The data for the tower that this effect will build.
@export var tower_data: TowerData


# --- VIRTUAL METHOD OVERRIDES ---

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

	# Emit the global signal, passing along the specific tower data.
	GlobalSignals.build_tower_requested.emit(tower_data)
