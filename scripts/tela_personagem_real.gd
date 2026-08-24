extends CanvasLayer
## Ficha funcional e explicativa do Akles. O Poder de Luta nao e um numero
## arbitrario: cada parcela e exibida com o mesmo multiplicador usado no save.

const FUNDO := "res://textures/ui/painel_harmonia_v2.jpg"
const KIT := "res://textures/ui/kit/"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const TAMANHO_LAYOUT := Vector2(1600.0, 900.0)
const ATRIBUTOS := [["forca", "Força"], ["destreza", "Destreza"],
    ["vitalidade", "Vitalidade"], ["ressonancia", "Ressonância"],
    ["percepcao", "Percepção"]]
const COMBATE := [["ataque", "Ataque"], ["defesa", "Defesa"],
    ["vida_maxima", "Vida máxima"], ["critico", "Chance crítica"],
    ["dano_critico", "Dano crítico"], ["poder_harmonico", "Poder harmônico"],
    ["coleta", "Eficiência de coleta"]]
const SLOTS := ["Amuleto", "Anel I", "Anel II", "Broche", "Bracelete", "Talismã"]

var _aberta := false
var _progresso: Node
var _nivel: Label
var _xp_texto: Label
var _xp_barra: ProgressBar
var _pontos: Label
var _poder_total: Label
var _poder_conta: Label
var _ascensao: Label
var _botao_subir_nivel: Button
var _arma: Label
var _eco: Label
var _composicao: Label
var _skills: Label
var _valores_atributo := {}
var _botoes_atributo := {}
var _valores_combate := {}
var _linhas_poder := {}
var _slots := {}
var _base_layout: Control


func _ready() -> void:
    layer = 16
    visible = false
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    get_viewport().size_changed.connect(_ajustar_ao_celular)
    _ajustar_ao_celular()
    if _progresso and not _progresso.alterado.is_connected(_atualizar):
        _progresso.alterado.connect(_atualizar)
    _atualizar()


func _caixa(fundo: Color, borda: Color, espessura := 1, raio := 8) -> StyleBoxFlat:
    var c := StyleBoxFlat.new()
    c.bg_color = fundo
    c.border_color = borda
    c.set_border_width_all(espessura)
    c.set_corner_radius_all(raio)
    c.content_margin_left = 12
    c.content_margin_right = 12
    c.content_margin_top = 9
    c.content_margin_bottom = 9
    return c


func _texto(texto: String, tamanho: int, cor: Color, titulo := false) -> Label:
    var l := Label.new()
    l.text = texto
    l.add_theme_font_override("font", load(FONTE_TITULO if titulo else FONTE_TEXTO))
    l.add_theme_font_size_override("font_size", tamanho)
    l.add_theme_color_override("font_color", cor)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 2)
    return l


func _botao(texto: String, largura := 120.0) -> Button:
    var b := Button.new()
    b.text = texto
    b.custom_minimum_size = Vector2(largura, 44)
    b.add_theme_font_override("font", load(FONTE_TEXTO))
    b.add_theme_font_size_override("font_size", 16)
    b.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
    b.add_theme_stylebox_override("normal", _caixa(Color(0.08, 0.10, 0.16, 0.94), Color(0.42, 0.36, 0.25), 1, 7))
    b.add_theme_stylebox_override("hover", _caixa(Color(0.12, 0.18, 0.24, 0.96), Color(0.42, 0.67, 0.82), 2, 7))
    b.add_theme_stylebox_override("disabled", _caixa(Color(0.05, 0.06, 0.09, 0.82), Color(0.18, 0.18, 0.20), 1, 7))
    return b


