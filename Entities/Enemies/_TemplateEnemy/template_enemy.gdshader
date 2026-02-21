shader_type canvas_item;

instance uniform float unscaled_time = 0.0;
uniform bool use_unscaled_time = false;
instance uniform float health_ratio = 1.0;

uniform float corner_radius_px = 7.0;
uniform vec2 rect_size = vec2(32.0, 32.0);

uniform float border_width : hint_range(0.0, 10.0) = 0.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Function for computing the distance from a rounded box boundary
float rounded_box_sdf(vec2 center_pos, vec2 half_size, float radius) {
    vec2 q = abs(center_pos) - half_size + vec2(radius);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

// Pseudo-random noise function for the glitch effect
float random(vec2 uv_pos) {
    return fract(sin(dot(uv_pos.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	
	// Scroll using computed unscaled time in-game, or fallback to TIME for Editor previews
	float t = use_unscaled_time ? unscaled_time : TIME;
	uv.x -= t;
	
	// Inverse health drives the chaos (0.0 at full health, 0.9 at 10% health)
	float glitch_strength = (1.0 - health_ratio);
	
	// Create "blocky" horizontal bands of noise by quantizing the Y continuous space
	float band_y = floor(uv.y * 12.0); // 12 bands across the sprite
	float noise = (random(vec2(uv.x, band_y + t * 5.0)) * 2.0) - 1.0;
	
	// Apply horizontal tear
	float tear_offset = noise * glitch_strength * 0.15;
	vec2 base_uv = uv;
	base_uv.y += tear_offset;
	
	// Chromatic Aberration - Read the texture 3 times with slight horizontal offsets
	float chrom_offset = noise * glitch_strength * 0.08;
	float r = texture(TEXTURE, vec2(base_uv.x + chrom_offset, base_uv.y)).r;
	float g = texture(TEXTURE, base_uv).g;
	float b = texture(TEXTURE, vec2(base_uv.x - chrom_offset, base_uv.y)).b;
	float a = texture(TEXTURE, base_uv).a; // Use base alpha to preserve the shape's mask
	
	vec4 tex_color = vec4(r, g, b, a);
	
	// Transform UV to pixel coordinates
	vec2 pixel_pos = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	
	// Create a Signed Distance Field constraint based on the actual pixel box
	float dist = rounded_box_sdf(pixel_pos - half_size, half_size, corner_radius_px);
	
	// Anti-alias the mathematically perfect rounded edge using fwidth
	// fwidth(dist) guarantees the blur is exactly 1 screen pixel wide,
	// no matter how zoomed in the camera is, preventing "smoky" scaling artifacts!
	float fw = fwidth(dist);
	float alpha_mask = 1.0 - smoothstep(-fw, fw, dist);
	
	// Create the border effect by mixing the border color where the inner SDF is within border_width
	vec4 final_color = tex_color;
	if (border_width > 0.0) {
		float border_mask = smoothstep(-border_width - fw, -border_width + fw, dist);
		// Mix the texture with the border color
		final_color = mix(tex_color, border_color, border_mask * border_color.a);
	}
	
	// Fade the overall alpha as the enemy loses health
	// Removed per user feedback
	// Ensure the SDF corner radius still clips the alpha:
	final_color.a *= alpha_mask;

	COLOR = final_color;
}
