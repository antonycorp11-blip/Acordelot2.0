extends Control
## A tela de Inventario, montada SOBRE a arte do conceito.
##
## A regra que decide tudo aqui: quem desenha e a textura, quem organiza e o
## Control. Moldura, slot, botao e ficha de recurso sao PNG recortado da arte;
## o codigo so os estica pelos cantos certos e poe texto e numero por cima.
## Tentar refazer a filigrana dourada com StyleBoxFlat daria um retangulo com
## borda — e a diferenca entre "a interface do conceito rodando" e "uma
## interpretacao do programador", que e exatamente o que nao se quer.
##
## As margens de NinePatch nao sao chute: foram medidas na imagem, procurando
## onde o ornamento acaba e o azul do miolo comeca. Errar nelas estica a
## cantoneira, e cantoneira esticada e a marca de interface remendada.

signal item_used(item_id: String)
signal item_equipped(item_id: String, slot: String)

const KIT := "res://textures/ui/kit/"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"

## As bordas de cada arte, em pixels, medidas no arquivo.
##
## AS MARGENS PRECISAM CABER NO TAMANHO DESENHADO, e era ai que estava o
## estrago: a arte do botao tem 183 pixels de altura com 139 de moldura fixa, e
## o botao aparece na tela com 52. Nao havendo miolo para esticar, o nine-patch
## empilha as bordas umas sobre as outras — foi o que virou aquele borrao
## dourado na tela do celular, e as "correntes" penduradas nos slots.
##
## A arte foi reduzida para o tamanho em que ela realmente aparece (botao a 30%,
## slot a 30%, moldura a 60%) e estas margens acompanharam na mesma proporcao.
const BORDA_PAINEL := [22, 68, 22, 64]   # esquerda, cima, direita, baixo
const BORDA_CARTAO := [3, 23, 6, 19]
const BORDA_SLOT := [11, 29, 12, 26]
const BORDA_BOTAO := [36, 28, 36, 14]

## O conceito e desenhado em 16:9. Fora dessa proporcao a tela ganha margem —
## nunca estica a arte, porque moldura esticada denuncia na hora.
const PROPORCAO := 16.0 / 9.0
const COLUNAS := 6

var gold_amount: int = 78542
var gemas: int = 1250

var equipped_slots := {
    "Arma": {"id": "espada_akles", "name": "Lâmina Harmônica", "arte": "equip/espada", "tier": "Nível do Item: 18", "rarity": "Épico", "stats": "+78 Força  •  +52 Vitalidade", "desc": "Lâmina ancestral imbuída com o poder dos mestres da música."},
    "Cabeça": {"id": "chapeu_bardo", "name": "Chapéu do Trovador", "arte": "equip/chapeu", "tier": "Nível do Item: 16", "rarity": "Raro", "stats": "+24 Inteligência  •  +12 Fé", "desc": "A pluma foi presente de um corvo que gostava de música."},
    "Amuleto": {"id": "amuleto_safira", "name": "Amuleto de Safira", "arte": "equip/amuleto", "tier": "Nível do Item: 17", "rarity": "Épico", "stats": "+60 Mana  •  +10% Regeneração", "desc": "Gema sintonizada com os fluxos de mana."},
    "Acessório": {"id": "anel_arcano", "name": "Anel da Floresta", "arte": "equip/anel", "tier": "Nível do Item: 15", "rarity": "Raro", "stats": "+38 Ressonância", "desc": "Safira lapidada pelos ourives da Capital."},
    "Peitoral": {"id": "peitoral_guardiao", "name": "Armadura do Guardião", "arte": "equip/peitoral", "tier": "Nível do Item: 18", "rarity": "Épico", "stats": "+85 Defesa  •  +350 Vida", "desc": "Placas reforçadas com encantamento de proteção."},
    "Luvas": {"id": "luvas_aco", "name": "Manoplas de Aço", "arte": "equip/luvas", "tier": "Nível do Item: 16", "rarity": "Raro", "stats": "+28 Defesa  •  +9 Destreza", "desc": "Articulações finas o bastante para dedilhar."},
    "Calças": {"id": "calcas_couro", "name": "Calças de Viajante", "arte": "equip/calcas", "tier": "Nível do Item: 14", "rarity": "Incomum", "stats": "+31 Defesa", "desc": "Couro curtido, remendado mais de uma vez."},
    "Botas": {"id": "botas_couro", "name": "Botas de Andarilho", "arte": "equip/botas", "tier": "Nível do Item: 15", "rarity": "Raro", "stats": "+22 Defesa  •  +14% Velocidade", "desc": "Couro resistente para terrenos acidentados."},
}

