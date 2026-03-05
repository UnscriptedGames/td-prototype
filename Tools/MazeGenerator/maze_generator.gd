@tool
extends Node2D

## Offline generator tool for building 19x12 maze layouts.
## Supports 1-3 spawn points converging into a single exit.
## Spawn and exit placement is fully automated using a Goal-First semantic system.

const GRID_WIDTH: int = 19
const GRID_HEIGHT: int = 12
const WALL_TILE_ID: int = 5
const FLOOR_TILE_ID: int = 1
const FORCED_SEGMENT_LENGTH: int = 2

## The virtual edge indices used to identify the 4 sides of the grid.
enum Edge { TOP = 0, BOTTOM = 1, LEFT = 2, RIGHT = 3 }

@export_group("Generator Settings")
@export var output_filename: String = "stage01_stem03"
@export_range(0.0, 2.0) var wander_strength: float = 1.2
## Minimum tiles to move in a straight line after each turn. Prevents staircase patterns.
@export_range(1, 8) var min_straight_steps: int = 3
## Number of spawn points to generate (1–3).
@export_range(1, 3) var spawn_count: int = 1
## Minimum Euclidean distance required between any spawn and the goal.
@export_range(5, 25) var min_spawn_goal_distance: float = 12.0
## Minimum Euclidean distance required between any two spawn points.
@export_range(3, 15) var min_spawn_spawn_distance: float = 5.0
## Optional seed for reproducible layouts. Set to 0 for a fully random seed.
@export var placement_seed: int = 0

@export_group("Path Quality")
## Minimum number of tiles each spawn's path must travel before reaching the goal.
## Scaled recommendation: 1 spawn=50, 2 spawns=35, 3 spawns=25.
@export_range(10, 80) var min_path_length_per_spawn: int = 35
## Minimum fraction of the grid (0.0–1.0) that must be covered by floor tiles.
## Ensures the maze uses enough of the available space. Recommended: 0.30.
@export_range(0.10, 0.60) var min_floor_coverage: float = 0.30
## Gravitational pull toward the grid centre during the wander phase.
## 0.0 = no effect (current behaviour). 0.8 = subtle arc. 1.5+ = strong centrist paths.
@export_range(0.0, 2.0) var centre_bias: float = 0.8

