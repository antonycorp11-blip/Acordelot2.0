extends CanvasLayer
## Atelier harmonico: uma altura por vez, com leitura clara do caminho
## corrompido -> purificado -> sintetizado, e uma aba propria para Partituras.

const FUNDO := "res://textures/ui/painel_harmonia_v2.jpg"
const ITENS := "res://textures/items/notas/"
const KIT := "res://textures/ui/kit/"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const TAMANHO_LAYOUT := Vector2(1600.0, 900.0)
const NOTAS := [
    ["do", "Dó"], ["do_sustenido", "Dó#"], ["re", "Ré"],
    ["re_sustenido", "Ré#"], ["mi", "Mi"], ["fa", "Fá"],
    ["fa_sustenido", "Fá#"], ["sol", "Sol"], ["sol_sustenido", "Sol#"],
    ["la", "Lá"], ["la_sustenido", "Lá#"], ["si", "Si"],
]
const PARTITURAS_ORDEM := ["menor", "harmonica", "magistral"]

var _progresso: Node
var _aberta := false
var _nota_atual := "do"
var _aba := "notas"
var _painel_notas: Control
var _painel_partituras: Control
var _botoes_abas := {}
var _botoes_notas := {}
var _titulo_nota: Label
var _icone_corrompido: TextureRect
var _icone_limpo: TextureRect
var _icone_pronto: TextureRect
var _qtd_corrompido: Label
var _qtd_limpo: Label
var _qtd_pronto: Label
var _botao_purificar: Button
var _botao_sintetizar: Button
var _claves: Label
var _resumo: Label
var _recado: Label
var _partituras_qtd := {}
var _partituras_criar := {}
var _partituras_usar := {}
var _ascensao: Label
var _botao_ascensao: Button
var _base_layout: Control


func _ready() -> void:
    layer = 17
    visible = false
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    get_viewport().size_changed.connect(_ajustar_ao_celular)
    _ajustar_ao_celular()
    if _progresso and not _progresso.alterado.is_connected(_atualizar):
        _progresso.alterado.connect(_atualizar)
    _selecionar_nota("do")
    _trocar_aba("notas")
    _atualizar()


func _caixa(fundo: Color, borda: Color, espessura := 1, raio := 8) -> StyleBoxFlat:
    var c := StyleBoxFlat.new()
    c.bg_color = fundo
    c.border_color = borda
    c.set_border_width_all(espessura)
    c.set_corner_radius_all(raio)
    c.content_margin_left = 12
    c.content_margin_right = 12
    c.content_margin_top = 8
    c.content_margin_bottom = 8
    return c


func _texto(texto: String, tamanho: int, cor: Color, titulo := false) -> Label:
    var l := Label.new()
    l.text = texto
    l.add_theme_font_override("font", load(FONTE_TITULO if titulo else FONTE_TEXTO))
    l.add_theme_font_size_override("font_size", tamanho)
    l.add_theme_color_override("font_color", cor)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 2)
    return l


func _botao(texto: String, largura := 170.0, destaque := false) -> Button:
    var b := Button.new()
    b.text = texto
    b.custom_minimum_size = Vector2(largura, 48)
    b.add_theme_font_override("font", load(FONTE_TEXTO))
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_color_override("font_color", Color(0.94, 0.94, 0.92))
    var normal := Color(0.12, 0.25, 0.35, 0.96) if destaque else Color(0.08, 0.10, 0.16, 0.94)
    var borda := Color(0.28, 0.72, 0.92, 0.9) if destaque else Color(0.42, 0.36, 0.25, 0.9)
    b.add_theme_stylebox_override("normal", _caixa(normal, borda, 1, 7))
    b.add_theme_stylebox_override("hover", _caixa(normal.lightened(0.10), borda.lightened(0.12), 2, 7))
    b.add_theme_stylebox_override("pressed", _caixa(normal.darkened(0.08), borda, 2, 7))
    b.add_theme_stylebox_override("disabled", _caixa(Color(0.06, 0.07, 0.10, 0.80), Color(0.20, 0.20, 0.22), 1, 7))
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
    for lado in ["margin_left", "margin_right"]:
        margem.add_theme_constant_override(lado, 54)
    margem.add_theme_constant_override("margin_top", 36)
    margem.add_theme_constant_override("margin_bottom", 38)
    base.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 12)
    margem.add_child(coluna)
    coluna.add_child(_cabecalho())
    coluna.add_child(_abas())
    _painel_notas = _montar_notas()
    _painel_notas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(_painel_notas)
    _painel_partituras = _montar_partituras()
    _painel_partituras.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(_painel_partituras)
    _recado = _texto("", 16, Color(0.75, 0.88, 1.0))
    _recado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _recado.custom_minimum_size.y = 26
    coluna.add_child(_recado)


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
    linha.custom_minimum_size.y = 58
    linha.add_child(_texto("Ateliê de Síntese", 34, Color(0.88, 0.78, 0.50), true))
    var espaco := Control.new()
    espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(espaco)
    _claves = _texto("", 18, Color(0.98, 0.82, 0.36))
    _claves.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(_claves)
    _resumo = _texto("", 15, Color(0.66, 0.80, 0.90))
    _resumo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(_resumo)
    var fechar := _botao("Fechar", 120)
    fechar.pressed.connect(func(): mostrar(false))
    linha.add_child(fechar)
    return linha


