extends Node2D
class_name TemplateLevel

## Template Level Script: Handles wave and enemy spawning

@export var level_data: LevelData	# Level data resource containing waves
@export var level_number: int = 1	# The number of this level

## Wave State
var _current_wave_index: int = 0	# Current wave index
var _spawning: bool = false	# True if currently spawning enemies

## Node References
@onready var entities := $Entities # Container for all spawned entities

## Path Cache
var _paths: Dictionary = {}	# Cached Path2D nodes for quick lookup


## This is now only called AFTER the scene is in the tree and ready.
func _ready() -> void:
	print("LEVEL: _ready() has started.")
	# Cache all Path2D nodes using a relative path string as the key
	var paths_node: Node2D = get_node("Paths")
	for child in paths_node.get_children():
		if child is Path2D:
			var key_string := "%s/%s" % [paths_node.name, child.name]
			_paths[key_string] = child

	# Start the first wave
	if level_data and not level_data.waves.is_empty():
		GameManager.set_level(level_number, level_data.waves.size())
		_start_wave(0)


## Starts a wave by index
func _start_wave(wave_index: int) -> void:
	if wave_index >= level_data.waves.size():
		return

	_current_wave_index = wave_index
	# Inform the GameManager which wave is starting (using 1-based for UI)
	GameManager.set_wave(_current_wave_index + 1)
	
	var wave: WaveData = level_data.waves[wave_index]
	if wave:
		_spawning = true
		_spawn_wave(wave)


## Spawns all enemy groups in a wave
func _spawn_wave(wave: WaveData) -> void:
	for spawn_instruction in wave.spawns:
		_spawn_group(spawn_instruction)


## Spawns a group of enemies along a path
func _spawn_group(spawn_instruction: SpawnInstruction) -> void:
	# Get the Path2D node for this spawn using the cache
	var path_key := str(spawn_instruction.path)
	var path_node: Path2D = _paths.get(path_key, null)
	if not path_node:
		push_error("Path not found: %s" % path_key)
		return

	# Wait for the start_delay before spawning this group
	await get_tree().create_timer(spawn_instruction.start_delay).timeout

	# Spawn the specified number of enemies with a delay between each
	for i in range(spawn_instruction.count):
		_spawn_enemy(spawn_instruction.enemy_scene, path_node)
		if i < spawn_instruction.count - 1:
			await get_tree().create_timer(spawn_instruction.enemy_delay).timeout


## Spawns a single enemy and attaches it to a path
func _spawn_enemy(enemy_scene: PackedScene, path_node: Path2D) -> void:
	# Get a reference to the container where we will place enemies
	var enemies_container: Node2D = get_node("Entities/Enemies")

	# Get an enemy from the object pool instead of instantiating
	var enemy: TemplateEnemy = ObjectPoolManager.get_object(enemy_scene) as TemplateEnemy
	if not is_instance_valid(enemy):
		return # Stop if the pool failed to provide an enemy

	# Reset the enemy to its default state before use
	enemy.reset()
	enemy.visible = true

	# Attach a PathFollow2D to move along the path
	var path_follow := PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_node.add_child(path_follow)

	# Give the enemy a reference to the PathFollow2D
	enemy.path_follow = path_follow
	# Add the enemy to our new container
	enemies_container.add_child(enemy)
	enemy.global_position = path_node.global_position
	
	# Enable processing now that the enemy is set up
	enemy.set_process(true)

	# Connect signals for path junctions and death
	enemy.reached_end_of_path.connect(_on_enemy_finished_path.bind(enemy))
	enemy.died.connect(_on_enemy_died)


## Handles enemy death and rewards
func _on_enemy_died(reward_amount: int) -> void:
	# Add currency via the GameManager
	GameManager.add_currency(reward_amount)


## Handles when an enemy reaches the end of a path or a junction
func _on_enemy_finished_path(enemy: TemplateEnemy) -> void:
	# Stop if the enemy instance is no longer valid
	if not is_instance_valid(enemy):
		return

	var path_follow: PathFollow2D = enemy.path_follow
	if not is_instance_valid(path_follow):
		push_error("Enemy missing path_follow reference at junction.")
		return

	var current_path: Path2D = path_follow.get_parent() as Path2D
	if not is_instance_valid(current_path):
		push_error("PathFollow2D has no Path2D parent at junction.")
		return

	# Check if the path has any branches to follow
	if not "branches" in current_path or (current_path.branches as Array).is_empty():
		# If no branches, the enemy reached the goal. Damage the player.
		GameManager.damage_player(1)
		# Tell the enemy to play its death animation and clean itself up
		enemy.reached_goal()
		return

	# If there are branches, move the enemy to a random new branch
	var next_path_nodepath: NodePath = (current_path.branches as Array).pick_random()
	var next_path: Path2D = current_path.get_node_or_null(next_path_nodepath) as Path2D
	
	if not next_path:
		push_error("Branch path node is not valid or was not found: %s" % next_path_nodepath)
		# If the branch is invalid, treat as reaching the goal
		GameManager.damage_player(1)
		# Tell the enemy to play its death animation and clean itself up
		enemy.reached_goal()
		return

	enemy.prepare_for_new_path()

	# Create a new PathFollow2D for the new path
	var new_path_follow := PathFollow2D.new()
	new_path_follow.rotates = false
	new_path_follow.loop = false
	next_path.add_child(new_path_follow)

	# The enemy is not reparented. It stays in the 'Entities' node.
	# We just give it the new path_follow node to track.
	enemy.path_follow = new_path_follow

	# Clean up the old path follower
	path_follow.queue_free()
