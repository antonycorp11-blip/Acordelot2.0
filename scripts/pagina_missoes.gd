extends Control
class_name PaginaMissoes
## O diario do dia dentro do shell.
const T := preload("res://scripts/ui_tema.gd")
var _diario: Node
var _contador: Label
var _lista: VBoxContainer
var _rodape: Label

func _ready() -> void:
    _diario = get_node_or_null("/root/Diario")
    _montar()
    if _diario and not _diario.alterado.is_connected(_pintar):
        _diario.alterado.connect(_pintar)

func ao_abrir() -> void: _pintar()

func _montar() -> void:
    var col := VBoxContainer.new()
    col.set_anchors_preset(Control.PRESET_FULL_RECT)
    col.add_theme_constant_override("separation", 8)
    add_child(col)
    _contador = T.rotulo_simples("", 19, T.SOBRANCELHA)
    col.add_child(_contador)
    col.add_child(T.espaco(8))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(rol)
    _lista = VBoxContainer.new()
    _lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _lista.add_theme_constant_override("separation", 12)
    rol.add_child(_lista)
    _rodape = T.rotulo("", T.CORPO, T.TEXTO_FRACO)
    col.add_child(_rodape)

func _pintar() -> void:
    if _diario == null or _lista == null: return
    for a in _lista.get_children(): a.queue_free()
    var feitas: int = _diario.concluidas()
    var total: int = _diario.missoes.size()
    _contador.text = "%d de %d concluídas hoje" % [feitas, total]
    _contador.add_theme_color_override("font_color",
        T.SUCESSO if total > 0 and feitas >= total else T.OURO_FORTE)
    for missao in _diario.missoes:
        _lista.add_child(_cartao(missao))
    _rodape.text = "Dia fechado. Amanhã chegam tarefas novas." if total > 0 and feitas >= total \
        else "Fechar as três rende %d Claves e uma Partitura Menor." % _diario.CLAVES_DO_DIA

func _cartao(missao: Dictionary) -> Control:
    var feito: int = int(missao["feito"])
    var meta: int = int(missao["meta"])
    var pronto: bool = feito >= meta
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", T.painel(T.NAVY_PAINEL,
        T.SUCESSO if pronto else T.OURO_ARO, 10, 1, 16))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 5)
    p.add_child(col)
    var topo := HBoxContainer.new()
    col.add_child(topo)
    var titulo := T.rotulo(String(missao["titulo"]), T.NOME_ITEM,
        T.SUCESSO if pronto else T.OURO_FORTE)
    titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topo.add_child(titulo)
    topo.add_child(T.rotulo("%d/%d" % [feito, meta], T.CONTADOR,
        T.SUCESSO if pronto else T.TEXTO))
    col.add_child(T.rotulo(String(missao["dono"]), T.LEGENDA, T.TEXTO_FRACO))
    col.add_child(T.rotulo(String(missao["texto"]), T.CORPO, T.TEXTO_FRACO))
    var barra := ProgressBar.new()
    barra.custom_minimum_size.y = 10
    barra.show_percentage = false
    barra.max_value = 1.0
    barra.value = clampf(float(feito) / maxf(float(meta), 1.0), 0.0, 1.0)
    var vazio := StyleBoxFlat.new()
    vazio.bg_color = Color(0.02, 0.03, 0.05, 0.95)
    vazio.set_corner_radius_all(5)
    barra.add_theme_stylebox_override("background", vazio)
    var cheio := StyleBoxFlat.new()
    cheio.bg_color = T.SUCESSO if pronto else T.OURO
    cheio.set_corner_radius_all(5)
    barra.add_theme_stylebox_override("fill", cheio)
    col.add_child(barra)
    return p
