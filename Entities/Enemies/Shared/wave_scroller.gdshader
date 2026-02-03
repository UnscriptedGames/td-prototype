shader_type canvas_item;

uniform float scroll_speed : hint_range(0.0, 5.0) = 1.0;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.15;
uniform vec2 sprite_size = vec2(48.0, 48.0); // Size of the sprite in pixels (before node scaling)
uniform float frame_count = 5.0; // How many "frames" wide the texture is (e.g. 5 for 1:5 ratio)

varying vec2 local_uv; // 0..1 space
varying vec2 local_pos; // -1..1 space

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void vertex() {
	// Map VERTEX (pixels) to -1..1 space using the known sprite size
	// This allows the shader to work with any texture size (48px, 64px, etc)
	vec2 half_size = sprite_size * 0.5;
	local_pos = VERTEX / half_size; 
	local_uv = local_pos * 0.5 + 0.5; // Map -1..1 to 0..1
}

void fragment() {
	// Map the 0-1 UV to a scrolling window based on frame count
    // The texture is assumed to be 'frame_count' times wider than the sprite
	vec2 scrolling_uv = vec2(fract(local_uv.x * (1.0 / frame_count) + TIME * scroll_speed), local_uv.y);
	vec4 tex_color = texture(TEXTURE, scrolling_uv);
	
	// Apply Rounded Corners using scale-independent local_pos (-1..1)
	// Half-extents are 1.0 in this space
	float d = sdRoundedBox(local_pos, vec2(1.0), corner_radius * 2.0);
	
	// Smooth anti-aliased edge
	float alpha = 1.0 - smoothstep(0.0, 0.05, d);
	
	COLOR = tex_color;
	COLOR.a *= alpha;
}
