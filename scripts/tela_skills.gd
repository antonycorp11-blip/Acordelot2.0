extends CanvasLayer
## Grade funcional de habilidades. Os marcos passivos ficam visiveis desde o
## inicio; nomes e efeitos finais podem ser definidos sem reconstruir a tela.

const FUNDO := "res://textures/ui/painel_harmonia_v2.jpg"
const FONTE_TITULO := "res://fontes/CinzelDecorative.ttf"
const FONTE_TEXTO := "res://fontes/Cinzel.ttf"
const AreaSeguraUI := preload("res://scripts/area_segura_ui.gd")
const TAMANHO := Vector2(1600, 900)
const SKILLS := [
    {"id":"ataque_basico","nome":"Cadência da Espada","icone":"res://textures/ui/btn_ataque.png","papel":"Ataque básico","desc":"Sequência de golpes do Akles. Cada nível aumenta seu dano em 5%."},
    {"id":"skill_1","nome":"Aura Azul","icone":"res://textures/ui/btn_skill1.png","papel":"Amplificação","desc":"Fortalece temporariamente os ataques. Cada nível aumenta a amplificação."},
    {"id":"skill_2","nome":"Lâmina Crescente","icone":"res://textures/ui/btn_skill2.png","papel":"Alcance e poder","desc":"Expande a espada e o alcance. Seus níveis elevam o dano durante o efeito."},
    {"id":"skill_3","nome":"Raio Harmônico","icone":"res://textures/ui/btn_skill3.png","papel":"Dano em linha","desc":"Feixe direcionável de grande alcance. Cada nível aumenta o dano do disparo."},
]

var _progresso: Node
var _base: Control
var _aberta := false
var _selecionada := "ataque_basico"
var _botoes := {}
var _fechar: Button
var _upar: Button
var _pontos: Label
var _titulo: Label
var _descricao: Label
var _nivel: Label
var _marcos: Array[Label] = []


func _ready() -> void:
    layer = 17
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    get_viewport().size_changed.connect(_ajustar)
    _ajustar()
    if _progresso and not _progresso.alterado.is_connected(_atualizar):
        _progresso.alterado.connect(_atualizar)
    visible = false


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
    b.custom_minimum_size = Vector2(largura, 52)
    b.add_theme_font_override("font", load(FONTE_TEXTO))
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_stylebox_override("normal", _caixa(Color(0.055, 0.08, 0.14, 0.96), Color(0.34, 0.40, 0.46), 1, 8))
    b.add_theme_stylebox_override("pressed", _caixa(Color(0.08, 0.18, 0.27, 0.98), Color(0.95, 0.73, 0.30), 2, 8))
    b.add_theme_stylebox_override("disabled", _caixa(Color(0.035, 0.04, 0.06, 0.88), Color(0.17, 0.17, 0.19), 1, 8))
    return b


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
    margem.add_theme_constant_override("margin_left", 60)
    margem.add_theme_constant_override("margin_right", 60)
    margem.add_theme_constant_override("margin_top", 38)
    margem.add_theme_constant_override("margin_bottom", 42)
    _base.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 16)
    margem.add_child(coluna)
    var cab := HBoxContainer.new()
    coluna.add_child(cab)
    cab.add_child(_texto("Trilhas de Ressonância", 35, Color(0.93, 0.79, 0.46), true))
    var vao := Control.new()
    vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cab.add_child(vao)
    _pontos = _texto("", 18, Color(0.48, 0.82, 1.0))
    _pontos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cab.add_child(_pontos)
    _fechar = _botao("Fechar", 120)
    cab.add_child(_fechar)
    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 18)
    coluna.add_child(corpo)
    corpo.add_child(_grade())
    corpo.add_child(_detalhes())
    _atualizar()


func _grade() -> Control:
    var painel := PanelContainer.new()
    painel.custom_minimum_size.x = 930
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.018, 0.035, 0.065, 0.92), Color(0.25, 0.35, 0.44), 1, 13))
    var grade := GridContainer.new()
    grade.columns = 2
    grade.add_theme_constant_override("h_separation", 14)
    grade.add_theme_constant_override("v_separation", 14)
    painel.add_child(grade)
    for dados in SKILLS:
        var id := str(dados["id"])
        var b := _botao(str(dados["nome"]), 440)
        b.custom_minimum_size.y = 230
        b.toggle_mode = true
        var pilha := VBoxContainer.new()
        pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
        pilha.offset_top = 40
        pilha.offset_bottom = -12
        pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(pilha)
        var icone := TextureRect.new()
        icone.texture = load(str(dados["icone"]))
        icone.custom_minimum_size = Vector2(0, 105)
        icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        pilha.add_child(icone)
        var trilha := _texto("◇  Nv.3    ◇  Nv.6    ◇  Nv.9", 14, Color(0.52, 0.72, 0.88))
        trilha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        pilha.add_child(trilha)
        grade.add_child(b)
        _botoes[id] = b
    return painel


