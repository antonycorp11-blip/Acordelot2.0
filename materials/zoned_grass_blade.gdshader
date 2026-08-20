shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap;
uniform vec3 base_color : source_color = vec3(0.18, 0.32, 0.12);
uniform vec3 tip_color : source_color = vec3(0.48, 0.72, 0.22);
uniform vec3 dry_tip_color : source_color = vec3(0.72, 0.68, 0.32);

// Parâmetros de Vento
uniform float wind_speed = 1.6;
uniform float wind_strength = 0.35;
uniform float wind_wave_size = 8.0;

varying float v_height;
varying vec3 v_world_pos;

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world_pos = world_pos;
    
    // Altura relativa no modelo para aplicar flexão do vento
    float height = clamp(VERTEX.y, 0.0, 3.0);
    v_height = height;
    
    // Onda de vento contínua se propagando pelo campo
    float wave = sin(TIME * wind_speed + (world_pos.x + world_pos.z) / wind_wave_size);
    float gust = sin(TIME * wind_speed * 1.7 + world_pos.x * 0.3) * cos(TIME * wind_speed * 0.9 + world_pos.z * 0.3);
    
    // Deforma apenas a parte superior do tufo
    float flex = (height * height) * wind_strength;
    VERTEX.x += (wave + gust * 0.5) * flex;
    VERTEX.z += (wave * 0.7 + gust * 0.4) * flex;
}

void fragment() {
    vec4 tex = texture(grass_albedo, UV);
    
    // Gradiente da base escura até a ponta iluminada
    float t_height = clamp(v_height / 1.6, 0.0, 1.0);
    vec3 grad_color = mix(base_color, tip_color, t_height);
    
    // Se a textura tiver alpha recorte (billboard / sprite)
    if (tex.a < 0.5) {
        discard;
    }
    
    vec3 final_color = tex.rgb * grad_color * 1.4;
    ALBEDO = final_color;
    ROUGHNESS = 0.8;
    SPECULAR = 0.1;
    // Subsurface Scattering fake para dar sensação de grama translúcida sob luz do sol
    SSS_STRENGTH = 0.25;
}
