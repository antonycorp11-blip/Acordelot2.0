extends "res://scripts/tela_personagem_real.gd"
## Apresentação V3 da ficha. Herda toda a progressão funcional da ficha
## anterior e troca somente a composição visual e a navegação entre subtelas.

signal tela_pedida(qual: String)

const FUNDO_V3 := "res://textures/ui/harmonia_celestial_v3.jpg"
const OURO := Color(0.94, 0.79, 0.42)
const AZUL := Color(0.30, 0.72, 1.0)
const ABAS_V3 := [["atributos", "♫", "Atributos"], ["arma", "⚔", "Arma"],
    ["acessorios", "◈", "Acessórios"], ["talentos", "✦", "Talentos"],
    ["perfil", "♙", "Perfil"]]

var _paginas_v3 := {}
var _abas_v3 := {}
var _aba_v3 := "atributos"
var _fechar_v3: Button
var _abrir_talentos: Button
var _abrir_sintese: Button
var _arma_detalhe: Label


func _ready() -> void:
    super._ready()
    # Acima do nome da zona, HUD e qualquer aviso do mundo.
    layer = 120


func _painel_v3(fundo := Color(0.015, 0.04, 0.078, 0.88), borda := Color(0.30, 0.43, 0.56, 0.90), raio := 12) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _caixa(fundo, borda, 1, raio))
    return p


func _botao_v3(valor: String, largura := 150.0, dourado := false) -> Button:
    var b := Button.new()
    b.text = valor
    b.custom_minimum_size = Vector2(largura, 50)
    b.add_theme_font_override("font", load(FONTE_TEXTO))
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_color_override("font_color", Color(0.97, 0.92, 0.79))
    var fundo := Color(0.27, 0.20, 0.07, 0.96) if dourado else Color(0.025, 0.065, 0.12, 0.94)
    var borda := OURO if dourado else Color(0.27, 0.48, 0.66)
    b.add_theme_stylebox_override("normal", _caixa(fundo, borda, 1, 8))
    b.add_theme_stylebox_override("hover", _caixa(fundo.lightened(0.10), borda.lightened(0.14), 2, 8))
    b.add_theme_stylebox_override("pressed", _caixa(fundo.darkened(0.08), AZUL, 2, 8))
    b.add_theme_stylebox_override("disabled", _caixa(Color(0.02, 0.025, 0.04, 0.84), Color(0.16, 0.17, 0.20), 1, 8))
    return b


func _montar() -> void:
    var bloqueio := ColorRect.new()
    bloqueio.color = Color(0.002, 0.005, 0.014, 0.95)
    bloqueio.set_anchors_preset(Control.PRESET_FULL_RECT)
    bloqueio.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(bloqueio)
    _base_layout = Control.new()
    _base_layout.size = TAMANHO_LAYOUT
    bloqueio.add_child(_base_layout)
    var fundo := TextureRect.new()
    fundo.texture = load(FUNDO_V3)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    fundo.stretch_mode = TextureRect.STRETCH_SCALE
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _base_layout.add_child(fundo)

    var margem := MarginContainer.new()
    margem.set_anchors_preset(Control.PRESET_FULL_RECT)
    margem.add_theme_constant_override("margin_left", 42)
    margem.add_theme_constant_override("margin_right", 42)
    margem.add_theme_constant_override("margin_top", 24)
    margem.add_theme_constant_override("margin_bottom", 28)
    _base_layout.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 12)
    margem.add_child(coluna)
    coluna.add_child(_cabecalho_v3())
    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 15)
    coluna.add_child(corpo)
    corpo.add_child(_menu_v3())
    corpo.add_child(_palco_v3())
    corpo.add_child(_paginas_container_v3())
    _celebracao = CelebracaoScript.new()
    add_child(_celebracao)


