shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// O vento do Acordelot, para o que tem folha.
//
// A malha do TripoSR nao tem textura nem normal: so posicao e COR POR VERTICE.
// Por isso o material do jogo le a cor do vertice como albedo — e por isso o
// vento tem de morar num shader proprio em vez de num StandardMaterial3D, que
// nao mexe em vertice.
//
// Pedra e casa NAO usam este material. Muro balancando denuncia o truque na
// hora, e e o tipo de detalhe que o jogador nota sem saber dizer o que viu.

// O TripoSR normaliza tudo que devolve para mais ou menos uma unidade de
// altura, com a base perto de -0,5. Entao a altura relativa do vertice sai da
// propria coordenada local, sem precisar de uniforme por objeto — o que permite
// UM material para o mundo inteiro em vez de um por modelo.
uniform float base_do_modelo = -0.5;
uniform float altura_do_modelo = 1.0;

uniform float forca = 0.055;
uniform float velocidade = 1.25;
// Tamanho da rajada, em metros. Grande de proposito: o que faz parecer vento e
// a mata inteira pender junta e voltar, nao cada arvore no seu tempo.
uniform float tamanho_da_rajada = 26.0;

void vertex() {
    vec3 no_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Quanto o ponto sobe no objeto, de 0 na raiz a 1 na ponta. Ao quadrado
    // porque galho alto balanca muito mais que tronco: linear faz a arvore
    // inteira deslizar de lado, como se estivesse mal colada no chao.
    float altura = clamp((VERTEX.y - base_do_modelo) / altura_do_modelo, 0.0, 1.0);
    float peso = altura * altura;

    // Duas ondas de periodos diferentes. Uma so daria balanco de metronomo, com
    // toda a mata voltando ao mesmo tempo — o que le como maquina, nao como ar.
    float fase = (no_mundo.x + no_mundo.z) / tamanho_da_rajada;
    float rajada = sin(TIME * velocidade + fase)
                 + 0.45 * sin(TIME * velocidade * 2.7 + fase * 1.9);

    VERTEX.x += rajada * forca * peso;
    VERTEX.z += rajada * forca * peso * 0.55;
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
