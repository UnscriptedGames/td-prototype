@tool
extends Node2D
class_name MazeRenderer

## Procedural renderer for maze walls, mimicking a Soundpad/Launchpad button style.
##
## Draws rounded, "floating" buttons on top of MapLayer data.
## Supports animated wipe reveals and dissolve transitions between two TileMapLayers.


# --- ENUMS ---

enum RevealMode { LINEAR, CENTER_OUT }
enum TransitionMode { DISSOLVE, SWIPE_RIGHT }


# --- EXPORTS ---

@export var source_layer_path: NodePath:
	set(value):
		source_layer_path = value
		_update_source_reference()
		queue_redraw()

@export var transition_layer_path: NodePath:
	set(value):
		transition_layer_path = value
		_update_transition_reference()
		queue_redraw()

@export var custom_styles: Array[MazeTileStyle] = []:
	set(value):
		custom_styles = value
		queue_redraw()

@export var grid_width: int = 25  # Match BackgroundRenderer default

@export var reveal_mode: RevealMode = RevealMode.LINEAR:
	set(value):
		reveal_mode = value
		queue_redraw()

@export var transition_mode: TransitionMode = TransitionMode.SWIPE_RIGHT:
	set(value):
		transition_mode = value
		queue_redraw()

@export var center_column: int = 12:  # Approx grid_width / 2
	set(value):
		center_column = value
		queue_redraw()

@export_range(0.0, 1.0) var reveal_ratio: float = 1.0:
	set(value):
		reveal_ratio = value
		queue_redraw()

@export_range(0.0, 1.0) var transition_progress: float = 1.0:
	set(value):
		transition_progress = value
		queue_redraw()

@export var dissolve_anim_width: float = 0.1:  # Width of the scaling band
	set(value):
		dissolve_anim_width = value
		queue_redraw()

@export var wipe_anim_width: float = 0.5:  # Width of the wipe soft edge
	set(value):
		wipe_anim_width = value
		queue_redraw()

@export var swipe_gap: float = 0.15:  # Gap between layers in SWIPE_RIGHT mode
	set(value):
		swipe_gap = value
		queue_redraw()

@export_group("Visuals")
# Geometry-only settings (Global)
@export var glow_steps: int = 4:
	set(value):
		glow_steps = value
		queue_redraw()

@export var glow_step_size: float = 0.8:
	set(value):
		glow_step_size = value
		queue_redraw()

@export var custom_glow_radius: float = 5.0:  # -1.0 = Auto (based on button radius), >= 0 = Custom
	set(value):
		custom_glow_radius = value
		queue_redraw()

@export var inner_padding: float = 3.0:  # Distance from edge for the glow
	set(value):
		inner_padding = value
		queue_redraw()

@export_range(0.0, 1.0) var button_scale: float = 1.0:
	set(value):
		button_scale = value
		queue_redraw()
@export var corner_radius: float = 5.0:
	set(value):
		corner_radius = value
		queue_redraw()

@export var depth_offset: Vector2 = Vector2(4, 4):
	set(value):
		depth_offset = value
		queue_redraw()


# --- VARIABLES ---

var _source_layer: TileMapLayer
var _transition_layer: TileMapLayer
var _style_lookup: Dictionary[Vector3i, MazeTileStyle] = {}
var _style_box_pool: Dictionary[Array, StyleBoxFlat] = {}


# --- LIFECYCLE OVERRIDES ---


func _ready() -> void:
	_preload_style_boxes()
	_update_source_reference()
	_update_transition_reference()


func _draw() -> void:
	if not _source_layer:
		return

	var source_tile_set: TileSet = _source_layer.tile_set
	if not source_tile_set:
		return

	_rebuild_style_lookup()

	if _transition_layer:
		_draw_layer(_transition_layer, false)

	_draw_layer(_source_layer, true)


# --- METHODS ---


func has_cell(coords: Vector2i) -> bool:
	# Returns true if the given cell has a matching style.
	if not _source_layer:
		return false
	return _get_active_style(coords) != null


func _preload_style_boxes() -> void:
	# Pre-populate pool with known styles to prevent stutter during animation.
	_style_box_pool.clear()

	for style: MazeTileStyle in custom_styles:
		if style:
			# Cache main button
			_create_style_box(style.button_color, corner_radius)

			# Cache glows
			if style.glow_opacity > 0:
				var glow_color: Color = style.glow_color
				glow_color.a = style.glow_opacity
				for index: int in range(glow_steps):
					var current_padding: float = inner_padding + (index * glow_step_size)
					var inner_radius: float = 0.0
					if custom_glow_radius >= 0.0:
						inner_radius = max(0.0, custom_glow_radius - (index * glow_step_size))
					else:
						inner_radius = max(0.0, corner_radius - current_padding)
					_create_style_box(glow_color, inner_radius)