func _detalhes() -> Control:
    var painel := PanelContainer.new()
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    painel.add_theme_stylebox_override("panel", _caixa(Color(0.025, 0.055, 0.095, 0.94), Color(0.36, 0.56, 0.70), 1, 14))
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 14)
    painel.add_child(coluna)
    _titulo = _texto("", 28, Color(0.95, 0.82, 0.48), true)
    _titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_titulo)
    _nivel = _texto("", 18, Color(0.55, 0.84, 1.0))
    _nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_nivel)
    _descricao = _texto("", 17, Color(0.80, 0.83, 0.89))
    _descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(_descricao)
    coluna.add_child(_texto("Marcos passivos", 21, Color(0.82, 0.66, 0.96), true))
    for marco in [3, 6, 9]:
        var l := _texto("", 16, Color(0.52, 0.56, 0.62))
        coluna.add_child(l)
        _marcos.append(l)
    var aviso := _texto("Os efeitos e nomes finais de cada passiva serão definidos sem alterar esta estrutura.", 14, Color(0.68, 0.69, 0.73))
    aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(aviso)
    var vao := Control.new()
    vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(vao)
    _upar = _botao("Aprimorar skill", 360)
    coluna.add_child(_upar)
    return painel


func _dados_atuais() -> Dictionary:
    for dados in SKILLS:
        if str(dados["id"]) == _selecionada:
            return dados
    return SKILLS[0]


func _atualizar() -> void:
    if _progresso == null or _titulo == null:
        return
    var dados := _dados_atuais()
    var nivel_skill := int(_progresso.niveis_skills.get(_selecionada, 1))
    var desbloqueio := int(_progresso.NIVEIS_DESBLOQUEIO_SKILLS.get(_selecionada, 1))
    var desbloqueada: bool = _progresso.skill_desbloqueada(_selecionada)
    _pontos.text = "Pontos de Skill  %d  •  1 por nível de Akles" % _progresso.pontos_de_skill_disponiveis()
    _titulo.text = str(dados["nome"])
    _nivel.text = "Nível %d / %d  •  %s" % [nivel_skill, _progresso.NIVEL_MAXIMO_SKILL, dados["papel"]]
    _descricao.text = str(dados["desc"])
    for i in _marcos.size():
        var marco: int = [3, 6, 9][i]
        _marcos[i].text = "%s  Marco passivo do nível %d" % ["◆" if nivel_skill >= marco else "◇", marco]
        _marcos[i].add_theme_color_override("font_color", Color(0.72, 0.56, 1.0) if nivel_skill >= marco else Color(0.44, 0.47, 0.53))
    for id in _botoes:
        var b := _botoes[id] as Button
        b.button_pressed = str(id) == _selecionada
        var n := int(_progresso.niveis_skills.get(id, 1))
        var req := int(_progresso.NIVEIS_DESBLOQUEIO_SKILLS.get(id, 1))
        b.text = "%s\n%s" % [_nome_skill(str(id)), "Nv.%d" % n if _progresso.nivel >= req else "Desbloqueia no nível %d" % req]
    _upar.disabled = not desbloqueada or nivel_skill >= _progresso.NIVEL_MAXIMO_SKILL or _progresso.pontos_de_skill_disponiveis() <= 0
    _upar.text = "Aprimorar para Nv.%d" % (nivel_skill + 1) if desbloqueada and nivel_skill < _progresso.NIVEL_MAXIMO_SKILL else "Desbloqueia no nível %d" % desbloqueio if not desbloqueada else "Nível máximo"


func _nome_skill(id: String) -> String:
    for dados in SKILLS:
        if str(dados["id"]) == id:
            return str(dados["nome"])
    return id


func mostrar(sim := true) -> void:
    _aberta = sim
    visible = sim
    if sim:
        _atualizar()


func _ajustar() -> void:
    if _base == null:
        return
    var viewport := get_viewport().get_visible_rect().size
    AreaSeguraUI.ajustar_base(_base, TAMANHO, viewport)


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
            _selecionada = str(id)
            _atualizar()
            get_viewport().set_input_as_handled()
            return
    if _upar.get_global_rect().has_point(pos):
        _progresso.subir_skill(_selecionada)
        get_viewport().set_input_as_handled()
