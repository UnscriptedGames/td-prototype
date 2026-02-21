# res://levels/template_level.gd
class_name TemplateLevel
extends Node2D

## Template level scene controller.
##
## Manages wave spawning, enemy pathing (including multi-lane generation),
## and the visual opening sequence (wipe → dissolve → path flow).

## Exported Variables

@export var level_data: LevelData
@export var lane_count: int = 4
@export var max_lane_offset: float = 25.0

@export var level_number: int = 1

## Regular Variables

var _current_wave_index: int = 0
var _spawning: bool = false
var _active_enemy_count: int = 0
var _paths: Dictionary[String, Path2D] = {}
var _lane_map: Dictionary[String, Array] = {} # SourcePathKey -> Array[Path2D]
var _lane_to_source_map: Dictionary[Path2D, Path2D] = {} # GeneratedLane -> LogicalSourcePath

# Spawn Queue System
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0

## Onready Variables

@onready var entities: Node2D = $Entities

@export_group("Renderers")
@export var background_renderer: BackgroundRenderer
@export var maze_renderer: MazeRenderer
@export var song_layer: TileMapLayer # Reference to the SongLayer (optional if named standardly)
@export var floor_tile_id: int = 1 # ID of the tile used for the floor/path

@export_group("Opening Sequence")
@export var play_opening_sequence: bool = true

## 1. Initial wait time before the sequence starts.
@export var step1_boot_delay: float = 2.0

## 2. Duration of the center-out wipe animation for the Song Layer.
@export var step2_song_wipe_duration: float = 3.0

## 3. Wait time after the wipe finishes, before the dissolve starts.
@export var step3_dissolve_delay: float = 1.0

## 4. Duration of the transition from Song Layer to Maze Layer.
@export var step4_dissolve_duration: float = 2.0

## 5. Duration of the background pad removal flow along the path.
@export var step5_path_flow_duration: float = 1.0

## 5a. Time (in seconds) to start the flow BEFORE the dissolve ends.
## Use this to overlap the animations.
@export var step5_flow_overlap: float = 0.0

## 6. Duration for individual pad animations (shrink/scale).
@export var step6_pad_anim_duration: float = 0.5

## Signals
signal opening_sequence_started
signal opening_sequence_finished

## Built-in Methods