func _montar() -> void:
    var sombra := ColorRect.new()
    sombra.color = Color(0.005, 0.008, 0.018, 0.88)
    sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
    sombra.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(sombra)
    var base := Control.new()
    base.custom_minimum_size = TAMANHO_LAYOUT
    base.size = TAMANHO_LAYOUT
    base.pivot_offset = Vector2.ZERO
    sombra.add_child(base)
    _base_layout = base
    var arte := TextureRect.new()
    arte.texture = load(FUNDO)
    arte.set_anchors_preset(Control.PRESET_FULL_RECT)
    arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    arte.stretch_mode = TextureRect.STRETCH_SCALE
    arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
    base.add_child(arte)
    var margem := MarginContainer.new()
    margem.set_anchors_preset(Control.PRESET_FULL_RECT)
    margem.add_theme_constant_override("margin_left", 52)
    margem.add_theme_constant_override("margin_right", 52)
    margem.add_theme_constant_override("margin_top", 34)
    margem.add_theme_constant_override("margin_bottom", 38)
    base.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 12)
    margem.add_child(coluna)
    coluna.add_child(_cabecalho())
    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 14)
    coluna.add_child(corpo)
    corpo.add_child(_painel_equipamentos())
    corpo.add_child(_painel_akles())
    corpo.add_child(_painel_dados())


func _ajustar_ao_celular() -> void:
    if _base_layout == null:
        return
    var viewport := get_viewport().get_visible_rect().size
    if viewport.x <= 0.0 or viewport.y <= 0.0:
        return
    var fator := minf(viewport.x / TAMANHO_LAYOUT.x, viewport.y / TAMANHO_LAYOUT.y)
    _base_layout.scale = Vector2.ONE * fator
    _base_layout.position = (viewport - TAMANHO_LAYOUT * fator) * 0.5


func _cabecalho() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 62
    linha.add_child(_texto("Akles — Espadachim da Harmonia", 31, Color(0.88, 0.78, 0.50), true))
    var espaco := Control.new()
    espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(espaco)
    var bloco_poder := VBoxContainer.new()
    bloco_poder.custom_minimum_size.x = 250
    var titulo := _texto("PODER DE LUTA", 13, Color(0.56, 0.74, 0.86))
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bloco_poder.add_child(titulo)
    _poder_total = _texto("0", 30, Color(0.98, 0.78, 0.32), true)
    _poder_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bloco_poder.add_child(_poder_total)
    _poder_conta = _texto("", 11, Color(0.62, 0.75, 0.82))
    _poder_conta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bloco_poder.add_child(_poder_conta)
    linha.add_child(bloco_poder)
    _pontos = _texto("", 16, Color(0.70, 0.86, 0.96))
    _pontos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(_pontos)
    var fechar := _botao("Fechar", 115)
    fechar.pressed.connect(func(): mostrar(false))
    linha.add_child(fechar)
    return linha


func _painel_equipamentos() -> Control:
    var painel := PanelContainer.new()
    painel.custom_minimum_size.x = 285
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.02, 0.04, 0.075, 0.90), Color(0.28, 0.33, 0.36), 1, 10))
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 8)
    painel.add_child(coluna)
    coluna.add_child(_texto("Arma e acessórios", 20, Color(0.88, 0.80, 0.58), true))
    var arma_painel := PanelContainer.new()
    arma_painel.add_theme_stylebox_override("panel", _caixa(Color(0.05, 0.08, 0.13, 0.94), Color(0.38, 0.55, 0.66), 1, 8))
    coluna.add_child(arma_painel)
    var arma_linha := HBoxContainer.new()
    arma_painel.add_child(arma_linha)
    var espada := TextureRect.new()
    espada.texture = load(KIT + "equip/espada.png")
    espada.custom_minimum_size = Vector2(64, 64)
    espada.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    espada.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    arma_linha.add_child(espada)
    _arma = _texto("", 14, Color(0.90, 0.90, 0.86))
    _arma.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _arma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _arma.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    arma_linha.add_child(_arma)
    var grade := GridContainer.new()
    grade.columns = 2
    grade.add_theme_constant_override("h_separation", 8)
    grade.add_theme_constant_override("v_separation", 8)
    coluna.add_child(grade)
    for slot in SLOTS:
        grade.add_child(_slot_acessorio(slot))
    var nota := _texto("Não existem armaduras. A arma pode ser trocada; os demais espaços são acessórios não visuais.", 12, Color(0.57, 0.64, 0.70))
    nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(nota)
    return painel


