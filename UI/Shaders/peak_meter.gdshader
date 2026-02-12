shader_type canvas_item;

uniform vec4 color_start : source_color = vec4(0.0, 1.0, 0.0, 1.0); // Green
uniform vec4 color_mid : source_color = vec4(1.0, 1.0, 0.0, 1.0);   // Yellow
uniform vec4 color_end : source_color = vec4(1.0, 0.0, 0.0, 1.0);   // Red

uniform float mid_point : hint_range(0.0, 1.0) = 0.5;
uniform float total_width = 350.0; // Matches bar width

varying float v_progress;

void vertex() {
	// Calculate progress based on local vertex position relative to total expected width.
	// This ensures the gradient is "static" and revealed, rather than squashed.
	v_progress = VERTEX.x / total_width;
}

void fragment() {
	vec4 color;
	if (v_progress < mid_point) {
		// Map 0 -> mid_point to 0 -> 1 for mix
		float t = v_progress / mid_point;
		color = mix(color_start, color_mid, t);
	} else {
		// Map mid_point -> 1 to 0 -> 1 for mix
		float t = (v_progress - mid_point) / (1.0 - mid_point);
		color = mix(color_mid, color_end, t);
	}
	
	COLOR = color;
}