func _update_source_reference() -> void:
	# Resolves the source TileMapLayer from exported NodePath.
	if source_layer_path and has_node(source_layer_path):
		var node: Node = get_node(source_layer_path)
		if node is TileMapLayer:
			if _source_layer and _source_layer.changed.is_connected(_on_source_changed):
				_source_layer.changed.disconnect(_on_source_changed)

			_source_layer = node

			if Engine.is_editor_hint():
				if not _source_layer.changed.is_connected(_on_source_changed):
					_source_layer.changed.connect(_on_source_changed)

			queue_redraw()
	else:
		if _source_layer and _source_layer.changed.is_connected(_on_source_changed):
			_source_layer.changed.disconnect(_on_source_changed)
		_source_layer = null
		queue_redraw()


func _update_transition_reference() -> void:
	# Resolves the transition TileMapLayer from exported NodePath.
	if transition_layer_path and has_node(transition_layer_path):
		var node: Node = get_node(transition_layer_path)
		if node is TileMapLayer:
			if _transition_layer and _transition_layer.changed.is_connected(_on_source_changed):
				_transition_layer.changed.disconnect(_on_source_changed)

			_transition_layer = node

			if Engine.is_editor_hint():
				if not _transition_layer.changed.is_connected(_on_source_changed):
					_transition_layer.changed.connect(_on_source_changed)

			queue_redraw()
	else:
		if _transition_layer and _transition_layer.changed.is_connected(_on_source_changed):
			_transition_layer.changed.disconnect(_on_source_changed)
		_transition_layer = null
		queue_redraw()


func _on_source_changed() -> void:
	queue_redraw()


func _rebuild_style_lookup() -> void:
	# Rebuilds the tile-to-style mapping from the custom_styles array.
	_style_lookup.clear()
	for tile_style: MazeTileStyle in custom_styles:
		if tile_style:
			var key: Vector3i = Vector3i(
				tile_style.source_id, tile_style.atlas_coords.x, tile_style.atlas_coords.y
			)
			_style_lookup[key] = tile_style


func _get_active_style(coords: Vector2i) -> MazeTileStyle:
	# Looks up the style for a specific cell based on source layer tile data.
	var source_id: int = _source_layer.get_cell_source_id(coords)
	var atlas_coords: Vector2i = _source_layer.get_cell_atlas_coords(coords)
	var key: Vector3i = Vector3i(source_id, atlas_coords.x, atlas_coords.y)

	if key in _style_lookup:
		return _style_lookup[key]

	# No match found -> Return null (don't draw)
	return null