@export_group("Preview (Read-Only)")
## These fields show the computed placement from the last generation. Do not edit manually.
@export var _preview_goal: Vector2i = Vector2i(-1, -1)
@export var _preview_spawns: Array[Vector2i] = []
@export var _preview_merge: Vector2i = Vector2i(-1, -1)

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

	# Seed the random number generator for placement.
	if placement_seed != 0:
		seed(placement_seed)

	# --- STEP 1: Automated Semantic Placement ---
	var placement: Dictionary = _pick_placements()
	if placement.is_empty():
		push_error(
			"MazeGenerator: Could not generate valid placement after all retries. Try adjusting distance constraints or spawn count."
		)
		return

	# Spawns are stored as virtual coords (off-grid), goal is on-grid.
	var virtual_spawns: Array[Vector2i] = placement["spawns"]
	var computed_goal: Vector2i = placement["goal"]  # The goal is explicitly on-grid.
	var computed_merge: Vector2i = placement["merge"]

	# Write coords back to inspector preview fields.
	_preview_goal = computed_goal
	_preview_spawns = virtual_spawns
	_preview_merge = computed_merge

	# Resolve each virtual spawn coord to the real grid-edge tile that sits just inside the boundary.
	var computed_spawns: Array[Vector2i] = []
	for virtual_spawn in virtual_spawns:
		computed_spawns.append(_resolve_virtual_to_grid(virtual_spawn))

	# Infer goal outward edge direction from the grid-edge tile.
	var exit_dir: Vector2i = -_get_edge_direction_for_tile(computed_goal)

	# Pre-compute the approach point for the guaranteed straight exit run.
	# Pulled inward by FORCED_SEGMENT_LENGTH from the grid-edge goal tile.
	var approach_point: Vector2i
	if exit_dir == Vector2i.RIGHT:
		approach_point = Vector2i(computed_goal.x - FORCED_SEGMENT_LENGTH, computed_goal.y)
	elif exit_dir == Vector2i.LEFT:
		approach_point = Vector2i(computed_goal.x + FORCED_SEGMENT_LENGTH, computed_goal.y)
	elif exit_dir == Vector2i.DOWN:
		approach_point = Vector2i(computed_goal.x, computed_goal.y - FORCED_SEGMENT_LENGTH)
	elif exit_dir == Vector2i.UP:
		approach_point = Vector2i(computed_goal.x, computed_goal.y + FORCED_SEGMENT_LENGTH)
	else:
		approach_point = computed_goal
	approach_point.x = clampi(approach_point.x, 1, GRID_WIDTH - 2)
	approach_point.y = clampi(approach_point.y, 1, GRID_HEIGHT - 2)

	# --- AUTO-RETRY LOOP (Max 30 attempts to find a valid carved layout) ---
	for attempt in range(30):
		maze_layer.clear()
		animation_layer.clear()

		# --- PASS 1: Primary Spawn (spawns[0]) carves the full route to the exit. ---
		var primary_spawn_tile: Vector2i = computed_spawns[0]
		var primary_heading: Vector2i = _get_edge_direction_for_virtual(virtual_spawns[0])
		_carve_lane(
			primary_spawn_tile,
			primary_heading,
			approach_point,
			computed_goal,
			exit_dir,
			true,
			exit_dir,
			0
		)

		# --- PASS 2+: Secondary Spawns carve toward the merge point and stop on contact. ---
		for spawn_index in range(1, computed_spawns.size()):
			var secondary_spawn_tile: Vector2i = computed_spawns[spawn_index]
			var secondary_heading: Vector2i = _get_edge_direction_for_virtual(
				virtual_spawns[spawn_index]
			)
			_carve_lane(
				secondary_spawn_tile,
				secondary_heading,
				computed_merge,
				computed_merge,
				Vector2i.ZERO,
				false,
				exit_dir,
				15  # Secondary lanes must run at least 15 tiles before merging.
			)

		# --- PRUNING: Union AStar search to clean dead-end stubs from all paths. ---
		var all_pruned_tiles: Dictionary = {}
		for spawn_tile in computed_spawns:
			var path_tiles: Array[Vector2i] = _prune_path(spawn_tile, computed_goal)
			for tile in path_tiles:
				all_pruned_tiles[tile] = true

		if all_pruned_tiles.size() > 0:
			maze_layer.clear()
			for tile in all_pruned_tiles.keys():
				_carve_point(tile)

		# --- CORNER SHAVE: Eliminate 2x2 floor clumps from merge junctions ---
		_shave_corners()

		_build_constrained_walls()

		# Stamp standalone off-grid floor tiles for each virtual spawn.
		# These tiles sit 1 cell beyond the grid boundary and are NOT wall-filled,
		# allowing enemies to spawn off-screen and walk in.
		# The goal is already inside the grid and carved as part of the path.
		for virtual_spawn in virtual_spawns:
			maze_layer.set_cell(virtual_spawn, FLOOR_TILE_ID, Vector2i(0, 0))

		# --- PATH QUALITY GUARD ---
		# Check 1: Each spawn's pruned path must meet the minimum tile count.
		var all_paths_long_enough: bool = true
		for spawn_tile in computed_spawns:
			var pruned_path: Array[Vector2i] = _prune_path(spawn_tile, computed_goal)
			if pruned_path.size() < min_path_length_per_spawn:
				all_paths_long_enough = false
				break
		if not all_paths_long_enough:
			continue  # Path too short — retry.

		# Check 2: Total carved floor coverage must meet the minimum fraction.
		var total_tiles: int = GRID_WIDTH * GRID_HEIGHT
		var floor_tile_count: int = maze_layer.get_used_cells().size()
		var floor_fraction: float = float(floor_tile_count) / float(total_tiles)
		if floor_fraction < min_floor_coverage:
			continue  # Coverage too sparse — retry.

		# Validation check: Did all spawns successfully reach the goal without being blocked?
		if _validate_maze(computed_spawns, computed_goal):
			print(
				"MazeGenerator: Generation complete on attempt ",
				attempt + 1,
				". Spawns: ",
				computed_spawns.size(),
				". Floor coverage: ",
				snapped(floor_fraction * 100.0, 0.1),
				"%"
			)
			return  # Success! Escape the retry loop.

		# If invalid, the loop continues and tries a new random seed over a fresh layer.

	# All 30 attempts exhausted — clear the canvas so no dirty/partial maze is shown.
	maze_layer.clear()
	animation_layer.clear()
	push_error(
		"MazeGenerator: Failed to generate a valid maze after 30 attempts. Try reducing min_path_length_per_spawn or min_floor_coverage."
	)


