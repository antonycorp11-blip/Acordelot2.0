extends RefCounted

## A CARTA DE UMA REGIAO, DESENHADA DO QUE FOI CONSTRUIDO
##
## O minimapa era um disco preto com quatro pontos azuis: dizia em que zona o
## jogador estava, nunca o que havia nela. Uma carta so vale se o desenho bate
## com o que se ve pela janela, entao aqui nada e inventado — o relevo vem da
## mesma conta que levantou o terreno, a agua do nivel declarado pela zona, as
## ruas dos mesmos numeros que o shader do chao usa para pintar, e as casas e
## arvores das pecas que estao plantadas na regiao, uma a uma, pelo nome.
##
## Custa uma imagem de 320 por 320 por zona, feita uma vez quando o jogador
## entra e guardada. Sao 102 mil amostras de altura, na casa das dezenas de
## milissegundos, e acontece enquanto a zona ainda esta se montando.

# O disco ocupa 162 px na tela e mostra uma JANELA de 52 m dos 160 da zona: so
# um terco da carta aparece de cada vez, ja ampliado. A 144 a janela visivel tem
# 47 texels para 162 px — ampliacao de 3,5x contra 2,6x —, diferenca que nao se
# le num radar, e a imagem passa a custar 1,8 vez menos.
#
# ISTO E DESEMPENHO, NAO CAPRICHO. Espalhar a geracao pelos quadros tirou a
# travada mas nao o custo: com o jogo a 16 quadros por segundo e 5 ms de
# orcamento, a carta a 192 levava MAIS DE TREZE SEGUNDOS para aparecer, e o
# jogador entrava na zona com o radar preto. Barato importa tanto quanto
# incremental.
const PIXELS := 144

## Nomes que o construtor da as pecas (`suporte.name = tag`). E por eles que a
## carta sabe o que e casa e o que e mato, sem adivinhar por tamanho.
const COPAS := ["tree_gn", "pine_tree", "mushroom_tree", "pinheiro_real",
	"arvore_de_rua", "folhagem", "arvore_borda"]
const PAREDES := ["casa", "casa_enxaimel_1", "casa_enxaimel_2", "casa_alta",
	"casa_larga", "casa_pedra", "casarao", "solar", "casa_taipa", "casa_torre",
	"taverna", "mansao_medieval", "sobrado", "celeiro", "moinho",
	"oficina_ferreiro", "loja_toldo", "torre", "muralha", "muro", "ponte"]
const MARCOS := ["fonte", "poco", "estatua", "cristal", "banca", "estandarte"]

const COR_COPA := Color(0.08, 0.24, 0.12)
const COR_PAREDE := Color(0.66, 0.43, 0.24)
const COR_MARCO := Color(0.85, 0.72, 0.35)
const COR_AGUA := Color(0.07, 0.30, 0.49)

## Chao de cada bioma, para a carta nao sair toda da mesma cor.
const CHAO_DO_BIOMA := {
	"floresta": Color(0.24, 0.36, 0.20),
	"campos": Color(0.43, 0.43, 0.21),
	"cidade": Color(0.34, 0.38, 0.29),
	"lago": Color(0.28, 0.38, 0.30),
	"serra": Color(0.38, 0.36, 0.31),
	"sagrado": Color(0.34, 0.38, 0.36),
	"ruina": Color(0.34, 0.31, 0.26),
	"sombria": Color(0.16, 0.19, 0.20),
}


## UMA VARREDURA SO, e cedendo o quadro.
##
## Media 1,9 s por zona — mais que tudo o que monta a regiao somado — e travava
## a tela inteira a cada travessia de divisa. Eram QUATRO passagens completas
## sobre a mesma imagem de 192 por 192: relevo, composicao natural, rede
## regional e vias urbanas, cada uma relendo 36 mil pixels do zero, e as duas
## ultimas ainda percorrendo a lista de segmentos por pixel.
##
## Agora e uma passagem: cada pixel decide de uma vez o que e. Os segmentos de
## rio e estrada sao achatados numa lista antes do laco, em vez de reabertos a
## cada ponto. E a cada faixa de linhas a funcao devolve o quadro — a carta
## demora alguns quadros a mais para ficar pronta e o jogo nao para.
## A ALTURA VEM DE UMA GRADE MAIS GROSSA, interpolada.
##
## `calcular_altura` e a conta cara — ruido, rio, estrada e nivelamento de vila
## empilhados — e a carta pedia uma por pixel: 36.864 por zona. O relevo e
## suave, entao amostrar de dois em dois pixels e interpolar entre os quatro
## vizinhos da o mesmo desenho com um quarto das contas. O sombreamento lateral
## continua funcionando porque a diferenca entre pixels vizinhos continua
## variando — so ficou mais macia, que num disco de 162 px ninguem distingue.
const PASSO_DA_ALTURA := 4

