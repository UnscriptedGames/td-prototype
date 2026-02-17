class_name TargetPriorityInspector
extends PanelContainer

## Sub-panel for selecting a tower's target priority.
##
## Displays a list of radio-style CheckButtons representing the available
## targeting strategies. Emits [signal priority_changed] when the user
## selects a new option.

signal priority_changed(priority: TargetPriority.Priority)

@onready var most_progress_check: CheckButton = $Content/VBox/MostProgress
@onready var least_progress_check: CheckButton = $Content/VBox/LeastProgress
@onready var strongest_check: CheckButton = $Content/VBox/Strongest
@onready var weakest_check: CheckButton = $Content/VBox/Weakest
@onready var lowest_health_check: CheckButton = $Content/VBox/LowestHealth

var _check_buttons: Array[CheckButton] = []

func _ready() -> void:
	# Cache all priority buttons for batch operations.
	_check_buttons = [
		most_progress_check, least_progress_check, strongest_check,
		weakest_check, lowest_health_check
	]
	
	for btn: CheckButton in _check_buttons:
		btn.toggled.connect(_on_toggled)

func set_priority(priority: TargetPriority.Priority) -> void:
	# Updates the visual state to reflect the given priority without emitting signals.
	for btn: CheckButton in _check_buttons:
		btn.set_block_signals(true)
		btn.button_pressed = false
		
	match priority:
		TargetPriority.Priority.MOST_PROGRESS: most_progress_check.button_pressed = true
		TargetPriority.Priority.LEAST_PROGRESS: least_progress_check.button_pressed = true
		TargetPriority.Priority.STRONGEST_ENEMY: strongest_check.button_pressed = true
		TargetPriority.Priority.WEAKEST_ENEMY: weakest_check.button_pressed = true
		TargetPriority.Priority.LOWEST_HEALTH: lowest_health_check.button_pressed = true
		
	for btn: CheckButton in _check_buttons:
		btn.set_block_signals(false)

func _on_toggled(toggled_on: bool) -> void:
	# Maps the currently-pressed button to its priority enum and emits.
	if not toggled_on:
		return
	
	var priority: TargetPriority.Priority = TargetPriority.Priority.MOST_PROGRESS
	
	if most_progress_check.button_pressed: priority = TargetPriority.Priority.MOST_PROGRESS
	elif least_progress_check.button_pressed: priority = TargetPriority.Priority.LEAST_PROGRESS
	elif strongest_check.button_pressed: priority = TargetPriority.Priority.STRONGEST_ENEMY
	elif weakest_check.button_pressed: priority = TargetPriority.Priority.WEAKEST_ENEMY
	elif lowest_health_check.button_pressed: priority = TargetPriority.Priority.LOWEST_HEALTH
	
	priority_changed.emit(priority)