func _slot_acessorio(slot: String) -> Control:
    var caixa := VBoxContainer.new()
    caixa.custom_minimum_size = Vector2(125, 112)
    var painel := Panel.new()
    painel.custom_minimum_size = Vector2(78, 76)
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.05, 0.07, 0.11, 0.94), Color(0.28, 0.28, 0.30), 1, 7))
    caixa.add_child(painel)
    var icone := TextureRect.new()
    icone.set_anchors_preset(Control.PRESET_FULL_RECT)
    icone.offset_left = 8
    icone.offset_top = 8
    icone.offset_right = -8
    icone.offset_bottom = -8
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    painel.add_child(icone)
    var nome := _texto(slot, 11, Color(0.70, 0.70, 0.72))
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    caixa.add_child(nome)
    _slots[slot] = [painel, icone, nome]
    return caixa


func _painel_akles() -> Control:
    var painel := PanelContainer.new()
    painel.custom_minimum_size.x = 400
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.025, 0.05, 0.085, 0.76), Color(0.34, 0.43, 0.48), 1, 10))
    var base := Control.new()
    painel.add_child(base)
    var figura := TextureRect.new()
    figura.texture = load("res://textures/dialogo/akles_corpo.png")
    figura.set_anchors_preset(Control.PRESET_FULL_RECT)
    figura.offset_top = 8
    figura.offset_bottom = -205
    figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    figura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    base.add_child(figura)
    var faixa := VBoxContainer.new()
    faixa.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    faixa.offset_left = 14
    faixa.offset_right = -14
    faixa.offset_top = -210
    faixa.offset_bottom = -12
    faixa.add_theme_constant_override("separation", 5)
    base.add_child(faixa)
    var linha_nivel := HBoxContainer.new()
    linha_nivel.alignment = BoxContainer.ALIGNMENT_CENTER
    linha_nivel.add_theme_constant_override("separation", 12)
    faixa.add_child(linha_nivel)
    _nivel = _texto("", 22, Color(0.94, 0.83, 0.52), true)
    _nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    linha_nivel.add_child(_nivel)
    _botao_subir_nivel = _botao("Subir nível", 170)
    _botao_subir_nivel.custom_minimum_size.y = 38
    _botao_subir_nivel.pressed.connect(_subir_nivel)
    linha_nivel.add_child(_botao_subir_nivel)
    _xp_barra = ProgressBar.new()
    _xp_barra.custom_minimum_size.y = 20
    _xp_barra.show_percentage = false
    _xp_barra.add_theme_stylebox_override("background", _caixa(Color(0.03, 0.04, 0.07), Color(0.20, 0.25, 0.28), 1, 5))
    _xp_barra.add_theme_stylebox_override("fill", _caixa(Color(0.18, 0.52, 0.78), Color(0.42, 0.76, 0.96), 1, 5))
    faixa.add_child(_xp_barra)
    _xp_texto = _texto("", 13, Color(0.80, 0.88, 0.94))
    _xp_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    faixa.add_child(_xp_texto)
    _ascensao = _texto("", 12, Color(0.86, 0.65, 0.92))
    _ascensao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    faixa.add_child(_ascensao)
    _eco = _texto("", 12, Color(0.56, 0.82, 0.94))
    _composicao = _texto("", 12, Color(0.78, 0.72, 0.94))
    _skills = _texto("", 12, Color(0.72, 0.76, 0.82))
    for linha in [_eco, _composicao, _skills]:
        linha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        faixa.add_child(linha)
    return painel