func _ready() -> void:
	# Auto-detect renderers if not assigned via inspector.
	if not background_renderer:
		background_renderer = find_child("BackgroundRenderer", true, false)
	if not maze_renderer:
		maze_renderer = find_child("MazeRenderer", true, false)
	if not song_layer:
		song_layer = find_child("SongLayer", true, false)
	
	# Initialise opening sequence state if enabled.
	if play_opening_sequence:
		if maze_renderer:
			var maze_layer_node: Node = find_child("MazeLayer", true, false)
			
			if maze_layer_node:
				maze_renderer.source_layer_path = maze_layer_node.get_path()
			if song_layer:
				maze_renderer.transition_layer_path = song_layer.get_path()
			
			maze_renderer.transition_progress = 0.0
			maze_renderer.reveal_mode = maze_renderer.RevealMode.CENTER_OUT
			maze_renderer.reveal_ratio = 0.0
		
		call_deferred("_start_opening_sequence")
	else:
		# Ensure everything is visible if sequence is skipped.
		if maze_renderer:
			maze_renderer.reveal_ratio = 1.0
		# Defer because _paths is populated below and isn't ready yet.
		call_deferred("_remove_background_tiles_under_path", false)
		opening_sequence_finished.emit()

	# Cache Path2D nodes using "Paths/Name" keys for quick lookup.
	var paths_node: Node2D = $Paths as Node2D
	
	# Build predecessor/successor maps for path stitching.
	var predecessor_map: Dictionary[Path2D, Path2D] = {}
	var successor_map: Dictionary[Path2D, Array] = {}
	
	for child: Node in paths_node.get_children():
		if child is Path2D and child.name.find("Lane") == -1:
			var source_path: Path2D = child as Path2D
			var key_string: String = "%s/%s" % [paths_node.name, source_path.name]
			_paths[key_string] = source_path
			
			# Check branches to populate connectivity maps.
			var branches: Array = []
			if "branches" in source_path:
				branches = source_path.branches
			
			for branch_path_node: NodePath in branches:
				var branch_node: Path2D = source_path.get_node_or_null(branch_path_node) as Path2D
				if branch_node:
					predecessor_map[branch_node] = source_path
					
					if not successor_map.has(source_path):
						successor_map[source_path] = []
					successor_map[source_path].append(branch_node)
	
	# Generate a global lane offset profile (sorted L->R).
	var lane_profile: Array[float] = []
	for i: int in range(lane_count):
		var offset: float = randf_range(-max_lane_offset, max_lane_offset)
		lane_profile.append(offset)
	lane_profile.sort()
	
	# Generate parallel lane curves for every source path.
	for child: Node in paths_node.get_children():
		if child is Path2D and child.name.find("Lane") == -1:
			var source_path: Path2D = child as Path2D
			var key_string: String = "%s/%s" % [paths_node.name, source_path.name]
			
			var lanes: Array[Path2D] = []
			
			# Check if we have a predecessor for end-stitching.
			var predecessor: Path2D = predecessor_map.get(source_path)
			var previous_tangent: Vector2 = Vector2.ZERO
			
			if predecessor and predecessor.curve.point_count >= 2:
				var p_last: Vector2 = predecessor.curve.get_point_position(
					predecessor.curve.point_count - 1
				)
				var p_prev: Vector2 = predecessor.curve.get_point_position(
					predecessor.curve.point_count - 2
				)
				previous_tangent = (p_last - p_prev).normalized()
			
			# Check successors for start-stitching.
			var next_tangents: Array[Vector2] = []
			var successors: Array = successor_map.get(source_path, [])
			for successor: Path2D in successors:
				if successor.curve.point_count >= 2:
					var p0: Vector2 = successor.curve.get_point_position(0)
					var p1: Vector2 = successor.curve.get_point_position(1)
					var segment_tangent: Vector2 = (p1 - p0).normalized()
					next_tangents.append(segment_tangent)
			
			for i: int in range(lane_profile.size()):
				var offset: float = lane_profile[i]
				var lane_name: String = "%s_Lane_%d" % [source_path.name, i]
				var new_curve: Curve2D
				
				if is_zero_approx(offset):
					new_curve = source_path.curve.duplicate()
				else:
					new_curve = LaneGenerator.generate_parallel_curve(
						source_path, offset, previous_tangent, next_tangents
					)
				
				if new_curve:
					var lane_path: Path2D = Path2D.new()
					lane_path.name = lane_name
					lane_path.curve = new_curve
					paths_node.add_child(lane_path)
					
					var lane_key: String = "%s/%s" % [paths_node.name, lane_name]
					_paths[lane_key] = lane_path
					lanes.append(lane_path)
					
					# Map this generated lane back to its logical source path.
					_lane_to_source_map[lane_path] = source_path
			
			_lane_map[key_string] = lanes
	
	# Register level metadata so the HUD shows total waves.
	if level_data:
		GameManager.set_level(level_number, level_data)
	
	GameManager.start_wave_requested.connect(_on_next_wave_requested)
	
	# Pool Initialisation
	ObjectPoolManager.create_node_pool("PathFollow2D", 50)

func _process(delta: float) -> void:
	# Processes the spawn queue each frame.
	if _spawning and _spawn_queue.size() > 0:
		_process_spawn_queue(delta)

func _exit_tree() -> void:
	pass


## Public Methods

