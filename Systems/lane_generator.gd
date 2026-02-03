class_name LaneGenerator
extends RefCounted

## LaneGenerator
##
## Static utility to generate parallel curves from a source Path2D.
## Designed for "Manhattan" style paths (straight lines and 90-degree corners).

static func generate_parallel_curve(source_path: Path2D, offset: float, previous_tangent: Vector2 = Vector2.ZERO, next_tangents: Array[Vector2] = []) -> Curve2D:
	if not source_path or not source_path.curve:
		return null
		
	var source_curve := source_path.curve
	var point_count := source_curve.point_count
	if point_count < 2:
		return source_curve.duplicate()
		
	var new_curve := Curve2D.new()
	new_curve.bake_interval = source_curve.bake_interval
	
	# Iterate through points to build offset segments
	var offset_segments: Array[Array] = []
	
	for i in range(point_count - 1):
		var p1 := source_curve.get_point_position(i)
		var p2 := source_curve.get_point_position(i + 1)
		
		var dir := (p2 - p1).normalized()
		var normal := Vector2(-dir.y, dir.x)
		
		var offset_p1 := p1 + (normal * offset)
		var offset_p2 := p2 + (normal * offset)
		
		offset_segments.append([offset_p1, offset_p2])
		
	# --- Point 0: Start Stitching (Extend Only) ---
	var start_p = offset_segments[0][0]
	
	if previous_tangent != Vector2.ZERO and not previous_tangent.is_equal_approx(Vector2.ZERO):
		var dir_prev = previous_tangent.normalized()
		var normal_prev = Vector2(-dir_prev.y, dir_prev.x)
		# Incoming line ends at projection of the original start
		var incoming_line_end = source_curve.get_point_position(0) + (normal_prev * offset)
		
		var seg_curr = offset_segments[0]
		var dir_curr = (seg_curr[1] - seg_curr[0]).normalized()
		
		var intersection = _line_intersection(incoming_line_end, dir_prev, seg_curr[0], dir_curr)
		if intersection:
			# Only use intersection if it EXTENDS the line backwards (Outside Turn).
			# Check dot product of (Intersection - Start) vs Direction.
			# If dot < 0, it is "Behind" the start.
			var to_intersection = intersection - start_p
			if to_intersection.dot(dir_curr) < -0.01:
				start_p = intersection

	new_curve.add_point(start_p)
	
	# --- Intermediate Points ---
	for i in range(offset_segments.size() - 1):
		var seg_a = offset_segments[i]
		var seg_b = offset_segments[i + 1]
		
		var dir_a = (seg_a[1] - seg_a[0]).normalized()
		var dir_b = (seg_b[1] - seg_b[0]).normalized()
		
		var intersection = _line_intersection(seg_a[0], dir_a, seg_b[0], dir_b)
		if intersection:
			new_curve.add_point(intersection)
		else:
			new_curve.add_point(seg_a[1])
				
	# --- Last Point: End Stitching (Extend Only) ---
	var end_p = offset_segments[offset_segments.size() - 1][1]
	
	if not next_tangents.is_empty():
		var seg_last = offset_segments[offset_segments.size() - 1]
		var dir_last = (seg_last[1] - seg_last[0]).normalized()
		
		var best_extension_dist = -1.0
		var best_end_p = end_p
		
		for next_tan in next_tangents:
			if next_tan == Vector2.ZERO or next_tan.is_equal_approx(Vector2.ZERO): continue
			
			var dir_next = next_tan.normalized()
			var normal_next = Vector2(-dir_next.y, dir_next.x)
			
			# Next line starts at projection of original end
			var next_line_start = source_curve.get_point_position(point_count - 1) + (normal_next * offset)
			
			var intersection = _line_intersection(seg_last[0], dir_last, next_line_start, dir_next)
			if intersection:
				# Only use intersection if it EXTENDS the line forwards (Outside Turn).
				# If dot > 0, it is "Ahead" of the end.
				var to_intersection = intersection - end_p
				var dist = to_intersection.dot(dir_last)
				
				if dist > 0.01 and dist > best_extension_dist:
					best_extension_dist = dist
					best_end_p = intersection
		
		end_p = best_end_p

	new_curve.add_point(end_p)
	
	return new_curve

static func _line_intersection(p1: Vector2, dir1: Vector2, p2: Vector2, dir2: Vector2):
	# Line A: p1 + t * dir1
	# Line B: p2 + u * dir2
	var det = dir1.cross(dir2)
	if abs(det) < 0.001:
		return null # Parallel
	
	var diff = p2 - p1
	var t = diff.cross(dir2) / det
	return p1 + dir1 * t
