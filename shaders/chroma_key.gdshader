shader_type canvas_item;

uniform vec4 key_color : source_color = vec4(1.0, 0.0, 1.0, 1.0); // Pure Magenta by default
uniform float tolerance : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Calculate distance between the current pixel color and the key color
    float distance = length(tex_color.rgb - key_color.rgb);
    
    // If the distance is within the tolerance, make it transparent
    if (distance < tolerance) {
        COLOR = vec4(0.0);
    } else {
        COLOR = tex_color;
    }
}
