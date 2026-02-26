extends Control

## Main menu screen.
##
## Provides a single "Start Game" button that loads Stage 1 into the
## [StageManager] and transitions to the Setlist Preview screen.

const STAGE_1_PATH: String = "res://Config/Stages/stage_01.tres"

@onready var start_button: Button = $StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)


func _on_start_button_pressed() -> void:
	# Load stage data and transition to the Setlist screen.
	var stage: StageData = load(STAGE_1_PATH) as StageData
	assert(stage != null, "Failed to load StageData from: " + STAGE_1_PATH)
	StageManager.load_stage(stage)
	get_tree().change_scene_to_file("res://UI/Setlist/setlist_screen.tscn")
