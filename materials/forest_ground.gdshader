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
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// A lajota da praca. Nao e a mesma pedra da estrada: rua e calcamento redondo de
// passagem, praca e lajota cortada — e a diferenca entre as duas e o que faz o
// jogador sentir que ENTROU na cidade.
uniform sampler2D flagstone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// Centro e raio das pracas, em metros de mundo: xy = centro, z = raio, w = 0
// quando a vaga nao e usada.
uniform vec4 pracas[16];
uniform int quantas_pracas = 0;

// A malha viaria de cada cidade: quantas avenidas saem do centro e ate onde vai
// cada anel. x = numero de avenidas, y/z/w = raio dos tres aneis (0 = sem anel).
uniform vec4 malha_viaria[16];

// Mapa das estradas do mundo inteiro, desenhado por .tools/gerar_estradas.py a
// partir da grade dos cenarios. Vermelho = terra batida, verde = calcamento.
// Uma leitura de textura resolve um tracado que ruido nenhum saberia fazer:
// estrada tem que SAIR de um cenario e CHEGAR no outro.
uniform sampler2D road_mask : filter_linear, repeat_disable;
uniform vec2 world_min = vec2(-660.0, -540.0);
uniform vec2 world_size = vec2(1320.0, 1200.0);
// 7 m deixava a mancha da textura pintada com metros de largura: de longe o
// campo virava um borrao de verde claro e verde escuro. Textura chapada precisa
// tilar MAIS, nao menos — o que esconde a repeticao aqui e a tintura de escala
// grande, nao o tamanho do azulejo.
uniform float meters_per_tile = 4.0;

// Tamanho da mancha de terra. Grande demais vira deserto, pequeno demais vira
// bolha: 34 m da caminho e clareira na escala em que o jogador anda.
// Onde a agua para. O mesmo numero do relevo: abaixo disso o chao esta no fundo
// do lago, e fundo de lago nao tem grama.
uniform float nivel_da_agua = -2.2;
// Faixa de praia acima da linha da agua, em metros.
uniform float faixa_da_praia = 0.7;

uniform float path_meters = 26.0;
// Largura da trilha. 0.05 da caminho de uns tres metros na escala do ruido.
uniform float path_amount = 0.055;

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

// Le a textura DUAS vezes e mistura por ruido.
//
// Uma leitura so poe o mesmo desenho de metro em metro, e o olho monta a grade
// sozinho: com a grama pintada, os tufos escuros alinharam num xadrez visivel
// de longe. A segunda leitura vem girada e numa escala irracional em relacao a
// primeira, entao as duas grades nunca coincidem; o ruido decide qual manda em
// cada ponto e a emenda entre elas nao tem forma reconhecivel.
//
// Custa uma leitura de textura a mais por pixel do chao. E o preco mais barato
// que existe para esse defeito — o outro caminho seria textura gigante, que
// nao cabe na memoria do alvo.
vec3 amostra_sem_grade(sampler2D textura, vec2 mundo) {
    const mat2 giro = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

    // O vento tambem passa pelo chao. A grama e textura, nao geometria, entao
    // nao ha folha para dobrar — o que se faz e empurrar a leitura da textura de
    // lado em ondas largas. Le como rajada varrendo o campo, e custa duas contas
    // de seno por pixel.
    //
    // O deslocamento e pequeno (poucos centimetros): passar disso faz o desenho
    // ESCORREGAR sobre o terreno em vez de balancar, e a ilusao quebra.
    float rajada = sin(mundo.x * 0.06 + TIME * 0.55)
                 + 0.6 * sin(mundo.y * 0.09 - TIME * 0.8);
    mundo += vec2(rajada * 0.055, rajada * 0.03);

    vec3 primeira = texture(textura, mundo / meters_per_tile).rgb;
    vec3 segunda = texture(textura, (giro * mundo) / (meters_per_tile * 1.61)).rgb;
    float escolha = fbm(mundo / 11.0);
    return mix(primeira, segunda, smoothstep(0.34, 0.66, escolha));
}

