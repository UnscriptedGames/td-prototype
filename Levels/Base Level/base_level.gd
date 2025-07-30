extends Node2D

## Base level script: handles wave and enemy spawning

@export var level_data: LevelData

var _current_wave: int = 0
var _spawning: bool = false

## Cache for path nodes by name
var _paths: Dictionary = {}

func _ready():
	## Cache all Path2D nodes in the scene for quick lookup
	for child in get_node("Paths").get_children():
		if child is Path2D:
			_paths["Paths/" + child.name] = child

	## Start the first wave if level_data is assigned
	if level_data and level_data.waves.size() > 0:
		_start_wave(0)

func _start_wave(wave_index: int) -> void:
	if wave_index >= level_data.waves.size():
		return

	_current_wave = wave_index
	var wave: Resource = level_data.waves[wave_index]
	if wave:
		_spawning = true
		_spawn_wave(wave)

func _spawn_wave(wave: Resource) -> void:
	## Spawn all enemy groups in the wave
	for spawn in wave.spawns:
		_spawn_group(spawn)

func _spawn_group(spawn: Resource) -> void:
	   ## Get the Path2D node for this spawn
	var path_key := str(spawn.path)
	var path_node: Path2D = _paths.get(path_key, null)
	if not path_node:
		push_error("Path not found: %s" % path_key)
		return

	## Wait for the start_delay before spawning this group
	await get_tree().create_timer(spawn.start_delay).timeout

	## Spawn the specified number of enemies with enemy_delay between each
	for i in range(spawn.count):
		_spawn_enemy(spawn.enemy_scene, path_node)
		if i < spawn.count - 1:
			await get_tree().create_timer(spawn.enemy_delay).timeout

func _spawn_enemy(enemy_scene: PackedScene, path_node: Path2D) -> void:
	var enemy = enemy_scene.instantiate()
	## Attach a PathFollow2D to move along the path
	var path_follow = PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_node.add_child(path_follow)
	path_follow.add_child(enemy)
	enemy.global_position = path_node.global_position
	enemy.set("path_follow", path_follow) # Optionally store reference for movement logic

	# Connect the enemy's reached_end_of_path signal to handle junctions
	if enemy.has_signal("reached_end_of_path"):
		enemy.connect("reached_end_of_path", Callable(self, "_on_enemy_reached_junction").bind(enemy))


func _on_enemy_reached_junction(enemy):
	if enemy.is_dying:
		return
	var path_follow = enemy.get("path_follow")
	if not path_follow:
		push_error("Enemy missing path_follow reference at junction.")
		return

	var current_path = path_follow.get_parent() as Path2D
	if not current_path:
		push_error("PathFollow2D has no Path2D parent at junction.")
		return

	var branches = []
	if current_path.has_meta("branches"):
		branches = current_path.get_meta("branches")
		if typeof(branches) == TYPE_PACKED_STRING_ARRAY:
			branches = branches as PackedStringArray
		elif typeof(branches) == TYPE_ARRAY:
			branches = branches as Array
		else:
			branches = []

	var valid_branches = []
	for branch_name in branches:
		var branch_key = "Paths/" + str(branch_name)
		if _paths.has(branch_key):
			valid_branches.append(branch_name)

	if valid_branches.size() == 0:
		enemy.die()
		return

	var next_branch_name = valid_branches[randi() % valid_branches.size()]
	var next_path_key = "Paths/" + str(next_branch_name)
	var next_path = _paths.get(next_path_key, null)
	if not next_path:
		push_error("Branch path not found: %s" % next_branch_name)
		enemy.queue_free()
		return
	
	enemy.prepare_for_new_path()

	var new_path_follow = PathFollow2D.new()
	new_path_follow.rotates = false
	new_path_follow.loop = false
	next_path.add_child(new_path_follow)

	var last_position = enemy.global_position

	path_follow.remove_child(enemy)
	new_path_follow.add_child(enemy)
	enemy.global_position = last_position
	enemy.set("path_follow", new_path_follow)

	path_follow.queue_free()
