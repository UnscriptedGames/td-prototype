@tool
extends Node2D

## Offline generator tool for building 19x12 maze layouts.
## Supports 1-3 spawn points converging into a single exit.

const GRID_WIDTH: int = 19
const GRID_HEIGHT: int = 12
const WALL_TILE_ID: int = 5
const FLOOR_TILE_ID: int = 1
const FORCED_SEGMENT_LENGTH: int = 2

@export_group("Generator Settings")
@export var output_filename: String = "stage01_stem03"
@export_range(0.0, 2.0) var wander_strength: float = 1.2
## Minimum tiles to move in a straight line after each turn. Prevents staircase patterns.
@export_range(1, 8) var min_straight_steps: int = 3

## Spawn coordinates. Use virtual coords (e.g. y=-1 for top edge). Add 1–3 entries.
@export var spawns: Array[Vector2i] = [Vector2i(4, -1)]

## Merge point: where secondary paths converge onto the primary path.
## Uses the same virtual coordinate rules as spawns/goal.
## Only relevant when spawns.size() > 1.
@export_range(-2, 21) var merge_x: int = 9
@export_range(-2, 13) var merge_y: int = 3

## Exit coordinate. Use virtual coords (e.g. x=19 for right edge).
@export_range(-2, 21) var goal_x: int = 19
@export_range(-2, 13) var goal_y: int = 5

@export_group("Actions")
## Check this box in the inspector to generate a new maze preview.
@export var generate_new: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate_maze()
		generate_new = false

## Check this box to bake the current preview into a .tscn file.
@export var save_to_disk: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_save_maze()
		save_to_disk = false

@export_group("Internal References")
@export var maze_layer: TileMapLayer
@export var animation_layer: TileMapLayer


