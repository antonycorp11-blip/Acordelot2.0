shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap;
uniform vec3 base_color : source_color = vec3(0.25, 0.45, 0.18);
uniform vec3 tip_color : source_color = vec3(0.55, 0.78, 0.28);

uniform float wind_speed = 1.4;
uniform float wind_strength = 0.18;
uniform float wind_wave_size = 10.0;

varying float v_height;

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    float height = clamp(VERTEX.y, 0.0, 1.2);
    v_height = height;
    
    float wave = sin(TIME * wind_speed + (world_pos.x + world_pos.z) / wind_wave_size);
    float flex = (height * 0.8) * wind_strength;
    VERTEX.x += wave * flex;
    VERTEX.z += wave * 0.7 * flex;
}

void fragment() {
    vec4 tex = texture(grass_albedo, UV);
    
    if (tex.a < 0.45) {
        discard;
    }
    
    float t_height = clamp(v_height / 0.9, 0.0, 1.0);
    vec3 grad_color = mix(base_color, tip_color, t_height);
    
    ALBEDO = tex.rgb * grad_color * 1.2;
    ROUGHNESS = 0.9;
    SPECULAR = 0.05;
}
