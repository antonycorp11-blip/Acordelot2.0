extends CanvasLayer
## Sintese das sete notas. Cada botao le e consome os recursos reais guardados
## por Progresso; o inventario recebe a nota pronta imediatamente.

const KIT := "res://textures/ui/kit/"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const NOTAS := [
    ["do", "Dó", Color(0.90, 0.30, 0.28)],
    ["re", "Ré", Color(0.95, 0.55, 0.24)],
    ["mi", "Mi", Color(0.92, 0.80, 0.26)],
    ["fa", "Fá", Color(0.35, 0.78, 0.42)],
    ["sol", "Sol", Color(0.28, 0.70, 0.92)],
    ["la", "Lá", Color(0.42, 0.46, 0.94)],
    ["si", "Si", Color(0.72, 0.38, 0.90)],
]

var _progresso: Node
var _fragmentos_totais: Label
var _recado: Label
var _fragmentos := {}
var _prontas := {}
var _botoes := {}


func _ready() -> void:
    layer = 17
    visible = false
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_atualizar):
        _progresso.alterado.connect(_atualizar)
    _atualizar()


func _caixa(fundo: Color, borda: Color, espessura := 1, raio := 8) -> StyleBoxFlat:
    var c := StyleBoxFlat.new()
    c.bg_color = fundo
    c.border_color = borda
    c.set_border_width_all(espessura)
    c.set_corner_radius_all(raio)
    return c


func _texto(txt: String, tamanho: int, cor: Color, titulo := false) -> Label:
    var l := Label.new()
    l.text = txt
    l.add_theme_font_override("font", load(FONTE_TITULO if titulo else FONTE_TEXTO))
    l.add_theme_font_size_override("font_size", tamanho)
    l.add_theme_color_override("font_color", cor)
    return l


func _montar() -> void:
    var fundo := ColorRect.new()
    fundo.color = Color(0.02, 0.02, 0.05, 0.78)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    fundo.gui_input.connect(func(e: InputEvent):
        if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
            mostrar(false))
    add_child(fundo)
    var proporcao := AspectRatioContainer.new()
    proporcao.set_anchors_preset(Control.PRESET_FULL_RECT)
    proporcao.ratio = 16.0 / 9.0
    proporcao.stretch_mode = AspectRatioContainer.STRETCH_FIT
    proporcao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fundo.add_child(proporcao)
    var painel := PanelContainer.new()
    painel.add_theme_stylebox_override("panel",
        _caixa(Color(0.055, 0.07, 0.13, 0.98), Color(0.62, 0.50, 0.26), 2, 12))
    proporcao.add_child(painel)
    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 28)
    margem.add_theme_constant_override("margin_right", 28)
    margem.add_theme_constant_override("margin_top", 20)
    margem.add_theme_constant_override("margin_bottom", 20)
    painel.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 14)
    margem.add_child(coluna)
    var cab := HBoxContainer.new()
    cab.add_child(_texto("Síntese de Notas", 36, Color(0.97, 0.84, 0.47), true))
    var vao := Control.new()
    vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cab.add_child(vao)
    _fragmentos_totais = _texto("", 19, Color(0.62, 0.86, 1.0))
    _fragmentos_totais.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cab.add_child(_fragmentos_totais)
    var fechar := Button.new()
    fechar.text = "✕  Fechar"
    fechar.custom_minimum_size = Vector2(150, 52)
    fechar.add_theme_font_override("font", load(FONTE_TEXTO))
    fechar.add_theme_font_size_override("font_size", 18)
    fechar.add_theme_stylebox_override("normal", _caixa(Color(0.32, 0.13, 0.15), Color(0.58, 0.28, 0.28)))
    fechar.pressed.connect(func(): mostrar(false))
    cab.add_child(fechar)
    coluna.add_child(cab)
    var explicacao := _texto("Una 5 fragmentos da mesma altura para estabilizar uma nota musical.", 17, Color(0.78, 0.80, 0.88))
    explicacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(explicacao)
    var grade := GridContainer.new()
    grade.columns = 7
    grade.add_theme_constant_override("h_separation", 10)
    grade.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(grade)
    for dados in NOTAS:
        grade.add_child(_cartao(str(dados[0]), str(dados[1]), dados[2]))
    _recado = _texto("", 18, Color(0.96, 0.86, 0.50))
    _recado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_recado)


func _cartao(id: String, nome: String, cor: Color) -> Control:
    var painel := PanelContainer.new()
    painel.custom_minimum_size = Vector2(150, 430)
    painel.add_theme_stylebox_override("panel",
        _caixa(Color(0.07, 0.085, 0.15, 0.95), cor.darkened(0.35), 2, 10))
    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 10)
    margem.add_theme_constant_override("margin_right", 10)
    margem.add_theme_constant_override("margin_top", 14)
    margem.add_theme_constant_override("margin_bottom", 14)
    painel.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_theme_constant_override("separation", 9)
    margem.add_child(coluna)
    var titulo := _texto(nome, 30, cor.lightened(0.18), true)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(titulo)
    var icone := TextureRect.new()
    icone.texture = load(KIT + "item/nota.png")
    icone.custom_minimum_size = Vector2(100, 130)
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icone.modulate = cor
    coluna.add_child(icone)
    var fragmentos := _texto("", 16, Color(0.84, 0.86, 0.92))
    fragmentos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(fragmentos)
    var prontas := _texto("", 16, Color(0.98, 0.90, 0.62))
    prontas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(prontas)
    var vao := Control.new()
    vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(vao)
    var botao := Button.new()
    botao.text = "Sintetizar"
    botao.custom_minimum_size.y = 48
    botao.add_theme_font_override("font", load(FONTE_TEXTO))
    botao.add_theme_font_size_override("font_size", 15)
    botao.add_theme_stylebox_override("normal", _caixa(Color(0.14, 0.22, 0.34), cor.darkened(0.15), 2))
    botao.pressed.connect(_sintetizar.bind(id, nome))
    coluna.add_child(botao)
    _fragmentos[id] = fragmentos
    _prontas[id] = prontas
    _botoes[id] = botao
    return painel


func _sintetizar(id: String, nome: String) -> void:
    if _progresso and _progresso.sintetizar_nota(id):
        _recado.text = "Nota %s sintetizada e enviada ao inventário." % nome
    else:
        _recado.text = "Faltam fragmentos para sintetizar %s." % nome


func _atualizar() -> void:
    if _progresso == null or _fragmentos_totais == null:
        return
    var total := 0
    for altura in ["do", "re", "mi", "fa", "sol", "la", "si"]:
        total += _progresso.quantidade("fragmento_" + altura)
    _fragmentos_totais.text = "Fragmentos: %d" % total
    for dados in NOTAS:
        var id := str(dados[0])
        (_fragmentos[id] as Label).text = "Fragmentos  %d / 5" % _progresso.quantidade("fragmento_" + id)
        (_prontas[id] as Label).text = "Notas prontas  %d" % _progresso.quantidade("nota_" + id)
        (_botoes[id] as Button).disabled = not _progresso.pode_pagar({"fragmento_" + id: 5})


func mostrar(sim := true) -> void:
    visible = sim
    if sim:
        _recado.text = ""
        _atualizar()
