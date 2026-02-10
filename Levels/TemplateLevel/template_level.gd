# res://levels/template_level.gd
class_name TemplateLevel
extends Node2D

## Template level: manages waves, spawns enemies, and syncs HUD scale to camera zoom.

## Exported Variables

@export var level_data: LevelData
@export var lane_count: int = 4
@export var max_lane_offset: float = 25.0

@export var level_number: int = 1

## Regular Variables

var _current_wave_index: int = 0
var _spawning: bool = false
var _active_enemy_count: int = 0 # NEW: Tracks living enemies
var _paths: Dictionary = {}
var _lane_map: Dictionary = {} # Map SourcePathKey -> Array of LanePaths

# Spawn Queue System
var _spawn_queue: Array[Dictionary] = [] # Stores pending spawns: {time, instruction, index}
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

## Built-in Methods

func _ready() -> void:
	# Try to auto-connect renderers if not assigned
	if not background_renderer:
		background_renderer = find_child("BackgroundRenderer", true, false)
	if not maze_renderer:
		maze_renderer = find_child("MazeRenderer", true, false)
	if not song_layer:
		song_layer = find_child("SongLayer", true, false)
		
	# Start functionality
	if play_opening_sequence:
		# Force full State Initialization to prevent flicker/wrong layer
		if maze_renderer:
			# Setup Layers (Source=Maze, Transition=Song)
			var maze_layer_node = find_child("MazeLayer", true, false)
			
			if maze_layer_node:
				maze_renderer.source_layer_path = maze_layer_node.get_path()
			if song_layer:
				maze_renderer.transition_layer_path = song_layer.get_path()
			
			# Setup State (Show Song Layer via Transition 0.0)
			if "transition_progress" in maze_renderer:
				maze_renderer.transition_progress = 0.0
				
			# Setup Wipe (Hidden, Center Out)
			if "reveal_mode" in maze_renderer:
				maze_renderer.reveal_mode = maze_renderer.RevealMode.CENTER_OUT
			maze_renderer.reveal_ratio = 0.0
			
		call_deferred("_start_opening_sequence")
	else:
		# Ensure everything is visible if sequence is skipped
		if maze_renderer: maze_renderer.reveal_ratio = 1.0

	# Cache Path2D nodes using "Paths/Name" keys for quick lookup.
	var paths_node := $Paths as Node2D
	# 0. Build Connectivity Maps and Cache Paths
	var predecessor_map: Dictionary = {}
	var successor_map: Dictionary = {}
	
	for child in paths_node.get_children():
		if child is Path2D and child.name.find("Lane") == -1:
			var key_string := "%s/%s" % [paths_node.name, child.name]
			_paths[key_string] = child
			
			# Check branches to populate maps
			var branches: Array = []
			if "branches" in child:
				branches = child.branches
				
			for branch_path_node in branches:
				var branch_node = child.get_node_or_null(branch_path_node) as Path2D
				if branch_node:
					predecessor_map[branch_node] = child
					
					if not successor_map.has(child):
						successor_map[child] = []
					successor_map[child].append(branch_node)

	# 1. Generate Global Lane Profile
	# Use a consistent seeded random or just random at load.
	# We want random distribution but fixed connectivity.
	var lane_profile: Array[float] = []
	for i in range(lane_count):
		# Random offset between -max and +max
		var offset = randf_range(-max_lane_offset, max_lane_offset)
		lane_profile.append(offset)
	
	# Sort profile for logical Left->Right consistency (helps debugging)
	lane_profile.sort()
	
	for child in paths_node.get_children():
		if child is Path2D and child.name.find("Lane") == -1: # Ignore already generated lanes
			var key_string := "%s/%s" % [paths_node.name, child.name]
			
			# 2. Auto-Lane Generation for ALL paths
			var lanes: Array[Path2D] = []
			
			# Check if we have a predecessor to stitch to
			var predecessor = predecessor_map.get(child)
			var previous_tangent = Vector2.ZERO
			
			if predecessor and predecessor.curve.point_count >= 2:
				var p_last = predecessor.curve.get_point_position(predecessor.curve.point_count - 1)
				var p_prev = predecessor.curve.get_point_position(predecessor.curve.point_count - 2)
				previous_tangent = (p_last - p_prev).normalized()

			# Check successors to stitch end
			var next_tangents: Array[Vector2] = []
			var successors = successor_map.get(child, [])
			for successor in successors:
				if successor.curve.point_count >= 2:
					var p0 = successor.curve.get_point_position(0)
					var p1 = successor.curve.get_point_position(1)
					var segment_tangent = (p1 - p0).normalized()
					next_tangents.append(segment_tangent)

			for i in range(lane_profile.size()):
				var offset = lane_profile[i]
				var lane_name = "%s_Lane_%d" % [child.name, i]
				var new_curve: Curve2D
				
				if is_zero_approx(offset):
					new_curve = child.curve.duplicate()
				else:
					new_curve = LaneGenerator.generate_parallel_curve(child, offset, previous_tangent, next_tangents)
				
				if new_curve:
					var lane_path = Path2D.new()
					lane_path.name = lane_name
					lane_path.curve = new_curve
					paths_node.add_child(lane_path)
					
					# Store in _paths for lookup
					var lane_key = "%s/%s" % [paths_node.name, lane_name]
					_paths[lane_key] = lane_path
					lanes.append(lane_path)
					
			_lane_map[key_string] = lanes

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
	
	# Check if this path has associated lanes
	var lanes = _lane_map.get(path_key, [])
	var lane_idx = -1
	
	if lanes.size() > 0:
		# Pick a random lane index
		lane_idx = randi() % lanes.size()
		path_node = lanes[lane_idx]
	
	if path_node:
		var enemy = _spawn_enemy(event["scene"], path_node)
		if enemy:
			enemy.lane_index = lane_idx # Assign lane index
	else:
		push_error("Path not found for queued spawn: %s" % path_key)


