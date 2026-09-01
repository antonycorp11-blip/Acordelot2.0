extends Control
class_name PaginaMapa
## O mapa do reino dentro do shell.
##
## O desenho e o MESMO do minimapa — nao ha um segundo cartografo. A pagina so
## empresta a sua area de desenho para a funcao que ja existe, em vez de
## duplicar as cores das zonas, as estradas e os rios num arquivo novo.
const T := preload("res://scripts/ui_tema.gd")
var _minimapa: Node
var _tela: Control

func _ready() -> void:
    _montar()

func ao_abrir() -> void:
    if _minimapa == null:
        _minimapa = get_tree().root.find_child("ZoneMinimap", true, false)
    if _minimapa and _tela:
        _minimapa._world_map_draw = _tela
        if not _tela.draw.is_connected(_minimapa._desenhar_mapa_reino):
            _tela.draw.connect(_minimapa._desenhar_mapa_reino)
        if not _tela.gui_input.is_connected(_minimapa._clicar_mapa_reino):
            _tela.gui_input.connect(_minimapa._clicar_mapa_reino)
    if _tela:
        _tela.queue_redraw()

func _montar() -> void:
    var col := VBoxContainer.new()
    col.set_anchors_preset(Control.PRESET_FULL_RECT)
    col.add_theme_constant_override("separation", 8)
    add_child(col)
    var p := T.coluna(10)
    p.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(p)
    _tela = Control.new()
    _tela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tela.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tela.mouse_filter = Control.MOUSE_FILTER_STOP
    p.add_child(_tela)
    col.add_child(T.rotulo(
        "Toque numa região para viajar. O desenho vem das estradas, rios e construções reais.",
        T.CORPO, T.TEXTO_FRACO))
