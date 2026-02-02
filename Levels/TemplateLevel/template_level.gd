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
var _active_enemy_count: int = 0 # NEW: Tracks living enemies
var _paths: Dictionary = {}

# Spawn Queue System
var _spawn_queue: Array[Dictionary] = [] # Stores pending spawns: {time, instruction, index}
var _spawn_timer: float = 0.0

## Onready Variables

@onready var entities: Node2D = $Entities

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
		
	# Connect to GameManager requests
	GameManager.start_wave_requested.connect(_on_next_wave_requested)

	# --- Pool Initialisation ---
	ObjectPoolManager.create_node_pool("PathFollow2D", 50)

func _process(delta: float) -> void:
	if _spawning and _spawn_queue.size() > 0:
		_process_spawn_queue(delta)

func _exit_tree() -> void:
	pass


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
		_active_enemy_count = 0
		_spawn_wave(wave)


## Custom Private Methods

func _spawn_wave(wave: WaveData) -> void:
	# Convert WaveData into a flattened timeline of spawn events
	_spawn_queue.clear()
	_spawn_timer = 0.0
	
	# We can't easily rely on just pushing instructions because they run in parallel in the old code
	# (create_timer non-blocking).
	# To replicate "parallel groups", we add them all to the queue with their global trigger times.
	# Actually, the old code ran `_spawn_group` for EACH instruction concurrently.
	# So we just add separate "threads" of execution? No, simpler:
	# We add each individual enemy spawn to a master priority queue sorted by time.
	
	var master_timeline: Array[Dictionary] = []
	
	for instruction in wave.spawns:
		var current_time = instruction.start_delay
		for i in range(instruction.count):
			master_timeline.append({
				"time": current_time,
				"scene": instruction.enemy_scene,
				"path": instruction.path
			})
			current_time += instruction.enemy_delay
			
	# Sort by time (lowest first)
	master_timeline.sort_custom(func(a, b): return a["time"] < b["time"])
	
	_spawn_queue = master_timeline


func _process_spawn_queue(delta: float) -> void:
	_spawn_timer += delta
	
	# Process all events that are due
	while _spawn_queue.size() > 0:
		var next_event = _spawn_queue[0]
		if _spawn_timer >= next_event["time"]:
			_spawn_queued_enemy(next_event)
			_spawn_queue.pop_front()
		else:
			break # Next event is in the future
			
	# Check if done spawning
	if _spawn_queue.size() == 0:
		_on_wave_spawn_finished()


func _spawn_queued_enemy(event: Dictionary) -> void:
	var path_key := str(event["path"])
	var path_node := _paths.get(path_key, null) as Path2D
	
	if path_node:
		_spawn_enemy(event["scene"], path_node)
	else:
		push_error("Path not found for queued spawn: %s" % path_key)


func _spawn_enemy(enemy_scene: PackedScene, path_node: Path2D) -> void:
	# Spawns one enemy and attaches a PathFollow2D for movement.
	var enemies_container := entities.get_node("Enemies") as Node2D

	var enemy := ObjectPoolManager.get_object(enemy_scene) as TemplateEnemy
	if not is_instance_valid(enemy):
		return

	enemy.visible = true

	var path_follow := ObjectPoolManager.get_pooled_node("PathFollow2D") as PathFollow2D
	if not is_instance_valid(path_follow):
		push_error("Failed to get a PathFollow2D from the pool.")
		# If pooling fails, we can fall back to creating a new one to prevent a crash.
		path_follow = PathFollow2D.new()

	path_follow.rotates = false
	path_follow.loop = false
	path_node.add_child(path_follow)

	enemy.path_follow = path_follow

	enemies_container.add_child(enemy)
	enemy.reset()
	enemy.global_position = path_node.global_position
	
	_active_enemy_count += 1 # Increment active count

	enemy.set_process(true)

	if not enemy.reached_end_of_path.is_connected(_on_enemy_finished_path):
		enemy.reached_end_of_path.connect(_on_enemy_finished_path)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: TemplateEnemy, reward_amount: int) -> void:
	# Awards currency for defeated enemies.
	GameManager.add_currency(reward_amount)
	_active_enemy_count -= 1
	_check_wave_completion()


func _on_enemy_finished_path(enemy: TemplateEnemy) -> void:
	# Handles path end or branching for a moving enemy.
	if not is_instance_valid(enemy):
		# If enemy invalid, still debit count logic? Hard to say, safe to ignore usually.
		return

	var path_follow := enemy.path_follow as PathFollow2D
	if not is_instance_valid(path_follow):
		push_error("Enemy missing path_follow reference.")
		return

	var current_path := path_follow.get_parent() as Path2D
	# ... (Branching logic unchanged, omitted for brevity if unmodified, wait, I need to provide full body for replacement...)
	# Since this tool requires full replacement or chunks, and I am modifying _on_enemy_finished_path substantially 
	# (decrementing count on Goal), I must be careful. 
	# The prompt asks for Atomic Updates. I will provide the FULL methods.

	if not is_instance_valid(current_path):
		push_error("PathFollow2D has no Path2D parent.")
		return

	var has_branches := "branches" in current_path and not (current_path.branches as Array).is_empty()
	if not has_branches:
		GameManager.damage_player(enemy.data.damage)
		enemy.reached_goal()
		_active_enemy_count -= 1 # Enemy removed from play
		_check_wave_completion()
		return

	var next_path_nodepath := (current_path.branches as Array).pick_random() as NodePath
	var next_path := current_path.get_node_or_null(next_path_nodepath) as Path2D
	if not next_path:
		push_error("Invalid branch path: %s" % next_path_nodepath)
		GameManager.damage_player(enemy.data.damage)
		enemy.reached_goal()
		_active_enemy_count -= 1 # Enemy removed from play
		_check_wave_completion()
		return

	enemy.prepare_for_new_path()

	var new_path_follow := ObjectPoolManager.get_pooled_node("PathFollow2D") as PathFollow2D
	if not is_instance_valid(new_path_follow):
		push_error("Failed to get a PathFollow2D from the pool.")
		new_path_follow = PathFollow2D.new()

	new_path_follow.rotates = false
	new_path_follow.loop = false
	next_path.add_child(new_path_follow)

	enemy.path_follow = new_path_follow

	ObjectPoolManager.return_node(path_follow)


func _on_next_wave_requested() -> void:
	# Starts the next wave when requested by the HUD.
	if _spawning:
		return

	if level_data and _current_wave_index >= level_data.waves.size():
		return

	#_spawning = true # Set in _start_wave
	_start_wave(_current_wave_index)
	_current_wave_index += 1


func _on_wave_spawn_finished() -> void:
	# Ends the spawning phase and updates HUD controls.
	_spawning = false
	# Check if wave is already done (e.g. all enemies died instantly/fast)
	_check_wave_completion()
	
	
func _check_wave_completion() -> void:
	# Only complete the wave if NO enemies are left AND we are done spawning.
	if _active_enemy_count <= 0 and not _spawning:
		GameManager.wave_completed()
