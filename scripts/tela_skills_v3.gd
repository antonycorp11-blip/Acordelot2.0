extends "res://scripts/tela_skills.gd"
## V3 visual das Trilhas. A progressão, pontos e limites continuam no script
## original; esta camada organiza quatro cartas verticais e o detalhe lateral.

const FUNDO_V3 := "res://textures/ui/harmonia_celestial_v3.jpg"
const OURO := Color(0.94, 0.79, 0.42)
const AZUL := Color(0.30, 0.72, 1.0)

var _icone_detalhe_v3: TextureRect
var _status_cartas_v3 := {}


func _ready() -> void:
    super._ready()
    layer = 120


func _painel_v3(fundo := Color(0.015, 0.04, 0.078, 0.90), borda := Color(0.29, 0.43, 0.56), raio := 12) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _caixa(fundo, borda, 1, raio))
    return p


func _montar() -> void:
    var sombra := ColorRect.new()
    sombra.color = Color(0.002, 0.005, 0.014, 0.95)
    sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
    sombra.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(sombra)
    _base = Control.new()
    _base.size = TAMANHO
    sombra.add_child(_base)
    var arte := TextureRect.new()
    arte.texture = load(FUNDO_V3)
    arte.set_anchors_preset(Control.PRESET_FULL_RECT)
    arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    arte.stretch_mode = TextureRect.STRETCH_SCALE
    arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _base.add_child(arte)
    var margem := MarginContainer.new()
    margem.set_anchors_preset(Control.PRESET_FULL_RECT)
    margem.add_theme_constant_override("margin_left", 44)
    margem.add_theme_constant_override("margin_right", 44)
    margem.add_theme_constant_override("margin_top", 24)
    margem.add_theme_constant_override("margin_bottom", 30)
    _base.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 11)
    margem.add_child(coluna)
    coluna.add_child(_cabecalho_v3())
    var chamada := _texto("—  Escolha um caminho. A harmonia que você aprimora hoje molda o amanhã.  —", 16, Color(0.76, 0.78, 0.85))
    chamada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(chamada)
    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 16)
    coluna.add_child(corpo)
    corpo.add_child(_cartas_v3())
    corpo.add_child(_detalhes_v3())
    _atualizar()


func _cabecalho_v3() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 72
    var titulo := VBoxContainer.new()
    titulo.custom_minimum_size.x = 330
    linha.add_child(titulo)
    titulo.add_child(_texto("♫  TALENTOS", 29, OURO, true))
    titulo.add_child(_texto("TRILHAS DE RESSONÂNCIA", 12, Color(0.67, 0.54, 0.32)))
    var elenco := HBoxContainer.new()
    elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    elenco.alignment = BoxContainer.ALIGNMENT_CENTER
    elenco.add_theme_constant_override("separation", 12)
    linha.add_child(elenco)
    for i in 10:
        elenco.add_child(_retrato_v3(i == 4))
    _fechar = _botao("×", 58)
    _fechar.custom_minimum_size.y = 58
    _fechar.add_theme_font_size_override("font_size", 30)
    linha.add_child(_fechar)
    return linha


func _retrato_v3(atual := false) -> Control:
    var p := PanelContainer.new()
    p.clip_contents = true
    p.custom_minimum_size = Vector2(56, 56)
    p.add_theme_stylebox_override("panel", _caixa(Color(0.022, 0.05, 0.095, 0.95), AZUL if atual else Color(0.36, 0.30, 0.22), 2 if atual else 1, 28))
    if atual:
        var recorte := AtlasTexture.new()
        recorte.atlas = load("res://textures/dialogo/akles.png")
        recorte.region = Rect2(0, 0, 102, 177)
        var retrato := TextureRect.new()
        retrato.texture = recorte
        retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        p.add_child(retrato)
    else:
        var vazio := _texto("·", 27, Color(0.28, 0.35, 0.45))
        vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vazio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        p.add_child(vazio)
    return p


func _cartas_v3() -> Control:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 1030
    coluna.add_theme_constant_override("separation", 10)
    var grade := GridContainer.new()
    grade.columns = 4
    grade.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grade.add_theme_constant_override("h_separation", 12)
    coluna.add_child(grade)
    for dados in SKILLS:
        grade.add_child(_carta_v3(dados))
    var rodape := _painel_v3(Color(0.02, 0.045, 0.085, 0.94), Color(0.39, 0.32, 0.21), 8)
    rodape.custom_minimum_size.y = 58
    coluna.add_child(rodape)
    _pontos = _texto("", 18, Color(0.57, 0.82, 1.0), true)
    _pontos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _pontos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    rodape.add_child(_pontos)
    return coluna