func _cabecalho_v3() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 74
    linha.add_theme_constant_override("separation", 14)
    var titulo := _texto("♫  PERSONAGEM", 30, OURO, true)
    titulo.custom_minimum_size.x = 305
    titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(titulo)
    var elenco := HBoxContainer.new()
    elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    elenco.alignment = BoxContainer.ALIGNMENT_CENTER
    elenco.add_theme_constant_override("separation", 12)
    linha.add_child(elenco)
    for i in 10:
        elenco.add_child(_retrato_vazio_v3(i == 4))
    _fechar_v3 = _botao_v3("×", 58)
    _fechar_v3.custom_minimum_size.y = 58
    _fechar_v3.add_theme_font_size_override("font_size", 30)
    _fechar_v3.tooltip_text = "Fechar"
    _fechar_v3.pressed.connect(func(): mostrar(false))
    linha.add_child(_fechar_v3)
    return linha


func _retrato_vazio_v3(atual := false) -> Control:
    var p := PanelContainer.new()
    p.clip_contents = true
    p.custom_minimum_size = Vector2(58, 58)
    p.add_theme_stylebox_override("panel", _caixa(Color(0.022, 0.05, 0.095, 0.95), AZUL if atual else Color(0.36, 0.30, 0.22), 2 if atual else 1, 29))
    if atual:
        var recorte := AtlasTexture.new()
        recorte.atlas = load("res://textures/dialogo/akles.png")
        recorte.region = Rect2(0, 0, 102, 177)
        var retrato := TextureRect.new()
        retrato.texture = recorte
        retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
        p.add_child(retrato)
    else:
        var vazio := _texto("·", 28, Color(0.27, 0.34, 0.44))
        vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vazio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        p.add_child(vazio)
    return p


func _menu_v3() -> Control:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 225
    coluna.add_theme_constant_override("separation", 13)
    for dados in ABAS_V3:
        var b := _botao_v3(str(dados[2]), 220)
        b.custom_minimum_size.y = 62
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        var icone: String = str({"atributos":"nav/personagem.png", "arma":"equip/espada.png",
            "acessorios":"equip/anel.png", "talentos":"nav/talentos.png",
            "perfil":"nav/personagem.png"}.get(str(dados[0]), "nav/personagem.png"))
        b.icon = load(KIT + icone)
        b.expand_icon = true
        b.add_theme_constant_override("icon_max_width", 30)
        b.toggle_mode = true
        b.set_meta("aba", dados[0])
        b.pressed.connect(_mudar_aba_v3.bind(str(dados[0])))
        coluna.add_child(b)
        _abas_v3[dados[0]] = b
    var espaco := Control.new()
    espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(espaco)
    var musica := _painel_v3(Color(0.018, 0.045, 0.085, 0.90), Color(0.43, 0.36, 0.22))
    musica.custom_minimum_size.y = 78
    var ml := _texto("♫\nMúsicas", 15, OURO)
    ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    musica.add_child(ml)
    coluna.add_child(musica)
    return coluna


func _palco_v3() -> Control:
    var palco := _painel_v3(Color(0.012, 0.035, 0.078, 0.46), Color(0.30, 0.55, 0.73, 0.82), 15)
    palco.custom_minimum_size.x = 570
    palco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var base := Control.new()
    palco.add_child(base)
    var brilho := _texto("✦          ♫          ✦", 28, Color(0.30, 0.68, 1.0, 0.75), true)
    brilho.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    brilho.offset_top = -208
    brilho.offset_bottom = -158
    brilho.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    base.add_child(brilho)
    var figura := TextureRect.new()
    figura.texture = load("res://textures/dialogo/akles_corpo.png")
    figura.set_anchors_preset(Control.PRESET_FULL_RECT)
    figura.offset_left = 30
    figura.offset_right = -30
    figura.offset_top = 4
    figura.offset_bottom = -142
    figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    figura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    base.add_child(figura)
    var faixa := _painel_v3(Color(0.014, 0.03, 0.06, 0.95), Color(0.48, 0.39, 0.22), 8)
    faixa.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    faixa.offset_left = 22
    faixa.offset_right = -22
    faixa.offset_top = -136
    faixa.offset_bottom = -16
    base.add_child(faixa)
    var dados := VBoxContainer.new()
    dados.add_theme_constant_override("separation", 4)
    faixa.add_child(dados)
    var classe := _texto("ESPADACHIM DA HARMONIA", 18, OURO, true)
    classe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dados.add_child(classe)
    _arma = _texto("", 15, Color(0.82, 0.87, 0.94))
    _arma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dados.add_child(_arma)
    _eco = _texto("", 13, Color(0.50, 0.80, 1.0))
    _eco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dados.add_child(_eco)
    return palco


