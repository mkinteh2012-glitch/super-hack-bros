shader_type canvas_item;
render_mode unshaded;

// Create a varying variable to safely transfer world coordinates across functions
varying vec2 world_sdf_pos;

void vertex() {
    // CanvasItem shaders require matrix multiplication to occur in the vertex step
    world_sdf_pos = (CANVAS_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // 1. Correctly read the camera position using the data from the vertex step
    vec2 sdf_pos = screen_uv_to_sdf(world_sdf_pos);
    
    // 2. Fetch the distance boundary to the walls
    float distance_to_wall = texture_sdf(sdf_pos);
    
    // 3. Define the size of the shadow impact ring (in pixels)
    float shadow_radius = 25.0; 
    
    if (distance_to_wall > 0.0 && distance_to_wall < shadow_radius) {
        // Soften the boundary ring edges
        float shadow_intensity = 1.0 - (distance_to_wall / shadow_radius);
        
        // Output clean contact shadows where the surfaces collide
        COLOR = vec4(0.0, 0.0, 0.0, shadow_intensity * 0.7); 
    } else {
        // Keep the blank ground fully transparent
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}
