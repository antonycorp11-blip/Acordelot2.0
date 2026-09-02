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
## Qual aba da barra de baixo foi tocada. Quem sabe abrir cada tela e o jogo, e
## nao o inventario — assim uma tela nova nao pede mudanca aqui dentro.
signal aba_pedida(qual: String)

const KIT := "res://textures/ui/kit/"
const FUNDO_HARMONICO := "res://textures/ui/harmonia_celestial_v3.jpg"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const AreaSeguraUI := preload("res://scripts/area_segura_ui.gd")

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

var gold_amount: int = 0
var equipped_slots := {}

## A bolsa deixou de ser uma vitrine de itens ficticios. Estes sao exatamente os
## recursos que os sistemas do jogo entregam e a Sintese consome.
const ITENS_DE_RECURSO := [
    ["claves", "Claves", "item/moeda", "Valioso", "valioso", "Moeda PVE deixada pelos Shikers."],
    ["ressonador", "Ressonador Harmônico", "item/runa", "Raro", "ferramenta", "Ferramenta durável usada para extrair fragmentos e Almas dos Ecos."],
    ["madeira", "Madeira", "item/bolsa", "Comum", "material", "Material coletado de árvores e galhos aproveitáveis."],
    ["pedra", "Pedra", "item/minerio", "Comum", "material", "Material bruto obtido em veios e rochas."],
    ["acorde_cura", "Acorde de Cura", "item/acorde_cura", "Raro", "consumivel", "Tríade maior de Dó (Dó · Mi · Sol). Restaura 45% da vida."],
    ["acorde_vigor", "Acorde de Vigor", "item/acorde_vigor", "Épico", "consumivel", "Tríade menor de Dó (Dó · Ré# · Sol). Restaura 25% da vida e concede escudo."],
    ["partitura_menor", "Partitura Menor", "item/partitura", "Incomum", "consumivel", "Concede 100 XP ao Akles."],
    ["partitura_harmonica", "Partitura Harmônica", "item/partitura", "Raro", "consumivel", "Concede 500 XP ao Akles ou participa da ascensão do nível 20."],
    ["partitura_magistral", "Partitura Magistral", "item/partitura", "Épico", "consumivel", "Concede 1.500 XP ao Akles ou participa da ascensão do nível 40."],
    ["selo_regente", "Selo do Regente", "item/runa", "Épico", "material", "Item de chefe necessário para superar a ascensão do nível 20."],
    ["nucleo_maestro", "Núcleo do Maestro", "item/cristal_acorde", "Lendário", "material", "Item de chefe necessário para superar a ascensão do nível 40."],
    ["emblema_nota_silenciada", "Emblema da Nota Silenciada", "res://textures/items/emblema_nota_silenciada.png", "Lendário", "material", "Insígnia do cavaleiro que guardou o silêncio entre as notas. Material de ascensão do nível 40."],
    ["pocao_cura", "Poção de Cura", "item/pocao_vida", "Incomum", "consumivel", "Preparado de ervas de Acordelot. Recupera vida durante a exploração."],
    ["alma_eco_do", "Alma do Eco de Dó", "item/cristal_do", "Épico", "material", "Essência rara necessária para futuramente invocar o Eco de Dó."],
    ["alma_eco_do_sustenido", "Alma do Eco de Dó#", "item/cristal_do", "Épico", "material", "Essência rara de um Eco de Dó sustenido."],
    ["alma_eco_re", "Alma do Eco de Ré", "item/cristal_re", "Épico", "material", "Essência rara de um Eco de Ré."],
    ["alma_eco_re_sustenido", "Alma do Eco de Ré#", "item/cristal_re", "Épico", "material", "Essência rara de um Eco de Ré sustenido."],
    ["alma_eco_mi", "Alma do Eco de Mi", "item/cristal_mi", "Épico", "material", "Essência rara de um Eco de Mi."],
    ["alma_eco_fa", "Alma do Eco de Fá", "item/cristal_fa", "Épico", "material", "Essência rara de um Eco de Fá."],
    ["alma_eco_fa_sustenido", "Alma do Eco de Fá#", "item/cristal_fa", "Épico", "material", "Essência rara de um Eco de Fá sustenido."],
    ["alma_eco_sol", "Alma do Eco de Sol", "item/cristal_sol", "Épico", "material", "Essência rara de um Eco de Sol."],
    ["alma_eco_sol_sustenido", "Alma do Eco de Sol#", "item/cristal_sol", "Épico", "material", "Essência rara de um Eco de Sol sustenido."],
    ["alma_eco_la", "Alma do Eco de Lá", "item/cristal_la", "Épico", "material", "Essência rara de um Eco de Lá."],
    ["alma_eco_la_sustenido", "Alma do Eco de Lá#", "item/cristal_la", "Épico", "material", "Essência rara de um Eco de Lá sustenido."],
    ["alma_eco_si", "Alma do Eco de Si", "item/cristal_si", "Lendário", "material", "Essência rara de um Eco de Si."],
    ["fragmento_do", "Fragmento de Dó", "res://textures/items/notas/fragmento_do.png", "Incomum", "material", "Fragmento harmônico de Dó obtido de um Eco Musical."],
    ["fragmento_do_sustenido", "Fragmento de Dó#", "res://textures/items/notas/fragmento_do_sustenido.png", "Incomum", "material", "Fragmento harmônico de Dó sustenido obtido de um Eco Musical."],
    ["fragmento_re", "Fragmento de Ré", "res://textures/items/notas/fragmento_re.png", "Incomum", "material", "Fragmento harmônico de Ré obtido de um Eco Musical."],
    ["fragmento_re_sustenido", "Fragmento de Ré#", "res://textures/items/notas/fragmento_re_sustenido.png", "Incomum", "material", "Fragmento harmônico de Ré sustenido obtido de um Eco Musical."],
    ["fragmento_mi", "Fragmento de Mi", "res://textures/items/notas/fragmento_mi.png", "Incomum", "material", "Fragmento harmônico de Mi obtido de um Eco Musical."],
    ["fragmento_fa", "Fragmento de Fá", "res://textures/items/notas/fragmento_fa.png", "Incomum", "material", "Fragmento harmônico de Fá obtido de um Eco Musical."],
    ["fragmento_fa_sustenido", "Fragmento de Fá#", "res://textures/items/notas/fragmento_fa_sustenido.png", "Raro", "material", "Fragmento harmônico de Fá sustenido obtido de um Eco Musical."],
    ["fragmento_sol", "Fragmento de Sol", "res://textures/items/notas/fragmento_sol.png", "Raro", "material", "Fragmento harmônico de Sol obtido de um Eco Musical."],
    ["fragmento_sol_sustenido", "Fragmento de Sol#", "res://textures/items/notas/fragmento_sol_sustenido.png", "Raro", "material", "Fragmento harmônico de Sol sustenido obtido de um Eco Musical."],
    ["fragmento_la", "Fragmento de Lá", "res://textures/items/notas/fragmento_la.png", "Raro", "material", "Fragmento harmônico de Lá obtido de um Eco Musical."],
    ["fragmento_la_sustenido", "Fragmento de Lá#", "res://textures/items/notas/fragmento_la_sustenido.png", "Raro", "material", "Fragmento harmônico de Lá sustenido obtido de um Eco Musical."],
    ["fragmento_si", "Fragmento de Si", "res://textures/items/notas/fragmento_si.png", "Raro", "material", "Fragmento harmônico de Si obtido de um Eco Musical."],
    ["fragmento_corrompido_do", "Dó Corrompido", "res://textures/items/notas/fragmento_corrompido_do.png", "Raro", "material", "Fragmento de Dó contaminado por um Shiker. Precisa ser purificado."],
    ["fragmento_corrompido_do_sustenido", "Dó# Corrompido", "res://textures/items/notas/fragmento_corrompido_do_sustenido.png", "Raro", "material", "Fragmento de Dó sustenido contaminado. Precisa ser purificado."],
    ["fragmento_corrompido_re", "Ré Corrompido", "res://textures/items/notas/fragmento_corrompido_re.png", "Raro", "material", "Fragmento de Ré contaminado por um Shiker. Precisa ser purificado."],
    ["fragmento_corrompido_re_sustenido", "Ré# Corrompido", "res://textures/items/notas/fragmento_corrompido_re_sustenido.png", "Raro", "material", "Fragmento de Ré sustenido contaminado. Precisa ser purificado."],
    ["fragmento_corrompido_mi", "Mi Corrompido", "res://textures/items/notas/fragmento_corrompido_mi.png", "Raro", "material", "Fragmento de Mi contaminado por um Shiker. Precisa ser purificado."],
    ["fragmento_corrompido_fa", "Fá Corrompido", "res://textures/items/notas/fragmento_corrompido_fa.png", "Raro", "material", "Fragmento de Fá contaminado por um Shiker. Precisa ser purificado."],
    ["fragmento_corrompido_fa_sustenido", "Fá# Corrompido", "res://textures/items/notas/fragmento_corrompido_fa_sustenido.png", "Raro", "material", "Fragmento de Fá sustenido contaminado. Precisa ser purificado."],
    ["fragmento_corrompido_sol", "Sol Corrompido", "res://textures/items/notas/fragmento_corrompido_sol.png", "Raro", "material", "Fragmento de Sol contaminado por um Shiker. Precisa ser purificado."],
    ["fragmento_corrompido_sol_sustenido", "Sol# Corrompido", "res://textures/items/notas/fragmento_corrompido_sol_sustenido.png", "Raro", "material", "Fragmento de Sol sustenido contaminado. Precisa ser purificado."],
    ["fragmento_corrompido_la", "Lá Corrompido", "res://textures/items/notas/fragmento_corrompido_la.png", "Raro", "material", "Fragmento de Lá contaminado por um Shiker. Precisa ser purificado."],
    ["fragmento_corrompido_la_sustenido", "Lá# Corrompido", "res://textures/items/notas/fragmento_corrompido_la_sustenido.png", "Raro", "material", "Fragmento de Lá sustenido contaminado. Precisa ser purificado."],
    ["fragmento_corrompido_si", "Si Corrompido", "res://textures/items/notas/fragmento_corrompido_si.png", "Raro", "material", "Fragmento de Si contaminado por um Shiker. Precisa ser purificado."],
    ["nota_do", "Nota Dó Sintetizada", "res://textures/items/notas/nota_do.png", "Raro", "material", "Nota estável pronta para composição."],
    ["nota_do_sustenido", "Nota Dó# Sintetizada", "res://textures/items/notas/nota_do_sustenido.png", "Raro", "material", "Nota estável pronta para composição."],
    ["nota_re", "Nota Ré Sintetizada", "res://textures/items/notas/nota_re.png", "Raro", "material", "Nota estável pronta para composição."],
    ["nota_re_sustenido", "Nota Ré# Sintetizada", "res://textures/items/notas/nota_re_sustenido.png", "Raro", "material", "Nota estável pronta para composição."],
    ["nota_mi", "Nota Mi Sintetizada", "res://textures/items/notas/nota_mi.png", "Raro", "material", "Nota estável pronta para composição."],
    ["nota_fa", "Nota Fá Sintetizada", "res://textures/items/notas/nota_fa.png", "Raro", "material", "Nota estável pronta para composição."],
    ["nota_fa_sustenido", "Nota Fá# Sintetizada", "res://textures/items/notas/nota_fa_sustenido.png", "Épico", "material", "Nota estável pronta para composição."],
    ["nota_sol", "Nota Sol Sintetizada", "res://textures/items/notas/nota_sol.png", "Épico", "material", "Nota estável pronta para composição."],
    ["nota_sol_sustenido", "Nota Sol# Sintetizada", "res://textures/items/notas/nota_sol_sustenido.png", "Épico", "material", "Nota estável pronta para composição."],
    ["nota_la", "Nota Lá Sintetizada", "res://textures/items/notas/nota_la.png", "Épico", "material", "Nota estável pronta para composição."],
    ["nota_la_sustenido", "Nota Lá# Sintetizada", "res://textures/items/notas/nota_la_sustenido.png", "Épico", "material", "Nota estável pronta para composição."],
    ["nota_si", "Nota Si Sintetizada", "res://textures/items/notas/nota_si.png", "Épico", "material", "Nota estável pronta para composição."],
]