func _spawn_enemy(enemy_scene: PackedScene, path_node: Path2D) -> TemplateEnemy:
	# Spawns one enemy and attaches a PathFollow2D for movement.
	var enemies_container := entities.get_node("Enemies") as Node2D

	var enemy := ObjectPoolManager.get_object(enemy_scene) as TemplateEnemy
	if not is_instance_valid(enemy):
		return null

	# Visibility is now handled after positioning.

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
	
	# Enable visibility only AFTER positioning to prevent (0,0) flash.
	enemy.visible = true
	
	_active_enemy_count += 1 # Increment active count

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
	# Handles path end or branching for a moving enemy.
	if not is_instance_valid(enemy):
		return

	var path_follow := enemy.path_follow as PathFollow2D
	if not is_instance_valid(path_follow):
		push_error("Enemy missing path_follow reference.")
		return
		
	# Logic to find parent path
	var current_path_node = path_follow.get_parent() as Path2D
	
	# If we are on a "Lane", we need to find the "Source" path to check branches
	# The source path name is stored in the key? No.
	# But we know the structure: SourceName_Lane_Index
	# Or, simply, does the current path node have branches? 
	# Generated Lane Paths DO NOT have the 'branches' metadata on them directly unless we copied it (which we didn't).
	# We generated them as children of "Paths", unrelated to the source.
	
	# CRITICAL: We need to find the "Logical Source Path" for the current lane.
	# We can parse the name: "SpawnPath_Lane_2" -> "SpawnPath"
	# Or simpler: The Level keeps the map.
	
	var current_lane_name = current_path_node.name
	var source_path_name = current_lane_name
	var is_lane = current_lane_name.find("_Lane_") != -1
	
	if is_lane:
		# Strip suffix to get source name
		# Assume format: Name_Lane_X
		var parts = current_lane_name.split("_Lane_")
		source_path_name = parts[0]
	
	# Find source path node in _paths
	var source_key = "%s/%s" % [$Paths.name, source_path_name]
	var source_path = _paths.get(source_key)
	
	if not source_path:
		# Fallback/Error
		enemy.reached_goal()
		GameManager.damage_player(enemy.data.damage)
		_active_enemy_count -= 1
		_check_wave_completion()
		return

	var branches: Array = []
	if "branches" in source_path:
		branches = source_path.branches
		
	if branches.is_empty():
		GameManager.damage_player(enemy.data.damage)
		enemy.reached_goal()
		_active_enemy_count -= 1 # Enemy removed from play
		_check_wave_completion()
		return

	var next_path_nodepath := branches.pick_random() as NodePath
	# The branch points to a node path (relative or absolute). We need the Node.
	var next_source_path = source_path.get_node_or_null(next_path_nodepath) as Path2D
	
	if not next_source_path:
		push_error("Invalid branch path from %s to %s" % [source_path.name, next_path_nodepath])
		enemy.reached_goal()
		GameManager.damage_player(enemy.data.damage)
		_active_enemy_count -= 1
		_check_wave_completion()
		return
		
	# Now find the corresponding lane on the next path
	var next_path_key = "%s/%s" % [$Paths.name, next_source_path.name]
	var next_lanes = _lane_map.get(next_path_key, [])
	
	var target_lane_path = next_source_path # Default to base if no lanes
	if next_lanes.size() > 0:
		# Try to keep same index
		if enemy.lane_index >= 0 and enemy.lane_index < next_lanes.size():
			target_lane_path = next_lanes[enemy.lane_index]
		else:
			target_lane_path = next_lanes.pick_random() # Fallback
			
	# Transition
	enemy.prepare_for_new_path()

	var new_path_follow := ObjectPoolManager.get_pooled_node("PathFollow2D") as PathFollow2D
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
	if not background_renderer or not maze_renderer:
		return
		
	# 1. Reset State
	# Goal: MazeRenderer shows SongLayer wipe in, then dissolves to MazeLayer.
	if maze_renderer:
		maze_renderer.reveal_mode = maze_renderer.RevealMode.CENTER_OUT
		maze_renderer.reveal_ratio = 0.0
		maze_renderer.transition_progress = 0.0
	
	# 2. Sequence
	var tween = create_tween()
	
	# Removed global easing for consistent linear flow as requested
	tween.tween_interval(step1_boot_delay)
	
	# Step A: Wipe In Song (Visually)
	
	# Configure Wipe Width based on Pad Animation Duration
	if "wipe_anim_width" in maze_renderer and step2_song_wipe_duration > 0.001:
		var wipe_width = step6_pad_anim_duration / step2_song_wipe_duration
		maze_renderer.wipe_anim_width = clampf(wipe_width, 0.01, 1.0)
		
	tween.tween_property(maze_renderer, "reveal_ratio", 1.0, step2_song_wipe_duration)
	
	# Phase 2: Explicit Wait (Decoupled from Tween Chaining)
	tween.finished.connect(_on_wipe_finished)

