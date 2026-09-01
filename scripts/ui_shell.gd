extends CanvasLayer
class_name UiShell

## O SHELL DA INTERFACE PRINCIPAL — uma moldura, uma navbar, oito paginas.
##
## Antes cada tela era uma CanvasLayer inteira com fundo, moldura, botao de
## fechar e tamanho proprios. Abrir "Personagem" destruia a tela do inventario e
## levantava outra do zero — e a barra de navegacao de baixo, que existe
## justamente para trocar de aba, SUMIA. Oito telas, oito molduras, oito jeitos
## de fechar.
##
## Aqui a moldura, o cabecalho, o botao de fechar e a navbar sao UM so e nao
## piscam. Trocar de aba so troca o que esta no meio: `_conteudo` esconde a
## pagina anterior e mostra a seguinte, ja construida. Nenhum no e destruido, o
## que faz a troca ser imediata e nao dar engasgo.
##
## A pagina nao sabe que o shell existe: ela entrega um Control e pronto.

const T := preload("res://scripts/ui_tema.gd")
const AreaSeguraUI := preload("res://scripts/area_segura_ui.gd")

signal pagina_trocada(id: String)
signal fechado

const ALTURA_DO_CABECALHO := 92.0
const ALTURA_DA_NAVBAR := 104.0
const MARGEM := 10.0

var _base: Control
var _cabecalho: HBoxContainer
var _titulo: Label
var _extras: HBoxContainer
var _conteudo: Control
var _navbar: HBoxContainer

var _paginas: Dictionary = {}      # id -> {"no": Control, "botao": Button, "nome": String}
var _ordem: Array[String] = []
var _atual := ""


func _ready() -> void:
    # ACIMA DE TUDO QUE E JOGO.
    #
    # O anuncio de zona vive na camada 100 e atravessava a moldura: "Floresta
    # Inicial" aparecia escrito no meio da ficha do personagem. Menu principal e
    # a coisa mais na frente que existe enquanto esta aberto.
    layer = 105
    _montar()
    visible = false
    get_viewport().size_changed.connect(_acomodar)


func _montar() -> void:
    var fundo := ColorRect.new()
    fundo.color = T.ESCURECER
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(fundo)

    # A TELA DE PROJETO: tudo e desenhado em 1600x900 e escalado inteiro para o
    # aparelho. E o que as telas v3 ja faziam e agora vale para todas — e o que
    # garante que celular e computador vejam a MESMA composicao, so em tamanhos
    # diferentes, sem numero absoluto espalhado por script.
    _base = Control.new()
    _base.name = "Base"
    _base.size = T.CANVAS
    _base.mouse_filter = Control.MOUSE_FILTER_STOP
    fundo.add_child(_base)

    var moldura := PanelContainer.new()
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    moldura.add_theme_stylebox_override("panel", T.painel_principal())
    _base.add_child(moldura)

    # As camadas de fundo entram ANTES da coluna: quem e desenhado primeiro fica
    # atras. Elas nao pedem tamanho nenhum, entao nao mexem no layout.
    # A DECORACAO VAI NUM Control, NAO NO PanelContainer.
    #
    # Container estica TODO filho ate o retangulo inteiro, ancora nenhuma
    # respeitada: os cantos ornamentados de 110 px viraram quatro manchas
    # douradas de mil e seiscentos. Dentro de um Control comum cada peca fica do
    # tamanho que tem e no canto onde foi ancorada.
    var decoracao := Control.new()
    decoracao.name = "Decoracao"
    decoracao.set_anchors_preset(Control.PRESET_FULL_RECT)
    decoracao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    moldura.add_child(decoracao)
    T.fundo_em_camadas(decoracao)
    T.ornamentar_cantos(decoracao)

    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 0)
    moldura.add_child(coluna)

    coluna.add_child(_montar_cabecalho())
    coluna.add_child(T.espaco(10))

    var meio := MarginContainer.new()
    meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
    for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        meio.add_theme_constant_override(lado, int(MARGEM))
    coluna.add_child(meio)

    _conteudo = Control.new()
    _conteudo.name = "Conteudo"
    _conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _conteudo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _conteudo.mouse_filter = Control.MOUSE_FILTER_PASS
    meio.add_child(_conteudo)

    coluna.add_child(T.espaco(8))
    coluna.add_child(_montar_navbar())
    _acomodar()


