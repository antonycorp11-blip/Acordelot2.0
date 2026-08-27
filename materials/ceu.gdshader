shader_type sky;

// CEU DE VERDADE, SEM TEXTURA NENHUMA
//
// O ceu era um degrade de duas cores: correto de cor e vazio de conteudo, sem
// nuvem, sem estrela, sem sol desenhado. Aqui tudo e calculado — nao entra um
// byte no pacote, que e justamente o recurso que falta neste projeto.
//
// O custo mora no numero de OITAVAS do ruido. Duas bastam para nuvem de longe
// num celular; a terceira so aparece se o jogador colar o nariz na tela e
// custa o dobro. As cores continuam vindo do ciclo dia/noite, que ja sabia
// pintar topo e horizonte.

uniform vec4 cor_topo : source_color = vec4(0.35, 0.55, 0.85, 1.0);
uniform vec4 cor_horizonte : source_color = vec4(0.75, 0.86, 0.94, 1.0);
uniform vec4 cor_nuvem : source_color = vec4(1.0, 0.99, 0.96, 1.0);
// 0 de dia, 1 de madrugada. Acende as estrelas e apaga o brilho das nuvens.
uniform float noite : hint_range(0.0, 1.0) = 0.0;
// O jogador pode zerar isto no ajuste "Desempenho": ceu liso, custo zero.
uniform float forca_das_nuvens : hint_range(0.0, 1.0) = 0.62;
uniform float velocidade_do_vento = 0.006;

float embaralhar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 celula = floor(p);
	vec2 dentro = fract(p);
	// Suavizacao cubica: sem ela a nuvem sai com quinas de grade.
	dentro = dentro * dentro * (3.0 - 2.0 * dentro);
	float a = embaralhar(celula);
	float b = embaralhar(celula + vec2(1.0, 0.0));
	float c = embaralhar(celula + vec2(0.0, 1.0));
	float d = embaralhar(celula + vec2(1.0, 1.0));
	return mix(mix(a, b, dentro.x), mix(c, d, dentro.x), dentro.y);
}

void sky() {
	vec3 direcao = EYEDIR;
	float altura = clamp(direcao.y, -1.0, 1.0);

	// Degrade base. A potencia concentra a transicao perto do horizonte, que e
	// onde o olho espera ver o ceu clarear.
	float subida = pow(clamp(altura, 0.0, 1.0), 0.45);
	vec3 cor = mix(cor_horizonte.rgb, cor_topo.rgb, subida);

	// ESTRELAS: so acima do horizonte e so quando escurece. Sao pontos numa
	// grade fina, com brilho sorteado, e a maioria dos sorteios nao acende —
	// ceu cheio de estrela do mesmo tamanho parece papel de parede.
	if (noite > 0.01 && altura > 0.02) {
		vec2 grade = direcao.xz / max(altura + 0.35, 0.1) * 46.0;
		float sorte = embaralhar(floor(grade));
		float estrela = smoothstep(0.9915, 1.0, sorte);
		float cintilar = 0.65 + 0.35 * sin(TIME * 2.1 + sorte * 90.0);
		cor += vec3(estrela * cintilar * noite * clamp(altura * 2.2, 0.0, 1.0));
	}

	// NUVENS: o ceu e tratado como um plano la em cima, entao a mesma nuvem
	// estica perto do horizonte e encolhe no alto — que e como nuvem se ve de
	// baixo. Dividir por direcao.y faz isso sozinho.
	if (forca_das_nuvens > 0.01 && altura > 0.0) {
		vec2 plano = direcao.xz / max(altura, 0.12);
		vec2 vento = vec2(TIME * velocidade_do_vento, TIME * velocidade_do_vento * 0.4);
		float massa = ruido(plano * 0.55 + vento) * 0.62;
		massa += ruido(plano * 1.35 + vento * 1.9) * 0.30;

		// Corte alto: sobra ceu aberto entre as nuvens em vez de um mingau
		// cinzento cobrindo tudo.
		float nuvem = smoothstep(0.60, 0.78, massa);
		// A camera nao olha para o alto: as nuvens precisam nascer ja perto do
		// horizonte, que e justamente a faixa de ceu realmente visivel.
		nuvem *= smoothstep(-0.01, 0.08, altura) * forca_das_nuvens;

		vec3 tom = mix(cor_nuvem.rgb, cor_nuvem.rgb * 0.35, noite);
		cor = mix(cor, tom, nuvem * 0.70);
	}

	// SOL (ou lua): o ciclo ja gira a luz direcional; aqui so se desenha o
	// disco dela com um halo curto em volta.
	if (LIGHT0_ENABLED) {
		float perto = dot(direcao, LIGHT0_DIRECTION);
		float sol = smoothstep(0.9975, 0.9992, perto);
		float lua = smoothstep(0.9915, 0.9970, perto);
		float disco = mix(sol, lua, noite);
		float halo = pow(clamp(perto, 0.0, 1.0), mix(220.0, 95.0, noite)) * 0.65;
		vec3 cor_astro = mix(LIGHT0_COLOR, vec3(0.72, 0.82, 1.0), noite);
		cor += cor_astro * (disco + halo) * max(LIGHT0_ENERGY, 0.65);
	}

	COLOR = cor;
}
