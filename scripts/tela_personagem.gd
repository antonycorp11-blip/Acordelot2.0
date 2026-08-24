extends CanvasLayer
class_name TelaPersonagem
## A tela de Personagem: quem e o Akles, o que ele veste e quanto ele vale.
##
## Nasce da mesma gramatica do Inventario, e de proposito: painel escuro com fio
## de ouro, chapa lisa atras de cada bloco, e a arte guardada para o que importa.
## Duas telas do mesmo jogo devem parecer a mesma tela com conteudos diferentes
## — quando cada uma inventa a propria moldura, o jogo parece remendado.
##
## Tres colunas, que e a leitura natural de ficha de personagem: quem ele e a
## esquerda, o corpo no meio com o que esta vestido em volta, e os numeros a
## direita.

const KIT := "res://textures/ui/kit/"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const PROPORCAO := 16.0 / 9.0

## Os oito encaixes, na ordem em que aparecem nas duas colunas do corpo.
const ESQUERDA := ["Arma", "Cabeça", "Amuleto", "Acessório"]
const DIREITA := ["Peitoral", "Luvas", "Calças", "Botas"]

const ATRIBUTOS := [
    ["Força", "172"], ["Destreza", "128"], ["Vitalidade", "196"],
    ["Inteligência", "112"], ["Fé", "154"],
]
const COMBATE := [
    ["Ataque", "412"], ["Defesa", "289"], ["Vida Máxima", "2.020"],
    ["Mana Máxima", "290"], ["Chance de Crítico", "18,5%"], ["Dano Crítico", "163,0%"],
]

var _camada_visivel := false
var _fundo: ColorRect
## A bolsa e quem sabe o que esta equipado — a ficha so mostra.
var _bolsa: Node = null


func _ready() -> void:
    layer = 16
    visible = false
    _bolsa = get_tree().get_first_node_in_group("inventario")
    _montar()


func _caixa(fundo: Color, borda: Color, espessura := 1, raio := 8) -> StyleBoxFlat:
    var c := StyleBoxFlat.new()
    c.bg_color = fundo
    c.border_color = borda
    c.set_border_width_all(espessura)
    c.set_corner_radius_all(raio)
    return c


func _texto(txt: String, corpo: int, cor: Color, titulo := false) -> Label:
    var l := Label.new()
    l.text = txt
    l.add_theme_font_override("font", load(FONTE_TITULO if titulo else FONTE_TEXTO))
    l.add_theme_font_size_override("font_size", corpo)
    l.add_theme_color_override("font_color", cor)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 2)
    return l


func _montar() -> void:
    _fundo = ColorRect.new()
    _fundo.color = Color(0.02, 0.02, 0.05, 0.72)
    _fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    _fundo.gui_input.connect(func(e: InputEvent):
        if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
            mostrar(false))
    add_child(_fundo)

    var proporcao := AspectRatioContainer.new()
    proporcao.set_anchors_preset(Control.PRESET_FULL_RECT)
    proporcao.ratio = PROPORCAO
    proporcao.stretch_mode = AspectRatioContainer.STRETCH_FIT
    proporcao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fundo.add_child(proporcao)

    var janela := PanelContainer.new()
    janela.add_theme_stylebox_override("panel",
        _caixa(Color(0.055, 0.07, 0.13, 0.97), Color(0.62, 0.50, 0.26), 2, 12))
    proporcao.add_child(janela)

    var miolo := MarginContainer.new()
    miolo.add_theme_constant_override("margin_left", 26)
    miolo.add_theme_constant_override("margin_right", 26)
    miolo.add_theme_constant_override("margin_top", 18)
    miolo.add_theme_constant_override("margin_bottom", 18)
    janela.add_child(miolo)

    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 10)
    miolo.add_child(coluna)

    coluna.add_child(_cabecalho())

    var corpo := HBoxContainer.new()
    corpo.add_theme_constant_override("separation", 14)
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(corpo)

    corpo.add_child(_coluna_de_slots(ESQUERDA))
    corpo.add_child(_retrato_do_heroi())
    corpo.add_child(_coluna_de_slots(DIREITA))
    corpo.add_child(_painel_de_numeros())


func _cabecalho() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 56
    linha.add_theme_constant_override("separation", 14)

    var titulo := _texto("Personagem", 36, Color(0.97, 0.84, 0.47), true)
    titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    linha.add_child(titulo)

    var vao := Control.new()
    vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(vao)

    var fechar := Button.new()
    fechar.text = "✕  Fechar"
    fechar.custom_minimum_size = Vector2(150, 52)
    fechar.add_theme_font_override("font", load(FONTE_TEXTO))
    fechar.add_theme_font_size_override("font_size", 19)
    fechar.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    var vermelho := Color(0.32, 0.13, 0.15)
    fechar.add_theme_stylebox_override("normal", _caixa(vermelho, vermelho.lightened(0.28)))
    fechar.add_theme_stylebox_override("hover", _caixa(vermelho.lightened(0.12), vermelho.lightened(0.45)))
    fechar.add_theme_stylebox_override("pressed", _caixa(vermelho.darkened(0.2), vermelho))
    fechar.pressed.connect(func(): mostrar(false))
    linha.add_child(fechar)
    return linha