func _generate_maze() -> void:
	if not maze_layer or not animation_layer:
		push_error("MazeGenerator: Missing layer references")
		return
	if spawns.is_empty():
		push_error("MazeGenerator: No spawn points defined.")
		return

	# --- AUTO-RETRY LOOP (Max 10 attempts to find a valid layout) ---
	for attempt in range(10):
		maze_layer.clear()
		animation_layer.clear()

		# Infer virtual goal tile and exit direction.
		var virtual_goal: Vector2i
		var exit_dir: Vector2i
		if goal_y < 0:
			virtual_goal = Vector2i(clampi(goal_x, 0, GRID_WIDTH - 1), 0)
			exit_dir = Vector2i.UP
		elif goal_y >= GRID_HEIGHT:
			virtual_goal = Vector2i(clampi(goal_x, 0, GRID_WIDTH - 1), GRID_HEIGHT - 1)
			exit_dir = Vector2i.DOWN
		elif goal_x < 0:
			virtual_goal = Vector2i(0, clampi(goal_y, 0, GRID_HEIGHT - 1))
			exit_dir = Vector2i.LEFT
		elif goal_x >= GRID_WIDTH:
			virtual_goal = Vector2i(GRID_WIDTH - 1, clampi(goal_y, 0, GRID_HEIGHT - 1))
			exit_dir = Vector2i.RIGHT
		else:
			virtual_goal = Vector2i(goal_x, goal_y)
			exit_dir = Vector2i.ZERO

		# Infer merge tile (the convergence point for secondary paths).
		var merge_tile: Vector2i
		if merge_y < 0:
			merge_tile = Vector2i(clampi(merge_x, 0, GRID_WIDTH - 1), 0)
		elif merge_y >= GRID_HEIGHT:
			merge_tile = Vector2i(clampi(merge_x, 0, GRID_WIDTH - 1), GRID_HEIGHT - 1)
		elif merge_x < 0:
			merge_tile = Vector2i(0, clampi(merge_y, 0, GRID_HEIGHT - 1))
		elif merge_x >= GRID_WIDTH:
			merge_tile = Vector2i(GRID_WIDTH - 1, clampi(merge_y, 0, GRID_HEIGHT - 1))
		else:
			merge_tile = Vector2i(merge_x, merge_y)

		# Pre-compute the approach point for the guaranteed straight exit run.
		var approach_point: Vector2i
		if exit_dir == Vector2i.RIGHT:
			approach_point = Vector2i(virtual_goal.x - FORCED_SEGMENT_LENGTH, virtual_goal.y)
		elif exit_dir == Vector2i.LEFT:
			approach_point = Vector2i(virtual_goal.x + FORCED_SEGMENT_LENGTH, virtual_goal.y)
		elif exit_dir == Vector2i.DOWN:
			approach_point = Vector2i(virtual_goal.x, virtual_goal.y - FORCED_SEGMENT_LENGTH)
		elif exit_dir == Vector2i.UP:
			approach_point = Vector2i(virtual_goal.x, virtual_goal.y + FORCED_SEGMENT_LENGTH)
		else:
			approach_point = virtual_goal
		approach_point.x = clampi(approach_point.x, 0, GRID_WIDTH - 1)
		approach_point.y = clampi(approach_point.y, 0, GRID_HEIGHT - 1)

		# --- PASS 1: Primary Spawn (spawns[0]) carves the full route to the exit. ---
		var primary_spawn_tile: Vector2i = _infer_spawn_tile(spawns[0])
		var primary_heading: Vector2i = _get_spawn_direction(spawns[0])
		_carve_lane(
			primary_spawn_tile,
			primary_heading,
			approach_point,
			virtual_goal,
			exit_dir,
			true,
			exit_dir,
			0
		)

		# --- PASS 2+: Secondary Spawns carve toward the merge point and stop on contact. ---
		for spawn_index in range(1, spawns.size()):
			var secondary_spawn_tile: Vector2i = _infer_spawn_tile(spawns[spawn_index])
			var secondary_heading: Vector2i = _get_spawn_direction(spawns[spawn_index])
			_carve_lane(
				secondary_spawn_tile,
				secondary_heading,
				merge_tile,
				merge_tile,
				Vector2i.ZERO,
				false,
				exit_dir,
				15  # Secondary lanes must run at least 15 tiles before merging
			)

		# --- PRUNING: Union AStar search to clean dead-end stubs from all paths. ---
		var all_pruned_tiles: Dictionary = {}
		for spawn_entry in spawns:
			var spawn_tile: Vector2i = _infer_spawn_tile(spawn_entry)
			var path_tiles: Array[Vector2i] = _prune_path(spawn_tile, virtual_goal)
			for tile in path_tiles:
				all_pruned_tiles[tile] = true

		if all_pruned_tiles.size() > 0:
			maze_layer.clear()
			for tile in all_pruned_tiles.keys():
				_carve_point(tile)

		# --- CORNER SHAVE: Eliminate 2x2 floor clumps from merge junctions ---
		_shave_corners()

		_build_constrained_walls()

		# Validation check: Did all spawns successfully reach the goal without being blocked?
		if _validate_maze():
			print(
				"MazeGenerator: Generation complete on attempt ",
				attempt + 1,
				". Spawns: ",
				spawns.size()
			)
			return  # Success! Escape the retry loop.

		# If invalid, the loop continues and tries a new random seed over a fresh layer.

	push_error(
		"MazeGenerator: Failed to generate a valid multi-spawn maze after 10 attempts. The requested layout might be too constrained."
	)