func _carta_v3(dados: Dictionary) -> Control:
    var id := str(dados["id"])
    var b := _botao(str(dados["nome"]), 248)
    b.custom_minimum_size.y = 590
    b.toggle_mode = true
    b.add_theme_stylebox_override("normal", _caixa(Color(0.018, 0.04, 0.078, 0.91), Color(0.38, 0.31, 0.21), 1, 12))
    b.add_theme_stylebox_override("pressed", _caixa(Color(0.035, 0.09, 0.16, 0.96), OURO, 2, 12))
    var pilha := VBoxContainer.new()
    pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
    pilha.offset_left = 14
    pilha.offset_right = -14
    pilha.offset_top = 66
    pilha.offset_bottom = -16
    pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pilha.add_theme_constant_override("separation", 9)
    b.add_child(pilha)
    var aro := PanelContainer.new()
    aro.custom_minimum_size.y = 188
    aro.add_theme_stylebox_override("panel", _caixa(Color(0.018, 0.07, 0.14, 0.82), Color(0.40, 0.61, 0.82), 2, 94))
    pilha.add_child(aro)
    var icone := TextureRect.new()
    icone.texture = load(str(dados["icone"]))
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    aro.add_child(icone)
    var nome := _texto(str(dados["nome"]).to_upper(), 17, OURO, true)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    pilha.add_child(nome)
    var status := _texto("", 13, Color(0.55, 0.82, 1.0))
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pilha.add_child(status)
    _status_cartas_v3[id] = status
    var desc := _texto(str(dados["desc"]), 14, Color(0.75, 0.79, 0.87))
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    pilha.add_child(desc)
    var marcos := _texto("◇        ◇        ◇\nNV.3     NV.6     NV.9", 14, Color(0.48, 0.74, 1.0), true)
    marcos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pilha.add_child(marcos)
    _botoes[id] = b
    return b


func _detalhes_v3() -> Control:
    var painel := _painel_v3(Color(0.018, 0.045, 0.085, 0.94), Color(0.42, 0.34, 0.22), 13)
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 11)
    painel.add_child(coluna)
    _icone_detalhe_v3 = TextureRect.new()
    _icone_detalhe_v3.custom_minimum_size.y = 170
    _icone_detalhe_v3.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icone_detalhe_v3.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coluna.add_child(_icone_detalhe_v3)
    _titulo = _texto("", 28, OURO, true)
    _titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_titulo)
    _nivel = _texto("", 16, Color(0.55, 0.84, 1.0))
    _nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_nivel)
    _descricao = _texto("", 16, Color(0.80, 0.83, 0.89))
    _descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_descricao)
    coluna.add_child(_texto("MARCOS PASSIVOS", 18, Color(0.86, 0.70, 0.96), true))
    for marco in [3, 6, 9]:
        var l := _texto("", 15, Color(0.52, 0.56, 0.62))
        coluna.add_child(l)
        _marcos.append(l)
    var aviso := _texto("Os efeitos finais de cada passiva serão definidos sem alterar esta progressão.", 13, Color(0.65, 0.68, 0.74))
    aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(aviso)
    var vao := Control.new()
    vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(vao)
    _upar = _botao("APRIMORAR", 380)
    _upar.custom_minimum_size.y = 58
    _upar.add_theme_stylebox_override("normal", _caixa(Color(0.27, 0.20, 0.07, 0.96), OURO, 2, 10))
    coluna.add_child(_upar)
    return painel


func _atualizar() -> void:
    super._atualizar()
    if _icone_detalhe_v3:
        _icone_detalhe_v3.texture = load(str(_dados_atuais()["icone"]))
    if _progresso:
        for id in _botoes:
            # A carta já tem título próprio; o texto nativo do Button ficava
            # duplicado sobre a descrição após a atualização do nível.
            (_botoes[id] as Button).text = ""
            var nivel_skill := int(_progresso.niveis_skills.get(id, 1))
            var requisito := int(_progresso.NIVEIS_DESBLOQUEIO_SKILLS.get(id, 1))
            (_status_cartas_v3[id] as Label).text = "NÍVEL %d / %d" % [nivel_skill, _progresso.NIVEL_MAXIMO_SKILL] if _progresso.nivel >= requisito else "DESBLOQUEIA NO NÍVEL %d" % requisito


func mostrar(sim := true) -> void:
    super.mostrar(sim)
    if sim and _base:
        _base.modulate.a = 0.0
        create_tween().tween_property(_base, "modulate:a", 1.0, 0.22)
