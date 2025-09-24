class_name BuffTowerEffect
extends CardEffect

## @description An effect that applies a temporary buff to a single, targeted
## tower, enhancing its combat statistics and/or granting status effects.

# --- EXPORT VARIABLES ---

## The gold cost to apply this buff.
@export var cost: int = 0

## The duration of the buff in seconds.
@export var duration: float = 5.0

## The flat increase in the tower's attack range.
@export var range_increase: int = 0

## The flat increase in the tower's attack damage.
@export var damage_increase: int = 0

## The flat increase in the tower's fire rate (attacks per second).
@export var fire_rate_increase: float = 0.0

## The number of additional targets the tower can attack simultaneously.
@export var extra_targets: int = 0

## An array of status effects to be temporarily applied to the tower's attacks.
@export var status_effects: Array[StatusEffectData] = []


# --- VIRTUAL METHOD OVERRIDES ---

## Returns the cost to play the card.
## @return The cost of the card effect as an integer.
func get_cost() -> int:
	return cost


## Executes the buff tower effect by emitting a global signal.
## The targeted tower's BuffManager will listen for this signal.
## @param context: A dictionary containing the 'target_tower'.
func execute(context: Dictionary) -> void:
	var target_tower = context.get("target_tower")
	if not is_instance_valid(target_tower):
		push_error("BuffTowerEffect execute failed: target_tower is not valid.")
		return

	# The BuffManager on the tower will be responsible for applying the buff.
	# We pass 'self' which is the resource instance of this effect.
	target_tower.apply_buff(self)

	# Since this effect is instantaneous, we immediately signal its completion.
	GlobalSignals.card_effect_completed.emit()
