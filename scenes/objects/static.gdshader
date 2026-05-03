shader_type canvas_item;

uniform float noise_amount : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float get_noise(vec2 uv) {
    return fract(sin(dot(uv ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    // Generate noise based on UV and time
    float n = 1.0 * get_noise(UV + vec2(TIME, 0.0)) - 0.5;
    
    // Sample the screen (camera) and add noise
    vec4 scene_color = texture(screen_texture, SCREEN_UV);
    COLOR = scene_color + n * noise_amount;
}
