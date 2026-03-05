# res://Stages/BaseStage/base_stage.gd
class_name BaseStage
extends Node2D

## Base gameplay scene controller.
##
## Manages wave spawning, enemy pathing (including multi-lane generation),
## and the visual opening sequence (wipe → dissolve → path flow).
## Layout data (MazeLayer / AnimationLayer tiles) is injected at runtime
## from a lightweight layout scene referenced by StemData.


# --- SIGNALS ---

signal opening_sequence_started
signal opening_sequence_finished


# --- CONSTANTS ---


# --- EXPORTS ---

@export_group("Lane Settings")
## The active stem's data, injected by StageManager at runtime.
var stem_data: StemData
@export var lane_count: int = 4
@export var max_lane_offset: float = 25.0
@export var level_number: int = 1

@export_group("Renderers")
@export var background_renderer: BackgroundRenderer
@export var maze_renderer: MazeRenderer
@export var animation_layer: TileMapLayer  # Reference to the AnimationLayer
@export var floor_tile_id: int = 1  # ID of the tile used for the floor/path

@export_group("Opening Sequence")
@export var play_opening_sequence: bool = true

## 1. Initial wait time before the sequence starts.
@export var step1_boot_delay: float = 2.0

## 2. Duration of the center-out wipe animation for the Song Layer.
@export var step2_song_wipe_duration: float = 3.0

## 3. Wait time after the wipe finishes, before the dissolve starts.
@export var step3_dissolve_delay: float = 1.0

## 4. Duration of the transition from Animation Layer to Maze Layer.
@export var step4_dissolve_duration: float = 2.0

## 5. Duration of the background pad removal flow along the path.
@export var step5_path_flow_duration: float = 1.0

## 5a. Time (in seconds) to start the flow BEFORE the dissolve ends.
## Use this to overlap the animations.
@export var step5_flow_overlap: float = 0.0

## 6. Duration for individual pad animations (shrink/scale).
@export var step6_pad_anim_duration: float = 0.5


# --- VARIABLES ---

var _current_wave_index: int = 0
var _spawning: bool = false
var _active_enemy_count: int = 0
# Set to true by force_complete_stem() to skip the track-end penalty on next completion.
var _bypass_track_end_penalty: bool = false
# Set to true when the stem fails, to prevent wave completion from firing on the same frame.
var _stem_has_failed: bool = false

# AStarGrid2D Navigation
var _astar_grid: AStarGrid2D

@onready var _enemies_container: Node2D = $Entities/Enemies

# Spawn Queue System
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0

# Caches Marker2D world positions keyed by marker name (e.g. "Spawn_0", "Goal").
# Populated during _inject_layout() from the loaded layout scene's TerrainTags node.
var _spawn_markers: Dictionary[String, Vector2] = {}

# Created and managed in _setup_stem_audio().
var _stem_audio_player: AudioStreamPlayer


# --- ONREADY ---

@onready var entities: Node2D = $Entities


# --- LIFECYCLE OVERRIDES ---


func _ready() -> void:
	# Ensure game entities pause even though the parent SubViewport is ALWAYS.
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Inject layout tiles from the stem's layout scene before anything else.
	_inject_layout()

	# Auto-detect renderers if not assigned via inspector.
	if not background_renderer:
		background_renderer = find_child("BackgroundRenderer", true, false)
	if not maze_renderer:
		maze_renderer = find_child("MazeRenderer", true, false)
	if not animation_layer:
		animation_layer = find_child("AnimationLayer", true, false)

	# Initialise opening sequence state if enabled.
	if play_opening_sequence:
		if maze_renderer:
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
		call_deferred("_validate_spawn_data")
		call_deferred("_remove_background_tiles_under_path", false)
		opening_sequence_finished.emit()

	# Register level metadata so the HUD shows total waves.

	if stem_data:
		GameManager.set_level(level_number, stem_data)

	GameManager.start_wave_requested.connect(_on_next_wave_requested)
	GameManager.stem_failed.connect(_on_stem_failed)
	GameManager.force_complete_stem_requested.connect(
		func() -> void: _bypass_track_end_penalty = true
	)
	_setup_stem_audio()


