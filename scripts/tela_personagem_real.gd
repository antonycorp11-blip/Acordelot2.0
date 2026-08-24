extends CanvasLayer
## Ficha funcional do Akles. Todos os numeros saem de Progresso; matar Shikers,
## subir de nivel e investir pontos atualiza esta tela e o HUD.

const KIT := "res://textures/ui/kit/"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const ATRIBUTOS := [["forca", "Força"], ["destreza", "Destreza"],
    ["vitalidade", "Vitalidade"], ["ressonancia", "Ressonância"],
    ["percepcao", "Percepção"]]
const COMBATE := [["ataque", "Ataque"], ["defesa", "Defesa"],
    ["vida_maxima", "Vida Máxima"], ["critico", "Chance Crítica"],
    ["dano_critico", "Dano Crítico"], ["poder_harmonico", "Poder Harmônico"],
    ["coleta", "Eficiência de Coleta"]]
const SLOTS_ESQ := ["Amuleto", "Anel I", "Anel II"]
const SLOTS_DIR := ["Broche", "Bracelete", "Talismã"]

var _aberta := false
var _progresso: Node
var _nivel: Label
var _xp_texto: Label
var _xp_barra: ProgressBar
var _pontos: Label
var _valores_atributo := {}
var _botoes_atributo := {}
var _valores_combate := {}
var _slots := {}


func _ready() -> void:
    layer = 16
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
    var fundo := ColorRect.new()
    fundo.color = Color(0.02, 0.02, 0.05, 0.76)
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
    var janela := PanelContainer.new()
    janela.add_theme_stylebox_override("panel",
        _caixa(Color(0.055, 0.07, 0.13, 0.98), Color(0.62, 0.50, 0.26), 2, 12))
    proporcao.add_child(janela)
    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 26)
    margem.add_theme_constant_override("margin_right", 26)
    margem.add_theme_constant_override("margin_top", 18)
    margem.add_theme_constant_override("margin_bottom", 18)
    janela.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 12)
    margem.add_child(coluna)
    coluna.add_child(_cabecalho())
    var corpo := HBoxContainer.new()
    corpo.add_theme_constant_override("separation", 14)
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(corpo)
    corpo.add_child(_coluna_de_acessorios(SLOTS_ESQ))
    corpo.add_child(_retrato())
    corpo.add_child(_coluna_de_acessorios(SLOTS_DIR))
    corpo.add_child(_painel_de_numeros())


func _cabecalho() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 56
    linha.add_child(_texto("Personagem e Atributos", 34, Color(0.97, 0.84, 0.47), true))
    var vao := Control.new()
    vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(vao)
    _pontos = _texto("", 18, Color(0.76, 0.90, 1.0))
    _pontos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(_pontos)
    var fechar := Button.new()
    fechar.text = "✕  Fechar"
    fechar.custom_minimum_size = Vector2(150, 52)
    fechar.add_theme_font_override("font", load(FONTE_TEXTO))
    fechar.add_theme_font_size_override("font_size", 19)
    fechar.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    fechar.add_theme_stylebox_override("normal", _caixa(Color(0.32, 0.13, 0.15), Color(0.58, 0.28, 0.28)))
    fechar.pressed.connect(func(): mostrar(false))
    linha.add_child(fechar)
    return linha


func _coluna_de_acessorios(quais: Array) -> Control:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 126
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_theme_constant_override("separation", 12)
    for nome in quais:
        var caixa := VBoxContainer.new()
        var slot := Panel.new()
        slot.custom_minimum_size = Vector2(98, 98)
        slot.add_theme_stylebox_override("panel",
            _caixa(Color(0.09, 0.11, 0.18, 0.92), Color(0.38, 0.34, 0.25), 2))
        caixa.add_child(slot)
        var icone := TextureRect.new()
        icone.set_anchors_preset(Control.PRESET_FULL_RECT)
        icone.offset_left = 10
        icone.offset_top = 10
        icone.offset_right = -10
        icone.offset_bottom = -10
        icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(icone)
        var item_nome := _texto("Vazio", 11, Color(0.62, 0.64, 0.72))
        item_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        item_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        caixa.add_child(item_nome)
        var rotulo := _texto(str(nome), 12, Color(0.88, 0.80, 0.58))
        rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caixa.add_child(rotulo)
        coluna.add_child(caixa)
        _slots[nome] = [slot, icone, item_nome]
    return coluna


func _retrato() -> Control:
    var area := Control.new()
    area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var chao := PanelContainer.new()
    chao.set_anchors_preset(Control.PRESET_FULL_RECT)
    chao.add_theme_stylebox_override("panel",
        _caixa(Color(0.04, 0.055, 0.10, 0.88), Color(0.30, 0.26, 0.18), 1, 10))
    area.add_child(chao)
    var figura := TextureRect.new()
    figura.texture = load("res://textures/dialogo/akles_corpo.png")
    figura.set_anchors_preset(Control.PRESET_FULL_RECT)
    figura.offset_top = 4
    figura.offset_bottom = -86
    figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    figura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    area.add_child(figura)
    var faixa := VBoxContainer.new()
    faixa.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    faixa.offset_top = -92
    faixa.offset_bottom = -10
    area.add_child(faixa)
    var nome := _texto("Akles", 27, Color(0.97, 0.86, 0.52), true)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    faixa.add_child(nome)
    _nivel = _texto("", 14, Color(0.82, 0.84, 0.92))
    _nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    faixa.add_child(_nivel)
    _xp_barra = ProgressBar.new()
    _xp_barra.custom_minimum_size.y = 18
    _xp_barra.show_percentage = false
    _xp_barra.add_theme_stylebox_override("background", _caixa(Color(0.04, 0.05, 0.09), Color(0.28, 0.25, 0.20), 1, 4))
    _xp_barra.add_theme_stylebox_override("fill", _caixa(Color(0.25, 0.55, 0.90), Color(0.45, 0.72, 1.0), 1, 4))
    faixa.add_child(_xp_barra)
    _xp_texto = _texto("", 12, Color(0.88, 0.91, 1.0))
    _xp_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    faixa.add_child(_xp_texto)
    return area