var bag_items: Array = [
    {"id": "pocao_cura_g", "name": "Poção de Vitalidade", "arte": "item/pocao_vida", "qtd": 24, "tier": "Épico", "rarity": "Épico", "tipo": "consumivel", "desc": "Restaura 60% da Vida máxima. Uma mistura vibrante que ressoa com a essência da vida."},
    {"id": "pocao_mana_g", "name": "Poção de Mana", "arte": "item/pocao_mana", "qtd": 15, "tier": "Raro", "rarity": "Raro", "tipo": "consumivel", "desc": "Restaura 300 pontos de mana arcana."},
    {"id": "pocao_roxa", "name": "Elixir de Harmonia", "arte": "item/pocao_roxa", "qtd": 12, "tier": "Épico", "rarity": "Épico", "tipo": "consumivel", "desc": "Aumenta a ressonância por dois minutos."},
    {"id": "pocao_dourada", "name": "Néctar do Bardo", "arte": "item/pocao_dourada", "qtd": 8, "tier": "Lendário", "rarity": "Lendário", "tipo": "consumivel", "desc": "Dizem que foi engarrafado durante um eclipse."},
    {"id": "cristal_azul", "name": "Cristal de Mana", "arte": "item/cristal_azul", "qtd": 32, "tier": "Raro", "rarity": "Raro", "tipo": "material", "desc": "Gema pulsante usada em encantamentos."},
    {"id": "gema_roxa", "name": "Ametista Ressonante", "arte": "item/gema_roxa", "qtd": 18, "tier": "Épico", "rarity": "Épico", "tipo": "material", "desc": "Vibra sozinha quando há música por perto."},
    {"id": "gema_verde", "name": "Esmeralda Bruta", "arte": "item/gema_verde", "qtd": 9, "tier": "Raro", "rarity": "Raro", "tipo": "material", "desc": "Verde profundo, ainda por lapidar."},
    {"id": "gema_ambar", "name": "Âmbar Antigo", "arte": "item/gema_ambar", "qtd": 6, "tier": "Incomum", "rarity": "Incomum", "tipo": "material", "desc": "Guarda dentro de si uma nota presa há mil anos."},
    {"id": "partitura", "name": "Partitura Rara", "arte": "item/partitura", "qtd": 42, "tier": "Raro", "rarity": "Raro", "tipo": "missao", "desc": "Um trecho de melodia que ninguém sabe terminar."},
    {"id": "moeda_antiga", "name": "Moeda da Coroa", "arte": "item/moeda", "qtd": 65, "tier": "Comum", "rarity": "Comum", "tipo": "valioso", "desc": "Cunhada no reinado anterior. Ainda vale."},
    {"id": "corneta", "name": "Corneta de Bronze", "arte": "item/corneta", "qtd": 3, "tier": "Incomum", "rarity": "Incomum", "tipo": "valioso", "desc": "Rouca, mas ouve-se do outro lado do vale."},
    {"id": "pena", "name": "Pena de Escriba", "arte": "item/pena", "qtd": 31, "tier": "Comum", "rarity": "Comum", "tipo": "material", "desc": "Para copiar partituras sem borrar."},
    {"id": "bolsa_couro", "name": "Bolsa de Couro", "arte": "item/bolsa", "qtd": 19, "tier": "Comum", "rarity": "Comum", "tipo": "material", "desc": "Vazia. Serve para carregar o resto."},
    {"id": "flor_arcana", "name": "Flor de Lua", "arte": "item/flor", "qtd": 22, "tier": "Incomum", "rarity": "Incomum", "tipo": "material", "desc": "Só abre quando alguém canta perto dela."},
    {"id": "minerio_ferro", "name": "Minério de Ferro", "arte": "item/minerio", "qtd": 13, "tier": "Comum", "rarity": "Comum", "tipo": "material", "desc": "Minério bruto para barras de aço."},
    {"id": "chave_antiga", "name": "Chave Enferrujada", "arte": "item/chave", "qtd": 3, "tier": "Raro", "rarity": "Raro", "tipo": "missao", "desc": "Abre alguma coisa. Ninguém lembra o quê."},
    {"id": "fita_vermelha", "name": "Fita Carmesim", "arte": "item/fita", "qtd": 9, "tier": "Incomum", "rarity": "Incomum", "tipo": "valioso", "desc": "Marca a página de uma partitura importante."},
    {"id": "mapa_velho", "name": "Mapa do Vale", "arte": "item/mapa", "qtd": 1, "tier": "Raro", "rarity": "Raro", "tipo": "missao", "desc": "Um X no meio da floresta, sem legenda."},
    {"id": "runa_antiga", "name": "Runa Silente", "arte": "item/runa", "qtd": 17, "tier": "Épico", "rarity": "Épico", "tipo": "material", "desc": "A pedra é fria mesmo ao sol."},
    {"id": "nota_arcana", "name": "Essência Melódica", "arte": "item/nota", "qtd": 30, "tier": "Épico", "rarity": "Épico", "tipo": "material", "desc": "Fragmento concentrado de harmonia pura."},
]

