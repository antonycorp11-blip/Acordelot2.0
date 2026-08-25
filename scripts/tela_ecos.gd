extends CanvasLayer
## Santuário dos Ecos. A tela usa os próprios frames das criaturas, portanto
## apresenta a arte real do jogo e não miniaturas inventadas.

const FUNDO := "res://textures/ui/painel_harmonia_v2.jpg"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const TAMANHO := Vector2(1600, 900)

var _progresso: Node
var _dados: Array = []
var _por_id := {}
var _selecionado := "do"
var _aberta := false
var _base: Control
var _botoes := {}
var _fechar: Button
var _equipar: Button
var _preview: TextureRect
var _nome: Label
var _forma: Label
var _personalidade: Label
var _habilidade: Label
var _buff: Label
var _estado: Label


func _ready() -> void:
    layer = 17
    _progresso = get_node_or_null("/root/Progresso")
    _carregar_dados()
    _montar()
    get_viewport().size_changed.connect(_ajustar)
    _ajustar()
    if _progresso and not _progresso.alterado.is_connected(_atualizar):
        _progresso.alterado.connect(_atualizar)
    visible = false


func _carregar_dados() -> void:
    var arquivo := FileAccess.open("res://data/ecos_musicais.json", FileAccess.READ)
    if arquivo == null:
        return
    var raiz = JSON.parse_string(arquivo.get_as_text())
    if raiz is Dictionary:
        _dados = (raiz.get("ecos", []) as Array).duplicate(true)
    for eco in _dados:
        _por_id[str(eco.get("id", ""))] = eco


func _caixa(fundo: Color, borda: Color, espessura := 1, raio := 10) -> StyleBoxFlat:
    var c := StyleBoxFlat.new()
    c.bg_color = fundo
    c.border_color = borda
    c.set_border_width_all(espessura)
    c.set_corner_radius_all(raio)
    c.content_margin_left = 14
    c.content_margin_right = 14
    c.content_margin_top = 10
    c.content_margin_bottom = 10
    return c


func _texto(valor: String, tamanho: int, cor: Color, titulo := false) -> Label:
    var l := Label.new()
    l.text = valor
    l.add_theme_font_override("font", load(FONTE_TITULO if titulo else FONTE_TEXTO))
    l.add_theme_font_size_override("font_size", tamanho)
    l.add_theme_color_override("font_color", cor)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 2)
    return l


func _botao(valor: String, largura: float) -> Button:
    var b := Button.new()
    b.text = valor
    b.custom_minimum_size = Vector2(largura, 50)
    b.add_theme_font_override("font", load(FONTE_TEXTO))
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_stylebox_override("normal", _caixa(Color(0.06, 0.09, 0.15, 0.96), Color(0.34, 0.40, 0.45), 1, 8))
    b.add_theme_stylebox_override("hover", _caixa(Color(0.09, 0.17, 0.24, 0.98), Color(0.35, 0.76, 0.96), 2, 8))
    b.add_theme_stylebox_override("pressed", _caixa(Color(0.08, 0.20, 0.28, 0.98), Color(0.92, 0.73, 0.30), 2, 8))
    return b


func _retrato_eco(id: String, arte_frames: String) -> Texture2D:
    # Retrato dedicado nítido para menu. O atlas menor continua exclusivo do
    # mundo 3D, onde economiza memória e nunca é ampliado desta forma.
    var retrato := "res://textures/ui/ecos/%s.png" % id
    if ResourceLoader.exists(retrato):
        return load(retrato) as Texture2D
    if not arte_frames.is_empty() and ResourceLoader.exists(arte_frames):
        var frames := load(arte_frames) as SpriteFrames
        return frames.get_frame_texture(&"idle", 0)
    return null


func _montar() -> void:
    var sombra := ColorRect.new()
    sombra.color = Color(0.005, 0.008, 0.018, 0.90)
    sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
    sombra.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(sombra)
    _base = Control.new()
    _base.size = TAMANHO
    sombra.add_child(_base)
    var arte := TextureRect.new()
    arte.texture = load(FUNDO)
    arte.set_anchors_preset(Control.PRESET_FULL_RECT)
    arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    arte.stretch_mode = TextureRect.STRETCH_SCALE
    arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _base.add_child(arte)
    var margem := MarginContainer.new()
    margem.set_anchors_preset(Control.PRESET_FULL_RECT)
    margem.add_theme_constant_override("margin_left", 54)
    margem.add_theme_constant_override("margin_right", 54)
    margem.add_theme_constant_override("margin_top", 36)
    margem.add_theme_constant_override("margin_bottom", 38)
    _base.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 14)
    margem.add_child(coluna)
    var cab := HBoxContainer.new()
    coluna.add_child(cab)
    cab.add_child(_texto("Santuário dos Ecos", 35, Color(0.92, 0.79, 0.46), true))
    var espaco := Control.new()
    espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cab.add_child(espaco)
    var poder := _texto("4ª skill  •  Eco equipado segue Akles", 16, Color(0.55, 0.82, 0.96))
    poder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cab.add_child(poder)
    _fechar = _botao("Fechar", 120)
    cab.add_child(_fechar)
    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 18)
    coluna.add_child(corpo)
    corpo.add_child(_montar_catalogo())
    corpo.add_child(_montar_detalhes())
    _atualizar()


