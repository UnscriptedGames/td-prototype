shader_type canvas_item;

uniform vec4 color_sub : source_color = vec4(0.8, 0.8, 0.8, 1.0);   // White/Grey
uniform vec4 color_start : source_color = vec4(0.0, 1.0, 0.0, 1.0); // Green
uniform vec4 color_mid : source_color = vec4(1.0, 1.0, 0.0, 1.0);   // Yellow
uniform vec4 color_end : source_color = vec4(1.0, 0.0, 0.0, 1.0);   // Red

uniform float threshold_zero : hint_range(0.0, 1.0) = 0.0476;
uniform float threshold_low : hint_range(0.0, 1.0) = 0.3619;
uniform float threshold_high : hint_range(0.0, 1.0) = 0.6761;
uniform float total_width = 350.0; // Matches bar width

varying float v_progress;

void vertex() {
	// Calculate progress based on local vertex position relative to total expected width.
	// This ensures the gradient is "static" and revealed, rather than squashed.
	v_progress = VERTEX.x / total_width;
}

void fragment() {
	vec4 color;
	if (v_progress < threshold_zero) {
		// Keep the sub-floor a pure solid color without blending into the green start color
		color = color_sub;
	} else if (v_progress < threshold_low) {
		// Map threshold_zero -> threshold_low to 0 -> 1 for mix
		float t = (v_progress - threshold_zero) / (threshold_low - threshold_zero);
		color = mix(color_start, color_mid, t);
	} else if (v_progress < threshold_high) {
		// Map threshold_low -> threshold_high to 0 -> 1 for mix
		float t = (v_progress - threshold_low) / (threshold_high - threshold_low);
		color = mix(color_mid, color_end, t);
	} else {
		color = color_end;
	}
	
	COLOR = color;
}
