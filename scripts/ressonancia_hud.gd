extends CanvasLayer
## HUD pequeno e independente para mapas com Ecos capturáveis.

signal ressoar_iniciado
signal ressoar_parado

var _painel: PanelContainer
var _nome: Label
var _barra: ProgressBar
var _botao: Button
var _aviso: Label
var _afinador: Control
var _ponteiro := 0.0
var _janela := 0.3
var _afinado := false


func _desenhar_afinador() -> void:
    if _afinador == null:
        return
    var r := _afinador.size
    var meio := r.y * 0.5
    _afinador.draw_line(Vector2(0, meio), Vector2(r.x, meio), Color(0.30, 0.36, 0.48, 0.9), 2.0)
    # A janela: a faixa em que o Eco responde. Ela encolhe conforme a captura
    # avanca, entao o fim exige mais pontaria que o comeco.
    var meia := _janela * r.x * 0.5
    var cor_janela: Color = Color(1.0, 0.84, 0.42, 0.85) if _afinado else Color(0.55, 0.62, 0.75, 0.55)
    _afinador.draw_rect(Rect2(r.x * 0.5 - meia, 1.0, meia * 2.0, r.y - 2.0),
        Color(cor_janela.r, cor_janela.g, cor_janela.b, 0.18), true)
    _afinador.draw_rect(Rect2(r.x * 0.5 - meia, 1.0, meia * 2.0, r.y - 2.0), cor_janela, false, 1.5)
    var x: float = r.x * 0.5 + _ponteiro * r.x * 0.5
    var cor_ponteiro: Color = Color(1.0, 0.92, 0.58) if _afinado else Color(0.86, 0.90, 1.0)
    _afinador.draw_line(Vector2(x, 0.0), Vector2(x, r.y), cor_ponteiro, 2.5, true)


func _ready() -> void:
    layer = 12
    _painel = PanelContainer.new()
    _painel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _painel.offset_left = -180.0
    _painel.offset_right = 180.0
    _painel.offset_top = 86.0
    _painel.offset_bottom = 185.0
    var estilo := StyleBoxFlat.new()
    estilo.bg_color = Color(0.018, 0.035, 0.075, 0.92)
    estilo.border_color = Color(0.26, 0.78, 0.96, 0.86)
    estilo.set_border_width_all(2)
    estilo.set_corner_radius_all(13)
    estilo.content_margin_left = 16
    estilo.content_margin_right = 16
    estilo.content_margin_top = 9
    estilo.content_margin_bottom = 9
    _painel.add_theme_stylebox_override("panel", estilo)
    add_child(_painel)

    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 5)
    _painel.add_child(coluna)
    _nome = Label.new()
    _nome.text = "RESSONÂNCIA"
    _nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _nome.add_theme_font_size_override("font_size", 15)
    _nome.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
    coluna.add_child(_nome)
    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 8)
    coluna.add_child(linha)
    _barra = ProgressBar.new()
    _barra.custom_minimum_size = Vector2(230, 30)
    _barra.max_value = 1.0
    _barra.show_percentage = false
    linha.add_child(_barra)

    # A REGUA DE AFINACAO.
    #
    # Um ponteiro varrendo e uma janela dourada que estreita. E o desenho de um
    # afinador, de proposito: quem ja viu um afinador entende sem instrucao, e
    # quem nunca viu aprende o que significa "estar dentro do tom".
    _afinador = Control.new()
    _afinador.custom_minimum_size = Vector2(230, 16)
    _afinador.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _afinador.draw.connect(_desenhar_afinador)
    linha.add_child(_afinador)
    _botao = Button.new()
    _botao.text = "RESSOAR"
    _botao.custom_minimum_size = Vector2(102, 40)
    _botao.add_theme_font_size_override("font_size", 14)
    linha.add_child(_botao)
    _aviso = Label.new()
    _aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _aviso.add_theme_font_size_override("font_size", 12)
    _aviso.add_theme_color_override("font_color", Color(0.95, 0.83, 0.42))
    coluna.add_child(_aviso)
    _botao.button_down.connect(func(): ressoar_iniciado.emit())
    _botao.button_up.connect(func(): ressoar_parado.emit())
    visible = false


func mostrar_eco(nome_eco: String, progresso: float, tem_ressonador: bool,
        ponteiro := 0.0, janela := 0.3, afinado := false) -> void:
    _ponteiro = ponteiro
    _janela = janela
    _afinado = afinado
    if _afinador:
        _afinador.queue_redraw()
    visible = true
    _nome.text = "RESSONÂNCIA  •  " + nome_eco
    _barra.value = clampf(progresso, 0.0, 1.0)
    _botao.disabled = not tem_ressonador
    _aviso.text = "Ressonador necessário" if not tem_ressonador else "Segure para extrair o Eco"


func esconder() -> void:
    visible = false
    _barra.value = 0.0


func recompensa(texto: String) -> void:
    visible = true
    _nome.text = "RESSONÂNCIA CONCLUÍDA"
    _barra.value = 1.0
    _botao.disabled = true
    _aviso.text = texto