func _draw_layer(layer: TileMapLayer, is_source: bool) -> void:
	if not layer or not layer.tile_set:
		return

	var current_tile_size: Vector2 = Vector2(layer.tile_set.tile_size)
	var reference_width: float = float(_source_layer.tile_set.tile_size.x)

	for coordinates: Vector2i in layer.get_used_cells():
		var physical_x_coordinate: float = (
			(float(coordinates.x) + 0.5) * current_tile_size.x
		)
		var wipe_scale: float = _get_reveal_scale(
			physical_x_coordinate,
			reference_width
		)
		if wipe_scale <= 0.001:
			continue

		var scale_animation_multiplier: float = 1.0

		if _transition_layer:
			var distance: float = 0.0

			if transition_mode == TransitionMode.DISSOLVE:
				var noise_hash: float = (
					float(
						(coordinates.x * 73_856_093) ^ (coordinates.y * 19_349_663)
					) / 2_147_483_647.0
				)
				noise_hash = abs(noise_hash)
				distance = transition_progress - noise_hash

				if is_source and distance <= 0:
					continue
				if not is_source and distance > 0:
					continue

				if transition_progress > 0.01 and transition_progress < 0.99:
					var absolute_distance: float = abs(distance)
					if absolute_distance < dissolve_anim_width:
						scale_animation_multiplier = smoothstep(
							0.0, 1.0, absolute_distance / dissolve_anim_width
						)

			elif transition_mode == TransitionMode.SWIPE_RIGHT:
				var total_width: float = float(grid_width) * reference_width
				var normalized_x_coordinate: float = (
					physical_x_coordinate / total_width
				)

				# The transition sweeps from 0.0 to 1.0 + wipe_anim_width + swipe_gap
				var base_threshold: float = (
					transition_progress * (1.0 + wipe_anim_width + swipe_gap)
				)

				# Transition layer (Song) disappears when normalized_x_coordinate < threshold
				var transition_threshold: float = base_threshold
				# Source layer (Maze) appears when normalized_x_coordinate < threshold - swipe_gap
				var source_threshold: float = base_threshold - swipe_gap

				if is_source:
					distance = source_threshold - normalized_x_coordinate
					if distance <= 0:
						continue  # Not yet reached
					if distance < wipe_anim_width / 2.0:
						# Wipe in soft edge for source
						scale_animation_multiplier = smoothstep(
							0.0, 1.0, distance / (wipe_anim_width / 2.0)
						)
				else:
					distance = transition_threshold - normalized_x_coordinate
					if distance >= 0:
						continue  # Already passed

					# Wipe out soft edge for transition
					# We want scale=0 at distance=0, and scale=1 at distance < -wipe_anim_width/2.0
					if distance > -wipe_anim_width / 2.0:
						scale_animation_multiplier = smoothstep(
							0.0, 1.0, -distance / (wipe_anim_width / 2.0)
						)

		var source_id: int = layer.get_cell_source_id(coordinates)
		var atlas_coords: Vector2i = layer.get_cell_atlas_coords(coordinates)
		var key: Vector3i = Vector3i(source_id, atlas_coords.x, atlas_coords.y)
		var style: MazeTileStyle = _style_lookup.get(key)

		if not style:
			continue

		var cell_center: Vector2 = (
			(Vector2(coordinates) * current_tile_size) + (current_tile_size / 2.0)
		)
		var available_size: Vector2 = (current_tile_size - depth_offset.abs()).max(Vector2.ZERO)
		var draw_size: Vector2 = (
			available_size * button_scale * scale_animation_multiplier * wipe_scale
		)

		var centering_offset: Vector2 = -depth_offset * 0.5
		var offset_position: Vector2 = cell_center - (draw_size * 0.5) + centering_offset

		var face_rect: Rect2 = Rect2(offset_position, draw_size)
		var back_rect: Rect2 = face_rect
		back_rect.position += depth_offset

		_draw_extrusion(face_rect, back_rect, style.side_color)
		draw_style_box(_create_style_box(style.button_color, corner_radius), face_rect)

		if inner_padding > 0 and style.glow_opacity > 0:
			for index: int in range(glow_steps):
				var current_padding: float = inner_padding + (index * glow_step_size)
				var inner_rect: Rect2 = face_rect.grow(-current_padding)

				if inner_rect.size.x > 0 and inner_rect.size.y > 0:
					var inner_color: Color = style.glow_color
					inner_color.a = style.glow_opacity

					var inner_radius: float = 0.0
					if custom_glow_radius >= 0.0:
						inner_radius = max(0.0, custom_glow_radius - (index * glow_step_size))
					else:
						inner_radius = max(0.0, corner_radius - current_padding)

					var stylebox_glow: StyleBoxFlat = _create_style_box(inner_color, inner_radius)
					draw_style_box(stylebox_glow, inner_rect)