var bag_items: Array = []

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
var _det_moldura: PanelContainer
var _det_nome: Label
var _det_raridade: Label
var _det_posse: Label
var _det_desc: Label
var _rotulo_bolsa: Label
var _rotulo_moedas: Label
var _rotulo_materiais: Label
var _rotulo_fragmentos: Label
var _recado: Label
var _camada: CanvasLayer
var _proporcao: AspectRatioContainer


func _ready() -> void:
    # Pelo grupo: a clave coletada no chao precisa achar a bolsa sem saber por
    # onde ela pendura na arvore de nos.
    add_to_group("inventario")
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sincronizar_recursos()
    _montar()
    get_viewport().size_changed.connect(_ajustar_area_segura)
    _ajustar_area_segura()
    var progresso := get_node_or_null("/root/Progresso")
    if progresso and not progresso.recurso_alterado.is_connected(_recurso_mudou):
        progresso.recurso_alterado.connect(_recurso_mudou)
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


func _textura_de_item(arte: String):
    var caminho := arte if arte.begins_with("res://") else KIT + arte + ".png"
    if ResourceLoader.exists(caminho):
        return load(caminho)
    return load(KIT + "item/nota.png")


## Uma caixa de fundo simples: cor, borda fina e canto arredondado.
##
## Tres linhas que substituem tres texturas. Nao e economia de arquivo — e de
## RUIDO: superficie lisa atras do item faz o item aparecer, e superficie
## trabalhada disputa com ele.
func _caixa(fundo: Color, borda: Color, espessura := 1, raio := 8) -> StyleBoxFlat:
    var caixa := StyleBoxFlat.new()
    caixa.bg_color = fundo
    caixa.border_color = borda
    caixa.set_border_width_all(espessura)
    caixa.set_corner_radius_all(raio)
    return caixa


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

    # O fundo do botao deixou de ser a barra dourada do kit: seis daquelas na
    # mesma tela eram seis molduras competindo com os itens. Agora e chapa lisa,
    # e a COR diz a funcao — vermelho descarta, dourado e a acao principal, azul
    # e o resto.
    var cor: Color = CORES_DE_BOTAO.get(arte, Color(0.13, 0.17, 0.28))
    b.add_theme_stylebox_override("normal", _caixa(cor, cor.lightened(0.28)))
    b.add_theme_stylebox_override("hover", _caixa(cor.lightened(0.12), cor.lightened(0.45)))
    b.add_theme_stylebox_override("pressed", _caixa(cor.darkened(0.18), cor.lightened(0.2)))
    return b