func _paginas_container_v3() -> Control:
    var pilha := Control.new()
    pilha.custom_minimum_size.x = 690
    pilha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var dados := [["atributos", _pagina_atributos_v3()], ["arma", _pagina_arma_v3()],
        ["acessorios", _pagina_acessorios_v3()], ["talentos", _pagina_talentos_v3()],
        ["perfil", _pagina_perfil_v3()]]
    for par in dados:
        var pagina := par[1] as Control
        pagina.set_anchors_preset(Control.PRESET_FULL_RECT)
        pilha.add_child(pagina)
        _paginas_v3[par[0]] = pagina
    call_deferred("_mudar_aba_v3", "atributos")
    return pilha


func _identidade_v3() -> Control:
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 4)
    var topo := HBoxContainer.new()
    coluna.add_child(topo)
    var nome := _texto("Akles", 34, Color(0.98, 0.91, 0.72), true)
    nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topo.add_child(nome)
    var bloco := VBoxContainer.new()
    topo.add_child(bloco)
    var pt := _texto("PODER DE LUTA", 12, Color(0.57, 0.75, 0.90))
    pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bloco.add_child(pt)
    _poder_total = _texto("0", 30, OURO, true)
    _poder_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bloco.add_child(_poder_total)
    _nivel = _texto("", 19, Color(0.92, 0.88, 0.75))
    coluna.add_child(_nivel)
    _xp_barra = ProgressBar.new()
    _xp_barra.custom_minimum_size.y = 15
    _xp_barra.show_percentage = false
    _xp_barra.add_theme_stylebox_override("background", _caixa(Color(0.014, 0.022, 0.04), Color(0.24, 0.33, 0.44), 1, 6))
    _xp_barra.add_theme_stylebox_override("fill", _caixa(Color(0.10, 0.42, 0.72), AZUL, 1, 6))
    coluna.add_child(_xp_barra)
    _xp_texto = _texto("", 12, Color(0.70, 0.79, 0.88))
    _xp_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    coluna.add_child(_xp_texto)
    return coluna


func _pagina_atributos_v3() -> Control:
    var painel := _painel_v3()
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 8)
    painel.add_child(coluna)
    coluna.add_child(_identidade_v3())
    var divisao := HBoxContainer.new()
    divisao.size_flags_vertical = Control.SIZE_EXPAND_FILL
    divisao.add_theme_constant_override("separation", 17)
    coluna.add_child(divisao)
    var atributos := VBoxContainer.new()
    atributos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    atributos.add_child(_texto("ATRIBUTOS", 20, OURO, true))
    for dados in ATRIBUTOS:
        atributos.add_child(_linha_atributo(str(dados[0]), str(dados[1])))
    divisao.add_child(atributos)
    var stats := VBoxContainer.new()
    stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats.add_child(_texto("ESTATÍSTICAS", 20, OURO, true))
    for dados in COMBATE:
        var linha := HBoxContainer.new()
        var nome := _texto(str(dados[1]), 14, Color(0.73, 0.78, 0.86))
        nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        linha.add_child(nome)
        var valor := _texto("0", 15, Color(0.95, 0.88, 0.66))
        linha.add_child(valor)
        _valores_combate[dados[0]] = valor
        stats.add_child(linha)
    divisao.add_child(stats)
    _ascensao = _texto("", 13, Color(0.76, 0.68, 0.92))
    _ascensao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_ascensao)
    var acoes := HBoxContainer.new()
    acoes.alignment = BoxContainer.ALIGNMENT_END
    coluna.add_child(acoes)
    _pontos = _texto("", 15, Color(0.55, 0.82, 1.0))
    _pontos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _pontos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    acoes.add_child(_pontos)
    _botao_subir_nivel = _botao_v3("SUBIR NÍVEL", 230, true)
    _botao_subir_nivel.pressed.connect(_subir_nivel)
    acoes.add_child(_botao_subir_nivel)
    _abrir_sintese = _botao_v3("ASCENSÃO", 165, true)
    _abrir_sintese.pressed.connect(func(): tela_pedida.emit("sintese"))
    acoes.add_child(_abrir_sintese)
    return painel