## Cada raridade tem a sua moldura, e e por isso que existem quatro molduras na
## arte. Cor de borda diz o valor do item antes de qualquer leitura de texto.
const MOLDURA_DA_RARIDADE := {
    "Comum": "slot_verde", "Incomum": "slot_verde",
    "Raro": "slot_azul", "Épico": "slot_roxo", "Lendário": "slot_dourado",
}
const COR_DA_RARIDADE := {
    "Comum": Color(0.72, 0.76, 0.80), "Incomum": Color(0.45, 0.85, 0.52),
    "Raro": Color(0.40, 0.68, 0.98), "Épico": Color(0.76, 0.48, 0.98),
    "Lendário": Color(0.98, 0.74, 0.28),
}

const FILTROS := ["Todos", "Materiais", "Consumíveis", "Missões", "Valiosos"]
const TIPO_DO_FILTRO := {
    "Materiais": "material", "Consumíveis": "consumivel",
    "Missões": "missao", "Valiosos": "valioso",
}

var _fundo: ColorRect
var _janela: Control
var _grade: GridContainer
var _selecionado: Dictionary = {}
var _filtro := "Todos"
var _botoes_de_filtro: Array = []

var _det_icone: TextureRect
var _det_moldura: NinePatchRect
var _det_nome: Label
var _det_raridade: Label
var _det_posse: Label
var _det_desc: Label
var _rotulo_bolsa: Label
var _recado: Label


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _montar()
    visible = false


# -------------------------------------------------------------
# Peças de arte
# -------------------------------------------------------------
## Uma textura do kit esticada pelos cantos.
##
## NinePatchRect e nao TextureRect: a moldura precisa mudar de tamanho conforme
## a tela, e so o nine-patch estica o MIOLO deixando cantoneira e ornamento no
## tamanho em que foram desenhados.
func _arte(nome: String, borda: Array) -> NinePatchRect:
    var np := NinePatchRect.new()
    np.texture = load(KIT + nome + ".png")
    np.patch_margin_left = borda[0]
    np.patch_margin_top = borda[1]
    np.patch_margin_right = borda[2]
    np.patch_margin_bottom = borda[3]
    np.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return np