## Orcamento por quadro, em microssegundos. Faixa de linhas nao serve: a mesma
## faixa custa uma coisa num aparelho e outra noutro, e foi assim que dezesseis
## faixas de cem milissegundos passaram por "incremental".
const ORCAMENTO_US := 5000

static func desenhar(mundo: Node, zid: String, dados: Dictionary, regiao: Node,
		arvore: SceneTree = null) -> ImageTexture:
	var lado: float = float(mundo.TAMANHO_ZONA)
	var metros_por_pixel: float = lado / float(PIXELS)
	var meia: float = lado * 0.5
	var deslocamento: Vector3 = mundo.deslocamento_da_celula(
		mundo._celulas.get(zid, Vector2i.ZERO))

	# A grade de alturas, medida uma vez.
	var lado_grade: int = PIXELS / PASSO_DA_ALTURA + 2
	var alturas := PackedFloat32Array()
	alturas.resize(lado_grade * lado_grade)
	for gj in lado_grade:
		var zz: float = -meia + float(gj * PASSO_DA_ALTURA) * metros_por_pixel
		for gi in lado_grade:
			var xx: float = -meia + float(gi * PASSO_DA_ALTURA) * metros_por_pixel
			alturas[gj * lado_grade + gi] = mundo.calcular_altura(
				deslocamento.x + xx, deslocamento.z + zz)
		if arvore != null and gj % 8 == 0 and gj > 0:
			await arvore.process_frame

	# BYTES, NAO set_pixel. Vinte mil chamadas de `set_pixel`, cada uma criando e
	# desempacotando um Color, custam mais que a conta que decide a cor. Aqui a
	# imagem e montada num vetor de bytes e criada de uma vez no fim.
	var pixels := PackedByteArray()
	pixels.resize(PIXELS * PIXELS * 4)
	var base: Color = CHAO_DO_BIOMA.get(String(dados.get("biome", "")), Color(0.26, 0.34, 0.22))
	var tem_agua: bool = bool(dados.get("water", false))
	var nivel_da_agua: float = float(dados.get("water_level", -2.0))

	# Tudo o que o laco precisa, preparado UMA vez.
	var macicos: Array = dados.get("forest_clusters", [])
	var clareiras: Array = dados.get("clearings", [])
	var largura_rio: float = float(dados.get("river_width", 5.0))
	var pedra: bool = str(dados.get("road_surface", "terra")) == "pedra"
	var cor_estrada := Color(0.52, 0.50, 0.46) if pedra else Color(0.50, 0.35, 0.20)
	var borda_estrada := Color(0.20, 0.20, 0.18) if pedra else Color(0.27, 0.20, 0.13)
	var trechos_rio := _achatar(dados.get("river_paths", []), largura_rio + 1.1)
	var trechos_estrada := _achatar(dados.get("road_paths", []), 5.8)
	var limite_rio_q: float = (largura_rio + 1.1) * (largura_rio + 1.1)
	var vias := _vias_da_praca(mundo, dados)

	var relogio := Time.get_ticks_usec()
	for py in PIXELS:
		if arvore != null and Time.get_ticks_usec() - relogio > ORCAMENTO_US:
			await arvore.process_frame
			relogio = Time.get_ticks_usec()
		var z: float = -meia + (float(py) + 0.5) * metros_por_pixel
		var fz: float = (float(py) + 0.5) / float(PASSO_DA_ALTURA)
		var gj: int = int(fz)
		var tz: float = fz - float(gj)
		var altura_anterior: float = _altura_na_grade(alturas, lado_grade, -0.5 / float(PASSO_DA_ALTURA), gj, tz)
		for px in PIXELS:
			var x: float = -meia + (float(px) + 0.5) * metros_por_pixel
			var altura: float = _altura_na_grade(alturas, lado_grade,
				(float(px) + 0.5) / float(PASSO_DA_ALTURA), gj, tz)
			var p := Vector2(x, z)

			var destino := (py * PIXELS + px) * 4
			if tem_agua and altura < nivel_da_agua:
				var fundura: float = clampf((nivel_da_agua - altura) * 0.28, 0.0, 0.45)
				_gravar(pixels, destino, COR_AGUA.darkened(fundura))
				altura_anterior = altura
				continue

			# Relevo por sombreamento lateral: a diferenca para o pixel da
			# esquerda ja e a inclinacao do terreno naquele ponto, de graca.
			var inclinacao: float = clampf((altura - altura_anterior) * 1.6, -0.35, 0.35)
			altura_anterior = altura
			var cor: Color = base.lightened(maxf(inclinacao, 0.0)) \
				.darkened(maxf(-inclinacao, 0.0) + 0.06)

			# Macico e clareira: a mesma composicao que planta as arvores.
			for macico in macicos:
				if p.distance_squared_to(Vector2(float(macico[0]), float(macico[1]))) \
						< float(macico[2]) * float(macico[2]):
					cor = cor.darkened(0.15)
					break
			for clareira in clareiras:
				if p.distance_squared_to(Vector2(float(clareira[0]), float(clareira[1]))) \
						< float(clareira[2]) * float(clareira[2]):
					cor = Color(0.36, 0.43, 0.22)
					break

			# Rio e estrada da regiao, do mesmo plano usado no mundo 3D.
			# AO QUADRADO E COM CAIXA. A raiz quadrada e a comparacao de cada
			# segmento eram feitas para TODO pixel — ate vinte e oito por ponto
			# nesta zona. A caixa do trecho rejeita quase todos com quatro
			# comparacoes, e o que sobra compara distancia ao quadrado.
			var pintou := false
			for t in trechos_rio:
				if p.x < t[2] or p.x > t[4] or p.y < t[3] or p.y > t[5]:
					continue
				var d2r: float = _distancia_segmento_quadrada(p, t[0], t[1])
				if d2r <= limite_rio_q:
					cor = COR_AGUA.darkened((1.0 - clampf(sqrt(d2r) / maxf(largura_rio, 0.1), 0.0, 1.0)) * 0.20)
					pintou = true
					break
			if not pintou:
				for t in trechos_estrada:
					if p.x < t[2] or p.x > t[4] or p.y < t[3] or p.y > t[5]:
						continue
					var d2e: float = _distancia_segmento_quadrada(p, t[0], t[1])
					if d2e <= 33.64:
						cor = cor_estrada if d2e <= 22.09 else borda_estrada
						pintou = true
						break
			if not pintou and not vias.is_empty() and _sobre_a_via(p, vias):
				cor = vias["cor"]

			_gravar(pixels, destino, cor)

	var imagem := Image.create_from_data(PIXELS, PIXELS, false, Image.FORMAT_RGBA8, pixels)
	if regiao != null and is_instance_valid(regiao):
		await _carimbar_as_pecas(imagem, regiao, metros_por_pixel, meia, arvore)

	return ImageTexture.create_from_image(imagem)