## Uma coluna de encaixes de equipamento, com o icone do que esta vestido.
func _coluna_de_slots(quais: Array) -> Control:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 116
    coluna.add_theme_constant_override("separation", 10)
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER

    var equipado: Dictionary = {}
    if _bolsa and "equipped_slots" in _bolsa:
        equipado = _bolsa.equipped_slots

    for nome in quais:
        var caixa := VBoxContainer.new()
        caixa.add_theme_constant_override("separation", 2)

        var slot := Panel.new()
        slot.custom_minimum_size = Vector2(92, 92)
        var item: Dictionary = equipado.get(nome, {})
        var cor := Color(0.30, 0.33, 0.42)
        if not item.is_empty() and _bolsa and "COR_DA_RARIDADE" in _bolsa:
            cor = _bolsa.COR_DA_RARIDADE.get(item.get("rarity", "Comum"), cor)
        slot.add_theme_stylebox_override("panel",
            _caixa(Color(0.09, 0.11, 0.18, 0.9), cor.darkened(0.2), 2))
        caixa.add_child(slot)

        if not item.is_empty():
            var icone := TextureRect.new()
            icone.texture = load(KIT + str(item.get("arte", "item/moeda")) + ".png")
            icone.set_anchors_preset(Control.PRESET_FULL_RECT)
            icone.offset_left = 8
            icone.offset_top = 8
            icone.offset_right = -8
            icone.offset_bottom = -8
            icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
            slot.add_child(icone)

        var rotulo := _texto(nome, 12, Color(0.72, 0.74, 0.82))
        rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caixa.add_child(rotulo)
        coluna.add_child(caixa)
    return coluna


## O Akles de corpo inteiro, que e o centro da tela.
func _retrato_do_heroi() -> Control:
    var area := Control.new()
    area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    area.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var chao := PanelContainer.new()
    chao.set_anchors_preset(Control.PRESET_FULL_RECT)
    chao.add_theme_stylebox_override("panel",
        _caixa(Color(0.04, 0.055, 0.10, 0.85), Color(0.30, 0.26, 0.18), 1, 10))
    chao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    area.add_child(chao)

    var figura := TextureRect.new()
    # O Akles de corpo inteiro, que e o centro desta tela: e ele que o jogador
    # veio ver.
    figura.texture = load("res://textures/dialogo/akles_corpo.png")
    figura.set_anchors_preset(Control.PRESET_FULL_RECT)
    figura.offset_top = 8
    figura.offset_bottom = -34
    figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    figura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    area.add_child(figura)

    # Nome e nivel no pe da figura, como legenda dela — e nao num canto solto.
    var faixa := VBoxContainer.new()
    faixa.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    faixa.offset_top = -46
    faixa.offset_bottom = -6
    faixa.add_theme_constant_override("separation", 0)
    faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    area.add_child(faixa)

    var nome := _texto("Akles", 26, Color(0.97, 0.86, 0.52), true)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    faixa.add_child(nome)

    var oficio := _texto("Espadachim da Harmonia  ·  Nível 12", 14, Color(0.78, 0.80, 0.88))
    oficio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    faixa.add_child(oficio)
    return area


## Os numeros, em dois blocos: quem ele e, e como ele briga.
func _painel_de_numeros() -> Control:
    var area := PanelContainer.new()
    area.custom_minimum_size.x = 300
    area.add_theme_stylebox_override("panel",
        _caixa(Color(0.04, 0.055, 0.10, 0.85), Color(0.30, 0.26, 0.18), 1, 10))

    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 16)
    margem.add_theme_constant_override("margin_right", 16)
    margem.add_theme_constant_override("margin_top", 14)
    margem.add_theme_constant_override("margin_bottom", 14)
    area.add_child(margem)

    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 4)
    margem.add_child(coluna)

    coluna.add_child(_texto("Atributos", 19, Color(0.95, 0.83, 0.48), true))
    for par in ATRIBUTOS:
        coluna.add_child(_linha_de_numero(par[0], par[1]))

    var risco := Panel.new()
    risco.custom_minimum_size.y = 1
    var fio := StyleBoxFlat.new()
    fio.bg_color = Color(0.45, 0.38, 0.24, 0.8)
    risco.add_theme_stylebox_override("panel", fio)
    coluna.add_child(risco)

    coluna.add_child(_texto("Combate", 19, Color(0.95, 0.83, 0.48), true))
    for par in COMBATE:
        coluna.add_child(_linha_de_numero(par[0], par[1]))
    return area


## Rotulo a esquerda, valor a direita — a unica forma de uma lista de numeros
## ser lida em diagonal, que e como se le ficha de personagem.
func _linha_de_numero(rotulo: String, valor: String) -> Control:
    var linha := HBoxContainer.new()
    var esq := _texto(rotulo, 15, Color(0.80, 0.82, 0.88))
    esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(esq)
    var dir := _texto(valor, 16, Color(0.98, 0.94, 0.80))
    dir.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    linha.add_child(dir)
    return linha


func mostrar(sim := true) -> void:
    _camada_visivel = sim
    visible = sim


func esta_aberta() -> bool:
    return _camada_visivel