func _on_wipe_finished() -> void:
	# Explicitly wait using a SceneTreeTimer, ensuring the delay is robust.
	if step3_dissolve_delay > 0.0:
		await get_tree().create_timer(step3_dissolve_delay).timeout
	
	_start_dissolve_sequence()

func _start_dissolve_sequence() -> void:
	if not maze_renderer: return
	
	var tween = create_tween()
	
	# Step C & D: Dissolve & Flow (Overlapping)
	
	# Configure MazeRenderer Pop Speed based on Pad Animation Duration
	if "dissolve_anim_width" in maze_renderer and step4_dissolve_duration > 0.001:
		var calculated_width = step6_pad_anim_duration / step4_dissolve_duration
		# Safety Clamp: Cap at 1.0 (Full Duration) to prevent math errors if duration is huge
		maze_renderer.dissolve_anim_width = clampf(calculated_width, 0.01, 1.0)
	
	# We use set_parallel(true) to explicitly state that the following tweens
	# happen simultaneously. This guarantees they share the same start time on the timeline.
	tween.set_parallel(true)
	
	# 1. Start Dissolve (Duration 3s)
	if "transition_progress" in maze_renderer:
		tween.tween_property(maze_renderer, "transition_progress", 1.0, step4_dissolve_duration)
	
	# 2. Start Flow Timer (Delay = 3s - Overlap)
	# This starts at T=0 (relative to this block) but waits for 'flow_start_delay'.
	var flow_start_delay = max(0.0, step4_dissolve_duration - step5_flow_overlap)
	tween.tween_callback(_start_path_flow_dissolve).set_delay(flow_start_delay)
	
	# End Parallel Block
	tween.set_parallel(false)
	
	# Step E: Cleanup
	# This runs after the longest tween in the parallel block finishes.
	tween.tween_callback(func():
		maze_renderer.transition_layer_path = NodePath()
		maze_renderer.reveal_mode = maze_renderer.RevealMode.LINEAR # Reset for gameplay
	)

