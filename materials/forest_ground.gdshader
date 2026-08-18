shader_type spatial;
render_mode diffuse_burley;

// O chao e uma malha por pedaco do mundo. Se as UV fossem as da malha, cada
// pedaco repetiria o MESMO desenho e a emenda apareceria como grade no terreno.
// Tudo e amostrado pela posicao no mundo: pedacos vizinhos continuam o desenho
// um do outro.
//
// E sao DUAS texturas, nao uma: campo de grama uniforme parece carpete visto de
// cima. O que da vida ao chao e a terra batida abrindo trilha e clareira no meio
// do mato — e isso e a mistura das duas por ruido de escala grande.
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float meters_per_tile = 7.0;

// Tamanho da mancha de terra. Grande demais vira deserto, pequeno demais vira
// bolha: 34 m da caminho e clareira na escala em que o jogador anda.
uniform float path_meters = 34.0;
uniform float path_amount = 0.22;

// Variacao de tom por cima de tudo, em escala ainda maior: e o que esconde a
// repeticao da textura, que tila a cada 7 m e seria obvia de cima.
uniform float macro_meters = 48.0;
uniform vec3 tint_dry : source_color = vec3(0.68, 0.66, 0.50);
uniform vec3 tint_lush : source_color = vec3(0.46, 0.58, 0.38);
uniform float tint_strength = 0.35;

varying vec3 world_position;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Quintico em vez de cubico: o cubico deixa a derivada quebrar na divisa da
    // celula, e a quebra e visivel como risco reto no terreno.
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Soma de oitavas COM ROTACAO entre elas. Sem girar, toda oitava cai na mesma
// treliça alinhada aos eixos e o terreno ganha um xadrez de retangulos — foi
// exatamente o que apareceu no chao, e nao era emenda de pedaco.
float fbm(vec2 p) {
    const mat2 turn = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
    float total = 0.0;
    float weight = 0.5;
    for (int octave = 0; octave < 4; octave++) {
        total += noise(p) * weight;
        p = turn * p * 2.03;
        weight *= 0.5;
    }
    return total / 0.9375;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 ground_uv = world_position.xz / meters_per_tile;
    vec3 grass = texture(grass_texture, ground_uv).rgb;
    vec3 dirt = texture(dirt_texture, ground_uv * 0.7).rgb;

    // Duas escalas na mancha de terra: a larga decide onde ha caminho, a fina
    // desmancha a borda para nao virar recorte de papel.
    vec2 path_uv = world_position.xz / path_meters;
    float path = fbm(path_uv);
    float dirt_mask = smoothstep(0.50, 0.50 + path_amount, path);

    vec3 ground = mix(grass, dirt, dirt_mask);

    vec2 macro_uv = world_position.xz / macro_meters;
    float patch = fbm(macro_uv);
    vec3 tint = mix(tint_lush, tint_dry, patch);
    ground = mix(ground, ground * tint * 1.6, tint_strength);

    ALBEDO = ground;
    ROUGHNESS = 0.98;
    SPECULAR = 0.05;
}
