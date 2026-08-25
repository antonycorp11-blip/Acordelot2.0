extends "res://scripts/tela_sintese.gd"
## V3 do Ateliê. Conserva as receitas e o roteamento de toque já validados e
## apresenta as duas telas da referência com hierarquia e contagem claras.

const FUNDO_V3 := "res://textures/ui/harmonia_celestial_v3.jpg"
const OURO := Color(0.94, 0.79, 0.42)
const AZUL := Color(0.30, 0.72, 1.0)

var _nivel_v3: Label
var _xp_v3: Label
var _xp_barra_v3: ProgressBar
var _marcos_v3: Label
var _nome_notas_v3 := {}
var _contagem_notas_v3 := {}


func _ready() -> void:
    super._ready()
    layer = 120


func _painel_v3(fundo := Color(0.015, 0.04, 0.078, 0.90), borda := Color(0.30, 0.43, 0.56), raio := 11) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _caixa(fundo, borda, 1, raio))
    return p


func _montar() -> void:
    var sombra := ColorRect.new()
    sombra.color = Color(0.002, 0.005, 0.014, 0.95)
    sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
    sombra.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(sombra)
    _base_layout = Control.new()
    _base_layout.size = TAMANHO_LAYOUT
    sombra.add_child(_base_layout)
    var arte := TextureRect.new()
    arte.texture = load(FUNDO_V3)
    arte.set_anchors_preset(Control.PRESET_FULL_RECT)
    arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    arte.stretch_mode = TextureRect.STRETCH_SCALE
    arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _base_layout.add_child(arte)
    var margem := MarginContainer.new()
    margem.set_anchors_preset(Control.PRESET_FULL_RECT)
    margem.add_theme_constant_override("margin_left", 38)
    margem.add_theme_constant_override("margin_right", 38)
    margem.add_theme_constant_override("margin_top", 22)
    margem.add_theme_constant_override("margin_bottom", 26)
    _base_layout.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 8)
    margem.add_child(coluna)
    coluna.add_child(_cabecalho_v3())
    coluna.add_child(_abas_v3())
    _recado = _texto("", 16, Color(0.68, 0.86, 1.0))
    _recado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _recado.custom_minimum_size.y = 24
    coluna.add_child(_recado)
    _painel_notas = _notas_v3()
    _painel_notas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(_painel_notas)
    _painel_partituras = _partituras_v3()
    _painel_partituras.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(_painel_partituras)
    _celebracao = CelebracaoScript.new()
    add_child(_celebracao)


func _cabecalho_v3() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 65
    var titulo := VBoxContainer.new()
    titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(titulo)
    titulo.add_child(_texto("♫  ATELIÊ DE SÍNTESE", 30, OURO, true))
    titulo.add_child(_texto("NOTAS, PARTITURAS E ASCENSÃO HARMÔNICA", 12, Color(0.63, 0.69, 0.79)))
    _claves = _texto("", 18, OURO)
    _claves.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(_claves)
    _resumo = _texto("", 14, Color(0.65, 0.80, 0.92))
    _resumo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(_resumo)
    _botao_fechar = _botao("×", 58)
    _botao_fechar.custom_minimum_size.y = 58
    _botao_fechar.add_theme_font_size_override("font_size", 30)
    linha.add_child(_botao_fechar)
    return linha


func _abas_v3() -> Control:
    var linha := HBoxContainer.new()
    linha.alignment = BoxContainer.ALIGNMENT_CENTER
    linha.add_theme_constant_override("separation", 12)
    for dados in [["notas", "NOTAS E FRAGMENTOS"], ["partituras", "PARTITURAS E NÍVEL"]]:
        var b := _botao(str(dados[1]), 275)
        b.toggle_mode = true
        b.custom_minimum_size.y = 46
        linha.add_child(b)
        _botoes_abas[dados[0]] = b
    return linha


