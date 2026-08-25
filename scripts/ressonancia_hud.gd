extends CanvasLayer
## HUD pequeno e independente para mapas com Ecos capturáveis.

signal ressoar_iniciado
signal ressoar_parado

var _painel: PanelContainer
var _nome: Label
var _barra: ProgressBar
var _botao: Button
var _aviso: Label


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


func mostrar_eco(nome_eco: String, progresso: float, tem_ressonador: bool) -> void:
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

