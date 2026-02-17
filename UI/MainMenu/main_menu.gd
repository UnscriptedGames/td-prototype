extends Control

## Main menu screen.
##
## Provides a single "Start Game" button that resets [GameManager] state
## and transitions to Level 01 via [SceneManager].

@onready var start_button: Button = $StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)


func _on_start_button_pressed() -> void:
	# Resets game state and loads the first level.
	GameManager.reset_state()
	SceneManager.load_scene("res://Levels/Level01/level_01.tscn")
