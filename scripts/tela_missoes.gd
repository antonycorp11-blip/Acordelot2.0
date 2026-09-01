extends CanvasLayer
class_name TelaMissoes
## As três tarefas do dia, o que falta em cada uma e o que se ganha ao fechar.
##
## Segue a mesma moldura, a mesma fonte e os mesmos botões da tela de ajustes: um
## painel do kit, um miolo que ROLA e a saída fora da rolagem. Painel de tamanho
## fixo com conteúdo variável é o que faz componente vazar em celular estreito, e
## a quantidade de linhas aqui muda com a redação de cada tarefa.
##
## Sem ornamento novo. O dourado aparece no título, no aro da barra e no número
## do contador — e mais nada, porque é justamente o excesso de moldura que fazia
## as telas antigas parecerem carnaval.

const KIT := "res://textures/ui/kit/"
const FONTE := "res://fontes/Cinzel.ttf"

const OURO := Color(0.97, 0.84, 0.47)
const TEXTO := Color(0.86, 0.89, 0.94)
const APAGADO := Color(0.60, 0.64, 0.72)
const FEITO := Color(0.62, 0.95, 0.62)

var _fundo: ColorRect
var _lista: VBoxContainer
var _contador: Label
var _rodape: Label


func _ready() -> void:
    layer = 18
    _montar()
    visible = false
    var diario := get_node_or_null("/root/Diario")
    if diario and not diario.alterado.is_connected(_repintar):
        diario.alterado.connect(_repintar)


func mostrar(sim := true) -> void:
    visible = sim
    if sim:
        _repintar()


func _montar() -> void:
    _fundo = ColorRect.new()
    _fundo.color = Color(0.02, 0.02, 0.05, 0.78)
    _fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    _fundo.gui_input.connect(func(e: InputEvent):
        if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
            mostrar(false))
    add_child(_fundo)

    var painel := NinePatchRect.new()
    painel.texture = load(KIT + "moldura_painel_grande.png")
    painel.patch_margin_left = 22
    painel.patch_margin_top = 68
    painel.patch_margin_right = 22
    painel.patch_margin_bottom = 64
    painel.anchor_left = 0.5
    painel.anchor_right = 0.5
    painel.anchor_top = 0.06
    painel.anchor_bottom = 0.94
    painel.offset_left = -295.0
    painel.offset_right = 295.0
    painel.mouse_filter = Control.MOUSE_FILTER_STOP
    _fundo.add_child(painel)

    var coluna := VBoxContainer.new()
    coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
    coluna.offset_left = 34
    coluna.offset_right = -34
    coluna.offset_top = 74
    coluna.offset_bottom = -30
    coluna.add_theme_constant_override("separation", 6)
    painel.add_child(coluna)

    coluna.add_child(_rotulo("Diário de Acordelot", 26, OURO))

    _contador = _rotulo("0/3", 17, TEXTO)
    coluna.add_child(_contador)

    var rolagem := ScrollContainer.new()
    rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    coluna.add_child(rolagem)

    _lista = VBoxContainer.new()
    _lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _lista.add_theme_constant_override("separation", 10)
    rolagem.add_child(_lista)

    _rodape = _rotulo("", 13, APAGADO, true)
    coluna.add_child(_rodape)

    var fechar := _botao("Fechar", "botao_vermelho")
    fechar.pressed.connect(func(): mostrar(false))
    coluna.add_child(fechar)


func _repintar() -> void:
    if _lista == null:
        return
    for antigo in _lista.get_children():
        antigo.queue_free()

    var diario := get_node_or_null("/root/Diario")
    if diario == null:
        _contador.text = "—"
        return

    var feitas: int = diario.concluidas()
    var total: int = diario.missoes.size()
    _contador.text = "%d de %d concluídas hoje" % [feitas, total]
    _contador.add_theme_color_override("font_color",
        FEITO if total > 0 and feitas >= total else TEXTO)

    for missao in diario.missoes:
        _lista.add_child(_cartao(missao))

    if total > 0 and feitas >= total:
        _rodape.text = "Dia fechado. As tarefas de amanhã chegam com o novo dia."
    else:
        _rodape.text = "Fechar as três rende %d Claves e uma Partitura Menor." % diario.CLAVES_DO_DIA