## Carves a single lane from start_tile toward target_tile, then optionally
## runs the guaranteed straight exit run. Stops early if it touches existing floor tiles.
func _carve_lane(
	start_tile: Vector2i,
	initial_heading: Vector2i,
	wander_target: Vector2i,
	exit_target: Vector2i,
	lane_exit_dir: Vector2i,
	is_primary: bool,
	global_exit_dir: Vector2i,
	min_steps_before_merge: int = 0
) -> void:
	var current: Vector2i = start_tile
	var current_heading: Vector2i = initial_heading
	var max_steps: int = 300
	var steps: int = 0
	var straight_steps_taken: int = 0
	var recent_path: Array[Vector2i] = []

	_carve_point(current)
	recent_path.push_back(current)

	# Forced entrance segment directly into the grid.
	for _forced_step in range(FORCED_SEGMENT_LENGTH):
		current += current_heading
		current.x = clampi(current.x, 0, GRID_WIDTH - 1)
		current.y = clampi(current.y, 0, GRID_HEIGHT - 1)
		_carve_point(current)
		recent_path.push_back(current)
	straight_steps_taken = FORCED_SEGMENT_LENGTH

	# Wander toward wander_target.
	while current != wander_target and steps < max_steps:
		# Secondary paths stop early if they touch existing primary path floor tiles,
		# but ONLY after they have traveled their minimum mandatory length.
		if (
			not is_primary
			and steps >= min_steps_before_merge
			and _is_adjacent_to_existing_path(current, recent_path)
		):
			break

		steps += 1
		var exploration_progress: float = float(steps) / float(max_steps)
		var goal_bias_strength: float = 0.0
		if exploration_progress > 0.4:
			goal_bias_strength = (exploration_progress - 0.4) * 1.6

		var dx: int = wander_target.x - current.x
		var dy: int = wander_target.y - current.y

		var options: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
		var weights: Array[float] = [0.5, 0.5, 0.5, 0.5]

		# Forced straight run after a turn.
		if straight_steps_taken < min_straight_steps:
			if current_heading == Vector2i.RIGHT:
				weights[1] = 0
				weights[2] = 0
				weights[3] = 0
			elif current_heading == Vector2i.LEFT:
				weights[0] = 0
				weights[2] = 0
				weights[3] = 0
			elif current_heading == Vector2i.UP:
				weights[0] = 0
				weights[1] = 0
				weights[3] = 0
			elif current_heading == Vector2i.DOWN:
				weights[0] = 0
				weights[1] = 0
				weights[2] = 0
		else:
			# No 180° turns.
			if current_heading == Vector2i.RIGHT:
				weights[1] = 0.0
			elif current_heading == Vector2i.LEFT:
				weights[0] = 0.0
			elif current_heading == Vector2i.UP:
				weights[3] = 0.0
			elif current_heading == Vector2i.DOWN:
				weights[2] = 0.0

			# Wander spread: random bias while exploring.
			var random_spread: float = wander_strength * 2.0 * (1.1 - goal_bias_strength)
			for i in range(4):
				if weights[i] > 0.0:
					weights[i] += randf() * random_spread

		# Goal bias: ramps in after exploration phase.
		if goal_bias_strength > 0.0:
			var goal_scale: float = goal_bias_strength * 2.5
			if dx > 0:
				weights[0] += goal_scale
			elif dx < 0:
				weights[1] += goal_scale
			if dy < 0:
				weights[2] += goal_scale
			elif dy > 0:
				weights[3] += goal_scale

		# Momentum: slight bonus for continuing straight.
		if current_heading == Vector2i.RIGHT:
			weights[0] += 0.8
		elif current_heading == Vector2i.LEFT:
			weights[1] += 0.8
		elif current_heading == Vector2i.UP:
			weights[2] += 0.8
		elif current_heading == Vector2i.DOWN:
			weights[3] += 0.8

		# Hard grid boundaries.
		if current.x <= 0:
			weights[1] = 0.0
		if current.x >= GRID_WIDTH - 1:
			weights[0] = 0.0
		if current.y <= 0:
			weights[2] = 0.0
		if current.y >= GRID_HEIGHT - 1:
			weights[3] = 0.0

		# Corridor guard: prevent accidental early entry into the exit approach zone.
		if is_primary:
			if global_exit_dir == Vector2i.RIGHT and current.y != exit_target.y:
				if (current.x + 1) >= wander_target.x:
					weights[0] = 0.0
			elif global_exit_dir == Vector2i.LEFT and current.y != exit_target.y:
				if (current.x - 1) <= wander_target.x:
					weights[1] = 0.0
			elif global_exit_dir == Vector2i.DOWN and current.x != exit_target.x:
				if (current.y + 1) >= wander_target.y:
					weights[3] = 0.0
			elif global_exit_dir == Vector2i.UP and current.x != exit_target.x:
				if (current.y - 1) <= wander_target.y:
					weights[2] = 0.0

		# 2-Tile clearance: ban moves that would directly touch existing floor.
		for i in range(4):
			if weights[i] > 0.0:
				var proposed_next: Vector2i = current + options[i]
				for ox in range(-1, 2):
					for oy in range(-1, 2):
						var scan_tile: Vector2i = proposed_next + Vector2i(ox, oy)
						if scan_tile in recent_path:
							continue
						if maze_layer.get_cell_source_id(scan_tile) == FLOOR_TILE_ID:
							weights[i] = 0.0
							break
					if weights[i] == 0.0:
						break

		# Fallback: if all blocked, push directly toward target.
		var total: float = weights[0] + weights[1] + weights[2] + weights[3]
		var chosen_dir: Vector2i
		if total <= 0.0:
			if abs(dx) > abs(dy):
				chosen_dir = Vector2i.RIGHT if dx > 0 else Vector2i.LEFT
			else:
				chosen_dir = Vector2i.DOWN if dy > 0 else Vector2i.UP
		else:
			var rand_val: float = randf() * total
			var cumulative: float = 0.0
			chosen_dir = options[0]
			for i in range(4):
				cumulative += weights[i]
				if rand_val <= cumulative:
					chosen_dir = options[i]
					break

		if chosen_dir == current_heading:
			straight_steps_taken += 1
		else:
			straight_steps_taken = 1

		current_heading = chosen_dir
		current += chosen_dir
		current.x = clampi(current.x, 0, GRID_WIDTH - 1)
		current.y = clampi(current.y, 0, GRID_HEIGHT - 1)
		_carve_point(current)
		recent_path.push_back(current)
		if recent_path.size() > 5:
			recent_path.pop_front()

	# Ensure approach point is always carved. Then run the guaranteed straight exit.
	if is_primary:
		_carve_point(wander_target)
		if lane_exit_dir != Vector2i.ZERO:
			var safety_steps: int = 0
			while current != exit_target and safety_steps < 20:
				safety_steps += 1
				current += lane_exit_dir
				current.x = clampi(current.x, 0, GRID_WIDTH - 1)
				current.y = clampi(current.y, 0, GRID_HEIGHT - 1)
				_carve_point(current)
		else:
			_carve_point(exit_target)