func _notas_v3() -> Control:
    var corpo := HBoxContainer.new()
    corpo.add_theme_constant_override("separation", 16)
    var seletor := _painel_v3(Color(0.012, 0.032, 0.065, 0.92), Color(0.41, 0.34, 0.22))
    seletor.custom_minimum_size.x = 435
    corpo.add_child(seletor)
    var coluna_esquerda := VBoxContainer.new()
    coluna_esquerda.add_theme_constant_override("separation", 8)
    seletor.add_child(coluna_esquerda)
    var titulo := _texto("—  SELECIONAR NOTA  —", 16, OURO, true)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna_esquerda.add_child(titulo)
    var grade := GridContainer.new()
    grade.columns = 3
    grade.add_theme_constant_override("h_separation", 7)
    grade.add_theme_constant_override("v_separation", 7)
    coluna_esquerda.add_child(grade)
    for dados in NOTAS:
        var id := str(dados[0])
        var b := _botao("", 128)
        b.custom_minimum_size.y = 130
        b.toggle_mode = true
        var conteudo := VBoxContainer.new()
        conteudo.set_anchors_preset(Control.PRESET_FULL_RECT)
        conteudo.offset_left = 5
        conteudo.offset_right = -5
        conteudo.offset_top = 5
        conteudo.offset_bottom = -4
        conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(conteudo)
        var icone := TextureRect.new()
        icone.texture = load(ITENS + "fragmento_" + id + ".png")
        icone.custom_minimum_size.y = 66
        icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        conteudo.add_child(icone)
        var nome_nota := _texto(str(dados[1]), 14, OURO, true)
        nome_nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        conteudo.add_child(nome_nota)
        var contagem := _texto("", 10, Color(0.67, 0.75, 0.84))
        contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        conteudo.add_child(contagem)
        _nome_notas_v3[id] = nome_nota
        _contagem_notas_v3[id] = contagem
        grade.add_child(b)
        _botoes_notas[id] = b
    var dica := _texto("Fragmentos limpos podem ser unidos para formar Notas sintetizadas.", 12, Color(0.62, 0.70, 0.81))
    dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna_esquerda.add_child(dica)

    var centro := _painel_v3(Color(0.012, 0.035, 0.075, 0.86), Color(0.40, 0.34, 0.22), 13)
    centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    corpo.add_child(centro)
    var coluna := VBoxContainer.new()
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_theme_constant_override("separation", 10)
    centro.add_child(coluna)
    _titulo_nota = _texto("", 31, OURO, true)
    _titulo_nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_titulo_nota)
    var explicacao := _texto("Purifique fragmentos corrompidos e estabilize a harmonia desta nota.", 14, Color(0.68, 0.75, 0.85))
    explicacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(explicacao)
    var fluxo := HBoxContainer.new()
    fluxo.alignment = BoxContainer.ALIGNMENT_CENTER
    fluxo.add_theme_constant_override("separation", 9)
    fluxo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(fluxo)
    var a := _etapa_v3("CORROMPIDO", Color(0.76, 0.38, 0.96))
    _icone_corrompido = a[0]
    _qtd_corrompido = a[1]
    fluxo.add_child(a[2])
    fluxo.add_child(_seta_v3())
    var b := _etapa_v3("PURIFICADO", Color(0.36, 0.77, 1.0))
    _icone_limpo = b[0]
    _qtd_limpo = b[1]
    fluxo.add_child(b[2])
    fluxo.add_child(_seta_v3())
    var c := _etapa_v3("NOTA SINTETIZADA", OURO)
    _icone_pronto = c[0]
    _qtd_pronto = c[1]
    fluxo.add_child(c[2])
    var acoes := HBoxContainer.new()
    acoes.alignment = BoxContainer.ALIGNMENT_CENTER
    acoes.add_theme_constant_override("separation", 14)
    coluna.add_child(acoes)
    _botao_purificar = _botao("PURIFICAR  |  25 CLAVES", 285)
    acoes.add_child(_botao_purificar)
    _botao_sintetizar = _botao("SINTETIZAR  |  100 CLAVES", 315, true)
    acoes.add_child(_botao_sintetizar)
    var ajuda := _texto("1 corrompido → 1 purificado     •     5 purificados → 1 nota", 13, Color(0.66, 0.72, 0.81))
    ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(ajuda)
    return corpo


func _seta_v3() -> Label:
    var seta := _texto("›", 42, Color(0.58, 0.68, 0.78))
    seta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return seta


func _etapa_v3(nome: String, cor: Color) -> Array:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 225
    var titulo := _texto(nome, 15, cor, true)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(titulo)
    var pedestal := _painel_v3(Color(0.012, 0.045, 0.09, 0.70), Color(cor.r, cor.g, cor.b, 0.72), 100)
    pedestal.custom_minimum_size = Vector2(218, 230)
    coluna.add_child(pedestal)
    var icone := TextureRect.new()
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pedestal.add_child(icone)
    var qtd := _texto("Possui 0", 18, Color(0.96, 0.94, 0.86), true)
    qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(qtd)
    return [icone, qtd, coluna]


func _partituras_v3() -> Control:
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 12)
    var grade := GridContainer.new()
    grade.columns = 3
    grade.custom_minimum_size.y = 365
    grade.add_theme_constant_override("h_separation", 14)
    coluna.add_child(grade)
    for tipo in PARTITURAS_ORDEM:
        grade.add_child(_cartao_partitura_v3(tipo))
    var baixo := HBoxContainer.new()
    baixo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    baixo.add_theme_constant_override("separation", 14)
    coluna.add_child(baixo)
    baixo.add_child(_progresso_v3())
    baixo.add_child(_bonus_v3())
    return coluna