func _montar_cabecalho() -> Control:
    var caixa := MarginContainer.new()
    caixa.custom_minimum_size.y = ALTURA_DO_CABECALHO
    # Folga para os cantos ornamentados: sem ela o titulo e o botao de fechar
    # caem em cima do desenho.
    for lado in ["margin_left", "margin_right"]:
        caixa.add_theme_constant_override(lado, 96)
    caixa.add_theme_constant_override("margin_top", 10)
    caixa.add_theme_constant_override("margin_bottom", 6)

    _cabecalho = HBoxContainer.new()
    _cabecalho.add_theme_constant_override("separation", 22)
    _cabecalho.alignment = BoxContainer.ALIGNMENT_BEGIN
    caixa.add_child(_cabecalho)

    # O titulo vem sobre a PLACA do kit, nao solto no ar.
    var placa := PanelContainer.new()
    placa.add_theme_stylebox_override("panel", T.placa_de_titulo())
    _cabecalho.add_child(placa)
    _titulo = T.rotulo("", T.TITULO_PAGINA, T.OURO_FORTE)
    _titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    placa.add_child(_titulo)

    # Onde a pagina pendura os contadores dela. Fica ENTRE o titulo e o fechar,
    # empurrado para a direita, com espaco de sobra entre um contador e outro.
    _extras = HBoxContainer.new()
    _extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _extras.alignment = BoxContainer.ALIGNMENT_END
    _extras.add_theme_constant_override("separation", 30)
    _cabecalho.add_child(_extras)

    # UM SO BOTAO DE FECHAR, no mesmo canto, do mesmo tamanho, em toda a UI.
    var fechar := T.botao_fechar(fechar_tudo)
    var canto := CenterContainer.new()
    canto.add_child(fechar)
    _cabecalho.add_child(canto)
    return caixa


func _montar_navbar() -> Control:
    var caixa := MarginContainer.new()
    caixa.custom_minimum_size.y = ALTURA_DA_NAVBAR
    for lado in ["margin_left", "margin_right"]:
        caixa.add_theme_constant_override(lado, int(MARGEM))
    caixa.add_theme_constant_override("margin_top", 8)
    caixa.add_theme_constant_override("margin_bottom", 10)
    # Mesma folga do cabecalho: o canto ornamentado de baixo ficava escrito por
    # cima de "Personagem" e de "Ecos".
    caixa.add_theme_constant_override("margin_left", 96)
    caixa.add_theme_constant_override("margin_right", 96)
    _navbar = HBoxContainer.new()
    _navbar.alignment = BoxContainer.ALIGNMENT_CENTER
    _navbar.add_theme_constant_override("separation", 10)
    caixa.add_child(_navbar)
    return caixa


## Registra uma pagina. `no` e o conteudo — sem fundo, sem moldura, sem navbar.
func registrar(id: String, nome: String, icone: String, no: Control) -> void:
    if _paginas.has(id):
        return
    no.set_anchors_preset(Control.PRESET_FULL_RECT)
    no.visible = false
    _conteudo.add_child(no)

    var b := Button.new()
    b.custom_minimum_size = Vector2(112, 86)
    b.focus_mode = Control.FOCUS_NONE
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    b.pressed.connect(abrir.bind(id))

    var pilha := VBoxContainer.new()
    pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
    pilha.alignment = BoxContainer.ALIGNMENT_CENTER
    pilha.add_theme_constant_override("separation", 2)
    pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(pilha)

    var img := TextureRect.new()
    img.name = "Icone"
    if ResourceLoader.exists(icone):
        img.texture = load(icone)
    img.custom_minimum_size = Vector2(0, 46)
    img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pilha.add_child(img)

    var txt := T.rotulo(nome, T.LEGENDA, T.TEXTO_FRACO)
    txt.name = "Nome"
    txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pilha.add_child(txt)

    # O indicador da aba ativa: um risco dourado embaixo. Discreto, e suficiente.
    var marca := ColorRect.new()
    marca.name = "Marca"
    marca.color = T.OURO
    marca.custom_minimum_size.y = 3
    marca.visible = false
    marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pilha.add_child(marca)

    _navbar.add_child(b)
    _paginas[id] = {"no": no, "botao": b, "nome": nome}
    _ordem.append(id)