func _pagina_arma_v3() -> Control:
    var painel := _painel_v3()
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 16)
    painel.add_child(coluna)
    coluna.add_child(_texto("ARMA", 27, OURO, true))
    var faixa := HBoxContainer.new()
    faixa.add_theme_constant_override("separation", 25)
    coluna.add_child(faixa)
    var icone := TextureRect.new()
    icone.texture = load(KIT + "equip/espada.png")
    icone.custom_minimum_size = Vector2(200, 260)
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    faixa.add_child(icone)
    var dados := VBoxContainer.new()
    dados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dados.alignment = BoxContainer.ALIGNMENT_CENTER
    faixa.add_child(dados)
    _arma_detalhe = _texto("", 25, Color(0.96, 0.86, 0.58), true)
    _arma_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dados.add_child(_arma_detalhe)
    dados.add_child(_texto("Espada leve de uma mão\nFonte principal do estilo de combate de Akles.", 17, Color(0.76, 0.82, 0.90)))
    var bonus := _painel_v3(Color(0.025, 0.055, 0.095, 0.92), Color(0.28, 0.51, 0.72))
    coluna.add_child(bonus)
    var bt := _texto("BÔNUS DA ARMA\nAtaque base  •  Poder de luta  •  Escala com o nível da arma", 18, Color(0.65, 0.84, 1.0), true)
    bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bonus.add_child(bt)
    var aviso := _texto("A arma poderá ser trocada. Os outros espaços de equipamento são acessórios não visuais.", 15, Color(0.70, 0.73, 0.80))
    aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(aviso)
    return painel


func _pagina_acessorios_v3() -> Control:
    var painel := _painel_v3()
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 12)
    painel.add_child(coluna)
    coluna.add_child(_texto("ACESSÓRIOS", 27, OURO, true))
    coluna.add_child(_texto("Equipamentos de ressonância — não alteram a aparência de Akles", 14, Color(0.64, 0.77, 0.88)))
    var grade := GridContainer.new()
    grade.columns = 3
    grade.add_theme_constant_override("h_separation", 10)
    grade.add_theme_constant_override("v_separation", 12)
    coluna.add_child(grade)
    for slot in SLOTS:
        var item := _slot_acessorio(slot)
        item.custom_minimum_size = Vector2(205, 210)
        grade.add_child(item)
    return painel


func _pagina_talentos_v3() -> Control:
    var painel := _painel_v3()
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 14)
    painel.add_child(coluna)
    coluna.add_child(_texto("TALENTOS", 27, OURO, true))
    coluna.add_child(_texto("TRILHAS DE RESSONÂNCIA", 20, Color(0.58, 0.82, 1.0), true))
    _skills = _texto("", 17, Color(0.82, 0.84, 0.90))
    _skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(_skills)
    for nome in ["Cadência da Espada", "Aura Azul", "Lâmina Crescente", "Raio Harmônico"]:
        var linha := _painel_v3(Color(0.025, 0.055, 0.095, 0.90), Color(0.25, 0.43, 0.58), 8)
        linha.add_child(_texto("✦  " + nome + "    ◇ Nv.3    ◇ Nv.6    ◇ Nv.9", 16, Color(0.78, 0.86, 0.95)))
        coluna.add_child(linha)
    var vao := Control.new()
    vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(vao)
    _abrir_talentos = _botao_v3("ABRIR TRILHAS DE RESSONÂNCIA", 390, true)
    _abrir_talentos.pressed.connect(func(): tela_pedida.emit("talentos"))
    coluna.add_child(_abrir_talentos)
    return painel


