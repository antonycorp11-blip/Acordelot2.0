shader_type spatial;
render_mode diffuse_burley;

// O chao e uma malha por pedaco do mundo. Se as UV fossem as da malha, cada
// pedaco repetiria o MESMO desenho e a emenda apareceria como grade no terreno.
// Entao tudo e amostrado pela posicao no mundo: pedacos vizinhos continuam o
// desenho um do outro.
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float meters_per_tile = 6.0;
// A grama tila a cada poucos metros, entao a repeticao SERIA obvia de cima. O
// que a esconde e a variacao de tom em escala grande, dezenas de metros de
// clareira e sombra por cima do mesmo desenho.
uniform float macro_meters = 42.0;
uniform vec3 tint_dry : source_color = vec3(0.62, 0.68, 0.44);
uniform vec3 tint_lush : source_color = vec3(0.42, 0.62, 0.30);
uniform float tint_strength = 0.45;

varying vec3 world_position;

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

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 grass = texture(grass_texture, world_position.xz / meters_per_tile).rgb;

    // Duas escalas de mancha: a larga faz clareira e sombra de nuvem, a fina
    // desmancha a borda entre elas para nao virar bolha.
    vec2 macro_uv = world_position.xz / macro_meters;
    float patch = noise(macro_uv) * 0.75 + noise(macro_uv * 3.1) * 0.25;
    vec3 tint = mix(tint_lush, tint_dry, patch);

    ALBEDO = mix(grass, grass * tint * 1.5, tint_strength);
    ROUGHNESS = 0.96;
    SPECULAR = 0.12;
}
