shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 portal_color : source_color = vec4(0.2, 0.75, 1.0, 0.9);
uniform vec4 inner_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float swirl_speed = 2.5;

void fragment() {
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv) * 2.0;
    
    if (dist > 1.0) {
        discard;
    }
    
    float angle = atan(centered_uv.y, centered_uv.x);
    float spiral = sin(angle * 4.0 + dist * 12.0 - TIME * swirl_speed);
    float pulse = sin(TIME * 3.0) * 0.1 + 0.9;
    
    float ring = smoothstep(1.0, 0.7, dist) * smoothstep(0.0, 0.4, dist);
    vec3 col = mix(portal_color.rgb, inner_color.rgb, spiral * 0.5 + 0.5);
    
    ALBEDO = col * (ring * pulse * 1.8);
    ALPHA = clamp(ring * portal_color.a * 1.5, 0.0, 1.0);
}