## Returns true if the given tile has a floor neighbor not in its own recent_path.
## Used by secondary paths to detect when they have merged with the primary path.
func _is_adjacent_to_existing_path(tile: Vector2i, own_recent_path: Array[Vector2i]) -> bool:
	for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = tile + offset
		if neighbor in own_recent_path:
			continue
		if maze_layer.get_cell_source_id(neighbor) == FLOOR_TILE_ID:
			return true
	return false


## Resolves a virtual spawn coordinate into a real grid tile.
func _infer_spawn_tile(spawn: Vector2i) -> Vector2i:
	if spawn.y <= -1:
		return Vector2i(clampi(spawn.x, 0, GRID_WIDTH - 1), 0)
	elif spawn.y >= GRID_HEIGHT:
		return Vector2i(clampi(spawn.x, 0, GRID_WIDTH - 1), GRID_HEIGHT - 1)
	elif spawn.x <= -1:
		return Vector2i(0, clampi(spawn.y, 0, GRID_HEIGHT - 1))
	elif spawn.x >= GRID_WIDTH:
		return Vector2i(GRID_WIDTH - 1, clampi(spawn.y, 0, GRID_HEIGHT - 1))
	return spawn


## Returns the perpendicular entry direction for a virtual spawn.
func _get_spawn_direction(spawn: Vector2i) -> Vector2i:
	if spawn.y <= -1:
		return Vector2i.DOWN
	if spawn.y >= GRID_HEIGHT:
		return Vector2i.UP
	if spawn.x <= -1:
		return Vector2i.RIGHT
	if spawn.x >= GRID_WIDTH:
		return Vector2i.LEFT
	# Default fallback if spawn is already in-grid
	return Vector2i.DOWN


