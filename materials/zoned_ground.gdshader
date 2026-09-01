shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 zone_size = vec2(160.0, 160.0);
uniform float meters_per_tile = 3.2;

// O navegador mobile deixava o verde quase fluorescente. As tinturas ficam
// naturais aqui, antes da luz e do tonemap, para preservar detalhe sem formar
// a chapa verde-clara vista no celular.
uniform vec3 tint_lush : source_color = vec3(0.38, 0.52, 0.32);
uniform vec3 tint_dry : source_color = vec3(0.48, 0.45, 0.30);

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
// Duas ruas paralelas opcionais: z1, z2, meia largura, alcance em X.
uniform vec4 vias_secundarias = vec4(999.0, 999.0, 0.0, 0.0);
// 0 = terra batida, 1 = calcamento de pedra.
//
// Vila e cidade tem o mesmo desenho de via e chao diferente, e a diferenca
// conta a historia: na vila a rua e o chao pisado por quem passa, em Acordelot
// e chao construido por quem manda. Uma variavel decide qual, e o mesmo shader
// serve as duas.
uniform float via_de_pedra = 0.0;

// Estradas do mapa regional. São segmentos em coordenadas locais (x,z), e a
// mesma lista também é desenhada no mapa-múndi.
uniform int quantidade_caminhos = 0;
uniform float caminho_de_pedra = 0.0;
uniform vec4 caminho_0 = vec4(999.0);
uniform vec4 caminho_1 = vec4(999.0);
uniform vec4 caminho_2 = vec4(999.0);
uniform vec4 caminho_3 = vec4(999.0);
uniform vec4 caminho_4 = vec4(999.0);
uniform vec4 caminho_5 = vec4(999.0);
uniform vec4 caminho_6 = vec4(999.0);
uniform vec4 caminho_7 = vec4(999.0);
uniform vec4 caminho_8 = vec4(999.0);
uniform vec4 caminho_9 = vec4(999.0);
uniform vec4 caminho_10 = vec4(999.0);
uniform vec4 caminho_11 = vec4(999.0);

varying vec3 world_pos;
// A posicao DENTRO da zona, separada da posicao no mundo.
//
// Grama e ruido usam a de mundo, e e o certo: assim o padrao atravessa a divisa
// entre duas zonas sem emenda. Rua e largo, nao — vem do planejador em
// coordenadas da propria zona. Enquanto so existia uma zona, no centro do
// mundo, as duas eram a mesma coisa; com o mundo aberto, a vila foi para 160 m
// ao norte e as ruas dela continuaram sendo desenhadas na origem, isto e, em
// lugar nenhum.
varying vec3 pos_local;
varying vec3 world_normal;

// SEM sin(). O hash antigo custava um seno por amostra, e o `fbm` abaixo pede
// doze amostras: com quatro `fbm` e um `noise` por pixel, o chao — que cobre a
// tela inteira — pedia mais de cinquenta senos POR PIXEL. Em GPU integrada e em
// celular o seno e caro, e isto sozinho dominava o quadro.
//
// Esta versao usa so multiplicacao e parte fracionaria. O padrao muda um pouco,
// mas e ruido: ninguem compara dois ruidos, compara-se relevo com relevo.
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// DUAS OITAVAS, nao tres. A terceira contribui um oitavo do resultado e custa
// um terco do trabalho; num chao visto de cima, a cinco metros de distancia,
// ela nao aparece. O peso e reescalado para a faixa continuar a mesma e as
// bordas de estrada e rua nao mudarem de largura.
float fbm(vec2 p) {
    float total = noise(p) * 0.5;
    total += noise(p * 2.05) * 0.25;
    return total * 1.1667;
}

