shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 zone_size = vec2(160.0, 160.0);
uniform float meters_per_tile = 4.0;

// Tinturas suaves para manter verde vibrante
uniform vec3 tint_lush : source_color = vec3(0.55, 0.72, 0.45);
uniform vec3 tint_dry : source_color = vec3(0.68, 0.65, 0.48);

uniform float water_level = -2.0;
uniform float shore_blend = 0.8;

// O desenho viario da povoacao, em metros e no espaco do mundo.
//
// Ate aqui a rua da vila era so a AUSENCIA de casa: o planejador afastava as
// construcoes para abrir oito metros de via, e o chao debaixo era grama igual
// ao resto. A cidade tinha o vazio da rua sem ter a rua — dai a leitura de
// "casas jogadas no campo".
//
// x = meia largura da via principal (0 desliga tudo)
// y = ate onde ela vai, para os dois lados, no eixo Z
// z = raio do largo no meio
// w = meia largura das travessas
uniform vec4 via_principal = vec4(0.0);
// x = em que Z as travessas cruzam, y = ate que |X| elas vao
uniform vec2 via_travessa = vec2(0.0);

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
    float total = 0.0;
    float weight = 0.5;
    for (int i = 0; i < 3; i++) {
        total += noise(p) * weight;
        p = p * 2.05;
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
    
    vec3 col_grass = texture(grass_texture, uv).rgb;
    vec3 col_dirt  = texture(dirt_texture, uv).rgb;
    vec3 col_stone = texture(stone_texture, uv * 0.8).rgb;
    vec3 col_rock  = texture(rock_texture, uv * 0.65).rgb;
    
    // Variação suave de tom verdejante
    float macro = fbm(world_pos.xz / 42.0);
    vec3 grass_varied = mix(col_grass * tint_lush * 1.15, col_grass * tint_dry * 1.05, macro * 0.4);
    
    // Caminhos orgânicos de terra batida
    float path_noise = smoothstep(0.48, 0.56, fbm(world_pos.xz / 18.0));
    vec3 base_color = mix(grass_varied, col_dirt, path_noise * 0.65);

    // A via da povoacao, por cima do chao natural.
    if (via_principal.x > 0.01) {
        // A borda nao e reta: um metro de ruido come a linha do asfalto e a
        // deixa gasta. Rua de terra com borda de regua le como pista pintada.
        float franja = (fbm(world_pos.xz / 3.5) - 0.5) * 1.6;

        float meia = via_principal.x + franja;
        float rua = (1.0 - smoothstep(meia - 0.9, meia + 0.5, abs(world_pos.x)))
                  * (1.0 - smoothstep(via_principal.y - 3.0, via_principal.y, abs(world_pos.z)));

        float largo = 1.0 - smoothstep(via_principal.z - 2.5 + franja,
                                       via_principal.z + 0.6 + franja,
                                       length(world_pos.xz));

        float meia_t = via_principal.w + franja;
        float travessa = (1.0 - smoothstep(meia_t - 0.7, meia_t + 0.5,
                                           abs(world_pos.z - via_travessa.x)))
                       * (1.0 - smoothstep(via_travessa.y - 3.0, via_travessa.y,
                                           abs(world_pos.x)));

        float via = clamp(max(max(rua, largo), travessa), 0.0, 1.0);
        // Terra batida, um tom mais escura que a de fora: chao pisado escurece.
        base_color = mix(base_color, col_dirt * 0.82, via * 0.92);
    }
    
    // Encostas rochosas naturais
    float slope = 1.0 - world_normal.y;
    float rock_blend = smoothstep(0.32, 0.58, slope);
    base_color = mix(base_color, col_rock, rock_blend);
    
    // Praia perto do nível da água
    if (world_pos.y < water_level + shore_blend) {
        float shore = 1.0 - clamp((world_pos.y - water_level) / shore_blend, 0.0, 1.0);
        base_color = mix(base_color, col_dirt * 0.9, shore * 0.9);
    }
    
    ALBEDO = base_color;
    ROUGHNESS = 0.9;
    SPECULAR = 0.05;
}
