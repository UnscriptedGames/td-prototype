class_name CardEffect
extends Resource

## @description A base resource for all card abilities.
## Specific card effects should inherit from this class and override the
## execute() method with their unique logic.


# --- VIRTUAL METHODS ---

## Returns the currency cost to play the card.
## This is a virtual method intended to be overridden by child classes.
## @return The cost of the card effect as an integer.
func get_cost() -> int:
	# Prints a warning if the base method is ever called directly.
	push_warning("Base CardEffect get_cost() method called. This should be overridden.")
	# Returns a default value of 0 if not implemented by a child class.
	return 0


## Executes the primary logic of the card effect.
## This is a virtual method intended to be overridden by child classes.
## @param context: A dictionary containing targeting and state info.
func execute(_context: Dictionary) -> void:
	# Prints a warning if the base method is ever called directly.
	push_warning("Base CardEffect execute() method called. This should be overridden.")