func _start_path_flow_dissolve() -> void:
	if not background_renderer or not maze_renderer:
		return
		
	# 1. Get Maze Layer Data
	var layer_node = maze_renderer.get_node_or_null(maze_renderer.source_layer_path)
	if not layer_node is TileMapLayer:
		return
	var maze_layer = layer_node as TileMapLayer
	
	# 2. Find Start Point (Spawn01)
	# Start with a default in case path is missing
	var start_coords = Vector2i(0, 8)
	
	var spawn_path = _paths.get("%s/Spawn01" % $Paths.name) as Path2D
	if spawn_path and spawn_path.curve.point_count > 0:
		var start_local = spawn_path.curve.get_point_position(0) + spawn_path.position
		# Map path local (which is usually global-ish/level relative) to TileMap local
		# Assuming Paths and TileMaps are siblings or zero-offset
		var map_pos = maze_layer.to_local(to_global(start_local))
		start_coords = maze_layer.local_to_map(map_pos)
		
	# 3. BFS Flood Fill
	# Find all connected floor tiles (ID == floor_tile_id)
	var queue: Array[Vector2i] = [start_coords]
	var visited: Dictionary = {start_coords: 0} # Coords -> Distance
	var max_distance: int = 0
	
	# Standard 4-way neighbors
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_dist = visited[current]
		
		# Update max distance for normalization
		if current_dist > max_distance:
			max_distance = current_dist
			
		for dir in directions:
			var next = current + dir
			
			if visited.has(next):
				continue
				
			# Check if valid floor tile
			if maze_layer.get_cell_source_id(next) == floor_tile_id:
				visited[next] = current_dist + 1
				queue.append(next)
				
	# 4. Animate
	# Create a tween to hide background cells along the path
	var tween = create_tween()
	
	# We want the whole flow to take `step5_path_flow_duration`
	# So delay per step = duration / max_distance
	var step_delay = 0.05
	if max_distance > 0:
		step_delay = step5_path_flow_duration / float(max_distance)
		
	for cell in visited.keys():
		var dist = visited[cell]
		var delay = float(dist) * step_delay
		
		# We can't use tween_callback with specific delays easily in a loop without a parallel/sequence mess
		# Better to use tween_method or just a timer?
		# Actually, tween.parallel() with tween_callback doesn't allow individual delays easily.
		# But we can use a separate purely parallel tween structure or just schedule specific calls.
		
		# Best approach for massive number of calls:
		# Use a method that takes a time and checks against elapsed? No.
		# Use typical godot trick: tween.parallel().tween_callback().set_delay()
		
		# Duration for individual cell shrink
		var shrink_duration = step6_pad_anim_duration
		
		tween.parallel().tween_callback(func():
			background_renderer.animate_hide_cell(cell, shrink_duration)
		).set_delay(delay)