func _painel_dados() -> Control:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 680
    coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    coluna.add_theme_constant_override("separation", 10)
    var topo := HBoxContainer.new()
    topo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    topo.add_theme_constant_override("separation", 10)
    coluna.add_child(topo)
    topo.add_child(_painel_atributos())
    topo.add_child(_painel_estatisticas())
    coluna.add_child(_painel_poder())
    return coluna


func _painel_atributos() -> Control:
    var painel := PanelContainer.new()
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.02, 0.04, 0.075, 0.90), Color(0.28, 0.34, 0.38), 1, 9))
    var coluna := VBoxContainer.new()
    painel.add_child(coluna)
    coluna.add_child(_texto("Atributos", 19, Color(0.88, 0.80, 0.58), true))
    for dados in ATRIBUTOS:
        coluna.add_child(_linha_atributo(str(dados[0]), str(dados[1])))
    return painel


func _linha_atributo(id: String, nome: String) -> Control:
    var linha := HBoxContainer.new()
    var rotulo := _texto(nome, 15, Color(0.76, 0.79, 0.84))
    rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(rotulo)
    var valor := _texto("0", 17, Color(0.94, 0.91, 0.78))
    valor.custom_minimum_size.x = 42
    valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    linha.add_child(valor)
    var mais := _botao("+", 36)
    mais.custom_minimum_size.y = 31
    mais.tooltip_text = "Investir um ponto em " + nome
    mais.pressed.connect(_investir.bind(id))
    linha.add_child(mais)
    _valores_atributo[id] = valor
    _botoes_atributo[id] = mais
    return linha


func _painel_estatisticas() -> Control:
    var painel := PanelContainer.new()
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.02, 0.04, 0.075, 0.90), Color(0.28, 0.34, 0.38), 1, 9))
    var coluna := VBoxContainer.new()
    painel.add_child(coluna)
    coluna.add_child(_texto("Estatísticas", 19, Color(0.88, 0.80, 0.58), true))
    for dados in COMBATE:
        var linha := HBoxContainer.new()
        var nome := _texto(str(dados[1]), 14, Color(0.72, 0.75, 0.81))
        nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        linha.add_child(nome)
        var valor := _texto("0", 15, Color(0.90, 0.89, 0.80))
        valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        linha.add_child(valor)
        _valores_combate[dados[0]] = valor
        coluna.add_child(linha)
    return painel


func _painel_poder() -> Control:
    var painel := PanelContainer.new()
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.045, 0.035, 0.065, 0.92), Color(0.50, 0.38, 0.55), 1, 9))
    var coluna := VBoxContainer.new()
    painel.add_child(coluna)
    coluna.add_child(_texto("Como o Poder de Luta é calculado", 18, Color(0.90, 0.74, 0.94), true))
    for dados in [["nivel", "Nível"], ["atributos", "Atributos"], ["arma", "Arma / equipamento"],
            ["acessorios", "Acessórios"], ["eco", "Eco equipado"],
            ["composicao", "Composição"], ["skills", "Skills"]]:
        var linha := HBoxContainer.new()
        var formula := _texto(str(dados[1]), 13, Color(0.70, 0.72, 0.78))
        formula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        linha.add_child(formula)
        var valor := _texto("+0", 14, Color(0.96, 0.82, 0.46))
        valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        linha.add_child(valor)
        _linhas_poder[dados[0]] = [formula, valor]
        coluna.add_child(linha)
    return painel


func _investir(id: String) -> void:
    if _progresso:
        _progresso.investir_atributo(id)


func _subir_nivel() -> void:
    if _progresso:
        _progresso.subir_nivel()


