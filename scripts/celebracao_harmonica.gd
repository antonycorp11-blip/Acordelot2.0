extends Control
class_name CelebracaoHarmonica
## Feedback leve para progressao: nenhum shader, particula ou textura nova.
## O brilho e composto por paineis e Tween, portanto funciona igual no Web.

var _cartao: PanelContainer
var _titulo: Label
var _detalhe: Label
var _tween: Tween


func _ready() -> void:
    # ANCORA **E** MARGEM. `set_anchors_preset` mexe so nas ancoras: o retangulo
    # continuava com o tamanho que tinha antes, e o cartao, centrado nesse
    # retangulo errado, nascia com metade fora da tela pela esquerda e pelo alto
    # — medido em x -140 e y -82. Como ele so aparece ao subir de nivel, dava
    # para nao notar ate acontecer.
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    get_viewport().size_changed.connect(func():
        set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT))
    _cartao = PanelContainer.new()
    _cartao.set_anchors_preset(Control.PRESET_CENTER)
    _cartao.offset_left = -280
    _cartao.offset_right = 280
    _cartao.offset_top = -82
    _cartao.offset_bottom = 82
    _cartao.pivot_offset = Vector2(280, 82)
    _cartao.modulate.a = 0.0
    add_child(_cartao)
    var caixa := StyleBoxFlat.new()
    caixa.bg_color = Color(0.018, 0.045, 0.09, 0.96)
    caixa.border_color = Color(0.34, 0.78, 1.0, 0.95)
    caixa.set_border_width_all(2)
    caixa.set_corner_radius_all(18)
    caixa.shadow_color = Color(0.1, 0.55, 1.0, 0.38)
    caixa.shadow_size = 18
    _cartao.add_theme_stylebox_override("panel", caixa)
    var coluna := VBoxContainer.new()
    coluna.alignment = BoxContainer.ALIGNMENT_CENTER
    _cartao.add_child(coluna)
    _titulo = Label.new()
    _titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _titulo.add_theme_font_override("font", load("res://fontes/CinzelDecorative.ttf"))
    _titulo.add_theme_font_size_override("font_size", 30)
    _titulo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
    coluna.add_child(_titulo)
    _detalhe = Label.new()
    _detalhe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _detalhe.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    _detalhe.add_theme_font_size_override("font_size", 18)
    _detalhe.add_theme_color_override("font_color", Color(0.76, 0.90, 1.0))
    coluna.add_child(_detalhe)


func mostrar_evento(titulo: String, detalhe: String, cor := Color(0.34, 0.78, 1.0)) -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    _titulo.text = "✦  " + titulo + "  ✦"
    _detalhe.text = detalhe
    var caixa := _cartao.get_theme_stylebox("panel") as StyleBoxFlat
    caixa.border_color = cor
    caixa.shadow_color = Color(cor.r, cor.g, cor.b, 0.38)
    _cartao.scale = Vector2(0.78, 0.78)
    _cartao.modulate = Color(1, 1, 1, 0)
    _tween = create_tween().set_parallel(true)
    _tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_property(_cartao, "scale", Vector2.ONE, 0.32)
    _tween.tween_property(_cartao, "modulate:a", 1.0, 0.18)
    _tween.chain().set_parallel(false).tween_interval(0.85)
    _tween.tween_property(_cartao, "modulate:a", 0.0, 0.28)