func _abas() -> Control:
    var linha := HBoxContainer.new()
    linha.alignment = BoxContainer.ALIGNMENT_CENTER
    linha.add_theme_constant_override("separation", 10)
    for dados in [["notas", "Notas e Fragmentos"], ["partituras", "Partituras e Nível"]]:
        var b := _botao(str(dados[1]), 260)
        b.toggle_mode = true
        b.pressed.connect(_trocar_aba.bind(str(dados[0])))
        linha.add_child(b)
        _botoes_abas[dados[0]] = b
    return linha


func _montar_notas() -> Control:
    var corpo := HBoxContainer.new()
    corpo.add_theme_constant_override("separation", 18)
    var seletor := PanelContainer.new()
    seletor.custom_minimum_size.x = 330
    seletor.add_theme_stylebox_override("panel", _caixa(Color(0.02, 0.04, 0.075, 0.90), Color(0.25, 0.32, 0.38), 1, 10))
    corpo.add_child(seletor)
    var grade := GridContainer.new()
    grade.columns = 3
    grade.add_theme_constant_override("h_separation", 7)
    grade.add_theme_constant_override("v_separation", 7)
    seletor.add_child(grade)
    for dados in NOTAS:
        var id := str(dados[0])
        var b := _botao(str(dados[1]), 94)
        b.custom_minimum_size.y = 80
        b.icon = load(ITENS + "fragmento_" + id + ".png")
        b.expand_icon = true
        b.add_theme_constant_override("icon_max_width", 40)
        b.pressed.connect(_selecionar_nota.bind(id))
        grade.add_child(b)
        _botoes_notas[id] = b

    var centro := PanelContainer.new()
    centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    centro.add_theme_stylebox_override("panel", _caixa(Color(0.025, 0.055, 0.095, 0.90), Color(0.38, 0.52, 0.62), 1, 12))
    corpo.add_child(centro)
    var coluna := VBoxContainer.new()
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_theme_constant_override("separation", 12)
    centro.add_child(coluna)
    _titulo_nota = _texto("", 28, Color(0.88, 0.82, 0.62), true)
    _titulo_nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_titulo_nota)
    var fluxo := HBoxContainer.new()
    fluxo.alignment = BoxContainer.ALIGNMENT_CENTER
    fluxo.add_theme_constant_override("separation", 10)
    coluna.add_child(fluxo)
    var etapa_a = _etapa("Corrompido", Color(0.72, 0.38, 0.94))
    _icone_corrompido = etapa_a[0]
    _qtd_corrompido = etapa_a[1]
    fluxo.add_child(etapa_a[2])
    fluxo.add_child(_texto("›", 42, Color(0.45, 0.55, 0.64)))
    var etapa_b = _etapa("Purificado", Color(0.38, 0.76, 0.94))
    _icone_limpo = etapa_b[0]
    _qtd_limpo = etapa_b[1]
    fluxo.add_child(etapa_b[2])
    fluxo.add_child(_texto("›", 42, Color(0.45, 0.55, 0.64)))
    var etapa_c = _etapa("Nota sintetizada", Color(0.92, 0.77, 0.36))
    _icone_pronto = etapa_c[0]
    _qtd_pronto = etapa_c[1]
    fluxo.add_child(etapa_c[2])
    var acoes := HBoxContainer.new()
    acoes.alignment = BoxContainer.ALIGNMENT_CENTER
    acoes.add_theme_constant_override("separation", 12)
    coluna.add_child(acoes)
    _botao_purificar = _botao("Purificar 1", 190)
    _botao_purificar.pressed.connect(_purificar)
    acoes.add_child(_botao_purificar)
    _botao_sintetizar = _botao("Sintetizar 5", 210, true)
    _botao_sintetizar.pressed.connect(_sintetizar)
    acoes.add_child(_botao_sintetizar)
    var ajuda := _texto("Shikers deixam fragmentos com partículas roxas. Purifique-os e una 5 fragmentos limpos para formar uma nota.", 14, Color(0.67, 0.72, 0.78))
    ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(ajuda)
    return corpo


