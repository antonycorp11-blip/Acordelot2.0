shader_type spatial;
render_mode cull_disabled, diffuse_burley, depth_draw_never;

// A agua do Acordelot: lagoa de fundo de vale.
//
// Nao ha mapa de lagos. O relevo ja tem vale, e a agua simplesmente para numa
// altura fixa — o que estiver abaixo dela enche. E como lagoa se forma no mundo
// real, e sai de graca: nenhum desenho a mais para carregar, e o lago casa com o
// terreno em qualquer regiao porque os dois saem da mesma funcao.
//
// O movimento e feito de duas camadas de ruido correndo em direcoes e
// velocidades diferentes. Uma camada so daria a superficie inteira deslizando
// para o mesmo lado, que le como esteira, nao como agua.

uniform vec3 cor_rasa : source_color = vec3(0.20, 0.63, 0.68);
uniform vec3 cor_funda : source_color = vec3(0.025, 0.16, 0.31);
uniform vec3 cor_espuma : source_color = vec3(0.88, 0.98, 1.00);

uniform float velocidade = 0.055;
uniform float escala_da_onda = 0.42;
// Ate onde a margem faz espuma, em metros de profundidade.
uniform float margem = 0.55;
uniform float opacidade_maxima = 0.86;

// Profundidade em metros, gravada por vertice quando a malha e montada. Ler a
// profundidade do buffer de profundidade da tela seria mais exato e custa uma
// leitura de textura por pixel — caro no alvo, e desnecessario: o terreno nao
// muda, entao o valor pode ser assado.
varying float profundidade;
varying vec3 posicao_no_mundo;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
    profundidade = COLOR.r;
    posicao_no_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Ondulacao da propria superficie. Pequena de proposito: lagoa nao tem
    // vagalhao, e amplitude grande abriria fresta entre a agua e a margem.
    VERTEX.y += sin(posicao_no_mundo.x * 0.8 + TIME * 1.15) * 0.030
              + sin(posicao_no_mundo.z * 1.1 - TIME * 0.85) * 0.024;
}

void fragment() {
    vec2 uv = posicao_no_mundo.xz * escala_da_onda;
    float a = ruido(uv + vec2(TIME * velocidade, TIME * velocidade * 0.6));
    float b = ruido(uv * 1.7 - vec2(TIME * velocidade * 0.8, TIME * velocidade * 1.3));
    float brilho = a * 0.6 + b * 0.4;
    // Ondas direcionais quebram o aspecto de ruído borrado. São apenas senos,
    // sem mapa de reflexão ou leitura da tela, portanto continuam baratas no
    // renderizador Web de compatibilidade.
    float onda_a = sin(uv.x * 2.1 + uv.y * 0.7 + TIME * 0.75);
    float onda_b = sin(uv.y * 2.7 - uv.x * 0.45 - TIME * 0.62);
    float crista = pow(clamp(onda_a * 0.5 + onda_b * 0.5, 0.0, 1.0), 5.0);

    // Quanto mais funda, mais escura e mais opaca: e o que da leitura de volume
    // a uma superficie que e um plano so.
    float funda = clamp(profundidade / 2.2, 0.0, 1.0);
    vec3 cor = mix(cor_rasa, cor_funda, funda);
    cor += brilho * 0.09 + crista * vec3(0.16, 0.23, 0.27);
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
    cor = mix(cor, vec3(0.34, 0.58, 0.72), fresnel * 0.28);

    // Espuma na margem, onde a agua encosta no barranco. Sem ela a lagoa termina
    // num corte reto sobre a grama e parece vidro apoiado no chao.
    float na_margem = 1.0 - smoothstep(0.0, margem, profundidade);
    float renda = smoothstep(0.45, 0.75, brilho);
    cor = mix(cor, cor_espuma, na_margem * (0.35 + renda * 0.5));

    ALBEDO = cor;
    // A borda rasa e quase transparente: e o que deixa o fundo aparecer perto da
    // margem e faz a agua parecer entrar no terreno em vez de encostar nele.
    ALPHA = mix(0.30, opacidade_maxima, funda) + na_margem * renda * 0.25;
    ROUGHNESS = mix(0.16, 0.07, crista);
    SPECULAR = 0.72;
    METALLIC = 0.0;
}