## Automated Goal-First placement algorithm.
## Returns a Dictionary with keys: "goal", "spawns", "merge".
## Returns an empty Dictionary on failure.
func _pick_placements() -> Dictionary:
	# Allow up to 50 full placement retries before giving up.
	for _placement_attempt in range(50):
		# Step 1: Pick a random goal edge and tile along it (avoiding corners).
		# Returns a grid-edge coordinate (on-grid, so enemies die visibly).
		var goal_edge: int = randi() % 4
		var computed_goal: Vector2i = _resolve_virtual_to_grid(
			_random_virtual_tile_on_edge(goal_edge)
		)

		# Step 2: Build candidate spawn pool from all 4 edges (as virtual coords).
		var all_candidates: Array[Vector2i] = []
		for edge_index in range(4):
			var edge_tiles: Array[Vector2i] = _get_all_virtual_tiles_on_edge(edge_index)
			for edge_tile in edge_tiles:
				# Guard: candidate must not be on the no-go zone around the computed goal.
				var resolved_candidate: Vector2i = _resolve_virtual_to_grid(edge_tile)
				if _is_in_goal_buffer(resolved_candidate, computed_goal):
					continue
				all_candidates.append(edge_tile)

		# Sort candidates by descending distance from the computed goal (furthest first).
		all_candidates.sort_custom(
			func(tile_a: Vector2i, tile_b: Vector2i) -> bool:
				var resolved_a: Vector2i = _resolve_virtual_to_grid(tile_a)
				var resolved_b: Vector2i = _resolve_virtual_to_grid(tile_b)
				return resolved_a.distance_to(computed_goal) > resolved_b.distance_to(computed_goal)
		)

		# Greedily pick spawns from the sorted candidates.
		var virtual_spawns: Array[Vector2i] = []
		for candidate in all_candidates:
			if virtual_spawns.size() >= spawn_count:
				break

			var resolved_candidate: Vector2i = _resolve_virtual_to_grid(candidate)

			# Guard: Distance from candidate to goal (using resolved coords).
			var distance_to_goal: float = resolved_candidate.distance_to(computed_goal)
			if distance_to_goal < min_spawn_goal_distance:
				continue

			# Guard: Distance from candidate to all already-chosen spawns.
			var too_close_to_existing_spawn: bool = false
			for existing_virtual_spawn in virtual_spawns:
				var resolved_existing: Vector2i = _resolve_virtual_to_grid(existing_virtual_spawn)
				if resolved_candidate.distance_to(resolved_existing) < min_spawn_spawn_distance:
					too_close_to_existing_spawn = true
					break
			if too_close_to_existing_spawn:
				continue

			virtual_spawns.append(candidate)

		# Validate we got the requested number of spawns.
		if virtual_spawns.size() < spawn_count:
			continue  # Not enough valid candidates — retry with a new goal.

		# Guard: Not all spawns on the same edge (only enforced when spawn_count > 1).
		if spawn_count > 1:
			var unique_edges: Dictionary = {}
			for virtual_spawn in virtual_spawns:
				unique_edges[_get_edge_index_for_virtual(virtual_spawn)] = true
			if unique_edges.size() < 2:
				continue  # All spawns landed on the same edge — retry.

		# Step 5: Compute the automatic merge point using resolved (in-grid) coords.
		# Average all resolved spawn positions, then lerp 20% toward the computed goal.
		var centroid_x: float = 0.0
		var centroid_y: float = 0.0
		for virtual_spawn in virtual_spawns:
			var resolved_spawn: Vector2i = _resolve_virtual_to_grid(virtual_spawn)
			centroid_x += float(resolved_spawn.x)
			centroid_y += float(resolved_spawn.y)
		centroid_x /= float(virtual_spawns.size())
		centroid_y /= float(virtual_spawns.size())

		var computed_merge: Vector2i = Vector2i(
			roundi(lerpf(centroid_x, float(computed_goal.x), 0.2)),
			roundi(lerpf(centroid_y, float(computed_goal.y), 0.2))
		)
		computed_merge.x = clampi(computed_merge.x, 1, GRID_WIDTH - 2)
		computed_merge.y = clampi(computed_merge.y, 1, GRID_HEIGHT - 2)

		return {"goal": computed_goal, "spawns": virtual_spawns, "merge": computed_merge}

	return {}  # All retries exhausted.


