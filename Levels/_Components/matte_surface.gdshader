shader_type canvas_item;

// -- Configuration --
uniform float noise_strength : hint_range(0.0, 1.0) = 0.05;
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.1;

// -- Screen Space Gradient --
// Simulates a subtle top-left light source across the whole screen/world
uniform vec2 light_direction = vec2(1.0, 1.0); 

// -- Pseuso-Random Hash --
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// 1. Base Color (Vertex Color from draw_polygon)
	vec4 col = COLOR;
	
	// 2. Procedural Noise (Grain)
	// Use Screen UV or FragCoord to keep noise stable in world space if preferred,
	// or Local UV if we had it (we don't easily for polygons).
	// FRAGCOORD is screen-space pixel coordinates.
	float noise = hash(FRAGCOORD.xy);
	
	// Mix noise: 0.0 = darker, 1.0 = lighter. Centers around 0.5.
	// We want subtle variation.
	float noise_off = (noise - 0.5) * noise_strength;
	col.rgb += vec3(noise_off);
	
	// 3. Subtle Gradient (Soft Lighting)
	// We use SCREEN_UV for a "global" lighting feel, or we could pass local coords.
	// Let's use SCREEN_UV for a consistent "finishing" look across all islands.
	// Light coming from Top-Left (0,0) -> Bottom-Right (1,1).
	float grad = dot(SCREEN_UV, normalize(light_direction));
	// Remap -1..1 or 0..1 to subtle shift
	// We want Top-Left brighter, Bottom-Right darker? 
	// actually dot(UV, 1,1) means 0 at TL, 1.4 at BR.
	// So grad increases as we go down-right.
	// We want LIGHT at TL, so we invert.
	grad = 1.0 - grad;
	
	// Apply gradient spread
	float grad_off = (grad - 0.5) * gradient_strength;
	col.rgb += vec3(grad_off);
	
	// Output
	COLOR = col;
}