## Bilinear na grade grossa. `fx` ja vem em coordenada de grade.
static func _altura_na_grade(alturas: PackedFloat32Array, lado: int,
		fx: float, gj: int, tz: float) -> float:
	var gi: int = clampi(int(floor(fx)), 0, lado - 2)
	var tx: float = clampf(fx - float(gi), 0.0, 1.0)
	var j: int = clampi(gj, 0, lado - 2)
	var a: float = alturas[j * lado + gi]
	var b: float = alturas[j * lado + gi + 1]
	var c: float = alturas[(j + 1) * lado + gi]
	var d: float = alturas[(j + 1) * lado + gi + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func _distancia_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Os segmentos de todas as polilinhas numa lista so, para o laco de pixel nao
## reabrir a estrutura aninhada trinta e seis mil vezes.
static func _achatar(caminhos: Array, folga: float) -> Array:
	var trechos: Array = []
	for caminho in caminhos:
		for i in range(caminho.size() - 1):
			var a := Vector2(float(caminho[i][0]), float(caminho[i][1]))
			var b := Vector2(float(caminho[i + 1][0]), float(caminho[i + 1][1]))
			# [a, b, x minimo, z minimo, x maximo, z maximo] — a caixa ja
			# alargada pela largura da via, para a rejeicao ser uma comparacao.
			trechos.append([a, b,
				minf(a.x, b.x) - folga, minf(a.y, b.y) - folga,
				maxf(a.x, b.x) + folga, maxf(a.y, b.y) + folga])
	return trechos


static func _distancia_segmento_quadrada(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)


static func _gravar(pixels: PackedByteArray, onde: int, cor: Color) -> void:
	pixels[onde] = int(clampf(cor.r, 0.0, 1.0) * 255.0)
	pixels[onde + 1] = int(clampf(cor.g, 0.0, 1.0) * 255.0)
	pixels[onde + 2] = int(clampf(cor.b, 0.0, 1.0) * 255.0)
	pixels[onde + 3] = 255


## As medidas da malha urbana, prontas para a conta por pixel.
static func _vias_da_praca(mundo: Node, dados: Dictionary) -> Dictionary:
	var pracas: Dictionary = mundo._city_layouts.get("pracas", {})
	var praca: Dictionary = pracas.get(String(dados.get("layout_id", "")), {})
	var vias: Dictionary = praca.get("vias", {})
	if vias.is_empty():
		return {}
	var principal: Array = vias.get("principal", [0.0, 0.0])
	if principal.size() < 2 or float(principal[0]) < 0.01:
		return {}
	return {
		"meia": float(principal[0]), "alcance": float(principal[1]),
		"largo": float(vias.get("largo", 0.0)),
		"travessas": vias.get("travessas", [0.0, 0.0, 0.0]),
		"secundarias": vias.get("secundarias", [999.0, 999.0, 0.0, 0.0]),
		"cor": Color(0.55, 0.55, 0.58) if bool(vias.get("pedra", false)) \
			else Color(0.52, 0.44, 0.33),
	}


static func _sobre_a_via(p: Vector2, v: Dictionary) -> bool:
	if absf(p.x) < float(v["meia"]) and absf(p.y) < float(v["alcance"]):
		return true
	var largo: float = float(v["largo"])
	if largo > 0.01 and p.length() < largo:
		return true
	var travessas: Array = v["travessas"]
	if travessas.size() >= 3:
		var meia_t: float = float(v["alcance"]) if travessas.size() < 2 else float(travessas[1])
		if absf(p.y - float(travessas[0])) < meia_t and absf(p.x) < float(travessas[2]):
			return true
	var secundarias: Array = v["secundarias"]
	if secundarias.size() >= 4 and float(secundarias[0]) < 900.0:
		for onde in [float(secundarias[0]), float(secundarias[1])]:
			if absf(p.y - onde) < float(secundarias[2]) and absf(p.x) < float(secundarias[3]):
				return true
	return false


## Uma marca por peca plantada. O tamanho da marca sai da CAIXA do modelo, para
## o solar ocupar mais quarteirao que o barril — e o que faz a carta parecer a
## vila e nao uma constelacao de pontos iguais.
static func _carimbar_as_pecas(imagem: Image, regiao: Node3D,
		metros_por_pixel: float, meia: float, arvore: SceneTree = null) -> void:
	# Cada edificio ainda pede a propria caixa, e medir a caixa e outra varredura
	# de nos. Numa regiao de cento e setenta pecas isso sozinho estourava o
	# quadro depois que o resto da carta ja respirava.
	var relogio := Time.get_ticks_usec()
	for peca in regiao.find_children("*", "Node3D", true, false):
		if arvore != null and Time.get_ticks_usec() - relogio > ORCAMENTO_US:
			await arvore.process_frame
			relogio = Time.get_ticks_usec()
		# Pelo metadado, nao pelo nome: irmao homonimo perde o nome para um
		# "@Node3D@2199" gerado pelo motor, e era assim que a segunda casa de
		# cada tipo desaparecia da carta.
		var nome := String(peca.get_meta("tag", peca.name))
		var cor: Color
		var largura := 2.0
		var edificio := false
		if COPAS.has(nome):
			cor = COR_COPA
			largura = 2.6
		elif PAREDES.has(nome):
			cor = COR_PAREDE
			edificio = true
		elif MARCOS.has(nome):
			cor = COR_MARCO
			largura = 2.0
		else:
			continue

		var onde: Vector3 = peca.global_position - regiao.global_position
		var px := int((onde.x + meia) / metros_por_pixel)
		var py := int((onde.z + meia) / metros_por_pixel)
		if edificio:
			var ocupacao := _ocupacao_da_peca(peca)
			var metade_x := maxi(int(ocupacao.x / metros_por_pixel * 0.5), 2)
			var metade_y := maxi(int(ocupacao.y / metros_por_pixel * 0.5), 2)
			for dy in range(-metade_y, metade_y + 1):
				for dx in range(-metade_x, metade_x + 1):
					var ax := px + dx
					var ay := py + dy
					if ax < 0 or ay < 0 or ax >= PIXELS or ay >= PIXELS:
						continue
					var borda: bool = abs(dx) == metade_x or abs(dy) == metade_y
					imagem.set_pixel(ax, ay, cor.darkened(0.45) if borda else cor)
			continue
		var raio := int(maxf(largura / metros_por_pixel, 1.0))
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				var ax := px + dx
				var ay := py + dy
				if ax < 0 or ay < 0 or ax >= PIXELS or ay >= PIXELS:
					continue
				if dx * dx + dy * dy > raio * raio:
					continue
				imagem.set_pixel(ax, ay, cor)


static func _ocupacao_da_peca(peca: Node3D) -> Vector2:
	var caixa := AABB()
	var encontrou := false
	var para_local := peca.global_transform.affine_inverse()
	for filho in peca.find_children("*", "MeshInstance3D", true, false):
		var malha := filho as MeshInstance3D
		if malha.mesh == null:
			continue
		var local: AABB = (para_local * malha.global_transform) * malha.get_aabb()
		caixa = local if not encontrou else caixa.merge(local)
		encontrou = true
	if not encontrou:
		return Vector2(4.0, 4.0)
	var giro := peca.global_rotation.y
	var c := absf(cos(giro))
	var s := absf(sin(giro))
	return Vector2(maxf(caixa.size.x * c + caixa.size.z * s, 2.0),
		maxf(caixa.size.x * s + caixa.size.z * c, 2.0))