func _painel_de_numeros() -> Control:
    var area := PanelContainer.new()
    area.custom_minimum_size.x = 345
    area.add_theme_stylebox_override("panel",
        _caixa(Color(0.04, 0.055, 0.10, 0.88), Color(0.30, 0.26, 0.18), 1, 10))
    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 14)
    margem.add_theme_constant_override("margin_right", 14)
    margem.add_theme_constant_override("margin_top", 14)
    margem.add_theme_constant_override("margin_bottom", 14)
    area.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 3)
    margem.add_child(coluna)
    coluna.add_child(_texto("Atributos", 19, Color(0.95, 0.83, 0.48), true))
    for dados in ATRIBUTOS:
        coluna.add_child(_linha_atributo(str(dados[0]), str(dados[1])))
    coluna.add_child(HSeparator.new())
    coluna.add_child(_texto("Estatísticas", 19, Color(0.95, 0.83, 0.48), true))
    for dados in COMBATE:
        coluna.add_child(_linha_estatistica(str(dados[0]), str(dados[1])))
    return area


func _linha_atributo(id: String, nome: String) -> Control:
    var linha := HBoxContainer.new()
    var rotulo := _texto(nome, 15, Color(0.80, 0.82, 0.88))
    rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(rotulo)
    var valor := _texto("0", 17, Color(0.98, 0.94, 0.80))
    valor.custom_minimum_size.x = 42
    valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    linha.add_child(valor)
    var mais := Button.new()
    mais.text = "+"
    mais.custom_minimum_size = Vector2(30, 28)
    mais.tooltip_text = "Investir um ponto em " + nome
    mais.pressed.connect(_investir.bind(id))
    linha.add_child(mais)
    _valores_atributo[id] = valor
    _botoes_atributo[id] = mais
    return linha


func _linha_estatistica(id: String, nome: String) -> Control:
    var linha := HBoxContainer.new()
    var rotulo := _texto(nome, 14, Color(0.76, 0.78, 0.85))
    rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(rotulo)
    var valor := _texto("0", 15, Color(0.92, 0.90, 0.78))
    valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    linha.add_child(valor)
    _valores_combate[id] = valor
    return linha


func _investir(id: String) -> void:
    if _progresso:
        _progresso.investir_atributo(id)


func _atualizar() -> void:
    if _progresso == null or _nivel == null:
        return
    _nivel.text = "Espadachim da Harmonia  ·  Nível %d" % _progresso.nivel
    _xp_barra.max_value = _progresso.xp_para_nivel()
    _xp_barra.value = _progresso.experiencia
    _xp_texto.text = "%d / %d XP" % [_progresso.experiencia, _progresso.xp_para_nivel()]
    _pontos.text = "Pontos disponíveis: %d" % _progresso.pontos_de_atributo
    for dados in ATRIBUTOS:
        var id := str(dados[0])
        (_valores_atributo[id] as Label).text = str(_progresso.valor_atributo(id))
        (_botoes_atributo[id] as Button).disabled = _progresso.pontos_de_atributo <= 0
    var stats: Dictionary = _progresso.estatisticas()
    for dados in COMBATE:
        var id := str(dados[0])
        var valor = stats.get(id, 0)
        var texto := str(int(valor))
        if id in ["critico", "dano_critico", "coleta"]:
            texto = "%.1f%%" % float(valor)
        (_valores_combate[id] as Label).text = texto
    for slot in _slots:
        var partes: Array = _slots[slot]
        var item: Dictionary = _progresso.acessorio_no_slot(str(slot))
        var painel := partes[0] as Panel
        var icone := partes[1] as TextureRect
        var nome := partes[2] as Label
        if item.is_empty():
            icone.texture = null
            nome.text = "Vazio"
            painel.add_theme_stylebox_override("panel",
                _caixa(Color(0.09, 0.11, 0.18, 0.92), Color(0.30, 0.30, 0.34), 1))
        else:
            icone.texture = load(KIT + str(item.get("arte", "equip/anel")) + ".png")
            nome.text = str(item.get("nome", "Acessório"))
            painel.add_theme_stylebox_override("panel",
                _caixa(Color(0.09, 0.11, 0.18, 0.92), Color(0.42, 0.64, 0.92), 2))


func mostrar(sim := true) -> void:
    _aberta = sim
    visible = sim
    if sim:
        _atualizar()


func esta_aberta() -> bool:
    return _aberta
