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

# O disco ocupa 162 px na tela. 192 preserva todos os detalhes visiveis e
# reduz de 204 mil para cerca de 74 mil as amostras feitas ao entrar na zona.
const PIXELS := 192

## Nomes que o construtor da as pecas (`suporte.name = tag`). E por eles que a
## carta sabe o que e casa e o que e mato, sem adivinhar por tamanho.
const COPAS := ["tree_gn", "pine_tree", "mushroom_tree", "pinheiro_real",
	"arvore_de_rua", "folhagem", "arvore_borda"]
const PAREDES := ["casa", "casa_enxaimel_1", "casa_enxaimel_2", "casa_alta",
	"casa_larga", "casa_pedra", "casarao", "solar", "casa_taipa", "casa_torre",
	"taverna", "mansao_medieval", "sobrado", "celeiro", "moinho",
	"oficina_ferreiro", "loja_toldo", "torre", "muralha", "muro", "ponte"]
const MARCOS := ["fonte", "poco", "estatua", "cristal", "banca", "estandarte"]

const COR_COPA := Color(0.13, 0.30, 0.16)
const COR_PAREDE := Color(0.62, 0.50, 0.38)
const COR_MARCO := Color(0.85, 0.72, 0.35)
const COR_AGUA := Color(0.16, 0.34, 0.52)

## Chao de cada bioma, para a carta nao sair toda da mesma cor.
const CHAO_DO_BIOMA := {
	"floresta": Color(0.24, 0.36, 0.20),
	"cidade": Color(0.42, 0.41, 0.34),
	"lago": Color(0.28, 0.38, 0.30),
	"serra": Color(0.38, 0.36, 0.31),
	"sagrado": Color(0.34, 0.38, 0.36),
	"ruina": Color(0.34, 0.31, 0.26),
	"sombria": Color(0.16, 0.19, 0.20),
}


static func desenhar(mundo: Node, zid: String, dados: Dictionary, regiao: Node) -> ImageTexture:
	var lado: float = float(mundo.TAMANHO_ZONA)
	var metros_por_pixel: float = lado / float(PIXELS)
	var meia: float = lado * 0.5
	var deslocamento: Vector3 = mundo.deslocamento_da_celula(
		mundo._celulas.get(zid, Vector2i.ZERO))

	var imagem := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	var base: Color = CHAO_DO_BIOMA.get(String(dados.get("biome", "")), Color(0.26, 0.34, 0.22))
	var tem_agua: bool = bool(dados.get("water", false))
	var nivel_da_agua: float = float(dados.get("water_level", -2.0))

	for py in PIXELS:
		var z: float = -meia + (float(py) + 0.5) * metros_por_pixel
		var altura_anterior: float = mundo.calcular_altura(deslocamento.x - meia, deslocamento.z + z)
		for px in PIXELS:
			var x: float = -meia + (float(px) + 0.5) * metros_por_pixel
			var altura: float = mundo.calcular_altura(deslocamento.x + x, deslocamento.z + z)

			if tem_agua and altura < nivel_da_agua:
				var fundura: float = clampf((nivel_da_agua - altura) * 0.28, 0.0, 0.45)
				imagem.set_pixel(px, py, COR_AGUA.darkened(fundura))
				altura_anterior = altura
				continue

			# Relevo por sombreamento lateral: a diferenca para o pixel da
			# esquerda ja e a inclinacao do terreno naquele ponto, de graca.
			# Sem isto a carta e uma mancha chapada e o jogador nao le morro.
			var inclinacao: float = clampf((altura - altura_anterior) * 1.6, -0.35, 0.35)
			imagem.set_pixel(px, py, base.lightened(maxf(inclinacao, 0.0))
				.darkened(maxf(-inclinacao, 0.0) + 0.06))
			altura_anterior = altura

	_riscar_as_vias(imagem, mundo, dados, metros_por_pixel, meia)
	if regiao != null and is_instance_valid(regiao):
		_carimbar_as_pecas(imagem, regiao, metros_por_pixel, meia)

	return ImageTexture.create_from_image(imagem)


## As mesmas medidas que o shader do chao recebe, em coordenadas da zona.
static func _riscar_as_vias(imagem: Image, mundo: Node, dados: Dictionary,
		metros_por_pixel: float, meia: float) -> void:
	var pracas: Dictionary = mundo._city_layouts.get("pracas", {})
	var praca: Dictionary = pracas.get(String(dados.get("layout_id", "")), {})
	var vias: Dictionary = praca.get("vias", {})
	if vias.is_empty():
		return

	var principal: Array = vias.get("principal", [0.0, 0.0])
	var travessas: Array = vias.get("travessas", [0.0, 0.0, 0.0])
	var secundarias: Array = vias.get("secundarias", [999.0, 999.0, 0.0, 0.0])
	var meia_rua: float = float(principal[0])
	var alcance_z: float = float(principal[1])
	var raio_do_largo: float = float(vias.get("largo", 0.0))
	var cor: Color = Color(0.55, 0.55, 0.58) if bool(vias.get("pedra", false)) \
		else Color(0.52, 0.44, 0.33)
	if meia_rua < 0.01:
		return

	for py in PIXELS:
		var z: float = -meia + (float(py) + 0.5) * metros_por_pixel
		for px in PIXELS:
			var x: float = -meia + (float(px) + 0.5) * metros_por_pixel
			var na_via := absf(x) < meia_rua and absf(z) < alcance_z
			if not na_via and raio_do_largo > 0.01:
				na_via = Vector2(x, z).length() < raio_do_largo
			if not na_via:
				var meia_t: float = float(principal[1]) if travessas.size() < 2 else float(travessas[1])
				if absf(z - float(travessas[0])) < meia_t and absf(x) < float(travessas[2]):
					na_via = true
			if not na_via and secundarias.size() >= 4 and float(secundarias[0]) < 900.0:
				for onde in [float(secundarias[0]), float(secundarias[1])]:
					if absf(z - onde) < float(secundarias[2]) and absf(x) < float(secundarias[3]):
						na_via = true
						break
			if na_via:
				imagem.set_pixel(px, py, cor)


## Uma marca por peca plantada. O tamanho da marca sai da CAIXA do modelo, para
## o solar ocupar mais quarteirao que o barril — e o que faz a carta parecer a
## vila e nao uma constelacao de pontos iguais.
static func _carimbar_as_pecas(imagem: Image, regiao: Node3D,
		metros_por_pixel: float, meia: float) -> void:
	for peca in regiao.find_children("*", "Node3D", true, false):
		var nome := String(peca.name)
		var cor: Color
		var largura := 2.0
		if COPAS.has(nome):
			cor = COR_COPA
			largura = 2.6
		elif PAREDES.has(nome):
			cor = COR_PAREDE
			largura = 4.2
		elif MARCOS.has(nome):
			cor = COR_MARCO
			largura = 2.0
		else:
			continue

		var onde: Vector3 = peca.global_position - regiao.global_position
		var px := int((onde.x + meia) / metros_por_pixel)
		var py := int((onde.z + meia) / metros_por_pixel)
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