## Returns whether a candidate tile falls within the no-go buffer zone around the goal.
## Uses a Chebyshev (square) distance check equal to the forced segment length + 1.
func _is_in_goal_buffer(candidate: Vector2i, goal: Vector2i) -> bool:
	var buffer: int = FORCED_SEGMENT_LENGTH + 1
	return abs(candidate.x - goal.x) <= buffer and abs(candidate.y - goal.y) <= buffer


## Returns all valid non-corner virtual tile positions along a given edge.
## Virtual coords sit 1 tile outside the grid boundary (e.g., y=-1 for TOP edge).
func _get_all_virtual_tiles_on_edge(edge_index: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	match edge_index:
		Edge.TOP:
			# Virtual y = -1. Avoid virtual corners by keeping x in [1, GRID_WIDTH-2].
			for x_coord in range(1, GRID_WIDTH - 1):
				tiles.append(Vector2i(x_coord, -1))
		Edge.BOTTOM:
			# Virtual y = GRID_HEIGHT.
			for x_coord in range(1, GRID_WIDTH - 1):
				tiles.append(Vector2i(x_coord, GRID_HEIGHT))
		Edge.LEFT:
			# Virtual x = -1.
			for y_coord in range(1, GRID_HEIGHT - 1):
				tiles.append(Vector2i(-1, y_coord))
		Edge.RIGHT:
			# Virtual x = GRID_WIDTH.
			for y_coord in range(1, GRID_HEIGHT - 1):
				tiles.append(Vector2i(GRID_WIDTH, y_coord))
	return tiles


## Picks a random non-corner virtual tile along a given edge index.
func _random_virtual_tile_on_edge(edge_index: int) -> Vector2i:
	var candidates: Array[Vector2i] = _get_all_virtual_tiles_on_edge(edge_index)
	return candidates[randi() % candidates.size()]


## Resolves a virtual (off-grid) coordinate to the nearest real grid-edge tile.
## e.g., Vector2i(5, -1) → Vector2i(5, 0)  |  Vector2i(-1, 3) → Vector2i(0, 3)
func _resolve_virtual_to_grid(virtual_tile: Vector2i) -> Vector2i:
	if virtual_tile.y < 0:
		return Vector2i(virtual_tile.x, 0)
	if virtual_tile.y >= GRID_HEIGHT:
		return Vector2i(virtual_tile.x, GRID_HEIGHT - 1)
	if virtual_tile.x < 0:
		return Vector2i(0, virtual_tile.y)
	if virtual_tile.x >= GRID_WIDTH:
		return Vector2i(GRID_WIDTH - 1, virtual_tile.y)
	return virtual_tile


## Returns the Edge enum index that a virtual coordinate belongs to.
func _get_edge_index_for_virtual(virtual_tile: Vector2i) -> int:
	if virtual_tile.y < 0:
		return Edge.TOP
	if virtual_tile.y >= GRID_HEIGHT:
		return Edge.BOTTOM
	if virtual_tile.x < 0:
		return Edge.LEFT
	return Edge.RIGHT


## Returns the inward-facing cardinal direction for a tile sitting on a grid edge.
func _get_edge_direction_for_tile(tile: Vector2i) -> Vector2i:
	if tile.y == 0:
		return Vector2i.DOWN
	if tile.y == GRID_HEIGHT - 1:
		return Vector2i.UP
	if tile.x == 0:
		return Vector2i.RIGHT
	return Vector2i.LEFT


## Returns the inward-facing cardinal direction for a virtual off-grid coordinate.
## This is the direction a lane will march into the grid interior.
func _get_edge_direction_for_virtual(virtual_tile: Vector2i) -> Vector2i:
	if virtual_tile.y < 0:
		return Vector2i.DOWN
	if virtual_tile.y >= GRID_HEIGHT:
		return Vector2i.UP
	if virtual_tile.x < 0:
		return Vector2i.RIGHT
	return Vector2i.LEFT


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

		# Centre-bias: boost directions that move toward the grid interior.
		# Strength is proportional to distance from centre so it decays naturally.
		if centre_bias > 0.0:
			var centre_x: float = (GRID_WIDTH - 1) * 0.5
			var centre_y: float = (GRID_HEIGHT - 1) * 0.5
			var dx_to_centre: float = centre_x - float(current.x)
			var dy_to_centre: float = centre_y - float(current.y)
			if dx_to_centre > 0.0:
				weights[0] += centre_bias * (dx_to_centre / centre_x)
			elif dx_to_centre < 0.0:
				weights[1] += centre_bias * (abs(dx_to_centre) / centre_x)
			if dy_to_centre > 0.0:
				weights[3] += centre_bias * (dy_to_centre / centre_y)
			elif dy_to_centre < 0.0:
				weights[2] += centre_bias * (abs(dy_to_centre) / centre_y)

		# Hard grid boundaries: prevent escape from the grid.
		if current.x <= 0:
			weights[1] = 0.0
		if current.x >= GRID_WIDTH - 1:
			weights[0] = 0.0
		if current.y <= 0:
			weights[2] = 0.0
		if current.y >= GRID_HEIGHT - 1:
			weights[3] = 0.0

		# Boundary no-wander guard: ban the path from hugging the extreme edge tiles
		# during the free-wander phase. The wander interior is [1, GRID_WIDTH-2] x [1, GRID_HEIGHT-2].
		for i in range(4):
			if weights[i] > 0.0:
				var proposed_wander: Vector2i = current + options[i]
				if (
					proposed_wander.x == 0
					or proposed_wander.x == GRID_WIDTH - 1
					or proposed_wander.y == 0
					or proposed_wander.y == GRID_HEIGHT - 1
				):
					weights[i] = 0.0

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
	if _preview_spawns.is_empty() or _preview_goal == Vector2i(-1, -1):
		push_error("MazeGenerator: No placement data found. Please generate a maze first.")
		return
	if not _validate_maze(_preview_spawns, _preview_goal):
		push_error("MazeGenerator: Discarding invalid maze (no clear path). Please generate again.")
		return

	var out_dir: String = "res://Stages/LevelLayouts"
	if not DirAccess.dir_exists_absolute(out_dir):
		var dir_err = DirAccess.make_dir_recursive_absolute(out_dir)
		if dir_err != OK:
			push_error(
				"MazeGenerator: Failed to create directories for '",
				out_dir,
				"'. Error code: ",
				dir_err
			)
			return

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

	_create_terrain_markers(root)

	scene.pack(root)
	var path: String = out_dir + "/" + output_filename + ".tscn"
	var err = ResourceSaver.save(scene, path)
	if err == OK:
		print("MazeGenerator: Successfully saved baked layout to -> ", path)
		if Engine.is_editor_hint() and FileAccess.file_exists(path):
			EditorInterface.get_resource_filesystem().scan()
	else:
		push_error("MazeGenerator: Failed to save maze. Error code: ", err)
	root.free()


## Creates a TerrainTags node under root containing:
## - One Marker2D per spawn, named sequentially: Spawn_0, Spawn_1, Spawn_2, etc.
## - One Marker2D named "Goal" for the exit point.
## Positions are set to the world-space centre of each tile.
## The virtual spawn coordinates in _preview_spawns are 1 cell off the grid,
## so we use _resolve_virtual_to_grid() to get the on-grid edge tile position,
## then apply the maze_layer tile map to find the correct world position.
func _create_terrain_markers(root: Node2D) -> void:
	if _preview_spawns.is_empty() or _preview_goal == Vector2i(-1, -1):
		push_warning("MazeGenerator: Skipping terrain marker creation — no placement data.")
		return

	# Remove any existing TerrainTags node to avoid duplicates on re-save.
	var existing_tags: Node = root.get_node_or_null("TerrainTags")
	if existing_tags:
		existing_tags.queue_free()

	# Create a clean parent node to group all markers.
	var terrain_tags_node: Node2D = Node2D.new()
	terrain_tags_node.name = "TerrainTags"
	root.add_child(terrain_tags_node)
	terrain_tags_node.owner = root

	# Bake spawn markers using the virtual coordinates (resolved to on-grid edge tiles).
	for spawn_index: int in range(_preview_spawns.size()):
		var virtual_spawn: Vector2i = _preview_spawns[spawn_index]
		var on_grid_spawn: Vector2i = _resolve_virtual_to_grid(virtual_spawn)
		var spawn_marker: Marker2D = Marker2D.new()
		spawn_marker.name = "Spawn_" + str(spawn_index)
		spawn_marker.position = maze_layer.map_to_local(on_grid_spawn)
		terrain_tags_node.add_child(spawn_marker)
		spawn_marker.owner = root

	# Bake the single goal marker.
	var goal_marker: Marker2D = Marker2D.new()
	goal_marker.name = "Goal"
	goal_marker.position = maze_layer.map_to_local(_preview_goal)
	terrain_tags_node.add_child(goal_marker)
	goal_marker.owner = root

	print(
		"MazeGenerator: Baked %d spawn marker(s) and 1 goal marker into scene."
		% _preview_spawns.size()
	)


func _validate_maze(spawns: Array[Vector2i], goal: Vector2i) -> bool:
	var grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	grid.cell_size = Vector2(84, 84)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var actual_goal: Vector2i = Vector2i(
		clampi(goal.x, 0, GRID_WIDTH - 1), clampi(goal.y, 0, GRID_HEIGHT - 1)
	)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell = Vector2i(x, y)
			grid.set_point_solid(cell, maze_layer.get_cell_source_id(cell) != FLOOR_TILE_ID)
	# All spawns must be able to reach the goal.
	for spawn_tile in spawns:
		var actual_spawn: Vector2i = Vector2i(
			clampi(spawn_tile.x, 0, GRID_WIDTH - 1), clampi(spawn_tile.y, 0, GRID_HEIGHT - 1)
		)
		var id_path = grid.get_id_path(actual_spawn, actual_goal)
		if id_path.size() == 0:
			return false
	return true
