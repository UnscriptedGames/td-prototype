extends Control

## Main menu screen.
##
## Provides a single "Start Game" button that loads Stage 1 into the
## [StageManager] and transitions to the Setlist Preview screen.

const STAGE_1_PATH: String = "res://Config/Stages/stage01.tres"


func _ready() -> void:
	pass


func is_main_menu() -> bool:
	return true