func _cartao_partitura_v3(tipo: String) -> Control:
    var receita: Dictionary = _progresso.PARTITURAS.get(tipo, {}) if _progresso else {}
    var cores := {"menor":Color(0.24, 0.54, 0.86), "harmonica":OURO, "magistral":Color(0.68, 0.38, 0.94)}
    var cor: Color = cores.get(tipo, OURO)
    var painel := _painel_v3(Color(0.014, 0.035, 0.072, 0.92), cor.darkened(0.20), 12)
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var coluna := VBoxContainer.new()
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_theme_constant_override("separation", 5)
    painel.add_child(coluna)
    var nome := _texto(str(receita.get("nome", tipo.capitalize())).to_upper(), 21, cor, true)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(nome)
    var icone := TextureRect.new()
    icone.texture = load(KIT + "item/partitura.png")
    icone.custom_minimum_size = Vector2(0, 150)
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coluna.add_child(icone)
    var custo := _texto("♫  %s CLAVES     XP  %s" % [_milhar(int(receita.get("custo", 0))), _milhar(int(receita.get("xp", 0)))], 15, Color(0.84, 0.85, 0.88))
    custo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(custo)
    var qtd := _texto("POSSUI 0", 15, Color(0.94, 0.91, 0.81))
    qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(qtd)
    _partituras_qtd[tipo] = qtd
    var acoes := HBoxContainer.new()
    acoes.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_child(acoes)
    var criar := _botao("CRIAR", 155, tipo != "menor")
    acoes.add_child(criar)
    _partituras_criar[tipo] = criar
    var usar := _botao("USAR", 145)
    acoes.add_child(usar)
    _partituras_usar[tipo] = usar
    return painel


func _progresso_v3() -> Control:
    var painel := _painel_v3(Color(0.015, 0.035, 0.07, 0.94), Color(0.43, 0.35, 0.22), 11)
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 7)
    painel.add_child(coluna)
    coluna.add_child(_texto("ASCENSÃO HARMÔNICA", 21, OURO, true))
    var linha := HBoxContainer.new()
    coluna.add_child(linha)
    _nivel_v3 = _texto("", 28, Color(0.98, 0.88, 0.60), true)
    _nivel_v3.custom_minimum_size.x = 170
    linha.add_child(_nivel_v3)
    var xp_col := VBoxContainer.new()
    xp_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(xp_col)
    _xp_v3 = _texto("", 14, Color(0.78, 0.83, 0.90))
    xp_col.add_child(_xp_v3)
    _xp_barra_v3 = ProgressBar.new()
    _xp_barra_v3.custom_minimum_size.y = 15
    _xp_barra_v3.show_percentage = false
    _xp_barra_v3.add_theme_stylebox_override("background", _caixa(Color(0.012, 0.02, 0.04), Color(0.22, 0.31, 0.41), 1, 6))
    _xp_barra_v3.add_theme_stylebox_override("fill", _caixa(Color(0.12, 0.46, 0.78), AZUL, 1, 6))
    xp_col.add_child(_xp_barra_v3)
    _marcos_v3 = _texto("10               15               20               25               35\n◆────────────────◆────────────────◇────────────────◇────────────────◇", 15, Color(0.64, 0.78, 0.94), true)
    _marcos_v3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_marcos_v3)
    _ascensao = _texto("", 14, Color(0.78, 0.80, 0.87))
    _ascensao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(_ascensao)
    _botao_ascensao = _botao("REALIZAR ASCENSÃO", 250, true)
    coluna.add_child(_botao_ascensao)
    return painel


func _bonus_v3() -> Control:
    var painel := _painel_v3(Color(0.018, 0.04, 0.075, 0.94), Color(0.43, 0.35, 0.22), 11)
    painel.custom_minimum_size.x = 395
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 8)
    painel.add_child(coluna)
    coluna.add_child(_texto("✦  PRÓXIMO MARCO", 20, OURO, true))
    for linha in ["Poder harmônico        +80", "Vida máxima             +300", "Ataque                         +25", "Defesa                         +20", "Chance crítica           +2,0%", "Dano crítico              +5,0%"]:
        coluna.add_child(_texto(linha, 15, Color(0.80, 0.82, 0.88)))
    var aviso := _texto("Novos conteúdos e limites são liberados nos marcos de ascensão.", 12, Color(0.61, 0.68, 0.78))
    aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(aviso)
    return painel


func _atualizar() -> void:
    super._atualizar()
    if _progresso == null or _nivel_v3 == null:
        return
    _nivel_v3.text = "NÍVEL ATUAL\n%d" % _progresso.nivel
    _xp_v3.text = "XP ATUAL  %s / %s" % [_milhar(_progresso.experiencia), _milhar(_progresso.xp_para_nivel())]
    _xp_barra_v3.max_value = _progresso.xp_para_nivel()
    _xp_barra_v3.value = min(_progresso.experiencia, _progresso.xp_para_nivel())
    for dados in NOTAS:
        var id := str(dados[0])
        (_botoes_notas[id] as Button).text = ""
        (_contagem_notas_v3[id] as Label).text = "CORR. %d  •  LIMPO %d  •  NOTA %d" % [
            _progresso.quantidade("fragmento_corrompido_" + id),
            _progresso.quantidade("fragmento_" + id),
            _progresso.quantidade("nota_" + id)]


func mostrar(sim := true) -> void:
    super.mostrar(sim)
    if sim and _base_layout:
        _base_layout.modulate.a = 0.0
        create_tween().tween_property(_base_layout, "modulate:a", 1.0, 0.22)