## Quatro cores no jogo inteiro, e cada uma quer dizer uma coisa.
const CORES_DE_BOTAO := {
    "botao_roxo": Color(0.20, 0.17, 0.34),
    "botao_azul": Color(0.11, 0.16, 0.27),
    "botao_vermelho": Color(0.32, 0.13, 0.15),
    "botao_dourado": Color(0.34, 0.26, 0.11),
}


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
    _camada = CanvasLayer.new()
    _camada.name = "CamadaInventario"
    _camada.layer = 120
    # NASCE ESCONDIDA, e escondida NELA, nao no Control de fora.
    #
    # CanvasLayer nao e CanvasItem: ele ignora o visible do pai. Enquanto quem
    # escondia era o Control, a camada continuava desenhando — e o jogo abria
    # com o inventario na tela, sem jeito de fechar.
    _camada.visible = false
    add_child(_camada)

    _fundo = ColorRect.new()
    # Escurece o jogo sem apagar: a vila continua atras, como na conversa.
    _fundo.color = Color(0.02, 0.02, 0.05, 0.72)
    _fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    _camada.add_child(_fundo)

    # Tocar fora da janela tambem fecha, como em qualquer aplicativo. E a saida
    # que o dedo tenta antes de procurar botao.
    _fundo.gui_input.connect(func(evento: InputEvent):
        if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
            toggle_inventory(false))

    _proporcao = AspectRatioContainer.new()
    _proporcao.set_anchors_preset(Control.PRESET_FULL_RECT)
    _proporcao.ratio = PROPORCAO
    _proporcao.stretch_mode = AspectRatioContainer.STRETCH_FIT
    _proporcao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fundo.add_child(_proporcao)

    _janela = Control.new()
    _janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _proporcao.add_child(_janela)

    # Base celeste comum às telas novas. É uma textura vazia de conteúdo:
    # números, filtros, itens e ações continuam sendo Controls funcionais.
    var arte_fundo := TextureRect.new()
    arte_fundo.texture = load(FUNDO_HARMONICO)
    arte_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    arte_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    arte_fundo.stretch_mode = TextureRect.STRETCH_SCALE
    arte_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _janela.add_child(arte_fundo)

    # MOLDURA DISCRETA, e nao a filigrana inteira.
    #
    # A arte do conceito e desenhada para ser OLHADA; um inventario e usado. Com
    # a moldura cheia de ouro em volta, mais quatro cores de slot dentro, o olho
    # nao achava o item — que e a unica coisa que importa nesta tela. Aqui fica
    # um painel escuro com uma linha de ouro fina: a identidade continua, o
    # ruido sai, e o que brilha passa a ser o item.
    var moldura := PanelContainer.new()
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    moldura.add_theme_stylebox_override("panel", _caixa(Color(0.008, 0.025, 0.055, 0.34), Color(0.62, 0.50, 0.26), 1, 12))
    moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _janela.add_child(moldura)

    # Tudo o que e conteudo mora DENTRO da margem da moldura, senao passa por
    # cima do ouro.
    var miolo := MarginContainer.new()
    miolo.set_anchors_preset(Control.PRESET_FULL_RECT)
    miolo.add_theme_constant_override("margin_left", 34)
    miolo.add_theme_constant_override("margin_right", 34)
    miolo.add_theme_constant_override("margin_top", 22)
    miolo.add_theme_constant_override("margin_bottom", 20)
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

    _trocar_filtro(_filtro)