func _texto(txt: String, corpo: int, cor: Color, titulo := false) -> Label:
    var l := Label.new()
    l.text = txt
    l.add_theme_font_override("font", load(FONTE_TITULO if titulo else FONTE_TEXTO))
    l.add_theme_font_size_override("font_size", corpo)
    l.add_theme_color_override("font_color", cor)
    # Sombra dura atras do texto: a arte por baixo tem dourado claro e azul
    # escuro na mesma regiao, e sem ela a legenda some em cima do ornamento.
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 2)
    return l


## Um botao que E a arte do botao: a textura no fundo, o texto por cima.
func _botao(rotulo: String, arte: String, largura: float, altura := 54.0) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(largura, altura)
    b.text = rotulo
    b.add_theme_font_override("font", load(FONTE_TEXTO))
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    b.add_theme_color_override("font_hover_color", Color(1, 1, 0.92))
    b.add_theme_color_override("font_pressed_color", Color(0.86, 0.82, 0.70))
    # O fundo do botao e a arte, entao os estilos do tema tem de sumir — senao
    # o cinza padrao do Godot aparece por tras da filigrana.
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())

    var fundo := _arte(arte, BORDA_BOTAO)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.show_behind_parent = true
    b.add_child(fundo)
    return b


# -------------------------------------------------------------
# A montagem da tela
# -------------------------------------------------------------
func _montar() -> void:
    # CAMADA PROPRIA, acima do jogo.
    #
    # O inventario nascia dentro do mesmo CanvasLayer da HUD e no meio da lista
    # de filhos: o nome da zona, as barras de vida e as fichas de recurso do
    # jogo desenhavam POR CIMA da tela aberta. Numa camada de numero maior a
    # tela cobre tudo, como a caixa de conversa ja fazia.
    var camada := CanvasLayer.new()
    camada.name = "CamadaInventario"
    camada.layer = 15
    add_child(camada)

    _fundo = ColorRect.new()
    # Escurece o jogo sem apagar: a vila continua atras, como na conversa.
    _fundo.color = Color(0.02, 0.02, 0.05, 0.72)
    _fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    camada.add_child(_fundo)

    var proporcao := AspectRatioContainer.new()
    proporcao.set_anchors_preset(Control.PRESET_FULL_RECT)
    proporcao.ratio = PROPORCAO
    proporcao.stretch_mode = AspectRatioContainer.STRETCH_FIT
    proporcao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fundo.add_child(proporcao)

    _janela = Control.new()
    _janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
    proporcao.add_child(_janela)

    var moldura := _arte("moldura_painel_grande", BORDA_PAINEL)
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    _janela.add_child(moldura)

    # Tudo o que e conteudo mora DENTRO da margem da moldura, senao passa por
    # cima do ouro.
    var miolo := MarginContainer.new()
    miolo.set_anchors_preset(Control.PRESET_FULL_RECT)
    miolo.add_theme_constant_override("margin_left", 46)
    miolo.add_theme_constant_override("margin_right", 46)
    miolo.add_theme_constant_override("margin_top", 26)
    miolo.add_theme_constant_override("margin_bottom", 30)
    miolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _janela.add_child(miolo)

    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 10)
    miolo.add_child(coluna)

    coluna.add_child(_cabecalho())

    var corpo := HBoxContainer.new()
    corpo.add_theme_constant_override("separation", 14)
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(corpo)

    corpo.add_child(_coluna_de_filtros())
    corpo.add_child(_area_da_grade())
    corpo.add_child(_cartao_de_detalhe())

    coluna.add_child(_barra_de_navegacao())

    _preencher_grade()