func _start_wave(wave_index: int) -> void:
	# Begins spawning enemies for a specific wave.
	if wave_index >= level_data.waves.size():
		return
	
	GameManager.set_wave(wave_index + 1)
	
	_current_wave_index = wave_index
	var wave: WaveData = level_data.waves[wave_index] as WaveData
	if wave:
		_spawning = true
		_active_enemy_count = 0
		_spawn_wave(wave)


## Private Methods

func _spawn_wave(wave: WaveData) -> void:
	# Flattens all SpawnInstructions into a single sorted timeline of spawn events.
	# Each instruction can specify a start_delay and enemy_delay, which are accumulated
	# into absolute trigger times. All instructions run in parallel.
	_spawn_queue.clear()
	_spawn_timer = 0.0
	
	var master_timeline: Array[Dictionary] = []
	
	for instruction: SpawnInstruction in wave.spawns:
		var current_time: float = instruction.start_delay
		for i: int in range(instruction.count):
			master_timeline.append({
				"time": current_time,
				"scene": instruction.enemy_scene,
				"path": instruction.path
			})
			current_time += instruction.enemy_delay
	
	master_timeline.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"]
	)
	
	_spawn_queue = master_timeline


func _process_spawn_queue(delta: float) -> void:
	# Drains the sorted spawn queue, firing all events whose time has arrived.
	_spawn_timer += delta
	
	while _spawn_queue.size() > 0:
		var next_event: Dictionary = _spawn_queue[0]
		if _spawn_timer >= next_event["time"]:
			_spawn_queued_enemy(next_event)
			_spawn_queue.pop_front()
		else:
			break
	
	if _spawn_queue.size() == 0:
		_on_wave_spawn_finished()


func _spawn_queued_enemy(event: Dictionary) -> void:
	# Resolves path + lane for a queued spawn event and creates the enemy.
	var path_key: String = str(event["path"])
	var path_node: Path2D = _paths.get(path_key, null) as Path2D
	
	var lanes: Array = _lane_map.get(path_key, [])
	var lane_idx: int = -1
	
	if lanes.size() > 0:
		lane_idx = randi() % lanes.size()
		path_node = lanes[lane_idx]
	
	if path_node:
		var enemy: TemplateEnemy = _spawn_enemy(event["scene"], path_node)
		if enemy:
			enemy.lane_index = lane_idx
	else:
		push_error("Path not found for queued spawn: %s" % path_key)


func _spawn_enemy(enemy_scene: PackedScene, path_node: Path2D) -> TemplateEnemy:
	# Instantiates one enemy and attaches a PathFollow2D for curve-based movement.
	var enemies_container: Node2D = entities.get_node("Enemies") as Node2D
	
	var enemy: TemplateEnemy = ObjectPoolManager.get_object(enemy_scene) as TemplateEnemy
	if not is_instance_valid(enemy):
		return null
	
	var path_follow: PathFollow2D = ObjectPoolManager.get_pooled_node("PathFollow2D") as PathFollow2D
	if not is_instance_valid(path_follow):
		push_error("Failed to get a PathFollow2D from the pool.")
		path_follow = PathFollow2D.new()
	
	path_follow.rotates = false
	path_follow.loop = false
	path_node.add_child(path_follow)
	
	enemy.path_follow = path_follow
	
	enemies_container.add_child(enemy)
	enemy.reset()
	enemy.global_position = path_node.global_position
	
	# Enable visibility only AFTER positioning to prevent (0,0) flash.
	enemy.visible = true
	_active_enemy_count += 1
	
	enemy.set_process(true)
	
	if not enemy.reached_end_of_path.is_connected(_on_enemy_finished_path):
		enemy.reached_end_of_path.connect(_on_enemy_finished_path)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	
	return enemy


func _on_enemy_died(_enemy: TemplateEnemy, reward_amount: int) -> void:
	# Awards currency for defeated enemies.
	GameManager.add_currency(reward_amount)
	_active_enemy_count -= 1
	_check_wave_completion()