func _etapa(nome: String, cor: Color) -> Array:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 180
    var titulo := _texto(nome, 16, cor)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(titulo)
    var icone := TextureRect.new()
    icone.custom_minimum_size = Vector2(170, 170)
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coluna.add_child(icone)
    var qtd := _texto("0", 21, Color(0.94, 0.94, 0.90), true)
    qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(qtd)
    return [icone, qtd, coluna]


func _montar_partituras() -> Control:
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 14)
    var grade := GridContainer.new()
    grade.columns = 3
    grade.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grade.add_theme_constant_override("h_separation", 16)
    coluna.add_child(grade)
    for tipo in PARTITURAS_ORDEM:
        grade.add_child(_cartao_partitura(tipo))
    var asc := PanelContainer.new()
    asc.add_theme_stylebox_override("panel", _caixa(Color(0.055, 0.04, 0.085, 0.92), Color(0.52, 0.35, 0.68), 1, 10))
    coluna.add_child(asc)
    var linha := HBoxContainer.new()
    asc.add_child(linha)
    var bloco := VBoxContainer.new()
    bloco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(bloco)
    bloco.add_child(_texto("Ascensão Harmônica", 21, Color(0.88, 0.72, 0.96), true))
    _ascensao = _texto("", 15, Color(0.78, 0.80, 0.86))
    bloco.add_child(_ascensao)
    _botao_ascensao = _botao("Realizar ascensão", 220, true)
    _botao_ascensao.pressed.connect(_ascender)
    linha.add_child(_botao_ascensao)
    return coluna


func _cartao_partitura(tipo: String) -> Control:
    var receita: Dictionary = _progresso.PARTITURAS.get(tipo, {}) if _progresso else {}
    var painel := PanelContainer.new()
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.025, 0.045, 0.075, 0.92), Color(0.34, 0.39, 0.43), 1, 11))
    var coluna := VBoxContainer.new()
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_theme_constant_override("separation", 7)
    painel.add_child(coluna)
    var nome := _texto(str(receita.get("nome", tipo.capitalize())), 22, Color(0.90, 0.81, 0.55), true)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(nome)
    var icone := TextureRect.new()
    icone.texture = load(KIT + "item/partitura.png")
    icone.custom_minimum_size = Vector2(120, 120)
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coluna.add_child(icone)
    coluna.add_child(_texto("%s Claves  •  %s XP" % [_milhar(int(receita.get("custo", 0))), _milhar(int(receita.get("xp", 0)))], 16, Color(0.74, 0.82, 0.90)))
    var qtd := _texto("Possui: 0", 17, Color(0.92, 0.92, 0.88))
    qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(qtd)
    _partituras_qtd[tipo] = qtd
    var acoes := HBoxContainer.new()
    acoes.alignment = BoxContainer.ALIGNMENT_CENTER
    coluna.add_child(acoes)
    var criar := _botao("Criar", 125)
    criar.pressed.connect(_criar_partitura.bind(tipo))
    acoes.add_child(criar)
    _partituras_criar[tipo] = criar
    var usar := _botao("Usar", 125, true)
    usar.pressed.connect(_usar_partitura.bind(tipo))
    acoes.add_child(usar)
    _partituras_usar[tipo] = usar
    return painel


func _trocar_aba(qual: String) -> void:
    _aba = qual
    if _painel_notas:
        _painel_notas.visible = qual == "notas"
    if _painel_partituras:
        _painel_partituras.visible = qual == "partituras"
    for id in _botoes_abas:
        (_botoes_abas[id] as Button).button_pressed = str(id) == qual
    if _recado:
        _recado.text = ""


func _selecionar_nota(id: String) -> void:
    _nota_atual = id
    for nota in _botoes_notas:
        (_botoes_notas[nota] as Button).button_pressed = str(nota) == id
    _atualizar()


func _nome_da_nota(id: String) -> String:
    for dados in NOTAS:
        if str(dados[0]) == id:
            return str(dados[1])
    return id.capitalize()


func _purificar() -> void:
    var ok: bool = _progresso != null and _progresso.purificar_fragmento(_nota_atual)
    _recado.text = "Fragmento purificado." if ok else "Você ainda não possui esse fragmento corrompido."