## O topo: titulo a esquerda, recursos no meio, fechar a direita.
func _cabecalho() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 62
    linha.add_theme_constant_override("separation", 16)

    var titulo := _texto("♫  INVENTÁRIO", 34, Color(0.97, 0.84, 0.47), true)
    titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    linha.add_child(titulo)

    var vao := Control.new()
    vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(vao)

    _rotulo_bolsa = _ficha(linha, "barra_ficha_bolsa", "%d / 150" % bag_items.size())
    _rotulo_moedas = _ficha(linha, "barra_ficha_moeda", "Claves  " + _milhar(gold_amount))
    var progresso := get_node_or_null("/root/Progresso")
    _rotulo_materiais = _ficha(linha, "barra_ficha_gema", "Materiais  " + _milhar(_total_de_materiais()))
    _rotulo_fragmentos = _ficha(linha, "barra_ficha_bolsa", "Frag.  " + _milhar(_total_de_fragmentos()))

    # FECHAR, escrito. O "X" sozinho, pequeno e em cima da cantoneira dourada,
    # nao se lia no celular — e sair de uma tela cheia e a acao que mais precisa
    # ser obvia, porque quem nao acha a saida acha que o jogo travou.
    var fechar := _botao("×", "botao_vermelho", 62.0, 58.0)
    fechar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    fechar.add_theme_font_size_override("font_size", 30)
    fechar.tooltip_text = "Fechar"
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
    coluna.custom_minimum_size.x = 220
    coluna.add_theme_constant_override("separation", 10)

    for nome in FILTROS:
        var arte: String = "botao_roxo" if nome == _filtro else "botao_azul"
        var b := _botao(nome, arte, 210.0, 56.0)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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

    var fundo := PanelContainer.new()
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.add_theme_stylebox_override("panel", _caixa(Color(0.018, 0.045, 0.09, 0.72), Color(0.42, 0.35, 0.22), 1, 10))
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
## O NUMERO CABE NO CANTO DO SLOT.
##
## A caixa da quantidade tem pouco mais de trinta pixels e a fonte, dezessete:
## "1" cabia, "3341" nao — o milhar transbordava para a esquerda e ficava por
## cima da moeda. Quatro digitos ja e o caso comum (Claves), entao a partir do
## milhar o numero vira "3,3 mil" abreviado, que e o que cabe e o que se le de
## relance num icone pequeno.
func _quantidade_curta(n: int) -> String:
    if n < 1000:
        return str(n)
    if n < 1000000:
        var mil: float = float(n) / 1000.0
        return ("%.0fK" % mil) if mil >= 10.0 else ("%.1fK" % mil).replace(".", ",")
    var mi: float = float(n) / 1000000.0
    return ("%.0fM" % mi) if mi >= 10.0 else ("%.1fM" % mi).replace(".", ",")