func _process(delta: float) -> void:
	# Processes the spawn queue each frame.
	if _spawning and _spawn_queue.size() > 0:
		_process_spawn_queue(delta)


func _exit_tree() -> void:
	if GameManager.start_wave_requested.is_connected(_on_next_wave_requested):
		GameManager.start_wave_requested.disconnect(_on_next_wave_requested)
	if GameManager.stem_failed.is_connected(_on_stem_failed):
		GameManager.stem_failed.disconnect(_on_stem_failed)

	# Ensure audio is hard-stopped when leaving the scene so it doesn't bleed into Setlist.
	if is_instance_valid(_stem_audio_player):
		_stem_audio_player.stop()


# --- METHODS ---


func set_stem_data(data: StemData) -> void:
	stem_data = data


## Loads the layout scene referenced by `stem_data.layout_scene_path` and
## copies its MazeLayer / AnimationLayer tile data into this scene's own layers.
func _inject_layout() -> void:
	if not stem_data or stem_data.layout_scene_path.is_empty():
		return

	var layout_scene: PackedScene = load(stem_data.layout_scene_path) as PackedScene
	if not layout_scene:
		push_error("BaseStage: Failed to load layout scene '%s'." % stem_data.layout_scene_path)
		return

	var layout_instance: Node2D = layout_scene.instantiate() as Node2D
	if not layout_instance:
		push_error(
			(
				"BaseStage: Layout scene '%s' did not instantiate as Node2D."
				% stem_data.layout_scene_path
			)
		)
		return

	# Find TileMapLayers inside the layout prefab.
	var layout_maze: TileMapLayer = layout_instance.get_node_or_null("MazeLayer") as TileMapLayer
	var layout_anim: TileMapLayer = (
		layout_instance.get_node_or_null("AnimationLayer") as TileMapLayer
	)

	# Copy tile data into this scene's own layers.
	var local_maze: TileMapLayer = find_child("MazeLayer", true, false) as TileMapLayer
	var local_anim: TileMapLayer = find_child("AnimationLayer", true, false) as TileMapLayer

	if layout_maze and local_maze:
		local_maze.tile_set = layout_maze.tile_set
		local_maze.clear()
		for cell: Vector2i in layout_maze.get_used_cells():
			var source_id: int = layout_maze.get_cell_source_id(cell)
			var atlas_coords: Vector2i = layout_maze.get_cell_atlas_coords(cell)
			var alt_tile: int = layout_maze.get_cell_alternative_tile(cell)
			local_maze.set_cell(cell, source_id, atlas_coords, alt_tile)
	else:
		push_warning("BaseStage: MazeLayer not found in layout or base scene.")

	if layout_anim and local_anim:
		local_anim.tile_set = layout_anim.tile_set
		local_anim.clear()
		for cell: Vector2i in layout_anim.get_used_cells():
			var source_id: int = layout_anim.get_cell_source_id(cell)
			var atlas_coords: Vector2i = layout_anim.get_cell_atlas_coords(cell)
			var alt_tile: int = layout_anim.get_cell_alternative_tile(cell)
			local_anim.set_cell(cell, source_id, atlas_coords, alt_tile)
	else:
		push_warning("BaseStage: AnimationLayer not found in layout or base scene.")

	# Hide the native TileMapLayers so ONLY the renderers draw.
	if local_maze:
		local_maze.visible = false
	if local_anim:
		local_anim.visible = false

	# Harvest terrain marker world positions from the layout scene's TerrainTags node.
	var terrain_tags_node: Node = layout_instance.get_node_or_null("TerrainTags")
	if terrain_tags_node:
		for marker_node: Node in terrain_tags_node.get_children():
			if marker_node is Marker2D:
				var terrain_marker: Marker2D = marker_node as Marker2D
				_spawn_markers[terrain_marker.name] = terrain_marker.global_position
				print("BaseStage: Cached terrain marker '%s' at %s" % [terrain_marker.name, terrain_marker.global_position])
	else:
		push_warning("BaseStage: Layout scene has no TerrainTags node. Spawn tags will not resolve.")

	# The layout instance is no longer needed.
	layout_instance.queue_free()

	# Force the procedural renderers to adopt the new data and redraw.
	if not maze_renderer:
		maze_renderer = find_child("MazeRenderer", true, false)

	if maze_renderer:
		if local_maze:
			maze_renderer.source_layer_path = local_maze.get_path()
		if local_anim:
			maze_renderer.transition_layer_path = local_anim.get_path()

		# Force the TileMapLayer changes to register in the custom renderer next frame
		if maze_renderer.has_method("_update_source_reference"):
			maze_renderer.call_deferred("_update_source_reference")
		if maze_renderer.has_method("_update_transition_reference"):
			maze_renderer.call_deferred("_update_transition_reference")

		# Use styles defined in the Stem config to support per-stem colors
		if stem_data and "maze_styles" in stem_data and not stem_data.maze_styles.is_empty():
			maze_renderer.custom_styles = stem_data.maze_styles.duplicate()
		elif "custom_styles" in maze_renderer and maze_renderer.custom_styles.is_empty():
			# Fallback if StemData has no styles defined
			var primary_style := MazeTileStyle.new()
			primary_style.source_id = 1
			primary_style.button_color = Color("ffffff")
			primary_style.side_color = Color("c5c5c5")
			primary_style.glow_color = Color("00cdff")
			primary_style.glow_opacity = 0.5
			var wall_style := MazeTileStyle.new()
			wall_style.source_id = 5
			wall_style.button_color = Color("1a1a1a")
			wall_style.side_color = Color("0a0a0a")
			wall_style.glow_color = Color("ff0044")
			wall_style.glow_opacity = 0.2
			maze_renderer.custom_styles = [primary_style, wall_style]

		maze_renderer.call_deferred("queue_redraw")

	if not background_renderer:
		background_renderer = find_child("BackgroundRenderer", true, false)

	if background_renderer:
		# A single 84x84 maze tile maps to a 3x3 grid of 28x28 background pads.
		# Viewport is 1596x1008. (1596 / 28 = 57 cols), (1008 / 28 = 36 rows).
		background_renderer.tile_size = Vector2(28, 28)
		background_renderer.grid_width = 57
		background_renderer.grid_height = 36
		background_renderer.visible = true
		background_renderer.call_deferred("queue_redraw")


