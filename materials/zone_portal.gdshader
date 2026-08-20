shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 portal_color : source_color = vec4(0.2, 0.75, 1.0, 0.75);
uniform vec4 rune_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float swirl_speed = 2.0;

void fragment() {
    vec2 centered = (UV - vec2(0.5)) * 2.0;
    float dist = length(centered);
    
    if (dist > 1.0) {
        discard;
    }
    
    float angle = atan(centered.y, centered.x);
    float spiral = sin(angle * 3.0 + dist * 8.0 - TIME * swirl_speed);
    
    float ring = smoothstep(1.0, 0.75, dist) * smoothstep(0.1, 0.45, dist);
    vec3 col = mix(portal_color.rgb, rune_color.rgb, clamp(spiral * 0.5 + 0.5, 0.0, 1.0));
    
    ALBEDO = col;
    EMISSION = col * (ring * 1.5);
    ALPHA = ring * portal_color.a;
}