func _slot(item: Dictionary) -> Control:
    var botao := Button.new()
    botao.custom_minimum_size = Vector2(104, 112)
    for estado in ["normal", "hover", "pressed", "focus"]:
        botao.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    botao.pressed.connect(_selecionar.bind(item))
    # Arrastar e soltar: o slot entrega o proprio item ao ser arrastado e
    # aceita o de outro, trocando os dois de lugar. E o minimo que um
    # inventario precisa fazer para o jogador sentir que a bolsa e dele.
    botao.set_drag_forwarding(
        _pegar_arrastado.bind(item), _aceita_soltar, _soltar_em.bind(item))

    # A raridade vira UM FIO de cor na borda, nao uma moldura inteira colorida.
    # Vinte molduras acesas em quatro cores era a tela de carnaval; o fio diz a
    # mesma coisa e deixa o item ser a parte colorida do slot.
    var cor: Color = COR_DA_RARIDADE.get(item.get("rarity", "Comum"), Color(0.6, 0.6, 0.6))
    botao.add_theme_stylebox_override("normal", _caixa(Color(0.09, 0.11, 0.18, 0.9), cor.darkened(0.25), 2))
    botao.add_theme_stylebox_override("hover", _caixa(Color(0.13, 0.16, 0.24, 0.95), cor, 2))
    botao.add_theme_stylebox_override("pressed", _caixa(Color(0.16, 0.19, 0.28, 0.95), cor, 2))

    var icone := TextureRect.new()
    icone.texture = _textura_de_item(str(item.get("arte", "item/moeda")))
    icone.set_anchors_preset(Control.PRESET_FULL_RECT)
    # Recuo grande: a moldura tem bico em cima e embaixo, e o icone encostado
    # nele fica com a cabeca cortada pelo ornamento.
    icone.offset_left = 9
    icone.offset_right = -9
    icone.offset_top = 8
    icone.offset_bottom = -14
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    botao.add_child(icone)

    var qtd := _texto(_quantidade_curta(int(item.get("qtd", 1))), 17, Color(0.99, 0.95, 0.80))
    # Para DENTRO da moldura: encostado na borda, o numero caia em cima do
    # ornamento de baixo do slot e ficava pela metade.
    qtd.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    qtd.offset_left = -52
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
    pre.texture = _textura_de_item(str(item.get("arte", "item/moeda")))
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
    area.custom_minimum_size.x = 325
    area.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var fundo := PanelContainer.new()
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.add_theme_stylebox_override("panel", _caixa(Color(0.018, 0.045, 0.09, 0.78), Color(0.42, 0.35, 0.22), 1, 10))
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

    _det_moldura = PanelContainer.new()
    _det_moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    _det_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

    # Um fio, nao um ornamento: a divisoria dourada do kit tinha mais peso
    # visual que o nome do item logo acima dela.
    var risco := Panel.new()
    risco.custom_minimum_size.y = 1
    var linha := StyleBoxFlat.new()
    linha.bg_color = Color(0.45, 0.38, 0.24, 0.8)
    risco.add_theme_stylebox_override("panel", linha)
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
    ["melodia", "Síntese"], ["inventario", "Inventário"], ["missoes", "Missões"],
    ["mapa", "Mapa"], ["loja", "Loja"], ["lira", "Ecos"]]

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
        caixa.custom_minimum_size = Vector2(112, 74)
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


