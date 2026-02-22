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

# AStarGrid2D Navigation
var _astar_grid: AStarGrid2D

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
		# Initialize navigation immediately if there's no sequence.
		call_deferred("_initialize_navigation_grid")
		call_deferred("_remove_background_tiles_under_path", false)
		opening_sequence_finished.emit()


	# Register level metadata so the HUD shows total waves.

	if level_data:
		GameManager.set_level(level_number, level_data)
	
	GameManager.start_wave_requested.connect(_on_next_wave_requested)

func _process(delta: float) -> void:
	# Processes the spawn queue each frame.
	if _spawning and _spawn_queue.size() > 0:
		_process_spawn_queue(delta)

func _exit_tree() -> void:
	if GameManager.start_wave_requested.is_connected(_on_next_wave_requested):
		GameManager.start_wave_requested.disconnect(_on_next_wave_requested)


## Public Methods

func _start_wave(wave_index: int) -> void:
	# Begins spawning enemies for a specific wave.
	if wave_index >= level_data.waves.size():
		return
	
	var wave: WaveData = level_data.waves[wave_index] as WaveData
	GameManager.set_wave(wave_index + 1, wave)
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
				"spawn_tile": instruction.spawn_tile,
				"weighted_targets": instruction.weighted_targets
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
	# Use the explicit coordinate from the Weighted Spawn Instruction
	var start_tile: Vector2i = event.get("spawn_tile", Vector2i.ZERO)
	
	# Try to safely resolve the exact world coordinate of the center of that tile
	var spawn_position: Vector2 = Vector2.ZERO
	if maze_renderer:
		var layer_node = maze_renderer.get_node_or_null(maze_renderer.source_layer_path)
		if layer_node is TileMapLayer:
			var local_pos = layer_node.map_to_local(start_tile)
			spawn_position = layer_node.to_global(local_pos)
		else:
			push_error("Failed to resolve spawn_position: maze layer not found.")
			return
	
	# Wait for AStar to be ready if it isn't
	if not _astar_grid:
		_initialize_navigation_grid()
		
	# Resolve Target
	var target_tile: Vector2i = Vector2i.ZERO # Default/fallback
	var weighted_targets: Array = event.get("weighted_targets", [])
	
	if not weighted_targets.is_empty():
		var total_weight: float = 0.0
		for wt: WeightedTarget in weighted_targets:
			if wt: total_weight += wt.weight
			
		var random_val: float = randf_range(0.0, total_weight)
		var cumulative: float = 0.0
		
		for wt: WeightedTarget in weighted_targets:
			if not wt: continue
			cumulative += wt.weight
			if random_val <= cumulative:
				target_tile = wt.goal_tile
				break
	elif _astar_grid:
		# Fallback if the user hasn't set up the new WeightedTargets yet
		var region: Rect2i = _astar_grid.region
		target_tile = Vector2i(region.end.x - 1, region.position.y + int(region.size.y / 2.0))
	
	_spawn_enemy(event["scene"], spawn_position, start_tile, target_tile)


func _spawn_enemy(enemy_scene: PackedScene, spawn_position: Vector2, start_tile: Vector2i, target_tile: Vector2i) -> TemplateEnemy:
	var enemies_container: Node2D = entities.get_node("Enemies") as Node2D
	
	var enemy: TemplateEnemy = ObjectPoolManager.get_object(enemy_scene) as TemplateEnemy
	if not is_instance_valid(enemy):
		return null
	
	enemies_container.add_child(enemy)
	enemy.reset()
	enemy.global_position = spawn_position
	
	# Enable visibility only AFTER positioning to prevent (0,0) flash.
	enemy.visible = true
	_active_enemy_count += 1
	
	# Provide navigation context explicitly
	enemy.set_navigation_context(_astar_grid, start_tile, target_tile)
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
	# Goal reached logic
	if not is_instance_valid(enemy):
		return
	
	GameManager.add_peak_volume(enemy.health)
	enemy.reached_goal()
	_active_enemy_count -= 1
	_check_wave_completion()


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
	# Starts the background removal alongside the dissolve.
	_initialize_navigation_grid()
	_remove_background_tiles_under_path(true)

func _initialize_navigation_grid() -> void:
	if _astar_grid:
		return
		
	var layer_node: Node = maze_renderer.get_node_or_null(maze_renderer.source_layer_path)
	if not layer_node is TileMapLayer:
		push_error("Cannot initialize AStarGrid2D: maze layer not found.")
		return
		
	var maze_layer := layer_node as TileMapLayer
	var used_rect := maze_layer.get_used_rect()
	
	_astar_grid = AStarGrid2D.new()
	_astar_grid.region = used_rect
	_astar_grid.cell_size = maze_layer.tile_set.tile_size
	_astar_grid.offset = _astar_grid.cell_size / 2.0
	_astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar_grid.update()
	
	# Make only the floor tiles walkable
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell = Vector2i(x, y)
			var source_id = maze_layer.get_cell_source_id(cell)
			if source_id == floor_tile_id:
				_astar_grid.set_point_solid(cell, false)
			else:
				_astar_grid.set_point_solid(cell, true)
	
	print("AStarGrid2D Navigation Initialized for ", used_rect)

func _remove_background_tiles_under_path(animate: bool = true) -> void:
	# BFS flood-fill from Spawn01's start point, hiding background pads under the path.
	# When 'animate' is true, cells shrink sequentially along the BFS wavefront.
	if not background_renderer or not maze_renderer:
		return
	
	var layer_node: Node = maze_renderer.get_node_or_null(maze_renderer.source_layer_path)
	if not layer_node is TileMapLayer:
		return
	var maze_layer: TileMapLayer = layer_node as TileMapLayer
	
	# Instant hide bypasses BFS entirely to ensure all disconnected paths are cleared
	if not animate:
		for cell: Vector2i in maze_layer.get_used_cells():
			if maze_layer.get_cell_source_id(cell) == floor_tile_id:
				background_renderer.animate_hide_cell(cell, 0.0)
		return
		
	# Find a valid floor tile to start the BFS, scanning from left to right.
	var start_coords: Vector2i = Vector2i.ZERO
	var used_rect: Rect2i = maze_layer.get_used_rect()
	var found_start: bool = false
	
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell: Vector2i = Vector2i(x, y)
			if maze_layer.get_cell_source_id(cell) == floor_tile_id:
				start_coords = cell
				found_start = true
				break
		if found_start:
			break
			
	if not found_start:
		return
	
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
	
	# Animated sequential shrink.
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
