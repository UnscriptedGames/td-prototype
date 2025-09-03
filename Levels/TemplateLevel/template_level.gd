# res://levels/template_level.gd
class_name TemplateLevel
extends Node2D

## Template level: manages waves, spawns enemies, and syncs HUD scale to camera zoom.

## Exported Variables

@export var level_data: LevelData
@export var level_number: int = 1

## Regular Variables

var _current_wave_index: int = 0
var _spawning: bool = false
var _pending_group_spawns: int = 0
var _paths: Dictionary = {}

## Onready Variables

@onready var entities: Node2D = $Entities
@onready var _level_hud: LevelHUD = $LevelHUD as LevelHUD
@onready var _card_manager: CardManager = $CardManager
@onready var _cards_hud: CardsHUD = $CardsHUD as CardsHUD

## Built-in Methods

func _ready() -> void:
	# Cache Path2D nodes using "Paths/Name" keys for quick lookup.
	var paths_node := $Paths as Node2D
	for child in paths_node.get_children():
		if child is Path2D:
			var key_string := "%s/%s" % [paths_node.name, child.name]
			_paths[key_string] = child

	# Register level metadata so the HUD shows total waves.
	if level_data:
		GameManager.set_level(level_number, level_data)

	# --- Card System Initialisation ---
	# Initialise the CardsHUD with a reference to the CardManager.
	_cards_hud.initialise(_card_manager)

	# Register the LevelHUD with the InputManager
	if is_instance_valid(_level_hud):
		InputManager.register_level_hud(_level_hud)
		
	# Prepare HUD button state and connect the wave request signal.
	if is_instance_valid(_level_hud):
		if level_data and _current_wave_index < level_data.waves.size():
			_level_hud.set_next_wave_enabled(true)
			_level_hud.set_next_wave_text("Begin")
		else:
			_level_hud.set_next_wave_enabled(false)
			_level_hud.set_next_wave_text("Final Wave")

		_level_hud.next_wave_requested.connect(_on_next_wave_requested)
	else:
		if OS.is_debug_build():
			push_warning("LevelHUD not found in TemplateLevel.")

	
func _exit_tree() -> void:
	# Disconnect HUD signals to avoid leaks in recycled scenes.
	if is_instance_valid(_level_hud):
		if _level_hud.next_wave_requested.is_connected(_on_next_wave_requested):
			_level_hud.next_wave_requested.disconnect(_on_next_wave_requested)


## Custom Public Methods

func _start_wave(wave_index: int) -> void:
	# Starts spawning for a specific wave index.
	if wave_index >= level_data.waves.size():
		return

	GameManager.set_wave(wave_index + 1)

	_current_wave_index = wave_index
	var wave := level_data.waves[wave_index] as WaveData
	if wave:
		_spawning = true
		_spawn_wave(wave)


## Custom Private Methods

func _spawn_wave(wave: WaveData) -> void:
	# Starts all spawn groups in a wave.
	_pending_group_spawns = wave.spawns.size()
	if _pending_group_spawns <= 0:
		_on_wave_spawn_finished()
		return

	for spawn_instruction in wave.spawns:
		_spawn_group(spawn_instruction)


func _spawn_group(spawn_instruction: SpawnInstruction) -> void:
	# Spawns a group of enemies along a path with delays.
	var path_key := str(spawn_instruction.path)
	var path_node := _paths.get(path_key, null) as Path2D
	if not path_node:
		push_error("Path not found: %s" % path_key)
		_on_group_spawn_finished()
		return

	await get_tree().create_timer(spawn_instruction.start_delay).timeout

	for i in range(spawn_instruction.count):
		_spawn_enemy(spawn_instruction.enemy_scene, path_node)
		if i < spawn_instruction.count - 1:
			await get_tree().create_timer(spawn_instruction.enemy_delay).timeout

	_on_group_spawn_finished()


func _spawn_enemy(enemy_scene: PackedScene, path_node: Path2D) -> void:
	# Spawns one enemy and attaches a PathFollow2D for movement.
	var enemies_container := entities.get_node("Enemies") as Node2D

	var enemy := ObjectPoolManager.get_object(enemy_scene) as TemplateEnemy
	if not is_instance_valid(enemy):
		return

	enemy.visible = true

	var path_follow := PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_node.add_child(path_follow)

	enemy.path_follow = path_follow

	enemies_container.add_child(enemy)
	enemy.reset()
	enemy.global_position = path_node.global_position

	enemy.set_process(true)

	if not enemy.reached_end_of_path.is_connected(_on_enemy_finished_path):
		enemy.reached_end_of_path.connect(_on_enemy_finished_path)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: TemplateEnemy, reward_amount: int) -> void:
	# Awards currency for defeated enemies.
	GameManager.add_currency(reward_amount)


func _on_enemy_finished_path(enemy: TemplateEnemy) -> void:
	# Handles path end or branching for a moving enemy.
	if not is_instance_valid(enemy):
		return

	var path_follow := enemy.path_follow as PathFollow2D
	if not is_instance_valid(path_follow):
		push_error("Enemy missing path_follow reference.")
		return

	var current_path := path_follow.get_parent() as Path2D
	if not is_instance_valid(current_path):
		push_error("PathFollow2D has no Path2D parent.")
		return

	var has_branches := "branches" in current_path and not (current_path.branches as Array).is_empty()
	if not has_branches:
		GameManager.damage_player(enemy.data.damage)
		enemy.reached_goal()
		return

	var next_path_nodepath := (current_path.branches as Array).pick_random() as NodePath
	var next_path := current_path.get_node_or_null(next_path_nodepath) as Path2D
	if not next_path:
		push_error("Invalid branch path: %s" % next_path_nodepath)
		GameManager.damage_player(enemy.data.damage)
		enemy.reached_goal()
		return

	enemy.prepare_for_new_path()

	var new_path_follow := PathFollow2D.new()
	new_path_follow.rotates = false
	new_path_follow.loop = false
	next_path.add_child(new_path_follow)

	enemy.path_follow = new_path_follow

	path_follow.queue_free()


func _on_next_wave_requested() -> void:
	# Starts the next wave when requested by the HUD.
	if _spawning:
		return

	if level_data and _current_wave_index >= level_data.waves.size():
		if is_instance_valid(_level_hud):
			_level_hud.set_next_wave_enabled(false)
			_level_hud.set_next_wave_text("Final Wave")
		return

	_spawning = true
	if is_instance_valid(_level_hud):
		_level_hud.set_next_wave_enabled(false)
		_level_hud.set_next_wave_text("Spawning")

	_start_wave(_current_wave_index)
	_current_wave_index += 1


func _on_group_spawn_finished() -> void:
	# Tracks completion of a spawn group.
	_pending_group_spawns -= 1
	if _pending_group_spawns <= 0:
		_on_wave_spawn_finished()


func _on_wave_spawn_finished() -> void:
	# Ends the spawning phase and updates HUD controls.
	_spawning = false
	if not is_instance_valid(_level_hud):
		return

	var has_more := level_data and _current_wave_index < level_data.waves.size()
	if not has_more:
		_level_hud.set_next_wave_enabled(false)
		_level_hud.set_next_wave_text("Final Wave")
		return

	_level_hud.set_next_wave_enabled(true)
	_level_hud.set_next_wave_text("Next Wave")
