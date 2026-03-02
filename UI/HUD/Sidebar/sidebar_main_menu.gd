extends VBoxContainer

## Sidebar-specific Main Menu content.
## Emits signals for the GameWindow to handle high-level navigation.

signal setlist_pressed
signal quit_pressed

@onready var setlist_button: Button = %SetlistButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	setlist_button.pressed.connect(func(): setlist_pressed.emit())
	# settings_button.pressed.connect(...) # Placeholder
	quit_button.pressed.connect(func(): quit_pressed.emit())
