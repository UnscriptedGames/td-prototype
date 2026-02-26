class_name DebugToolbar
extends MarginContainer

@onready var speed_down_btn: Button = $Panel/Controls/SpeedDownButton
@onready var speed_up_btn: Button = $Panel/Controls/SpeedUpButton
@onready var speed_label: Label = $Panel/Controls/SpeedLabel

func _ready() -> void:
	# Hide in production builds by default
	if not OS.is_debug_build():
		hide()
	
	speed_down_btn.pressed.connect(GameManager.step_speed_down)
	speed_up_btn.pressed.connect(GameManager.step_speed_up)
	
	if GameManager.has_signal("game_speed_changed"):
		GameManager.game_speed_changed.connect(_on_speed_changed)
		_on_speed_changed(Engine.time_scale)

func _on_speed_changed(new_speed: float) -> void:
	speed_label.text = "%.1fx" % new_speed