float distancia_segmento(vec2 p, vec4 linha) {
    vec2 a = linha.xy;
    vec2 b = linha.zw;
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
    return length(p - (a + ab * t));
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    pos_local = VERTEX;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec2 uv = world_pos.xz / meters_per_tile;

    vec3 col_grass = texture(grass_texture, uv).rgb;
    // A MESMA GRAMA NUMA SEGUNDA ESCALA, e a repeticao some.
    //
    // O ladrilho tem 3,2 m e a zona tem 160: a mesma imagem aparecia CINQUENTA
    // vezes de ponta a ponta, e o olho enxerga esse xadrez de longe melhor do
    // que enxerga a grama. Somar a mesma textura numa escala grande e
    // incomensuravel com a pequena quebra o padrao — o par so volta a se repetir
    // depois de centenas de metros, isto e, nunca dentro de uma zona. Custa uma
    // busca de textura, que e barato perto de mais uma oitava de ruido.
    vec3 col_grass_largo = texture(grass_texture, uv * 0.287).rgb;
    vec3 col_dirt  = texture(dirt_texture, uv).rgb;
    vec3 col_stone = texture(stone_texture, uv * 1.12).rgb;
    vec3 col_rock  = texture(rock_texture, uv * 0.65).rgb;

    // Variação suave de tom verdejante
    float macro = fbm(world_pos.xz / 42.0);
    // A mistura das duas escalas VARIA com o mesmo ruido macro que ja existe:
    // proporcao fixa so lavaria o contraste, e ruido proprio custaria mais.
    col_grass = mix(col_grass, col_grass_largo, 0.26 + macro * 0.34);

    vec3 grass_varied = mix(col_grass * tint_lush * 1.02, col_grass * tint_dry * 0.98, macro * 0.4);
    // Detalhe pequeno devolve leitura ao gramado sem textura maior. Usa uma
    // unica amostra de ruido e continua barato no Web.
    float detalhe = noise(world_pos.xz / 2.4);
    grass_varied *= mix(0.95, 1.04, detalhe);

    // MANCHAS SECAS. Onde o macro sobe muito, o capim amarela e deixa entrever
    // a terra. Reaproveita o `macro` ja calculado: e so ler outra faixa dele.
    float seco = smoothstep(0.55, 0.80, macro);
    grass_varied = mix(grass_varied, mix(col_grass * tint_dry * 0.92, col_dirt, 0.35), seco * 0.55);

    // Caminhos orgânicos de terra batida. O ruido e lido UMA vez e serve a duas
    // leituras: a trilha estreita e a clareira de terra batida mais larga.
    float terra_bruta = fbm(world_pos.xz / 18.0);
    float path_noise = smoothstep(0.48, 0.56, terra_bruta);
    float clareira_de_terra = smoothstep(0.60, 0.75, terra_bruta);
    vec3 base_color = mix(grass_varied, col_dirt, path_noise * 0.38);
    base_color = mix(base_color, col_dirt * 0.94, clareira_de_terra * 0.45);

    // CASCALHO: pedrinha onde a terra ja aparece. Nao sao malhas — e a textura
    // de rocha que ja foi buscada, entrando so nos pontos altos do ruido fino.
    // Dezenas de pedras de verdade custariam desenho; isto custa uma mistura.
    float cascalho = clareira_de_terra * smoothstep(0.62, 0.92, detalhe);
    base_color = mix(base_color, col_rock * 0.88, cascalho * 0.40);

    float distancia_estrada = 999.0;
    if (quantidade_caminhos > 0) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_0));
    if (quantidade_caminhos > 1) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_1));
    if (quantidade_caminhos > 2) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_2));
    if (quantidade_caminhos > 3) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_3));
    if (quantidade_caminhos > 4) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_4));
    if (quantidade_caminhos > 5) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_5));
    if (quantidade_caminhos > 6) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_6));
    if (quantidade_caminhos > 7) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_7));
    if (quantidade_caminhos > 8) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_8));
    if (quantidade_caminhos > 9) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_9));
    if (quantidade_caminhos > 10) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_10));
    if (quantidade_caminhos > 11) distancia_estrada = min(distancia_estrada, distancia_segmento(pos_local.xz, caminho_11));
    if (quantidade_caminhos > 0) {
        float desgaste = (fbm(pos_local.xz / 4.0) - 0.5) * 1.2;
        float mascara_estrada = 1.0 - smoothstep(4.2 + desgaste, 5.5 + desgaste, distancia_estrada);
        // A BEIRA DA ESTRADA, pisada mas ainda com capim.
        //
        // Antes a estrada acabava numa linha: de um lado terra, do outro
        // gramado cheio. Estrada de verdade tem acostamento — o mato rala onde
        // o pe passa raspando. Sai do mesmo `desgaste` e da mesma distancia ja
        // calculados, entao nao custa ruido nenhum a mais.
        float acostamento = 1.0 - smoothstep(5.5 + desgaste, 9.5 + desgaste, distancia_estrada);
        base_color = mix(base_color, col_dirt * 0.90,
                         max(acostamento - mascara_estrada, 0.0) * 0.42);
        vec3 material_estrada = mix(col_dirt * 0.80, col_stone * 0.70, caminho_de_pedra);
        base_color = mix(base_color, material_estrada, mascara_estrada * 0.95);
    }

    // A via da povoacao, por cima do chao natural.
    if (via_principal.x > 0.01) {
        // A borda nao e reta: um metro de ruido come a linha do asfalto e a
        // deixa gasta. Rua de terra com borda de regua le como pista pintada.
        float franja = (fbm(pos_local.xz / 3.5) - 0.5) * 1.6;

        float meia = via_principal.x + franja;
        float rua = (1.0 - smoothstep(meia - 0.9, meia + 0.5, abs(pos_local.x)))
                  * (1.0 - smoothstep(via_principal.y - 3.0, via_principal.y, abs(pos_local.z)));

        float largo = 1.0 - smoothstep(via_principal.z - 2.5 + franja,
                                       via_principal.z + 0.6 + franja,
                                       length(pos_local.xz));

        float meia_t = via_principal.w + franja;
        float travessa = (1.0 - smoothstep(meia_t - 0.7, meia_t + 0.5,
                                           abs(pos_local.z - via_travessa.x)))
                       * (1.0 - smoothstep(via_travessa.y - 3.0, via_travessa.y,
                                           abs(pos_local.x)));

        float meia_s = vias_secundarias.z + franja;
        float secundaria_1 = (1.0 - smoothstep(meia_s - 0.7, meia_s + 0.5,
                                                abs(pos_local.z - vias_secundarias.x)))
                           * (1.0 - smoothstep(vias_secundarias.w - 3.0,
                                               vias_secundarias.w, abs(pos_local.x)));
        float secundaria_2 = (1.0 - smoothstep(meia_s - 0.7, meia_s + 0.5,
                                                abs(pos_local.z - vias_secundarias.y)))
                           * (1.0 - smoothstep(vias_secundarias.w - 3.0,
                                               vias_secundarias.w, abs(pos_local.x)));

        float via = clamp(max(max(max(rua, largo), travessa),
                              max(secundaria_1, secundaria_2)), 0.0, 1.0);
        // Terra batida, um tom mais escura que a de fora: chao pisado escurece.
        // Ou pedra, quando a zona pede calcamento.
        // Calcada pisada em volta da via, pela mesma razao do acostamento da
        // estrada: rua que termina numa linha reta parece adesivo no gramado.
        float beira = clamp(max(max(
            (1.0 - smoothstep(meia + 0.5, meia + 3.6, abs(pos_local.x)))
                * (1.0 - smoothstep(via_principal.y - 3.0, via_principal.y, abs(pos_local.z))),
            1.0 - smoothstep(via_principal.z + 0.6 + franja,
                             via_principal.z + 3.8 + franja, length(pos_local.xz))),
            (1.0 - smoothstep(meia_t + 0.5, meia_t + 3.2, abs(pos_local.z - via_travessa.x)))
                * (1.0 - smoothstep(via_travessa.y - 3.0, via_travessa.y, abs(pos_local.x)))),
            0.0, 1.0);
        vec3 cor_da_via = mix(col_dirt * 0.82, col_stone * 0.70, via_de_pedra);
        base_color = mix(base_color, col_dirt * 0.88, max(beira - via, 0.0) * 0.45);
        base_color = mix(base_color, cor_da_via, via * 0.92);
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