## O topo: titulo a esquerda, recursos no meio, fechar a direita.
func _cabecalho() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 62
    linha.add_theme_constant_override("separation", 16)

    var titulo := _texto("Inventário", 40, Color(0.97, 0.84, 0.47), true)
    titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    linha.add_child(titulo)

    var vao := Control.new()
    vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(vao)

    _rotulo_bolsa = _ficha(linha, "barra_ficha_bolsa", "%d / 150" % bag_items.size())
    _ficha(linha, "barra_ficha_moeda", _milhar(gold_amount))
    _ficha(linha, "barra_ficha_gema", _milhar(gemas))

    var fechar := _botao("✕", "botao_vermelho", 62.0, 54.0)
    fechar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    # Um respiro da cantoneira dourada, senao o botao briga com o ornamento.
    fechar.custom_minimum_size.x = 62.0
    fechar.pressed.connect(func(): toggle_inventory(false))
    linha.add_child(fechar)
    return linha


## Uma ficha de recurso: a arte da moldurinha com o numero ao lado.
func _ficha(pai: Control, arte: String, valor: String) -> Label:
    var caixa := HBoxContainer.new()
    caixa.add_theme_constant_override("separation", 6)
    caixa.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    var icone := TextureRect.new()
    icone.texture = load(KIT + arte + ".png")
    icone.custom_minimum_size = Vector2(46, 46)
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    caixa.add_child(icone)

    var rotulo := _texto(valor, 20, Color(0.96, 0.90, 0.72))
    rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caixa.add_child(rotulo)

    pai.add_child(caixa)
    return rotulo


func _coluna_de_filtros() -> Control:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 190
    coluna.add_theme_constant_override("separation", 10)

    for nome in FILTROS:
        var arte: String = "botao_roxo" if nome == _filtro else "botao_azul"
        var b := _botao(nome, arte, 180.0, 54.0)
        b.set_meta("filtro", nome)
        b.pressed.connect(_trocar_filtro.bind(nome))
        coluna.add_child(b)
        _botoes_de_filtro.append(b)

    var vao := Control.new()
    vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(vao)
    return coluna


func _area_da_grade() -> Control:
    var area := Control.new()
    area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    area.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var fundo := _arte("moldura_painel_simples", BORDA_CARTAO)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    area.add_child(fundo)

    var rolagem := ScrollContainer.new()
    rolagem.set_anchors_preset(Control.PRESET_FULL_RECT)
    rolagem.offset_left = 18
    rolagem.offset_top = 22
    rolagem.offset_right = -18
    rolagem.offset_bottom = -18
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    area.add_child(rolagem)

    _grade = GridContainer.new()
    _grade.columns = COLUNAS
    _grade.add_theme_constant_override("h_separation", 8)
    _grade.add_theme_constant_override("v_separation", 8)
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rolagem.add_child(_grade)
    return area


## Um slot: moldura da raridade, arte do item, quantidade no canto.
func _slot(item: Dictionary) -> Control:
    var botao := Button.new()
    botao.custom_minimum_size = Vector2(92, 106)
    for estado in ["normal", "hover", "pressed", "focus"]:
        botao.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    botao.pressed.connect(_selecionar.bind(item))
    # Arrastar e soltar: o slot entrega o proprio item ao ser arrastado e
    # aceita o de outro, trocando os dois de lugar. E o minimo que um
    # inventario precisa fazer para o jogador sentir que a bolsa e dele.
    botao.set_drag_forwarding(
        _pegar_arrastado.bind(item), _aceita_soltar, _soltar_em.bind(item))

    var moldura := _arte(MOLDURA_DA_RARIDADE.get(item.get("rarity", "Comum"), "slot_verde"), BORDA_SLOT)
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    moldura.show_behind_parent = true
    botao.add_child(moldura)

    var icone := TextureRect.new()
    icone.texture = load(KIT + str(item.get("arte", "item/moeda")) + ".png")
    icone.set_anchors_preset(Control.PRESET_FULL_RECT)
    # Recuo grande: a moldura tem bico em cima e embaixo, e o icone encostado
    # nele fica com a cabeca cortada pelo ornamento.
    icone.offset_left = 16
    icone.offset_right = -16
    icone.offset_top = 22
    icone.offset_bottom = -20
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    botao.add_child(icone)

    var qtd := _texto(str(item.get("qtd", 1)), 17, Color(0.99, 0.95, 0.80))
    # Para DENTRO da moldura: encostado na borda, o numero caia em cima do
    # ornamento de baixo do slot e ficava pela metade.
    qtd.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    qtd.offset_left = -38
    qtd.offset_top = -34
    qtd.offset_right = -14
    qtd.offset_bottom = -14
    qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    qtd.mouse_filter = Control.MOUSE_FILTER_IGNORE
    botao.add_child(qtd)
    return botao


