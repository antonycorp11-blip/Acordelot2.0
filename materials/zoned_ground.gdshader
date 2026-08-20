shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Texturas do terreno
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// Máscara local de caminhos/estradas da zona (R=Terra, G=Pedra)
uniform sampler2D path_mask : filter_linear, repeat_disable;
uniform bool use_path_mask = false;
uniform vec2 zone_size = vec2(160.0, 160.0);

// Configurações de escala
uniform float meters_per_tile = 3.5;
uniform float macro_scale = 35.0;

// Tinturas para variação visual estilo Albion
uniform vec3 tint_lush : source_color = vec3(0.42, 0.65, 0.28);
uniform vec3 tint_dry : source_color = vec3(0.62, 0.58, 0.38);
uniform float tint_strength = 0.32;

// Altura e água
uniform float water_level = -2.0;
uniform float shore_blend = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    const mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
    float total = 0.0;
    float weight = 0.5;
    for (int i = 0; i < 3; i++) {
        total += noise(p) * weight;
        p = rot * p * 2.02;
        weight *= 0.5;
    }
    return total;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec2 uv = world_pos.xz / meters_per_tile;
    
    // Coleta as 4 texturas
    vec3 col_grass = texture(grass_texture, uv).rgb;
    vec3 col_dirt  = texture(dirt_texture, uv).rgb;
    vec3 col_stone = texture(stone_texture, uv * 0.85).rgb;
    vec3 col_rock  = texture(rock_texture, uv * 0.7).rgb;
    
    // Variação macro de cor para dar riqueza visual
    float macro_noise = fbm(world_pos.xz / macro_scale);
    vec3 grass_tinted = mix(col_grass * tint_lush * 1.25, col_grass * tint_dry * 1.15, macro_noise);
    
    // Ruído orgânico para misturar grama e terra batida natural
    float path_noise = smoothstep(0.42, 0.58, fbm(world_pos.xz / 12.0));
    vec3 base_color = mix(grass_tinted, col_dirt, path_noise * 0.6);
    
    // Inclinação: encostas íngremes viram rocha natural
    float slope = 1.0 - world_normal.y;
    float rock_blend = smoothstep(0.28, 0.55, slope);
    base_color = mix(base_color, col_rock, rock_blend);
    
    // Margem de água / praia
    if (world_pos.y < water_level + shore_blend) {
        float shore_factor = 1.0 - clamp((world_pos.y - water_level) / shore_blend, 0.0, 1.0);
        base_color = mix(base_color, col_dirt * 0.85, shore_factor * 0.85);
    }
    
    // Aplica máscara de estradas e calçamento da zona se existir
    if (use_path_mask) {
        vec2 mask_uv = (world_pos.xz / zone_size) + vec2(0.5, 0.5);
        if (mask_uv.x >= 0.0 && mask_uv.x <= 1.0 && mask_uv.y >= 0.0 && mask_uv.y <= 1.0) {
            vec4 mask = texture(path_mask, mask_uv);
            // Canal R = Terra Batida de Trilha
            base_color = mix(base_color, col_dirt, mask.r);
            // Canal G = Calçamento de Pedra
            base_color = mix(base_color, col_stone, mask.g);
        }
    }
    
    ALBEDO = base_color;
    ROUGHNESS = mix(0.85, 0.95, rock_blend);
    SPECULAR = 0.15;
}