func _on_enemy_finished_path(enemy: TemplateEnemy) -> void:
	# Handles path completion: either damages the player (terminal path) or
	# transitions the enemy onto the next branch, preserving lane index.
	if not is_instance_valid(enemy):
		return
	
	var path_follow: PathFollow2D = enemy.path_follow as PathFollow2D
	if not is_instance_valid(path_follow):
		push_error("Enemy missing path_follow reference.")
		return
	
	var current_path_node: Path2D = path_follow.get_parent() as Path2D
	
	# Look up the logical source path via the lane-to-source map.
	# If the enemy is on a generated lane, we need the source to check branches.
	# If it's already on a source path (no lanes), use it directly.
	var source_path: Path2D = _lane_to_source_map.get(current_path_node, current_path_node)
	
	if not source_path:
		enemy.reached_goal()
		GameManager.add_peak_volume(enemy.health)
		_active_enemy_count -= 1
		_check_wave_completion()
		return
	
	# Check branches on the logical source path.
	var branches: Array = []
	if "branches" in source_path:
		branches = source_path.branches
	
	if branches.is_empty():
		# Terminal path — enemy has reached the goal.
		GameManager.add_peak_volume(enemy.health)
		enemy.reached_goal()
		_active_enemy_count -= 1
		_check_wave_completion()
		return
	
	# Pick a random branch and resolve its node.
	var next_path_nodepath: NodePath = branches.pick_random() as NodePath
	var next_source_path: Path2D = source_path.get_node_or_null(next_path_nodepath) as Path2D
	
	if not next_source_path:
		push_error("Invalid branch path from %s to %s" % [source_path.name, next_path_nodepath])
		enemy.reached_goal()
		GameManager.add_peak_volume(enemy.health)
		_active_enemy_count -= 1
		_check_wave_completion()
		return
	
	# Find the corresponding lane on the next source path.
	var next_path_key: String = "%s/%s" % [$Paths.name, next_source_path.name]
	var next_lanes: Array = _lane_map.get(next_path_key, [])
	
	var target_lane_path: Path2D = next_source_path
	if next_lanes.size() > 0:
		if enemy.lane_index >= 0 and enemy.lane_index < next_lanes.size():
			target_lane_path = next_lanes[enemy.lane_index]
		else:
			target_lane_path = next_lanes.pick_random()
	
	# Transition enemy onto the new path.
	enemy.prepare_for_new_path()
	
	var new_path_follow: PathFollow2D = ObjectPoolManager.get_pooled_node("PathFollow2D") as PathFollow2D
	if not is_instance_valid(new_path_follow):
		new_path_follow = PathFollow2D.new()
	
	new_path_follow.rotates = false
	new_path_follow.loop = false
	target_lane_path.add_child(new_path_follow)
	
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

func _start_opening_sequence() -> void:
	# Kicks off the multi-phase opening sequence:
	# Boot delay -> Wipe In -> Dissolve -> Path Flow.
	if not background_renderer or not maze_renderer:
		return
	
	if maze_renderer:
		maze_renderer.reveal_mode = maze_renderer.RevealMode.CENTER_OUT
		maze_renderer.reveal_ratio = 0.0
		maze_renderer.transition_progress = 0.0
	
	opening_sequence_started.emit()
	
	var tween: Tween = create_tween()
	tween.tween_interval(step1_boot_delay)
	
	# Configure wipe softness based on pad animation duration.
	if step2_song_wipe_duration > 0.001:
		var wipe_width: float = step6_pad_anim_duration / step2_song_wipe_duration
		maze_renderer.wipe_anim_width = clampf(wipe_width, 0.01, 1.0)
	
	tween.tween_property(maze_renderer, "reveal_ratio", 1.0, step2_song_wipe_duration)
	tween.finished.connect(_on_wipe_finished)

func _on_wipe_finished() -> void:
	# Waits for the post-wipe delay, then begins the dissolve phase.
	if step3_dissolve_delay > 0.0:
		await get_tree().create_timer(step3_dissolve_delay).timeout
	_start_dissolve_sequence()