## As abas que JA tem tela abrem; as que nao tem avisam.
##
## Avisar que a tela nao existe e MELHOR que nao responder: o jogador para de
## insistir no botao e sabe que o toque foi registrado. Quando a tela nascer, o
## identificador dela entra na lista abaixo e o aviso some sozinho.
##
## "Missoes" e "Mapa" acabaram de sair da lista de espera: o diario do dia e o
## mapa do reino existem, e continuar dizendo "em breve" para um botao que tem
## destino e pior que nao ter o botao.
const ABAS_COM_TELA := ["personagem", "talentos", "melodia", "lira", "missoes", "mapa"]

func _abrir_aba(ident: String, rotulo: String) -> void:
    if ident == "inventario":
        return
    aba_pedida.emit(ident)
    if ident in ABAS_COM_TELA:
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
        var vazio := PanelContainer.new()
        vazio.custom_minimum_size = Vector2(104, 112)
        vazio.add_theme_stylebox_override("panel", _caixa(Color(0.06, 0.075, 0.13, 0.55), Color(0.22, 0.24, 0.32), 1))
        vazio.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
        var ativo: bool = str(b.get_meta("filtro")) == nome
        var cor := Color(0.055, 0.20, 0.38, 0.96) if ativo else Color(0.035, 0.065, 0.12, 0.90)
        var borda := Color(0.30, 0.72, 1.0) if ativo else Color(0.26, 0.35, 0.46)
        b.add_theme_stylebox_override("normal", _caixa(cor, borda, 2 if ativo else 1, 8))
    _preencher_grade()