## O que sai do slot quando o dedo arrasta: o item, e uma copia do icone
## acompanhando o dedo para o jogador ver o que esta carregando.
func _pegar_arrastado(_pos: Vector2, item: Dictionary) -> Variant:
    var pre := TextureRect.new()
    pre.texture = load(KIT + str(item.get("arte", "item/moeda")) + ".png")
    pre.custom_minimum_size = Vector2(64, 64)
    pre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pre.modulate.a = 0.85
    set_drag_preview(pre)
    _selecionar(item)
    return item


func _aceita_soltar(_pos: Vector2, dados: Variant) -> bool:
    return dados is Dictionary and dados.has("id")


## Troca os dois de lugar na bolsa. Trocar e nao inserir: inserir empurraria a
## fila inteira, e o jogador que arrastou UM item veria a bolsa toda se mexer.
func _soltar_em(_pos: Vector2, dados: Variant, destino: Dictionary) -> void:
    var origem: int = bag_items.find(dados)
    var alvo: int = bag_items.find(destino)
    if origem < 0 or alvo < 0 or origem == alvo:
        return
    bag_items[origem] = destino
    bag_items[alvo] = dados
    _preencher_grade()
    _selecionar(dados)


func _cartao_de_detalhe() -> Control:
    var area := Control.new()
    area.custom_minimum_size.x = 300
    area.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var fundo := _arte("moldura_painel_simples", BORDA_CARTAO)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    area.add_child(fundo)

    var coluna := VBoxContainer.new()
    coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
    coluna.offset_left = 20
    coluna.offset_top = 26
    coluna.offset_right = -20
    coluna.offset_bottom = -20
    coluna.add_theme_constant_override("separation", 8)
    area.add_child(coluna)

    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 12)
    coluna.add_child(topo)

    var caixa_icone := Control.new()
    caixa_icone.custom_minimum_size = Vector2(96, 112)
    topo.add_child(caixa_icone)

    _det_moldura = _arte("slot_dourado", BORDA_SLOT)
    _det_moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    caixa_icone.add_child(_det_moldura)

    _det_icone = TextureRect.new()
    _det_icone.set_anchors_preset(Control.PRESET_FULL_RECT)
    _det_icone.offset_left = 16
    _det_icone.offset_right = -16
    _det_icone.offset_top = 24
    _det_icone.offset_bottom = -20
    _det_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _det_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    caixa_icone.add_child(_det_icone)

    var textos := VBoxContainer.new()
    textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    textos.add_theme_constant_override("separation", 2)
    topo.add_child(textos)

    _det_nome = _texto("", 21, Color(0.98, 0.86, 0.52), true)
    _det_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    textos.add_child(_det_nome)
    _det_raridade = _texto("", 16, Color(0.76, 0.48, 0.98))
    textos.add_child(_det_raridade)
    _det_posse = _texto("", 15, Color(0.80, 0.82, 0.88))
    textos.add_child(_det_posse)

    var risco := TextureRect.new()
    risco.texture = load(KIT + "moldura_divisoria_03.png")
    risco.custom_minimum_size.y = 16
    risco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    risco.stretch_mode = TextureRect.STRETCH_SCALE
    coluna.add_child(risco)

    _det_desc = _texto("", 16, Color(0.84, 0.86, 0.92))
    _det_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _det_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(_det_desc)

    for par in [["Usar", "botao_roxo"], ["Dividir", "botao_azul"], ["Descartar", "botao_vermelho"]]:
        var b := _botao(par[0], par[1], 240.0, 54.0)
        b.pressed.connect(_acao.bind(par[0]))
        coluna.add_child(b)
    return area