func _start_dissolve_sequence() -> void:
	# Runs the dissolve (Song -> Maze) and overlapping path flow animations.
	if not maze_renderer:
		return
	
	var tween: Tween = create_tween()
	
	# Configure dissolve pop speed from pad animation duration.
	if step4_dissolve_duration > 0.001:
		var calculated_width: float = step6_pad_anim_duration / step4_dissolve_duration
		maze_renderer.dissolve_anim_width = clampf(calculated_width, 0.01, 1.0)
	
	# Dissolve and flow run in parallel.
	tween.set_parallel(true)
	tween.tween_property(maze_renderer, "transition_progress", 1.0, step4_dissolve_duration)
	
	var flow_start_delay: float = max(0.0, step4_dissolve_duration - step5_flow_overlap)
	tween.tween_callback(_start_path_flow_dissolve).set_delay(flow_start_delay)
	
	tween.set_parallel(false)
	
	# Cleanup after all parallel tweens complete.
	tween.tween_callback(func() -> void:
		maze_renderer.transition_layer_path = NodePath()
		maze_renderer.reveal_mode = maze_renderer.RevealMode.LINEAR
		opening_sequence_finished.emit()
	)

func _start_path_flow_dissolve() -> void:
	# Triggers the BFS-based background removal alongside the dissolve.
	_remove_background_tiles_under_path(true)

func _remove_background_tiles_under_path(animate: bool = true) -> void:
	# BFS flood-fill from Spawn01's start point, hiding background pads under the path.
	# When 'animate' is true, cells shrink sequentially along the BFS wavefront.
	if not background_renderer or not maze_renderer:
		return
	
	var layer_node: Node = maze_renderer.get_node_or_null(maze_renderer.source_layer_path)
	if not layer_node is TileMapLayer:
		return
	var maze_layer: TileMapLayer = layer_node as TileMapLayer
	
	# Determine BFS start point from Spawn01's first curve point.
	var start_coords: Vector2i = Vector2i(0, 8)
	var spawn_path: Path2D = _paths.get("%s/Spawn01" % $Paths.name) as Path2D
	if spawn_path and spawn_path.curve.point_count > 0:
		var start_local: Vector2 = spawn_path.curve.get_point_position(0) + spawn_path.position
		var map_pos: Vector2 = maze_layer.to_local(to_global(start_local))
		start_coords = maze_layer.local_to_map(map_pos)
	
	# BFS flood-fill: find all connected floor tiles.
	var bfs_queue: Array[Vector2i] = [start_coords]
	var visited: Dictionary[Vector2i, int] = {start_coords: 0}
	var max_distance: int = 0
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	while bfs_queue.size() > 0:
		var current: Vector2i = bfs_queue.pop_front()
		var current_dist: int = visited[current]
		
		if current_dist > max_distance:
			max_distance = current_dist
		
		for dir: Vector2i in directions:
			var next_cell: Vector2i = current + dir
			
			if visited.has(next_cell):
				continue
			
			if maze_layer.get_cell_source_id(next_cell) == floor_tile_id:
				visited[next_cell] = current_dist + 1
				bfs_queue.append(next_cell)
	
	# Instant hide or animated sequential shrink.
	if not animate:
		for cell: Vector2i in visited.keys():
			background_renderer.animate_hide_cell(cell, 0.0)
		return
	
	var tween: Tween = create_tween()
	var step_delay: float = 0.05
	if max_distance > 0:
		step_delay = step5_path_flow_duration / float(max_distance)
	
	for cell: Vector2i in visited.keys():
		var dist: int = visited[cell]
		var delay: float = float(dist) * step_delay
		var shrink_duration: float = step6_pad_anim_duration
		
		tween.parallel().tween_callback(func() -> void:
			background_renderer.animate_hide_cell(cell, shrink_duration)
		).set_delay(delay)