func _pagina_perfil_v3() -> Control:
    var painel := _painel_v3()
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 10)
    painel.add_child(coluna)
    coluna.add_child(_texto("PERFIL HARMÔNICO", 27, OURO, true))
    _poder_conta = _texto("", 25, Color(0.50, 0.82, 1.0), true)
    coluna.add_child(_poder_conta)
    coluna.add_child(_texto("Akles — Espadachim da Harmonia\nO Poder da Conta soma todas as fontes de poder de todos os personagens.", 15, Color(0.76, 0.80, 0.87)))
    coluna.add_child(_texto("COMO O PODER DE LUTA É CALCULADO", 19, Color(0.88, 0.68, 0.96), true))
    for dados in [["nivel", "Nível"], ["atributos", "Atributos"], ["arma", "Arma"],
            ["acessorios", "Acessórios"], ["eco", "Eco equipado"],
            ["composicao", "Composição"], ["skills", "Skills"]]:
        var linha := HBoxContainer.new()
        var formula := _texto(str(dados[1]), 15, Color(0.72, 0.76, 0.84))
        formula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        linha.add_child(formula)
        var valor := _texto("+0", 16, OURO)
        linha.add_child(valor)
        _linhas_poder[dados[0]] = [formula, valor]
        coluna.add_child(linha)
    _composicao = _texto("", 14, Color(0.76, 0.70, 0.92))
    coluna.add_child(_composicao)
    return painel


func _mudar_aba_v3(qual: String) -> void:
    _aba_v3 = qual
    for id in _paginas_v3:
        (_paginas_v3[id] as Control).visible = str(id) == qual
    for id in _abas_v3:
        var b := _abas_v3[id] as Button
        var ativo := str(id) == qual
        b.button_pressed = ativo
        b.add_theme_stylebox_override("normal", _caixa(Color(0.05, 0.18, 0.33, 0.97) if ativo else Color(0.025, 0.055, 0.10, 0.88), AZUL if ativo else Color(0.25, 0.35, 0.45), 2 if ativo else 1, 8))


func _atualizar() -> void:
    super._atualizar()
    if _progresso == null or _arma_detalhe == null:
        return
    _arma_detalhe.text = "%s\nNÍVEL DA ARMA %d" % [_progresso.arma_equipada, _progresso.nivel_da_arma]
    if _abrir_sintese:
        _abrir_sintese.visible = _progresso.esta_em_trava_de_ascensao()


func mostrar(sim := true) -> void:
    super.mostrar(sim)
    if sim and _base_layout:
        _base_layout.modulate.a = 0.0
        create_tween().tween_property(_base_layout, "modulate:a", 1.0, 0.22)


func _input(event: InputEvent) -> void:
    if not _aberta:
        return
    var pos := Vector2.ZERO
    if event is InputEventScreenTouch and event.pressed:
        pos = event.position
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        pos = event.position
    else:
        return
    if _fechar_v3.get_global_rect().has_point(pos):
        mostrar(false)
        get_viewport().set_input_as_handled()
        return
    for id in _abas_v3:
        if (_abas_v3[id] as Button).get_global_rect().has_point(pos):
            _mudar_aba_v3(str(id))
            get_viewport().set_input_as_handled()
            return
    if _botao_subir_nivel and _botao_subir_nivel.visible and _botao_subir_nivel.get_global_rect().has_point(pos):
        _subir_nivel()
        get_viewport().set_input_as_handled()
        return
    if _abrir_sintese and _abrir_sintese.visible and _abrir_sintese.get_global_rect().has_point(pos):
        tela_pedida.emit("sintese")
        get_viewport().set_input_as_handled()
        return
    if _abrir_talentos and _abrir_talentos.visible and _abrir_talentos.get_global_rect().has_point(pos):
        tela_pedida.emit("talentos")
        get_viewport().set_input_as_handled()
        return
    for id in _botoes_atributo:
        var b := _botoes_atributo[id] as Button
        if b.visible and b.get_global_rect().has_point(pos):
            _investir(str(id))
            get_viewport().set_input_as_handled()
            return
