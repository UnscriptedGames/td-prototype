extends Control

@onready var start_button: Button = $StartButton


func _ready() -> void:
	# Connect the button's pressed signal to our function.
	start_button.pressed.connect(_on_start_button_pressed)


func _on_start_button_pressed() -> void:
	# Reset the game state before starting a new session
	GameManager.reset_state()
	
	# Call our global SceneManager to handle the transition to the level.
	SceneManager.load_scene("res://Levels/Level01/level_01.tscn")