func _atualizar() -> void:
    if _progresso == null or _nivel == null:
        return
    _nivel.text = "Nível %d / %d" % [_progresso.nivel, _progresso.NIVEL_MAXIMO]
    _xp_barra.max_value = _progresso.xp_para_nivel()
    _xp_barra.value = min(_progresso.experiencia, _progresso.xp_para_nivel())
    _xp_texto.text = "%s / %s XP  •  obtida usando Partituras" % [_milhar(_progresso.experiencia), _milhar(_progresso.xp_para_nivel())]
    if _progresso.nivel >= _progresso.NIVEL_MAXIMO:
        _botao_subir_nivel.text = "Nível máximo"
        _botao_subir_nivel.disabled = true
    elif _progresso.esta_em_trava_de_ascensao():
        _botao_subir_nivel.text = "Ascensão necessária"
        _botao_subir_nivel.disabled = true
    elif _progresso.pode_subir_nivel():
        _botao_subir_nivel.text = "Subir nível"
        _botao_subir_nivel.disabled = false
    else:
        var faltam: int = maxi(0, _progresso.xp_para_nivel() - _progresso.experiencia)
        _botao_subir_nivel.text = "Faltam %s XP" % _milhar(faltam)
        _botao_subir_nivel.disabled = true
    _pontos.text = "Pontos: %d" % _progresso.pontos_de_atributo
    if _progresso.esta_em_trava_de_ascensao():
        _ascensao.text = "Ascensão do nível %d pendente — conclua na Síntese" % _progresso.nivel
    elif _progresso.nivel >= _progresso.NIVEL_MAXIMO:
        _ascensao.text = "Nível máximo atual alcançado"
    else:
        _ascensao.text = "Ascensões nos níveis 20 e 40"
    _arma.text = "%s\nNível da arma %d" % [_progresso.arma_equipada, _progresso.nivel_da_arma]
    _eco.text = "Eco equipado: " + str(_progresso.eco_equipado.get("nome", "Nenhum"))
    _composicao.text = "Composição: %d acorde(s) equipado(s)" % _progresso.acordes_equipados.size()
    var soma_skills := 0
    for valor in _progresso.niveis_skills.values():
        soma_skills += int(valor)
    _skills.text = "Níveis de skill somados: %d" % soma_skills
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
    _atualizar_acessorios()
    _atualizar_poder()


func _atualizar_acessorios() -> void:
    for slot in _slots:
        var partes: Array = _slots[slot]
        var painel := partes[0] as Panel
        var icone := partes[1] as TextureRect
        var nome := partes[2] as Label
        var item: Dictionary = _progresso.acessorio_no_slot(str(slot))
        if item.is_empty():
            icone.texture = null
            nome.text = str(slot) + "  •  vazio"
            painel.add_theme_stylebox_override("panel", _caixa(Color(0.05, 0.07, 0.11, 0.94), Color(0.24, 0.24, 0.26), 1, 7))
        else:
            icone.texture = load(KIT + str(item.get("arte", "equip/anel")) + ".png")
            nome.text = str(item.get("nome", slot))
            painel.add_theme_stylebox_override("panel", _caixa(Color(0.05, 0.08, 0.13, 0.94), Color(0.38, 0.62, 0.82), 2, 7))


func _atualizar_poder() -> void:
    var p: Dictionary = _progresso.poder_de_luta_detalhado()
    _poder_total.text = _milhar(int(p["total"]))
    _poder_conta.text = "Poder da conta: " + _milhar(_progresso.poder_de_luta_da_conta())
    var formulas := {
        "nivel": "Nível %d × 100" % _progresso.nivel,
        "atributos": "Atributos %d × 12" % int(p["soma_atributos"]),
        "arma": "Arma Nv.%d × 75 + base 125" % _progresso.nivel_da_arma,
        "acessorios": "Base + bônus × 20 + raridade",
        "eco": "Poder próprio do Eco equipado",
        "composicao": "Soma dos acordes equipados",
        "skills": "Níveis de skill %d × 35" % int(p["soma_skills"]),
    }
    for id in _linhas_poder:
        var partes: Array = _linhas_poder[id]
        (partes[0] as Label).text = str(formulas[id])
        (partes[1] as Label).text = "+%s" % _milhar(int(p[id]))


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


func mostrar(sim := true) -> void:
    _aberta = sim
    visible = sim
    if sim:
        _atualizar()


func esta_aberta() -> bool:
    return _aberta