func _draw_extrusion(front: Rect2, back: Rect2, color: Color) -> void:
	# Draws the 3D extrusion connecting front and back faces.
	# Uses 4 side strip quads + 4 corner "pills" (swept circles).
	var radius: float = min(corner_radius, min(front.size.x, front.size.y) * 0.5)

	# Draw the Back Face (Base) first
	draw_style_box(_create_style_box(color, corner_radius), back)

	# Front Face Tangents (horizontal)
	var front_top_left_horizontal: Vector2 = (
		Vector2(front.position.x + radius, front.position.y)
	)
	var front_top_right_horizontal: Vector2 = (
		Vector2(front.end.x - radius, front.position.y)
	)
	var front_bottom_left_horizontal: Vector2 = (
		Vector2(front.position.x + radius, front.end.y)
	)
	var front_bottom_right_horizontal: Vector2 = (
		Vector2(front.end.x - radius, front.end.y)
	)
	# Front Face Tangents (vertical)
	var front_top_left_vertical: Vector2 = (
		Vector2(front.position.x, front.position.y + radius)
	)
	var front_bottom_left_vertical: Vector2 = (
		Vector2(front.position.x, front.end.y - radius)
	)
	var front_top_right_vertical: Vector2 = (
		Vector2(front.end.x, front.position.y + radius)
	)
	var front_bottom_right_vertical: Vector2 = (
		Vector2(front.end.x, front.end.y - radius)
	)

	# Back Face Tangents
	var back_top_left_horizontal: Vector2 = (
		Vector2(back.position.x + radius, back.position.y)
	)
	var back_top_right_horizontal: Vector2 = (
		Vector2(back.end.x - radius, back.position.y)
	)
	var back_bottom_left_horizontal: Vector2 = (
		Vector2(back.position.x + radius, back.end.y)
	)
	var back_bottom_right_horizontal: Vector2 = (
		Vector2(back.end.x - radius, back.end.y)
	)
	var back_top_left_vertical: Vector2 = (
		Vector2(back.position.x, back.position.y + radius)
	)
	var back_bottom_left_vertical: Vector2 = (
		Vector2(back.position.x, back.end.y - radius)
	)
	var back_top_right_vertical: Vector2 = (
		Vector2(back.end.x, back.position.y + radius)
	)
	var back_bottom_right_vertical: Vector2 = (
		Vector2(back.end.x, back.end.y - radius)
	)

	# Draw Corner Pills (thick line connecting front/back corner circle centres)
	var corner_top_left: Vector2 = (
		Vector2(front.position.x + radius, front.position.y + radius)
	)
	draw_line(corner_top_left, corner_top_left + depth_offset, color, radius * 2.0)
	var corner_top_right: Vector2 = (
		Vector2(front.end.x - radius, front.position.y + radius)
	)
	draw_line(corner_top_right, corner_top_right + depth_offset, color, radius * 2.0)
	var corner_bottom_right: Vector2 = (
		Vector2(front.end.x - radius, front.end.y - radius)
	)
	draw_line(
		corner_bottom_right,
		corner_bottom_right + depth_offset,
		color,
		radius * 2.0
	)
	var corner_bottom_left: Vector2 = (
		Vector2(front.position.x + radius, front.end.y - radius)
	)
	draw_line(
		corner_bottom_left,
		corner_bottom_left + depth_offset,
		color,
		radius * 2.0
	)

	# Draw Side Strip Quads
	_draw_triangle_quad(
		front_top_left_horizontal,
		front_top_right_horizontal,
		back_top_right_horizontal,
		back_top_left_horizontal,
		color
	)  # Top
	_draw_triangle_quad(
		front_bottom_right_horizontal,
		front_bottom_left_horizontal,
		back_bottom_left_horizontal,
		back_bottom_right_horizontal,
		color
	)  # Bottom
	_draw_triangle_quad(
		front_bottom_left_vertical,
		front_top_left_vertical,
		back_top_left_vertical,
		back_bottom_left_vertical,
		color
	)  # Left
	_draw_triangle_quad(
		front_top_right_vertical,
		front_bottom_right_vertical,
		back_bottom_right_vertical,
		back_top_right_vertical,
		color
	)  # Right


func _draw_triangle_quad(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, color: Color) -> void:
	# Splits a quad into two triangles, skipping degenerate ones.
	_draw_safe_triangle(p1, p2, p3, color)
	_draw_safe_triangle(p1, p3, p4, color)


func _draw_safe_triangle(
	point_a: Vector2, point_b: Vector2, point_c: Vector2, color: Color
) -> void:
	# Draws a single triangle with winding correction.
	var area: float = (point_b.x - point_a.x) * (point_c.y - point_a.y) - (point_c.x - point_a.x) * (
		point_b.y - point_a.y
	)

	# Force consistent winding (CCW)
	if area < 0:
		var temporary_point: Vector2 = point_b
		point_b = point_c
		point_c = temporary_point
		area = -area

	if area > 0.1:  # Threshold to ignore degenerate/collinear triangles
		draw_polygon([point_a, point_b, point_c], [color])


func _create_style_box(color: Color, radius: float) -> StyleBoxFlat:
	# Caching wrapper for StyleBoxes to prevent excessive allocation.
	var key: Array = [color, radius]

	if _style_box_pool.has(key):
		return _style_box_pool[key]

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 4
	sb.anti_aliasing = true

	_style_box_pool[key] = sb
	return sb


func _get_reveal_scale(
	physical_x_coordinate: float,
	reference_width: float
) -> float:
	# Returns 0.0 (Hidden) to 1.0 (Fully Visible) based on reveal_mode and reveal_ratio.
	if reveal_mode == RevealMode.LINEAR:
		if (
			physical_x_coordinate / (float(grid_width) * reference_width)
			<= reveal_ratio
		):
			return 1.0
		return 0.0

	elif reveal_mode == RevealMode.CENTER_OUT:
		var physical_center: float = float(center_column) * reference_width
		var distance: float = abs(physical_x_coordinate - physical_center)
		var maximum_distance: float = max(
			float(center_column) * reference_width,
			float(grid_width - center_column) * reference_width
		)

		# Normalised position of this tile (0.0 = centre, 1.0 = edge)
		var normalized_position: float = (
			distance / maximum_distance if maximum_distance > 0 else 0.0
		)

		# If width is effectively zero, hard cut
		if wipe_anim_width < 0.001:
			return 1.0 if normalized_position <= reveal_ratio else 0.0

		# Soft scaling via a sliding smoothstep window
		var leading_edge: float = reveal_ratio * (1.0 + wipe_anim_width)
		var trailing_edge: float = leading_edge - wipe_anim_width

		return 1.0 - smoothstep(trailing_edge, leading_edge, normalized_position)

	return 1.0