func _montar_catalogo() -> Control:
    var painel := PanelContainer.new()
    painel.custom_minimum_size.x = 850
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.018, 0.035, 0.065, 0.91), Color(0.24, 0.34, 0.43), 1, 12))
    var grade := GridContainer.new()
    grade.columns = 4
    grade.add_theme_constant_override("h_separation", 9)
    grade.add_theme_constant_override("v_separation", 9)
    painel.add_child(grade)
    for eco in _dados:
        var id := str(eco.get("id", ""))
        var botao := _botao(str(eco.get("nota", id)), 194)
        botao.custom_minimum_size.y = 204
        botao.toggle_mode = true
        var pilha := VBoxContainer.new()
        pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
        pilha.offset_top = 36
        pilha.offset_bottom = -8
        pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
        botao.add_child(pilha)
        var icone := TextureRect.new()
        icone.custom_minimum_size = Vector2(180, 112)
        icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var caminho := str(eco.get("arte", ""))
        icone.texture = _retrato_eco(id, caminho)
        pilha.add_child(icone)
        var forma := _texto("Forma 1  •  Nascente" if not caminho.is_empty() else "Arte pendente", 13, Color(0.58, 0.78, 0.91))
        forma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        pilha.add_child(forma)
        grade.add_child(botao)
        _botoes[id] = botao
    return painel


func _montar_detalhes() -> Control:
    var painel := PanelContainer.new()
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.025, 0.055, 0.095, 0.94), Color(0.36, 0.56, 0.70), 1, 14))
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 9)
    painel.add_child(coluna)
    _nome = _texto("", 28, Color(0.95, 0.82, 0.48), true)
    _nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_nome)
    _forma = _texto("", 15, Color(0.57, 0.82, 0.98))
    _forma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_forma)
    _preview = TextureRect.new()
    _preview.custom_minimum_size = Vector2(0, 210)
    _preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coluna.add_child(_preview)
    _personalidade = _texto("", 16, Color(0.79, 0.82, 0.88))
    _personalidade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(_personalidade)
    _habilidade = _texto("", 17, Color(0.62, 0.86, 1.0))
    _habilidade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(_habilidade)
    _buff = _texto("", 17, Color(0.82, 0.67, 0.98))
    _buff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(_buff)
    var evolucao := _texto("Nascente  →  Crescente  →  Ancestral\nA habilidade mantém sua identidade e ganha alcance, potência e novos efeitos.", 14, Color(0.72, 0.73, 0.76))
    evolucao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    evolucao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(evolucao)
    _estado = _texto("", 15, Color(0.96, 0.84, 0.48))
    _estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_estado)
    _equipar = _botao("Equipar Eco", 310)
    coluna.add_child(_equipar)
    return painel


func _selecionar(id: String) -> void:
    _selecionado = id
    _atualizar()


func _atualizar() -> void:
    if _progresso == null or not _por_id.has(_selecionado):
        return
    var eco: Dictionary = _por_id[_selecionado]
    var descoberto: bool = _selecionado in _progresso.ecos_descobertos
    var equipado: bool = str(_progresso.eco_equipado.get("id", "")) == _selecionado
    for id in _botoes:
        (_botoes[id] as Button).button_pressed = str(id) == _selecionado
        (_botoes[id] as Button).modulate = Color.WHITE if id in _progresso.ecos_descobertos else Color(0.42, 0.46, 0.54, 0.80)
    _nome.text = str(eco.get("nome", "Eco"))
    _forma.text = "Forma 1 de 3  •  NASCENTE  •  Poder %d" % int(eco.get("poder", 0))
    _personalidade.text = "Personalidade\n" + str(eco.get("personalidade", ""))
    _habilidade.text = "Skill 4 — %s\n%s" % [eco.get("habilidade", ""), eco.get("efeito", "")]
    _buff.text = "Passiva — %s\n%s" % [eco.get("buff", ""), eco.get("buff_efeito", "")]
    var caminho := str(eco.get("arte", ""))
    _preview.texture = null
    _preview.texture = _retrato_eco(_selecionado, caminho)
    _equipar.disabled = not descoberto or caminho.is_empty() or equipado
    _equipar.text = "Equipado" if equipado else "Equipar como 4ª skill" if descoberto else "Ainda não capturado"
    if equipado:
        _estado.text = "Equipado • acompanha Akles e libera a 4ª skill"
    elif descoberto:
        _estado.text = "Disponível para equipar"
    else:
        var almas: int = int(_progresso.quantidade("alma_eco_" + _selecionado))
        var notas: int = int(_progresso.quantidade("nota_" + _selecionado))
        _estado.text = "Bloqueado • Almas %d / 3 • Notas %d / 5 • catalisador ainda será definido" % [almas, notas]


func _equipar_atual() -> void:
    if _progresso and _por_id.has(_selecionado):
        _progresso.equipar_eco(_por_id[_selecionado])


func mostrar(sim := true) -> void:
    _aberta = sim
    visible = sim
    if sim:
        _atualizar()


func _ajustar() -> void:
    if _base == null:
        return
    var viewport := get_viewport().get_visible_rect().size
    var fator := minf(viewport.x / TAMANHO.x, viewport.y / TAMANHO.y)
    _base.scale = Vector2.ONE * fator
    _base.position = (viewport - TAMANHO * fator) * 0.5


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
    if _fechar.get_global_rect().has_point(pos):
        mostrar(false)
        get_viewport().set_input_as_handled()
        return
    for id in _botoes:
        if (_botoes[id] as Button).get_global_rect().has_point(pos):
            _selecionar(str(id))
            get_viewport().set_input_as_handled()
            return
    if _equipar.get_global_rect().has_point(pos):
        _equipar_atual()
        get_viewport().set_input_as_handled()