func _start_wave(wave_index: int) -> void:
	# Begins spawning enemies for the stem. Since stem=wave now, we only run this once.
	if not stem_data:
		return

	GameManager.set_wave(wave_index + 1, stem_data)
	_spawning = true
	_active_enemy_count = 0
	_spawn_stem(stem_data)
	if is_instance_valid(_stem_audio_player) and not _stem_audio_player.playing:
		_stem_audio_player.play()


func _spawn_stem(stem: StemData) -> void:
	# Flattens all SpawnInstructions into a single sorted timeline of spawn events.
	# Each instruction can specify a start_delay and enemy_delay, which are accumulated
	# into absolute trigger times. All instructions run in parallel.
	_spawn_queue.clear()
	_spawn_timer = 0.0

	var master_timeline: Array[Dictionary] = []

	for instruction: SpawnInstruction in stem.spawns:
		var current_time: float = instruction.start_delay
		for index: int in range(instruction.count):
			master_timeline.append(
				{
					"time": current_time,
					"scene": instruction.enemy_scene,
					"spawn_location_tag": instruction.spawn_location_tag,
				}
			)
			current_time += instruction.enemy_delay

	master_timeline.sort_custom(
		func(event_first: Dictionary, event_second: Dictionary) -> bool:
			return event_first["time"] < event_second["time"]
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
	var spawn_location_tag: String = event.get("spawn_location_tag", "Random")

	# Resolve the tag to a world position via the cached spawn markers.
	var spawn_position: Vector2 = Vector2.ZERO
	if spawn_location_tag == "Random" or spawn_location_tag.is_empty():
		# Collect all keys that start with "Spawn_" and pick one at random.
		var available_spawn_keys: Array[String] = []
		for marker_key: String in _spawn_markers.keys():
			if marker_key.begins_with("Spawn_"):
				available_spawn_keys.append(marker_key)
		if available_spawn_keys.is_empty():
			push_error("BaseStage: No spawn markers cached. Cannot spawn enemy.")
			return
		spawn_position = _spawn_markers[available_spawn_keys[randi() % available_spawn_keys.size()]]
	elif _spawn_markers.has(spawn_location_tag):
		spawn_position = _spawn_markers[spawn_location_tag]
	else:
		push_error("BaseStage: Spawn tag '%s' not found in cached markers. Cannot spawn enemy." % spawn_location_tag)
		return

	# Wait for AStar to be ready if it isn't.
	if not _astar_grid:
		_initialize_navigation_grid()

	# Resolve the start tile from world position via the maze layer.
	var start_tile: Vector2i = Vector2i.ZERO
	if maze_renderer:
		var layer_node: Node = maze_renderer.get_node_or_null(maze_renderer.source_layer_path)
		if layer_node is TileMapLayer:
			var maze_layer: TileMapLayer = layer_node as TileMapLayer
			start_tile = maze_layer.local_to_map(maze_layer.to_local(spawn_position))
		else:
			push_error("BaseStage: Failed to resolve start_tile: maze layer not found.")
			return

	# Resolve goal tile: find the nearest walkable edge tile in the AStar grid.
	# Since there is only one exit, we look for the "Goal" marker's closest AStar tile.
	var target_tile: Vector2i = Vector2i.ZERO
	if _spawn_markers.has("Goal"):
		if maze_renderer:
			var layer_node: Node = maze_renderer.get_node_or_null(maze_renderer.source_layer_path)
			if layer_node is TileMapLayer:
				var maze_layer: TileMapLayer = layer_node as TileMapLayer
				target_tile = maze_layer.local_to_map(maze_layer.to_local(_spawn_markers["Goal"]))
	elif _astar_grid:
		# Fallback: pick a suitable edge tile from the AStar region.
		var region: Rect2i = _astar_grid.region
		target_tile = Vector2i(region.end.x - 1, region.position.y + int(region.size.y / 2.0))
		push_warning("BaseStage: No Goal marker found. Using fallback target tile %s." % target_tile)

	# Runtime validation: skip spawn if either tile is not walkable.
	var grid_region: Rect2i = _astar_grid.region
	if not grid_region.has_point(start_tile) or _astar_grid.is_point_solid(start_tile):
		push_warning("Skipping enemy spawn: start_tile %s (from tag '%s') is not walkable." % [start_tile, spawn_location_tag])
		return
	if not grid_region.has_point(target_tile) or _astar_grid.is_point_solid(target_tile):
		push_warning("Skipping enemy spawn: target_tile %s (Goal marker) is not walkable." % target_tile)
		return

	_spawn_enemy(event["scene"], spawn_position, start_tile, target_tile)


func _spawn_enemy(
	enemy_scene: PackedScene, spawn_position: Vector2, start_tile: Vector2i, target_tile: Vector2i
) -> TemplateEnemy:
	var enemy: TemplateEnemy = ObjectPoolManager.get_object(enemy_scene) as TemplateEnemy
	if not is_instance_valid(enemy):
		return null

	if is_instance_valid(_enemies_container):
		_enemies_container.add_child(enemy)
	else:
		push_error("Enemies container is not valid.")
		return null
	enemy.reset()
	enemy.global_position = spawn_position

	# Enable visibility only AFTER positioning to prevent (0,0) flash.
	enemy.visible = true
	_active_enemy_count += 1

	# Provide navigation context explicitly
	enemy.set_navigation_context(_astar_grid, start_tile, target_tile)
	enemy.set_process(true)

	if not enemy.path_finished.is_connected(_on_enemy_finished_path):
		enemy.path_finished.connect(_on_enemy_finished_path)
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
	# If the peak volume just caused a fail, don't also trigger wave completion.
	if not _stem_has_failed:
		_check_wave_completion()


func _on_next_wave_requested() -> void:
	# Starts the next wave when requested by the HUD.
	if _spawning:
		return

	if stem_data and _current_wave_index > 0:
		return  # Stem only has 1 wave

	_start_wave(_current_wave_index)
	_current_wave_index += 1


func _on_wave_spawn_finished() -> void:
	# Ends the spawning phase and updates HUD controls.
	_spawning = false
	# Check if wave is already done (e.g. all enemies died instantly/fast)
	_check_wave_completion()


func _check_wave_completion() -> void:
	# Only complete the wave if NO enemies are left AND we are done spawning.
	# Also skip if the stem has already failed this frame.
	if _stem_has_failed:
		return
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
	# Runs the dissolve (Animation -> Maze) and overlapping path flow animations.
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
	tween.tween_callback(
		func() -> void:
			maze_renderer.transition_layer_path = NodePath()
			maze_renderer.reveal_mode = maze_renderer.RevealMode.LINEAR
			opening_sequence_finished.emit()
	)


func _start_path_flow_dissolve() -> void:
	# Starts the background removal alongside the dissolve.
	_initialize_navigation_grid()
	_validate_spawn_data()
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

	if not is_instance_valid(maze_layer.tile_set):
		push_error("Cannot initialize AStarGrid2D: maze layer has no tile_set assigned.")
		return

	_astar_grid = AStarGrid2D.new()
	_astar_grid.region = used_rect
	_astar_grid.cell_size = maze_layer.tile_set.tile_size
	_astar_grid.offset = _astar_grid.cell_size / 2.0
	_astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar_grid.update()

	# Make only the floor tiles walkable
	for horizontal_index in range(
		used_rect.position.x,
		used_rect.position.x + used_rect.size.x
	):
		for vertical_index in range(
			used_rect.position.y,
			used_rect.position.y + used_rect.size.y
		):
			var cell: Vector2i = Vector2i(horizontal_index, vertical_index)
			var source_id: int = maze_layer.get_cell_source_id(cell)
			if source_id == floor_tile_id:
				_astar_grid.set_point_solid(cell, false)
			else:
				_astar_grid.set_point_solid(cell, true)

	print("AStarGrid2D Navigation Initialized for ", used_rect)


func _validate_spawn_data() -> void:
	# Validates all spawn location tags against the cached terrain markers at load time.
	if not stem_data:
		return

	for instruction_index: int in range(stem_data.spawns.size()):
		var instruction: SpawnInstruction = (
			stem_data.spawns[instruction_index] as SpawnInstruction
		)
		if not instruction:
			continue

		var tag: String = instruction.spawn_location_tag
		if tag == "Random" or tag.is_empty():
			# Random is always valid as long as at least one Spawn_ marker exists.
			var has_any_spawn: bool = false
			for marker_key: String in _spawn_markers.keys():
				if marker_key.begins_with("Spawn_"):
					has_any_spawn = true
					break
			if not has_any_spawn:
				push_warning(
					"Instruction %d uses 'Random' tag but no Spawn_ markers are cached!"
					% (instruction_index + 1)
				)
		elif not _spawn_markers.has(tag):
			push_warning(
				"Instruction %d: spawn_location_tag '%s' not found in layout markers!"
				% [instruction_index + 1, tag]
			)


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
				_hide_background_subcells(cell, 0.0)
		return

	# Find a valid floor tile to start the BFS, scanning from left to right.
	var start_coords: Vector2i = Vector2i.ZERO
	var used_rect: Rect2i = maze_layer.get_used_rect()
	var found_start: bool = false

	for horizontal_index in range(
		used_rect.position.x,
		used_rect.position.x + used_rect.size.x
	):
		for vertical_index in range(
			used_rect.position.y,
			used_rect.position.y + used_rect.size.y
		):
			var cell: Vector2i = Vector2i(horizontal_index, vertical_index)
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
		var current_distance: int = visited[current]

		if current_distance > max_distance:
			max_distance = current_distance

		for direction: Vector2i in directions:
			var next_cell: Vector2i = current + direction

			if visited.has(next_cell):
				continue

			if maze_layer.get_cell_source_id(next_cell) == floor_tile_id:
				visited[next_cell] = current_distance + 1
				bfs_queue.append(next_cell)

	# Animated sequential shrink.
	var tween: Tween = create_tween()
	var step_delay: float = 0.05
	if max_distance > 0:
		step_delay = step5_path_flow_duration / float(max_distance)

	for cell: Vector2i in visited.keys():
		var distance: int = visited[cell]
		var delay: float = float(distance) * step_delay
		var shrink_duration: float = step6_pad_anim_duration

		(
			tween
			. parallel()
			. tween_callback(func() -> void: _hide_background_subcells(cell, shrink_duration))
			. set_delay(delay)
		)


func _hide_background_subcells(maze_cell: Vector2i, duration: float) -> void:
	# An 84x84 maze cell maps to nine 28x28 background cells (a 3x3 grid).
	# Calculate the top-left background cell.
	var background_start_x: int = maze_cell.x * 3
	var background_start_y: int = maze_cell.y * 3

	# Hide all nine sub-cells.
	for x_offset in range(3):
		for y_offset in range(3):
			background_renderer.animate_hide_cell(
				Vector2i(background_start_x + x_offset, background_start_y + y_offset), duration
			)


func _setup_stem_audio() -> void:
	# Creates a managed AudioStreamPlayer and connects it to the stem completion pathway.
	# Uses the Good-quality stream as the primary track. Quality crossfading is handled
	# separately by the AudioManager (future implementation).
	if not stem_data:
		return

	_stem_audio_player = AudioStreamPlayer.new()
	_stem_audio_player.name = "StemAudioPlayer"
	add_child(_stem_audio_player)

	# Use the Good stream as the base track. AudioManager will handle crossfading.
	if stem_data.stem_audio_good:
		_stem_audio_player.stream = stem_data.stem_audio_good
	elif stem_data.stem_audio_avg:
		_stem_audio_player.stream = stem_data.stem_audio_avg
	elif stem_data.stem_audio_bad:
		_stem_audio_player.stream = stem_data.stem_audio_bad

	if _stem_audio_player.stream:
		_stem_audio_player.finished.connect(_on_stem_track_finished)


func _on_stem_track_finished() -> void:
	# Called when the stem's audio track reaches its end.
	# Boss stems loop; all others apply the track-end penalty and complete.
	if stem_data and stem_data.is_boss_stem:
		# Boss wave loops until the boss is defeated or the peak meter fills.
		_stem_audio_player.play()
		return

	_apply_track_end_penalty()

	if _stem_has_failed:
		return

	_clear_all_enemies()
	_spawning = false
	GameManager.wave_completed()


func _on_stem_failed() -> void:
	# Called when the peak meter clips to 100% during the wave (enemy leak).
	# Clears all enemies and stops spawning — StageManager handles the Setlist return.
	_stem_has_failed = true
	_spawning = false
	_spawn_queue.clear()
	_clear_all_enemies()
	if is_instance_valid(_stem_audio_player) and _stem_audio_player.playing:
		# Disconnect so stopping the player doesn't trigger _on_stem_track_finished
		if _stem_audio_player.finished.is_connected(_on_stem_track_finished):
			_stem_audio_player.finished.disconnect(_on_stem_track_finished)
		_stem_audio_player.stop()


func _apply_track_end_penalty() -> void:
	# Calculates and applies the track-end damage for all surviving enemies.
	# Skipped when _bypass_track_end_penalty is true (debug force-complete path).
	if _bypass_track_end_penalty or not stem_data:
		_bypass_track_end_penalty = false
		return

	var penalty_ratio: float = stem_data.track_end_penalty_ratio
	if penalty_ratio <= 0.0:
		return

	if not is_instance_valid(_enemies_container):
		return

	var total_penalty: float = 0.0
	for enemy in _enemies_container.get_children():
		if enemy.has_method("reset") and "health" in enemy:
			total_penalty += float(enemy.health) * penalty_ratio

	if total_penalty > 0.0:
		if OS.is_debug_build():
			print(
				"Track ended. Applying penalty: %.1f (ratio: %.2f)" % [total_penalty, penalty_ratio]
			)
		GameManager.add_peak_volume(total_penalty)


func _clear_all_enemies() -> void:
	# Returns all living enemies to the object pool cleanly.
	if not is_instance_valid(_enemies_container):
		return

	for enemy in _enemies_container.get_children():
		if is_instance_valid(enemy):
			ObjectPoolManager.return_object(enemy)

	_active_enemy_count = 0