## Troca so o miolo. A moldura, o cabecalho e a navbar nao piscam.
func abrir(id: String) -> void:
    if not _paginas.has(id):
        return
    visible = true
    if _atual == id:
        _pintar_navbar()
        return
    if _paginas.has(_atual):
        var antiga: Control = _paginas[_atual]["no"]
        antiga.visible = false
        # Pagina escondida nao pensa: nada de sistema pesado rodando atras.
        antiga.process_mode = Node.PROCESS_MODE_DISABLED
    _atual = id
    var nova: Control = _paginas[id]["no"]
    nova.process_mode = Node.PROCESS_MODE_INHERIT
    nova.visible = true
    _titulo.text = String(_paginas[id]["nome"]).to_upper()
    for filho in _extras.get_children():
        _extras.remove_child(filho)
    if nova.has_method("cabecalho_extra"):
        var extra = nova.cabecalho_extra()
        if extra is Control:
            _extras.add_child(extra)
    if nova.has_method("ao_abrir"):
        nova.ao_abrir()
    _pintar_navbar()
    _acomodar()
    _animar_entrada(nova)
    pagina_trocada.emit(id)


## A TROCA GANHA NOVENTA MILISSEGUNDOS DE VIDA.
##
## Aparecer instantaneo e correto e seco: a tela pisca e o olho perde onde
## estava. Um sobe-e-aparece curto conta ao jogador que aquilo ali e novo, sem
## fazer ninguem esperar — e curto de proposito, porque animacao de abrir menu
## e a primeira coisa que cansa quem joga todo dia.
func _animar_entrada(pagina: Control) -> void:
    pagina.modulate.a = 0.0
    pagina.position.y = 14.0
    var tw := create_tween().set_parallel()
    tw.tween_property(pagina, "modulate:a", 1.0, 0.09)
    tw.tween_property(pagina, "position:y", 0.0, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func fechar_tudo() -> void:
    visible = false
    if _paginas.has(_atual):
        _paginas[_atual]["no"].process_mode = Node.PROCESS_MODE_DISABLED
    fechado.emit()


func esta_aberto() -> bool:
    return visible


func pagina_atual() -> String:
    return _atual


func _pintar_navbar() -> void:
    for id in _ordem:
        var b: Button = _paginas[id]["botao"]
        var ativo: bool = id == _atual
        var img := b.find_child("Icone", true, false) as TextureRect
        var txt := b.find_child("Nome", true, false) as Label
        var marca := b.find_child("Marca", true, false) as ColorRect
        if img:
            img.modulate = Color(1, 1, 1) if ativo else Color(0.55, 0.60, 0.68)
        if txt:
            txt.add_theme_color_override("font_color", T.OURO_FORTE if ativo else T.TEXTO_FRACO)
        if marca:
            marca.visible = ativo


## Escala a tela de projeto inteira para dentro da area segura do aparelho.
func _acomodar() -> void:
    if _base == null:
        return
    AreaSeguraUI.ajustar_base(_base, T.CANVAS, get_viewport().get_visible_rect().size)


func _unhandled_input(evento: InputEvent) -> void:
    if not visible:
        return
    if evento is InputEventKey and evento.pressed and not evento.echo \
            and evento.keycode == KEY_ESCAPE:
        fechar_tudo()
        get_viewport().set_input_as_handled()
