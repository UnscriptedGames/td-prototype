shader_type canvas_item;

uniform sampler2D gradient_tex;
uniform float max_width = 225.0;
uniform float global_origin_x = 0.0;

void fragment() {
	vec4 input_color = COLOR;
	// Detect White Fill of the StyleBoxFlat
	if (input_color.r > 0.5) {
		// Screen-Space Mapping
		// FRAGCOORD.x is the absolute screen pixel X.
		// global_origin_x is the screen pixel X of the bar's left edge (passed from script).
		float dist = FRAGCOORD.x - global_origin_x;
		float grad_pos = clamp(dist / max_width, 0.0, 1.0);
		
		vec4 grad_color = texture(gradient_tex, vec2(grad_pos, 0.5));
		
		COLOR.rgb = grad_color.rgb;
		COLOR.a = input_color.a;
	}
}

		
		// Preserve original alpha (for antialiased rounded corners)
		COLOR.a = input_color.a;
	}
	// Else: Keep background color as is.
}