## A barra de baixo: as oito telas do jogo, cada uma com o seu icone da arte.
##
## So o Inventario faz alguma coisa por enquanto — as outras sete telas ainda
## nao existem. Ficam na barra assim mesmo porque a barra E o conceito: escondê
## las mudaria o desenho da tela por um motivo temporario.
const ABAS := [["personagem", "Personagem"], ["talentos", "Talentos"],
    ["melodia", "Melodia"], ["inventario", "Inventário"], ["missoes", "Missões"],
    ["mapa", "Mapa"], ["loja", "Loja"], ["lira", "Coleção"]]

func _barra_de_navegacao() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 78
    linha.alignment = BoxContainer.ALIGNMENT_CENTER
    linha.add_theme_constant_override("separation", 10)

    for aba in ABAS:
        # Botao, nao enfeite. Elas nao faziam NADA — nem o toque registravam —
        # e tela que nao responde ao dedo le como jogo travado, mesmo quando a
        # tela de destino ainda nao existe.
        var caixa := Button.new()
        # Largura que cabe "Inventario" sem encostar em "Missoes".
        caixa.custom_minimum_size = Vector2(96, 74)
        caixa.tooltip_text = str(aba[1])
        for estado in ["normal", "hover", "pressed", "focus"]:
            caixa.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
        caixa.pressed.connect(_abrir_aba.bind(String(aba[0]), String(aba[1])))

        var pilha := VBoxContainer.new()
        pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
        pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pilha.add_theme_constant_override("separation", 0)
        caixa.add_child(pilha)

        var icone := TextureRect.new()
        icone.texture = load(KIT + "nav/" + aba[0] + ".png")
        icone.custom_minimum_size = Vector2(48, 48)
        icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        # A aba aberta fica acesa; as outras, apagadas. E o unico jeito de
        # mostrar onde se esta sem ter as outras telas prontas.
        icone.modulate = Color(1, 1, 1) if aba[0] == "inventario" else Color(0.55, 0.55, 0.62)
        icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pilha.add_child(icone)

        var nome := _texto(aba[1], 12, Color(0.94, 0.86, 0.62) if aba[0] == "inventario" else Color(0.62, 0.62, 0.68))
        nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pilha.add_child(nome)

        linha.add_child(caixa)

    _recado = _texto("", 17, Color(0.95, 0.86, 0.55))
    _recado.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _recado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _recado.modulate.a = 0.0
    _recado.mouse_filter = Control.MOUSE_FILTER_IGNORE
    linha.add_child(_recado)
    return linha


## O toque nas abas que ainda nao tem tela.
##
## Avisar que a tela nao existe e MELHOR que nao responder: o jogador para de
## insistir no botao e sabe que o toque foi registrado. Quando a tela nascer, e
## so trocar este aviso pela abertura dela.
func _abrir_aba(ident: String, rotulo: String) -> void:
    if ident == "inventario":
        return
    if _recado == null:
        return
    _recado.text = "%s — em breve" % rotulo
    _recado.modulate.a = 1.0
    var tw := create_tween()
    tw.tween_interval(1.1)
    tw.tween_property(_recado, "modulate:a", 0.0, 0.5)


