extends Node2D
## Base level script: handles wave and enemy spawning.

@export var level_data: LevelData

var _current_wave: int = 0
var _spawning: bool = false

## Cache for path nodes, used for initial spawning.
var _paths: Dictionary = {}


func _ready() -> void:
	## Cache all Path2D nodes in the scene for quick lookup during spawning.
	for child in get_node("Paths").get_children():
		if child is Path2D:
			_paths["Paths/" + child.name] = child

	## Start the first wave if level_data is assigned.
	if level_data and not level_data.waves.is_empty():
		_start_wave(0)


func _start_wave(wave_index: int) -> void:
	if wave_index >= level_data.waves.size():
		return

	_current_wave = wave_index
	var wave: WaveData = level_data.waves[wave_index]
	if wave:
		_spawning = true
		_spawn_wave(wave)


func _spawn_wave(wave: WaveData) -> void:
	## Spawn all enemy groups in the wave.
	for spawn_instruction in wave.spawns:
		_spawn_group(spawn_instruction)


func _spawn_group(spawn_instruction: SpawnInstruction) -> void:
	## Get the Path2D node for this spawn using the cache.
	var path_key := str(spawn_instruction.path)
	var path_node: Path2D = _paths.get(path_key, null)
	if not path_node:
		push_error("Path not found: %s" % path_key)
		return

	## Wait for the start_delay before spawning this group.
	await get_tree().create_timer(spawn_instruction.start_delay).timeout

	## Spawn the specified number of enemies with a delay between each.
	for i in range(spawn_instruction.count):
		_spawn_enemy(spawn_instruction.enemy_scene, path_node)
		if i < spawn_instruction.count - 1:
			await get_tree().create_timer(spawn_instruction.enemy_delay).timeout


func _spawn_enemy(enemy_scene: PackedScene, path_node: Path2D) -> void:
	var enemy: BaseEnemy = enemy_scene.instantiate() as BaseEnemy

	## Attach a PathFollow2D to move along the path.
	var path_follow := PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_node.add_child(path_follow)

	## Use direct property access for type safety.
	enemy.path_follow = path_follow
	
	path_follow.add_child(enemy)
	enemy.global_position = path_node.global_position

	## Connect signals for path junctions and death.
	enemy.reached_end_of_path.connect(_on_enemy_reached_junction.bind(enemy))
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(reward_amount: int) -> void:
	## For now, we just print the reward.
	## Later, this will connect to the GameManager.
	if OS.is_debug_build():
		print("Enemy died! Player receives %d gold." % reward_amount)
	# GameManager.add_currency(reward_amount)


func _on_enemy_reached_junction(enemy: BaseEnemy) -> void:
	if enemy.is_dying():
		return

	var path_follow: PathFollow2D = enemy.path_follow
	if not is_instance_valid(path_follow):
		push_error("Enemy missing path_follow reference at junction.")
		return

	var current_path: Path2D = path_follow.get_parent() as Path2D
	if not is_instance_valid(current_path):
		push_error("PathFollow2D has no Path2D parent at junction.")
		return

	## Check if the current_path node has the 'branches' property from our attached script.
	if not "branches" in current_path or (current_path.branches as Array).is_empty():
		enemy.die() # If there are no branches defined, the enemy dies.
		return

	## Move to a random new branch using the direct NodePath.
	var next_path_nodepath: NodePath = (current_path.branches as Array).pick_random()
	var next_path: Path2D = current_path.get_node_or_null(next_path_nodepath) as Path2D
	
	if not next_path:
		push_error("Branch path node is not valid or was not found: %s" % next_path_nodepath)
		enemy.die()
		return

	enemy.prepare_for_new_path()

	var new_path_follow := PathFollow2D.new()
	new_path_follow.rotates = false
	new_path_follow.loop = false
	next_path.add_child(new_path_follow)

	var last_position: Vector2 = enemy.global_position

	path_follow.remove_child(enemy)
	new_path_follow.add_child(enemy)
	enemy.path_follow = new_path_follow
	enemy.global_position = last_position

	path_follow.queue_free()
