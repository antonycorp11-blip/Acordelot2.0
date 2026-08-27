shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, world_vertex_coords;

// Mato fotografado (tufo alto e erva florida) desenhado aos milhares.
//
// Tudo aqui é conta em METRO, no espaço do mundo, e por isso o `world_vertex_coords`
// no cabeçalho. A malha vem do Sketchfab em centímetros e com o eixo de cima
// no Z: fazer altura, vento e distância no espaço da malha significaria acertar
// esses dois detalhes peça por peça, e errar um deles deita a planta ou some
// com ela. No mundo, "para cima" é sempre +Y e um metro é sempre um metro.
//
// A peça encolhe até sumir na distância, pelo mesmo motivo da grama do chão: a
// trinta metros um tufo de meio metro é um ponto, e mil pontos são ruído.

uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_disable;
uniform float corte : hint_range(0.0, 1.0) = 0.4;
// Altura típica da peça no mundo, em metros — só serve de régua para o
// degradê do pé e para a força do vento.
uniform float altura_mundo = 0.5;
uniform float forca_vento = 0.05;
uniform float velocidade_vento = 1.15;
uniform float distancia_cheia = 20.0;
uniform float distancia_nula = 34.0;
// Quanto a normal é puxada para cima. A folha recortada tem normal virada para
// os lados; iluminada assim ela fica preta contra o gramado. Como massa de
// mato, recebendo luz de cima, ela volta a ser verde.
uniform float achatar_normal : hint_range(0.0, 1.0) = 0.66;

varying float altura_relativa;

void vertex() {
    vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    altura_relativa = clamp((VERTEX.y - base.y) / max(altura_mundo, 0.01), 0.0, 1.0);

    float presenca = 1.0 - smoothstep(distancia_cheia, distancia_nula,
        distance(base, CAMERA_POSITION_WORLD));
    vec3 fora = VERTEX - base;
    VERTEX = base + fora * vec3(mix(0.45, 1.0, presenca), presenca, mix(0.45, 1.0, presenca));

    float fase = base.x * 0.23 + base.z * 0.19;
    float balanco = sin(TIME * velocidade_vento + fase) * forca_vento
        * altura_relativa * altura_relativa;
    VERTEX.x += balanco;
    VERTEX.z += balanco * 0.4;

    NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), achatar_normal));
}

void fragment() {
    vec4 amostra = texture(textura, UV);
    ALPHA = amostra.a;
    ALPHA_SCISSOR_THRESHOLD = corte;
    // O pé da moita escurece: sem isso a peça recortada flutua sobre o chão,
    // porque a foto original vem iluminada por igual de cima a baixo.
    ALBEDO = amostra.rgb * mix(0.72, 1.06, altura_relativa);
    ROUGHNESS = 0.94;
    SPECULAR = 0.03;
}