func _selecionar(item: Dictionary) -> void:
    _selecionado = item
    var raridade: String = str(item.get("rarity", "Comum"))
    _det_icone.texture = _textura_de_item(str(item.get("arte", "item/moeda")))
    var cor_r: Color = COR_DA_RARIDADE.get(raridade, Color(0.6, 0.6, 0.6))
    _det_moldura.add_theme_stylebox_override("panel", _caixa(Color(0.09, 0.11, 0.18, 0.9), cor_r, 2))
    _det_nome.text = str(item.get("name", ""))
    _det_raridade.text = raridade
    _det_raridade.add_theme_color_override("font_color", COR_DA_RARIDADE.get(raridade, Color.WHITE))
    _det_posse.text = "Possui: %d" % int(item.get("qtd", 1))
    _det_desc.text = str(item.get("desc", ""))


func _acao(qual: String) -> void:
    if _selecionado.is_empty():
        return
    # Recursos pertencem a sistemas (Sintese, criacao, economia). Nao podem ser
    # apagados por um toque acidental em Usar/Descartar.
    if str(_selecionado.get("tipo", "")) in ["material", "valioso"]:
        return
    var ident: String = str(_selecionado.get("id", ""))
    match qual:
        "Usar":
            if ident.begins_with("partitura_"):
                var progresso := get_node_or_null("/root/Progresso")
                var tipo := ident.trim_prefix("partitura_")
                if progresso and progresso.usar_partitura(tipo):
                    _sincronizar_recursos()
                    _preencher_grade()
                return
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


func _sincronizar_recursos() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    var existentes := {}
    for item in bag_items:
        existentes[str(item.get("id", ""))] = item
    for dados in ITENS_DE_RECURSO:
        var id := str(dados[0])
        var total: int = progresso.quantidade(id)
        var item: Dictionary = existentes.get(id, {})
        if total <= 0:
            if not item.is_empty():
                bag_items.erase(item)
            continue
        if item.is_empty():
            item = {
                "id": dados[0], "name": dados[1], "arte": dados[2],
                "tier": dados[3], "rarity": dados[3], "tipo": dados[4],
                "desc": dados[5],
            }
            bag_items.append(item)
        item["qtd"] = total
    if not _selecionado.is_empty() and not bag_items.has(_selecionado):
        _selecionado = {}
    gold_amount = progresso.quantidade("claves")


func _total_de_fragmentos() -> int:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return 0
    var total := 0
    for nota in ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
                 "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]:
        total += progresso.quantidade("fragmento_" + nota)
        total += progresso.quantidade("fragmento_corrompido_" + nota)
    return total


func _total_de_materiais() -> int:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return 0
    return progresso.quantidade("madeira") + progresso.quantidade("pedra")


func _recurso_mudou(_id: String, _total: int) -> void:
    _sincronizar_recursos()
    if _rotulo_moedas:
        _rotulo_moedas.text = "Claves  " + _milhar(gold_amount)
    var progresso := get_node_or_null("/root/Progresso")
    if _rotulo_materiais:
        _rotulo_materiais.text = "Materiais  " + _milhar(_total_de_materiais())
    if _rotulo_fragmentos:
        _rotulo_fragmentos.text = "Frag.  " + _milhar(_total_de_fragmentos())
    if _camada and _camada.visible and _grade:
        _preencher_grade()


## A clave agora entra no estado persistente, aparece como moeda no cabecalho e
## como item da bolsa, inclusive depois de fechar o navegador.
func receber_claves(quantidade: int) -> void:
    receber_recurso("claves", quantidade)


func receber_recurso(id: String, quantidade: int) -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso:
        progresso.adicionar_recurso(id, quantidade)


func toggle_inventory(force_state = null) -> void:
    var aberto: bool = _camada != null and _camada.visible
    var novo: bool = (not aberto) if force_state == null else bool(force_state)
    if _camada:
        _camada.visible = novo
    visible = novo
    mouse_filter = Control.MOUSE_FILTER_STOP if novo else Control.MOUSE_FILTER_IGNORE
    # A grade so existe depois do _ready. Quem chamar antes disso — e o jogo
    # chama, ligando o botao da mochila na abertura — recebe a tela vazia em vez
    # de um erro; ela se preenche sozinha ao nascer.
    if novo and _grade != null:
        _sincronizar_recursos()
        _preencher_grade()
        _janela.modulate.a = 0.0
        create_tween().tween_property(_janela, "modulate:a", 1.0, 0.22)


func _ajustar_area_segura() -> void:
    AreaSeguraUI.ajustar_container(_proporcao, get_viewport().get_visible_rect().size)
