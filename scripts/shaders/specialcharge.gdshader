shader_type canvas_item;

uniform bool is_active = false;
uniform vec4 glow_color : source_color = vec4(0.1, 0.6, 1.0, 1.0); // Electric Blue
uniform float line_thickness : hint_range(0.0, 10.0) = 1.5;

void fragment() {
	vec4 current_color = texture(TEXTURE, UV);
	
	// If the shader isn't activated, just draw the normal sprite frame
	if (!is_active) {
		COLOR = current_color;
	} else {
		vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
		float outline = 0.0;
		
		// Check surrounding pixels to calculate the boundary edges
		outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
		outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
		outline = min(outline, 1.0);
		
		// Mix a pulsing bright neon outline into the background alpha channel
		vec4 final_outline = mix(current_color, glow_color, outline - current_color.a);
		
		// Add a subtle idle pulse animation effect using the built-in TIME clock
		float pulse = 0.6 + 0.4 * sin(TIME * 12.0);
		final_outline.rgb *= (1.0 + (outline - current_color.a) * pulse * 2.0);
		
		COLOR = final_outline;
	}
}