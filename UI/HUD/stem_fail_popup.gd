class_name StemFailPopup
extends ColorRect

@onready var retry_button: Button = $CenterContainer/Panel/VBox/ActionHBox/RetryButton
@onready var return_button: Button = $CenterContainer/Panel/VBox/ActionHBox/ReturnButton

func _ready() -> void:
	hide()
	retry_button.pressed.connect(_on_retry_pressed)
	return_button.pressed.connect(_on_return_pressed)
	GameManager.stem_failed.connect(_on_stem_failed)

func _exit_tree() -> void:
	if is_instance_valid(GameManager) and GameManager.stem_failed.is_connected(_on_stem_failed):
		GameManager.stem_failed.disconnect(_on_stem_failed)

	if is_instance_valid(retry_button) and retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.disconnect(_on_retry_pressed)

	if is_instance_valid(return_button) and return_button.pressed.is_connected(_on_return_pressed):
		return_button.pressed.disconnect(_on_return_pressed)

func _on_stem_failed() -> void:
	# Show the popup and pause the game so the action freezes behind it.
	show()
	GameManager.set_game_state(GameManager.GameState.PAUSED)

func _on_retry_pressed() -> void:
	hide()
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	StageManager.retry_stem()

func _on_return_pressed() -> void:
	hide()
	# Unpause before unloading so the next scene works correctly.
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	StageManager.return_to_setlist()