func _sintetizar() -> void:
    var ok: bool = _progresso != null and _progresso.sintetizar_nota(_nota_atual)
    _recado.text = "Nota sintetizada e enviada ao inventário." if ok else "São necessários 5 fragmentos purificados."


func _criar_partitura(tipo: String) -> void:
    var ok: bool = _progresso != null and _progresso.criar_partitura(tipo)
    _recado.text = "Partitura criada." if ok else "Claves insuficientes para essa Partitura."


func _usar_partitura(tipo: String) -> void:
    var ok: bool = _progresso != null and _progresso.usar_partitura(tipo)
    if ok:
        _recado.text = "XP adicionada. Abra Personagem e toque em Subir nível quando completar a barra."
    elif _progresso and _progresso.nivel >= _progresso.NIVEL_MAXIMO:
        _recado.text = "Akles já alcançou o nível máximo atual."
    else:
        _recado.text = "Você não possui essa Partitura."


func _ascender() -> void:
    var ok: bool = _progresso != null and _progresso.tentar_ascensao()
    _recado.text = "Ascensão concluída." if ok else "Ainda faltam Partituras ou o item específico do chefe."


func _atualizar() -> void:
    if _progresso == null or _titulo_nota == null:
        return
    var corrompido := "fragmento_corrompido_" + _nota_atual
    var limpo := "fragmento_" + _nota_atual
    var pronto := "nota_" + _nota_atual
    _titulo_nota.text = "Síntese de " + _nome_da_nota(_nota_atual)
    _icone_corrompido.texture = load(ITENS + corrompido + ".png")
    _icone_limpo.texture = load(ITENS + limpo + ".png")
    _icone_pronto.texture = load(ITENS + pronto + ".png")
    _qtd_corrompido.text = "Possui  %d" % _progresso.quantidade(corrompido)
    _qtd_limpo.text = "Possui  %d" % _progresso.quantidade(limpo)
    _qtd_pronto.text = "Possui  %d" % _progresso.quantidade(pronto)
    _botao_purificar.disabled = _progresso.quantidade(corrompido) < 1
    _botao_sintetizar.disabled = _progresso.quantidade(limpo) < 5
    _claves.text = "Claves  %s" % _milhar(_progresso.quantidade("claves"))
    var limpos := 0
    var contaminados := 0
    for dados in NOTAS:
        limpos += _progresso.quantidade("fragmento_" + str(dados[0]))
        contaminados += _progresso.quantidade("fragmento_corrompido_" + str(dados[0]))
    _resumo.text = "  Fragmentos %d  •  Corrompidos %d" % [limpos, contaminados]
    for tipo in PARTITURAS_ORDEM:
        var receita: Dictionary = _progresso.PARTITURAS[tipo]
        var recurso := str(receita["recurso"])
        (_partituras_qtd[tipo] as Label).text = "Possui: %d" % _progresso.quantidade(recurso)
        (_partituras_criar[tipo] as Button).disabled = _progresso.quantidade("claves") < int(receita["custo"])
        (_partituras_usar[tipo] as Button).disabled = _progresso.quantidade(recurso) < 1 or _progresso.nivel >= _progresso.NIVEL_MAXIMO
    if _progresso.esta_em_trava_de_ascensao():
        var req: Dictionary = _progresso.requisitos_da_ascensao()
        var partes := []
        for id in req:
            partes.append("%d/%d %s" % [_progresso.quantidade(str(id)), int(req[id]), _nome_requisito(str(id))])
        _ascensao.text = "Nível %d bloqueado: %s" % [_progresso.nivel, "  •  ".join(partes)]
        _botao_ascensao.visible = true
        _botao_ascensao.disabled = not _progresso.pode_pagar(req)
    elif _progresso.nivel >= _progresso.NIVEL_MAXIMO:
        _ascensao.text = "Nível máximo atual alcançado: 60."
        _botao_ascensao.visible = false
    else:
        var proxima := 20 if _progresso.nivel < 20 else 40 if _progresso.nivel < 40 else 60
        _ascensao.text = "Próximo marco de progressão: nível %d." % proxima
        _botao_ascensao.visible = false


func _nome_requisito(id: String) -> String:
    return {"partitura_harmonica": "Partituras Harmônicas", "partitura_magistral": "Partituras Magistrais", "selo_regente": "Selo do Regente", "nucleo_maestro": "Núcleo do Maestro"}.get(id, id.capitalize())


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
        _recado.text = ""
        _atualizar()


func esta_aberta() -> bool:
    return _aberta