# -------------------------------------------------------------
# Comportamento
# -------------------------------------------------------------
func _preencher_grade() -> void:
    for filho in _grade.get_children():
        filho.queue_free()

    var visiveis := _itens_do_filtro()
    for item in visiveis:
        _grade.add_child(_slot(item))

    # A grade nunca fica com buraco no fim da fileira: slots vazios completam a
    # ultima linha, que e o que faz a grade parecer grade e nao lista.
    var faltam: int = (COLUNAS - visiveis.size() % COLUNAS) % COLUNAS
    for i in faltam + COLUNAS:
        var vazio := _arte("slot_verde", BORDA_SLOT)
        vazio.custom_minimum_size = Vector2(92, 106)
        vazio.modulate = Color(1, 1, 1, 0.35)
        _grade.add_child(vazio)

    if visiveis.size() > 0:
        _selecionar(visiveis[0])
    if _rotulo_bolsa:
        _rotulo_bolsa.text = "%d / 150" % bag_items.size()


func _itens_do_filtro() -> Array:
    if _filtro == "Todos":
        return bag_items
    var tipo: String = str(TIPO_DO_FILTRO.get(_filtro, ""))
    return bag_items.filter(func(i): return str(i.get("tipo", "")) == tipo)


func _trocar_filtro(nome: String) -> void:
    _filtro = nome
    for b in _botoes_de_filtro:
        var arte: String = "botao_roxo" if str(b.get_meta("filtro")) == nome else "botao_azul"
        for filho in b.get_children():
            if filho is NinePatchRect:
                (filho as NinePatchRect).texture = load(KIT + arte + ".png")
    _preencher_grade()


func _selecionar(item: Dictionary) -> void:
    _selecionado = item
    var raridade: String = str(item.get("rarity", "Comum"))
    _det_icone.texture = load(KIT + str(item.get("arte", "item/moeda")) + ".png")
    _det_moldura.texture = load(KIT + str(MOLDURA_DA_RARIDADE.get(raridade, "slot_verde")) + ".png")
    _det_nome.text = str(item.get("name", ""))
    _det_raridade.text = raridade
    _det_raridade.add_theme_color_override("font_color", COR_DA_RARIDADE.get(raridade, Color.WHITE))
    _det_posse.text = "Possui: %d" % int(item.get("qtd", 1))
    _det_desc.text = str(item.get("desc", ""))


func _acao(qual: String) -> void:
    if _selecionado.is_empty():
        return
    var ident: String = str(_selecionado.get("id", ""))
    match qual:
        "Usar":
            item_used.emit(ident)
            _gastar(1)
        "Descartar":
            _gastar(int(_selecionado.get("qtd", 1)))
        _:
            pass


## Tira do saco, e some com o item quando acaba.
func _gastar(quanto: int) -> void:
    var restante: int = int(_selecionado.get("qtd", 1)) - quanto
    if restante > 0:
        _selecionado["qtd"] = restante
    else:
        bag_items.erase(_selecionado)
        _selecionado = {}
    _preencher_grade()


func _milhar(valor: int) -> String:
    var texto := str(valor)
    var saida := ""
    var conta := 0
    for i in range(texto.length() - 1, -1, -1):
        saida = texto[i] + saida
        conta += 1
        if conta % 3 == 0 and i > 0:
            saida = "." + saida
    return saida


func toggle_inventory(force_state = null) -> void:
    var novo: bool = (not visible) if force_state == null else bool(force_state)
    visible = novo
    mouse_filter = Control.MOUSE_FILTER_STOP if novo else Control.MOUSE_FILTER_IGNORE
    # A grade so existe depois do _ready. Quem chamar antes disso — e o jogo
    # chama, ligando o botao da mochila na abertura — recebe a tela vazia em vez
    # de um erro; ela se preenche sozinha ao nascer.
    if novo and _grade != null:
        _preencher_grade()