func _get_initial_heading(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if abs(dx) > abs(dy):
		return Vector2i.RIGHT if dx > 0 else Vector2i.LEFT
	else:
		return Vector2i.DOWN if dy > 0 else Vector2i.UP


func _build_constrained_walls() -> void:
	var floor_cells: Array[Vector2i] = maze_layer.get_used_cells()
	var wall_candidates: Dictionary = {}
	for cell in floor_cells:
		for x_off in range(-1, 2):
			for y_off in range(-1, 2):
				if x_off == 0 and y_off == 0:
					continue
				var neighbor: Vector2i = cell + Vector2i(x_off, y_off)
				if (
					neighbor.x >= 0
					and neighbor.x < GRID_WIDTH
					and neighbor.y >= 0
					and neighbor.y < GRID_HEIGHT
				):
					if maze_layer.get_cell_source_id(neighbor) == -1:
						wall_candidates[neighbor] = true
	for wall_cell in wall_candidates.keys():
		maze_layer.set_cell(wall_cell, WALL_TILE_ID, Vector2i(0, 0))


## Sweeps the carved floor tiles and removes the mathematical "inner corner" of
## any 2x2 square blocks. This guarantees a strict 1-tile path width at merge junctions.
func _shave_corners() -> void:
	var floor_cells: Array[Vector2i] = maze_layer.get_used_cells()
	var cells_dict: Dictionary = {}
	for cell in floor_cells:
		cells_dict[cell] = true

	var clumps_to_shave: Array[Vector2i] = []

	for cell in floor_cells:
		if (
			cells_dict.has(cell)
			and cells_dict.has(cell + Vector2i.RIGHT)
			and cells_dict.has(cell + Vector2i.DOWN)
			and cells_dict.has(cell + Vector2i(1, 1))
		):
			# Found a 2x2 block. Identify the "fat" inner corner by counting outside connections.
			var block: Array[Vector2i] = [
				cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i(1, 1)
			]

			var min_outside_neighbors: int = 99
			var inner_corner: Vector2i = block[0]

			for block_cell in block:
				var outside_count: int = 0
				for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var neighbor = block_cell + dir
					if not neighbor in block and cells_dict.has(neighbor):
						outside_count += 1

				if outside_count < min_outside_neighbors:
					min_outside_neighbors = outside_count
					inner_corner = block_cell

			if not clumps_to_shave.has(inner_corner):
				clumps_to_shave.append(inner_corner)

	for tile in clumps_to_shave:
		maze_layer.erase_cell(tile)
		cells_dict.erase(tile)


func _carve_point(pt: Vector2i) -> void:
	if pt.x >= 0 and pt.x < GRID_WIDTH and pt.y >= 0 and pt.y < GRID_HEIGHT:
		maze_layer.set_cell(pt, FLOOR_TILE_ID, Vector2i(0, 0))


## AStar pruning: finds the shortest path from start to end among only the carved
## floor tiles. Used to strip dead-end stubs from each lane.
func _prune_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	grid.cell_size = Vector2(84, 84)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell = Vector2i(x, y)
			grid.set_point_solid(cell, maze_layer.get_cell_source_id(cell) != FLOOR_TILE_ID)
	var id_path = grid.get_id_path(start, end)
	var final_path: Array[Vector2i] = []
	for p in id_path:
		final_path.append(p)
	return final_path


func _save_maze() -> void:
	if output_filename.is_empty():
		push_error("MazeGenerator: Output filename is empty.")
		return
	if not _validate_maze():
		push_error("MazeGenerator: Discarding invalid maze (no clear path). Please generate again.")
		return

	var out_dir: String = "res://Stages/LevelLayouts"
	var dir = DirAccess.open("res://Stages")
	if dir and not dir.dir_exists("LevelLayouts"):
		dir.make_dir("LevelLayouts")

	var scene = PackedScene.new()
	var root = Node2D.new()
	root.name = "MazeData"

	var host_guide: ReferenceRect = get_node_or_null("DesignGuide")
	if host_guide:
		var new_guide = host_guide.duplicate()
		root.add_child(new_guide)
		new_guide.owner = root
	else:
		var ref = ReferenceRect.new()
		ref.name = "DesignGuide"
		ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ref.border_color = Color(1.0, 0.0, 0.0, 0.5)
		ref.border_width = 2.0
		ref.size = Vector2(1596, 1008)
		root.add_child(ref)
		ref.owner = root

	var new_maze = maze_layer.duplicate()
	root.add_child(new_maze)
	new_maze.owner = root
	new_maze.visible = true

	var new_anim = animation_layer.duplicate()
	root.add_child(new_anim)
	new_anim.owner = root
	new_anim.visible = false

	scene.pack(root)
	var path: String = out_dir + "/" + output_filename + ".tscn"
	var err = ResourceSaver.save(scene, path)
	if err == OK:
		print("MazeGenerator: Successfully saved baked layout to -> ", path)
	else:
		push_error("MazeGenerator: Failed to save maze. Error code: ", err)
	root.free()


func _validate_maze() -> bool:
	var grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	grid.cell_size = Vector2(84, 84)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var actual_goal: Vector2i = Vector2i(
		clampi(goal_x, 0, GRID_WIDTH - 1), clampi(goal_y, 0, GRID_HEIGHT - 1)
	)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell = Vector2i(x, y)
			grid.set_point_solid(cell, maze_layer.get_cell_source_id(cell) != FLOOR_TILE_ID)
	# All spawns must be able to reach the goal.
	for spawn_entry in spawns:
		var spawn_tile: Vector2i = _infer_spawn_tile(spawn_entry)
		var path = grid.get_id_path(spawn_tile, actual_goal)
		if path.size() == 0:
			return false
	return true
