extends Node

## Bootstrapper for the SPA Architecture.
## Instead of locking Godot's run/main_scene to the MainMenu (which bypasses the shell),
## we boot this empty node, which immediately tells the SceneManager to inject the
## main menu into the persistent GameWindow shell.

func _ready() -> void:
    # Small delay to ensure all singletons (like AudioManager) have initialized
    call_deferred("_boot_game")

func _boot_game() -> void:
    SceneManager.load_scene("res://UI/MainMenu/main_menu.tscn", SceneManager.ViewType.MENU)
