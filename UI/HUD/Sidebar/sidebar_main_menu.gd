extends VBoxContainer

## Sidebar-specific Main Menu content.
## Emits signals for the GameWindow to handle high-level navigation.

signal studio_pressed
signal setlist_pressed
signal quit_pressed

@onready var studio_button: Button = %StudioButton
@onready var setlist_button: Button = %SetlistButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	studio_button.pressed.connect(func(): studio_pressed.emit())
	setlist_button.pressed.connect(func(): setlist_pressed.emit())
	# settings_button.pressed.connect(...) # Placeholder
	quit_button.pressed.connect(func(): quit_pressed.emit())


func _exit_tree() -> void:
	if is_instance_valid(studio_button):
		for conn in studio_button.pressed.get_connections():
			studio_button.pressed.disconnect(conn["callable"])

	if is_instance_valid(setlist_button):
		for conn in setlist_button.pressed.get_connections():
			setlist_button.pressed.disconnect(conn["callable"])

	if is_instance_valid(quit_button):
		for conn in quit_button.pressed.get_connections():
			quit_button.pressed.disconnect(conn["callable"])