void fragment() {
    vec2 ground_uv = world_position.xz / meters_per_tile;
    vec3 grass = amostra_sem_grade(grass_texture, world_position.xz);
    vec3 dirt = texture(dirt_texture, ground_uv * 0.7).rgb;

    // A terra sai de uma FAIXA do ruido, nao da metade dele.
    //
    // Com "acima de 0.5 e terra", metade do mundo virava terra: nao dava
    // caminho, dava um continente de barro com a grama nas beiradas — foi
    // exatamente a mancha enorme que apareceu em volta do jogador. Pegando so
    // onde o ruido PASSA por um valor, o resultado e a linha de nivel dele:
    // uma trilha estreita que serpenteia e se bifurca sozinha, que e como
    // caminho de terra nasce de verdade, de gente pisando sempre no mesmo lugar.
    vec2 path_uv = world_position.xz / path_meters;
    float path = fbm(path_uv);
    float dirt_mask = 1.0 - smoothstep(0.0, path_amount, abs(path - 0.5));

    vec3 ground = mix(grass, dirt, dirt_mask);

    // A estrada vem por cima da mancha natural: onde ela passa, manda ela.
    vec2 road_uv = (world_position.xz - world_min) / world_size;
    vec2 road = texture(road_mask, road_uv).rg;
    ground = mix(ground, dirt, smoothstep(0.45, 0.80, road.r));
    vec3 stone = texture(stone_texture, world_position.xz / 3.2).rgb;
    ground = mix(ground, stone, smoothstep(0.45, 0.80, road.g));

    // Calcamento da praca, por dentro do plato ja nivelado pelo relevo. A borda
    // desmancha nos ultimos metros para a cidade nao terminar num disco recortado
    // no meio do campo — vila de verdade tem quintal e horta antes do mato.
    float na_praca = 0.0;
    for (int i = 0; i < quantas_pracas; i++) {
        float d = distance(world_position.xz, pracas[i].xy);
        na_praca = max(na_praca, 1.0 - smoothstep(pracas[i].z * 0.72, pracas[i].z, d));
    }
    if (na_praca > 0.001) {
        vec3 lajota = texture(flagstone_texture, world_position.xz / 4.2).rgb;
        ground = mix(ground, lajota, na_praca);

        // Por cima da lajota, o leito das ruas em pedra de passagem.
        float rua = 0.0;
        for (int i = 0; i < quantas_pracas; i++) {
            vec2 rel = world_position.xz - pracas[i].xy;
            float dist = length(rel);
            if (dist > pracas[i].z) { continue; }

            float avenidas = malha_viaria[i].x;
            if (avenidas > 0.5) {
                // Distancia ate o eixo da avenida mais proxima. O angulo dobrado
                // pelo numero de avenidas transforma "qual raio" em "quanto
                // falta para o proximo", sem laco sobre as avenidas.
                float passo = 6.28318530718 / avenidas;
                float sobra = mod(atan(rel.y, rel.x) + passo * 0.5, passo) - passo * 0.5;
                // A largura da rua e constante em METROS: o desvio angular
                // multiplica pela distancia ao centro.
                rua = max(rua, 1.0 - smoothstep(2.6, 4.0, abs(sobra) * dist));
            }
            // Aneis: faixas circulares na distancia declarada.
            for (int k = 1; k < 4; k++) {
                float raio = malha_viaria[i][k];
                if (raio < 0.5) { continue; }
                rua = max(rua, 1.0 - smoothstep(2.2, 3.4, abs(dist - raio)));
            }
            // A praca central e toda calcada de passagem, sem quarteirao.
            rua = max(rua, 1.0 - smoothstep(7.0, 9.5, dist));
        }
        vec3 leito = texture(stone_texture, world_position.xz / 3.2).rgb;
        ground = mix(ground, leito, rua * na_praca);
    }

    // Leito do lago: terra, nunca grama. Uma lamina de agua por cima de campo
    // verde le como poca em cima do gramado, que foi a queixa — lagoa de verdade
    // tem fundo de terra, e a margem faz uma faixa de praia antes do capim.
    float submerso = 1.0 - smoothstep(nivel_da_agua, nivel_da_agua + faixa_da_praia,
                                      world_position.y);
    ground = mix(ground, dirt, submerso);

    vec2 macro_uv = world_position.xz / macro_meters;
    float patch = fbm(macro_uv);
    vec3 tint = mix(tint_lush, tint_dry, patch);
    ground = mix(ground, ground * tint * 1.6, tint_strength);

    ALBEDO = ground;
    ROUGHNESS = 0.98;
    SPECULAR = 0.05;
}