## Uma tarefa: quem pediu, o que é, e o quanto já andou.
func _cartao(missao: Dictionary) -> Control:
    var feito: int = int(missao["feito"])
    var meta: int = int(missao["meta"])
    var pronto: bool = feito >= meta

    var caixa := PanelContainer.new()
    var moldura := StyleBoxFlat.new()
    moldura.bg_color = Color(0.045, 0.07, 0.12, 0.90)
    moldura.border_color = Color(0.42, 0.62, 0.40, 0.85) if pronto else Color(0.55, 0.46, 0.26, 0.75)
    moldura.set_border_width_all(1)
    moldura.set_corner_radius_all(8)
    moldura.content_margin_left = 14
    moldura.content_margin_right = 14
    moldura.content_margin_top = 10
    moldura.content_margin_bottom = 12
    caixa.add_theme_stylebox_override("panel", moldura)

    var dentro := VBoxContainer.new()
    dentro.add_theme_constant_override("separation", 4)
    caixa.add_child(dentro)

    var topo := HBoxContainer.new()
    dentro.add_child(topo)

    var titulo := _rotulo(str(missao["titulo"]), 17, FEITO if pronto else OURO)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topo.add_child(titulo)

    var quanto := _rotulo("%d/%d" % [feito, meta], 15, FEITO if pronto else TEXTO)
    quanto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    topo.add_child(quanto)

    var quem := _rotulo(str(missao["dono"]), 12, APAGADO)
    quem.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    dentro.add_child(quem)

    var texto := _rotulo(str(missao["texto"]), 14, TEXTO, true)
    texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    dentro.add_child(texto)

    dentro.add_child(_barra(float(feito) / maxf(float(meta), 1.0), pronto))
    return caixa


## A barra de andamento: dois retângulos, sem textura.
##
## Podia usar a moldura de barra do kit, mas ela vem com o preenchimento pintado
## dentro e exigiria o mesmo recorte que a barra de vida usa. Para uma linha de
## quatro pixels dentro de um cartão, o aro desenhado à mão é mais honesto e não
## carrega mais uma imagem para a memória de vídeo.
func _barra(fracao: float, pronto: bool) -> Control:
    var trilho := PanelContainer.new()
    trilho.custom_minimum_size = Vector2(0, 8)
    var fundo := StyleBoxFlat.new()
    fundo.bg_color = Color(0.02, 0.03, 0.05, 0.95)
    fundo.set_corner_radius_all(4)
    trilho.add_theme_stylebox_override("panel", fundo)

    var cheio := ProgressBar.new()
    cheio.min_value = 0.0
    cheio.max_value = 1.0
    cheio.value = clampf(fracao, 0.0, 1.0)
    cheio.show_percentage = false
    cheio.custom_minimum_size = Vector2(0, 8)
    var vazio_estilo := StyleBoxFlat.new()
    vazio_estilo.bg_color = Color(0, 0, 0, 0)
    cheio.add_theme_stylebox_override("background", vazio_estilo)
    var cheio_estilo := StyleBoxFlat.new()
    cheio_estilo.bg_color = Color(0.44, 0.80, 0.46) if pronto else Color(0.85, 0.68, 0.32)
    cheio_estilo.set_corner_radius_all(4)
    cheio.add_theme_stylebox_override("fill", cheio_estilo)
    trilho.add_child(cheio)
    return trilho


func _rotulo(txt: String, corpo: int, cor: Color, quebra := false) -> Label:
    var l := Label.new()
    l.text = txt
    l.add_theme_font_override("font", load(FONTE))
    l.add_theme_font_size_override("font_size", corpo)
    l.add_theme_color_override("font_color", cor)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
    return l


func _botao(rotulo: String, arte := "botao_azul") -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(0, 46)
    b.text = rotulo
    b.add_theme_font_override("font", load(FONTE))
    b.add_theme_font_size_override("font_size", 18)
    b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    for estado in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    var fundo := NinePatchRect.new()
    fundo.texture = load(KIT + arte + ".png")
    fundo.patch_margin_left = 36
    fundo.patch_margin_top = 28
    fundo.patch_margin_right = 36
    fundo.patch_margin_bottom = 14
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.show_behind_parent = true
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(fundo)
    return b
