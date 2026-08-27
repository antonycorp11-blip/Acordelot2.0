shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

// Tapete de grama do mundo aberto.
//
// A versão anterior desenhava lâminas retas, escuras e do mesmo tamanho até o
// horizonte. Contra um chão claro isso não lia como grama: lia como confete
// verde-escuro salpicado no campo, e o problema piorava justamente longe, onde
// cada tufo virava um ponto de um pixel.
//
// Três correções, todas de graça no vértice:
//   1. a lâmina encolhe até sumir na distância, devolvendo o chão pintado ao
//      fundo do quadro em vez de ruído;
//   2. a cor da base é a do gramado, e só a ponta clareia — o tufo emerge do
//      chão em vez de ser colado sobre ele;
//   3. a normal é puxada para cima, então a moita recebe luz como massa
//      vegetal, não como um conjunto de facetas viradas para os lados.

uniform vec3 cor_base : source_color = vec3(0.20, 0.35, 0.12);
uniform vec3 cor_ponta : source_color = vec3(0.43, 0.65, 0.22);
uniform float forca_vento = 0.075;
uniform float velocidade_vento = 1.35;
// Onde a lâmina começa a encolher e onde ela desaparece, em metros.
uniform float distancia_cheia = 24.0;
uniform float distancia_nula = 46.0;
// Quanto a normal é puxada para cima (1 = a moita é iluminada como chão).
uniform float achatar_normal : hint_range(0.0, 1.0) = 0.72;

varying float altura_da_folha;
varying vec3 matiz_do_tufo;

void vertex() {
    altura_da_folha = UV.y;
    matiz_do_tufo = COLOR.rgb;

    vec3 base_mundo = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float distancia = distance(base_mundo, CAMERA_POSITION_WORLD);
    float presenca = 1.0 - smoothstep(distancia_cheia, distancia_nula, distancia);
    VERTEX.y *= presenca;
    VERTEX.xz *= mix(0.55, 1.0, presenca);

    float fase = base_mundo.x * 0.21 + base_mundo.z * 0.17;
    float vento = sin(TIME * velocidade_vento + fase) * forca_vento * UV.y * UV.y;
    VERTEX.x += vento;
    VERTEX.z += vento * 0.42;

    NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), achatar_normal));
}

void fragment() {
    float h = clamp(altura_da_folha, 0.0, 1.0);
    // A curva joga a transição para o alto: o pé da lâmina fica com a cor do
    // gramado por quase metade da altura, e é isso que faz o tufo "nascer".
    vec3 cor = mix(cor_base, cor_ponta, h * h);
    ALBEDO = cor * matiz_do_tufo;
    ROUGHNESS = 0.96;
    SPECULAR = 0.02;
}
