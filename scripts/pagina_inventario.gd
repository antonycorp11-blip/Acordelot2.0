extends Control
class_name PaginaInventario
## O INVENTARIO, redesenhado do zero em HTML e aprovado pelo dono antes de virar
## codigo — por isso os numeros aqui sao os da maquete, nao chute.
##
## O QUE MUDOU e por que:
##
## 1. O CARD GIGANTE DE DETALHE SAIU. Ele comia metade da tela. O detalhe agora
##    e uma JANELINHA que abre ao SEGURAR o item — pequena, centrada. Toque
##    simples so seleciona.
## 2. OS FILTROS VIRARAM ICONES numa faixa estreita a esquerda, em vez de nomes
##    grandes que gastavam largura.
## 3. A GRADE OCUPA O RESTO DA TELA, com ALTURA DE LINHA FIXA. Na maquete web, o
##    `aspect-ratio` do slot brigava com a altura da grade que rola e o Safari
##    empilhava as fileiras. Na Godot o GridContainer com celula de tamanho fixo
##    nao tem esse problema — cada slot mede o mesmo e nada se sobrepoe.
##
## A arte dos itens e a REAL do jogo (fragmentos, cristais, pergaminhos), lida
## do catalogo; a raridade pinta o aro do slot. O conteudo — quantidade, tipo,
## descricao, o que o botao Usar faz — sai do Progresso, como antes.

const P := preload("res://scripts/ui_proto.gd")
const CATALOGO := preload("res://scripts/inventory_ui.gd")

const CAPACIDADE := 150
## Medidas da maquete aprovada.
const LADO_DO_SLOT := 84.0
const ALTURA_DO_SLOT := 88.0
const VAO := 10.0
const LARGURA_DA_FAIXA := 92.0

## Cor de cada raridade — a mesma da maquete, separada do dourado do acento.
const CORES := {
    "Comum": Color("8290a6"), "Incomum": Color("4cc9a0"), "Raro": Color("3da8ff"),
    "Épico": Color("b56cff"), "Lendário": Color("f1cf78"), "Valioso": Color("ffb534"),
}

var _progresso: Node
var _diario: Node
var _filtro := "Todos"
var _selecionado := ""

var _grade: GridContainer
var _rolagem: ScrollContainer
var _botoes_filtro: Dictionary = {}
var _lotacao: ColorRect
var _rodape: Label
## Os numeros dos tres contadores do topo, por legenda.
var _selo_num: Dictionary = {}

## Segurar para abrir a janelinha.
var _hold: Timer
var _hold_id := ""
var _segurou := false
var _pop: Control
var _pop_card: PanelContainer


## A casca cede a tela inteira para esta pagina: topo proprio, sem cabecalho
## dela. A navbar de baixo continua, que e como se troca de tela.
func desenha_o_proprio_topo() -> bool:
    return true


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _diario = get_node_or_null("/root/Diario")
    _hold = Timer.new()
    _hold.one_shot = true
    add_child(_hold)
    _hold.timeout.connect(func():
        _segurou = true
        if _hold_id != "":
            _abrir_janela(_hold_id))
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_repintar):
        _progresso.alterado.connect(_repintar)


func ao_abrir() -> void:
    _repintar()


# ------------------------------------------------------------------ montagem

func _montar() -> void:
    var pilha := VBoxContainer.new()
    pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
    pilha.add_theme_constant_override("separation", 0)
    add_child(pilha)

    pilha.add_child(_montar_topo())

    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 14)
    var margem := MarginContainer.new()
    margem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margem.add_theme_constant_override(lado, 16)
    margem.add_child(corpo)
    pilha.add_child(margem)

    corpo.add_child(_montar_faixa())
    corpo.add_child(_montar_centro())

    _montar_janela()


## O topo: emblema, titulo, os tres contadores e o fechar.
func _montar_topo() -> Control:
    var barra := PanelContainer.new()
    var fundo := StyleBoxFlat.new()
    fundo.bg_color = Color("12203c")
    fundo.border_color = Color("243352")
    fundo.border_width_bottom = 1
    fundo.content_margin_left = 20
    fundo.content_margin_right = 18
    fundo.content_margin_top = 13
    fundo.content_margin_bottom = 11
    barra.add_theme_stylebox_override("panel", fundo)

    var fila := HBoxContainer.new()
    fila.add_theme_constant_override("separation", 14)
    barra.add_child(fila)

    var emblema := _disco_com_icone("nota", 44.0)
    fila.add_child(emblema)

    var ident := VBoxContainer.new()
    ident.add_theme_constant_override("separation", 0)
    ident.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var sobre := P.rotulo("ARQUIVO DO MAESTRO", 10, P.MUTED)
    sobre.add_theme_constant_override("line_spacing", 0)
    ident.add_child(sobre)
    var titulo := P.rotulo("INVENTÁRIO", 25, P.IVORY)
    titulo.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    ident.add_child(titulo)
    fila.add_child(ident)

    var espaco := Control.new()
    espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila.add_child(espaco)

    fila.add_child(_contador("moeda", P.GOLD_BRIGHT, "Claves"))
    fila.add_child(_contador("hexagono", Color("b56cff"), "Materiais"))
    fila.add_child(_contador("coroa", Color("4cc9a0"), "Fragmentos"))

    var fechar := Button.new()
    fechar.custom_minimum_size = Vector2(40, 40)
    fechar.focus_mode = Control.FOCUS_NONE
    var af := StyleBoxFlat.new()
    af.bg_color = Color("1a0f13")
    af.border_color = Color("7a3b3b")
    af.set_border_width_all(2)
    af.set_corner_radius_all(20)
    fechar.add_theme_stylebox_override("normal", af)
    fechar.add_theme_stylebox_override("hover", af)
    fechar.add_theme_stylebox_override("pressed", af)
    fechar.add_theme_stylebox_override("focus", af)
    var xis := Control.new()
    xis.set_anchors_preset(Control.PRESET_FULL_RECT)
    xis.mouse_filter = Control.MOUSE_FILTER_IGNORE
    xis.draw.connect(func():
        var c := xis.size * 0.5
        var cor := Color("f0c9c9")
        xis.draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), cor, 2.4, true)
        xis.draw_line(c + Vector2(7, -7), c + Vector2(-7, 7), cor, 2.4, true))
    fechar.add_child(xis)
    fechar.pressed.connect(func():
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("fechar_tudo"):
            casca.fechar_tudo())
    fila.add_child(fechar)
    return barra


## Um contador do topo: disco com icone, numero grande, legenda embaixo.
## Devolve o CHIP; o numero fica guardado em `_selo_num[legenda]`.
func _contador(icone: String, cor: Color, legenda: String) -> Control:
    var chip := PanelContainer.new()
    var e := StyleBoxFlat.new()
    e.bg_color = Color("0b142ab0")
    e.border_color = Color("243352")
    e.set_border_width_all(1)
    e.set_corner_radius_all(9)
    e.content_margin_left = 9
    e.content_margin_right = 13
    e.content_margin_top = 7
    e.content_margin_bottom = 7
    chip.add_theme_stylebox_override("panel", e)
    var fila := HBoxContainer.new()
    fila.add_theme_constant_override("separation", 8)
    chip.add_child(fila)
    fila.add_child(_icone(icone, 20.0, cor))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 0)
    col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var num := P.rotulo("0", 14, P.IVORY)
    col.add_child(num)
    var leg := P.rotulo(legenda.to_upper(), 10, P.MUTED)
    col.add_child(leg)
    fila.add_child(col)
    _selo_num[legenda] = num
    return chip


## A FAIXA DE FILTROS, so com icones.
func _montar_faixa() -> Control:
    var faixa := VBoxContainer.new()
    faixa.custom_minimum_size.x = LARGURA_DA_FAIXA
    faixa.add_theme_constant_override("separation", 8)
    for nome in CATALOGO.FILTROS:
        var b := _botao_de_filtro(String(nome))
        faixa.add_child(b)
        _botoes_filtro[String(nome)] = b
    return faixa


func _botao_de_filtro(nome: String) -> Button:
    var b := Button.new()
    b.custom_minimum_size.y = 62.0
    b.focus_mode = Control.FOCUS_NONE
    for estado in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())

    var placa := Panel.new()
    placa.name = "Placa"
    placa.set_anchors_preset(Control.PRESET_FULL_RECT)
    placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(placa)

    var col := VBoxContainer.new()
    col.set_anchors_preset(Control.PRESET_FULL_RECT)
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    col.add_theme_constant_override("separation", 3)
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(col)
    var ic := _icone_de_filtro(nome)
    ic.name = "Icone"
    ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    col.add_child(ic)
    var curto := nome
    if nome == "Consumíveis":
        curto = "Consum."
    var leg := P.rotulo(curto.to_upper(), 9, P.MUTED)
    leg.name = "Leg"
    leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(leg)

    var conta := P.rotulo("", 10, P.MUTED)
    conta.name = "Conta"
    conta.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    conta.offset_left = -22.0
    conta.offset_top = 5.0
    conta.offset_right = -6.0
    conta.mouse_filter = Control.MOUSE_FILTER_IGNORE
    conta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    conta.add_theme_color_override("font_outline_color", Color("0a1122"))
    conta.add_theme_constant_override("outline_size", 3)
    b.add_child(conta)

    b.pressed.connect(_escolher_filtro.bind(nome))
    return b


## A GRADE, com o cabecalho e a barra de lotacao.
func _montar_centro() -> Control:
    var centro := VBoxContainer.new()
    centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    centro.add_theme_constant_override("separation", 10)

    var cabeca := HBoxContainer.new()
    cabeca.add_theme_constant_override("separation", 10)
    var titulo := P.rotulo("Bolsa", 17, P.IVORY)
    titulo.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    cabeca.add_child(titulo)
    var sub := P.rotulo("Fragmentos, notas e relíquias", 12, P.MUTED)
    sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    cabeca.add_child(sub)
    var vazio := Control.new()
    vazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cabeca.add_child(vazio)
    var dica := P.rotulo("segure um item para ver detalhes", 11, Color("5a647c"))
    dica.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    cabeca.add_child(dica)
    centro.add_child(cabeca)

    _rolagem = ScrollContainer.new()
    _rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _rolagem.resized.connect(_arrumar_colunas)
    _grade = GridContainer.new()
    _grade.columns = 8
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grade.add_theme_constant_override("h_separation", int(VAO))
    _grade.add_theme_constant_override("v_separation", int(VAO))
    _rolagem.add_child(_grade)
    centro.add_child(_rolagem)

    var cap := HBoxContainer.new()
    cap.add_theme_constant_override("separation", 10)
    var trilho := ColorRect.new()
    trilho.color = Color("0a1226")
    trilho.custom_minimum_size = Vector2(0, 8)
    trilho.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    trilho.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _lotacao = ColorRect.new()
    _lotacao.color = P.GOLD_BRIGHT
    _lotacao.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    _lotacao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trilho.add_child(_lotacao)
    cap.add_child(trilho)
    _rodape = P.rotulo("", 12, P.MUTED)
    cap.add_child(_rodape)
    centro.add_child(cap)
    return centro


## Quantas colunas cabem na largura atual — recalculado quando a area muda.
func _arrumar_colunas() -> void:
    if _rolagem == null or _grade == null:
        return
    var largura := _rolagem.size.x - 8.0
    var colunas: int = maxi(1, int(floor((largura + VAO) / (LADO_DO_SLOT + VAO))))
    if _grade.columns != colunas:
        _grade.columns = colunas


# --------------------------------------------------------------- pintura

func _escolher_filtro(nome: String) -> void:
    _filtro = nome
    _repintar()


func _repintar() -> void:
    if _progresso == null or _grade == null:
        return
    _pintar_topo()
    _pintar_filtros()
    _pintar_grade()


func _pintar_topo() -> void:
    var materiais := 0
    var fragmentos := 0
    for it in CATALOGO.ITENS_DE_RECURSO:
        var id := String(it[0])
        var qtd: int = _progresso.quantidade(id)
        if String(it[4]) == "material":
            materiais += qtd
        if id.begins_with("fragmento_"):
            fragmentos += qtd
    if _selo_num.has("Claves"):
        _selo_num["Claves"].text = _milhar(_progresso.quantidade("claves"))
    if _selo_num.has("Materiais"):
        _selo_num["Materiais"].text = _curto(materiais)
    if _selo_num.has("Fragmentos"):
        _selo_num["Fragmentos"].text = _curto(fragmentos)


func _pintar_filtros() -> void:
    for nome in _botoes_filtro:
        var b: Button = _botoes_filtro[nome]
        var escolhido: bool = String(nome) == _filtro
        var placa := b.get_node_or_null("Placa") as Panel
        if placa:
            var e := StyleBoxFlat.new()
            e.bg_color = Color("13345a") if escolhido else Color(0, 0, 0, 0)
            e.border_color = Color("2f4f86") if escolhido else Color(0, 0, 0, 0)
            e.set_border_width_all(1)
            e.set_corner_radius_all(11)
            placa.add_theme_stylebox_override("panel", e)
        var leg := b.get_node_or_null("Leg") as Label
        if leg:
            leg.add_theme_color_override("font_color",
                Color("cfe2ff") if escolhido else P.MUTED)
        var conta := b.get_node_or_null("Conta") as Label
        if conta:
            conta.text = str(_contar_no_filtro(String(nome)))
            conta.add_theme_color_override("font_color",
                Color("9dc2ff") if escolhido else Color("5a647c"))
        var ic := b.get_node_or_null("Icone") as Control
        if ic:
            ic.queue_redraw()


func _contar_no_filtro(nome: String) -> int:
    var n := 0
    for it in CATALOGO.ITENS_DE_RECURSO:
        if _progresso.quantidade(String(it[0])) <= 0:
            continue
        if nome == "Todos" or String(it[4]) == String(CATALOGO.TIPO_DO_FILTRO.get(nome, "")):
            n += 1
    return n


func _pintar_grade() -> void:
    for velho in _grade.get_children():
        _grade.remove_child(velho)
        velho.queue_free()

    var itens: Array = []
    for it in CATALOGO.ITENS_DE_RECURSO:
        if _progresso.quantidade(String(it[0])) <= 0:
            continue
        if _filtro != "Todos" and String(it[4]) != String(CATALOGO.TIPO_DO_FILTRO.get(_filtro, "")):
            continue
        itens.append(it)

    if _selecionado == "" or _progresso.quantidade(_selecionado) <= 0:
        _selecionado = String(itens[0][0]) if not itens.is_empty() else ""

    for it in itens:
        _grade.add_child(_slot(it))
    # Casas vazias para a grade nao parecer que "acabou" — como no desenho.
    var vazias: int = maxi(0, _grade.columns * 4 - itens.size())
    for k in vazias:
        _grade.add_child(_slot_vazio())

    var ocupados := 0
    for it in CATALOGO.ITENS_DE_RECURSO:
        if _progresso.quantidade(String(it[0])) > 0:
            ocupados += 1
    _lotacao.anchor_right = clampf(float(ocupados) / float(CAPACIDADE), 0.0, 1.0)
    _rodape.text = "%d / %d espaços" % [ocupados, CAPACIDADE]
    _arrumar_colunas()


## Um slot: arte real do item, aro da raridade, quantidade no canto.
func _slot(it: Array) -> Control:
    var id := String(it[0])
    var raridade := String(it[3])
    var cor: Color = CORES.get(raridade, P.MUTED)
    var escolhido: bool = id == _selecionado

    var b := Button.new()
    b.custom_minimum_size = Vector2(LADO_DO_SLOT, ALTURA_DO_SLOT)
    b.focus_mode = Control.FOCUS_NONE
    b.clip_contents = true
    var e := StyleBoxFlat.new()
    e.bg_color = Color("0d1730")
    e.border_color = cor if escolhido else Color("243352")
    e.set_border_width_all(2 if escolhido else 1)
    e.set_corner_radius_all(11)
    b.add_theme_stylebox_override("normal", e)
    var ev := e.duplicate() as StyleBoxFlat
    ev.border_color = cor
    b.add_theme_stylebox_override("hover", ev)
    b.add_theme_stylebox_override("pressed", ev)
    b.add_theme_stylebox_override("focus", e)

    # aro fino da raridade, sempre visivel
    var aro := Control.new()
    aro.set_anchors_preset(Control.PRESET_FULL_RECT)
    aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    aro.draw.connect(func():
        var r := Rect2(Vector2(2, 2), aro.size - Vector2(4, 4))
        aro.draw_rect(r, Color(cor, 0.9 if escolhido else 0.35), false, 1.5 if escolhido else 1.0))
    b.add_child(aro)

    var img := P.arte(_caminho_da_arte(String(it[2])), Vector2(48, 48))
    img.set_anchors_preset(Control.PRESET_FULL_RECT)
    img.offset_left = 12.0
    img.offset_top = 6.0
    img.offset_right = -12.0
    img.offset_bottom = -18.0
    img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(img)

    var qtd := P.rotulo(_curto(_progresso.quantidade(id)), 12, P.IVORY)
    qtd.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    qtd.offset_left = -40.0
    qtd.offset_top = -20.0
    qtd.offset_right = -5.0
    qtd.offset_bottom = -3.0
    qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    qtd.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    qtd.add_theme_constant_override("outline_size", 4)
    qtd.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(qtd)

    # tocar seleciona; segurar abre a janelinha
    b.button_down.connect(func():
        _hold_id = id
        _segurou = false
        _hold.start(0.35))
    b.button_up.connect(func(): _hold.stop())
    b.pressed.connect(func():
        if _segurou:
            _segurou = false
            return
        _selecionado = id
        _pintar_grade())
    return b


func _slot_vazio() -> Control:
    var c := Panel.new()
    c.custom_minimum_size = Vector2(LADO_DO_SLOT, ALTURA_DO_SLOT)
    var e := StyleBoxFlat.new()
    e.bg_color = Color("080e1c")
    e.border_color = Color("1c2942")
    e.set_border_width_all(1)
    e.set_corner_radius_all(11)
    c.add_theme_stylebox_override("panel", e)
    c.modulate.a = 0.5
    var estrela := Control.new()
    estrela.set_anchors_preset(Control.PRESET_FULL_RECT)
    estrela.mouse_filter = Control.MOUSE_FILTER_IGNORE
    estrela.draw.connect(func():
        _desenhar_estrela(estrela, estrela.size * 0.5, 7.0, Color("2a3a5c")))
    c.add_child(estrela)
    return c


# ------------------------------------------------------ a janelinha (segurar)

func _montar_janela() -> void:
    _pop = Control.new()
    _pop.name = "Janela"
    _pop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _pop.visible = false
    _pop.z_index = 20
    add_child(_pop)

    var fundo := ColorRect.new()
    fundo.color = Color("04070f", 0.72)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    fundo.gui_input.connect(func(ev):
        if ev is InputEventMouseButton and ev.pressed:
            _fechar_janela())
    _pop.add_child(fundo)

    _pop_card = PanelContainer.new()
    _pop_card.set_anchors_preset(Control.PRESET_CENTER)
    _pop_card.custom_minimum_size.x = 360.0
    var e := StyleBoxFlat.new()
    e.bg_color = Color("122446")
    e.border_color = Color("33456a")
    e.set_border_width_all(1)
    e.set_corner_radius_all(15)
    e.content_margin_left = 20
    e.content_margin_right = 20
    e.content_margin_top = 18
    e.content_margin_bottom = 18
    e.shadow_color = Color(0, 0, 0, 0.75)
    e.shadow_size = 24
    _pop_card.add_theme_stylebox_override("panel", e)
    _pop.add_child(_pop_card)


func _abrir_janela(id: String) -> void:
    var ficha := _ficha(id)
    if ficha.is_empty():
        return
    for velho in _pop_card.get_children():
        velho.queue_free()

    var raridade := String(ficha[3])
    var cor: Color = CORES.get(raridade, P.MUTED)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 4)
    _pop_card.add_child(col)

    # chip de raridade + fechar na mesma linha
    var topo := HBoxContainer.new()
    var chip := _chip_raridade(raridade, cor)
    topo.add_child(chip)
    var vazio := Control.new()
    vazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topo.add_child(vazio)
    var px := Button.new()
    px.custom_minimum_size = Vector2(28, 28)
    px.focus_mode = Control.FOCUS_NONE
    var pe := StyleBoxFlat.new()
    pe.bg_color = Color("1a0f13")
    pe.border_color = Color("7a3b3b")
    pe.set_border_width_all(1)
    pe.set_corner_radius_all(14)
    for est in ["normal", "hover", "pressed", "focus"]:
        px.add_theme_stylebox_override(est, pe)
    var pxis := Control.new()
    pxis.set_anchors_preset(Control.PRESET_FULL_RECT)
    pxis.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pxis.draw.connect(func():
        var c := pxis.size * 0.5
        pxis.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Color("f0c9c9"), 2.0, true)
        pxis.draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), Color("f0c9c9"), 2.0, true))
    px.add_child(pxis)
    px.pressed.connect(_fechar_janela)
    topo.add_child(px)
    col.add_child(topo)

    # arte grande com halo
    var palco := Control.new()
    palco.custom_minimum_size.y = 96.0
    var halo := P.arte("", Vector2(0, 0))
    halo.queue_free()
    var brilho := Control.new()
    brilho.set_anchors_preset(Control.PRESET_FULL_RECT)
    brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
    brilho.draw.connect(func():
        var c := brilho.size * 0.5
        for i in range(10, 0, -1):
            brilho.draw_circle(c, 8.0 * i, Color(cor, 0.02)))
    palco.add_child(brilho)
    var img := P.arte(_caminho_da_arte(String(ficha[2])), Vector2(76, 76))
    img.set_anchors_preset(Control.PRESET_CENTER)
    img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    palco.add_child(img)
    col.add_child(palco)

    var nome := P.rotulo(String(ficha[1]), 20, Color.WHITE, true)
    nome.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nome.custom_minimum_size.x = 320.0
    col.add_child(nome)
    var cat := P.rotulo(_nome_da_categoria(String(ficha[4])), 12, P.MUTED)
    cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(cat)

    col.add_child(_risco_dourado())

    var desc := P.rotulo(String(ficha[5]) if ficha.size() > 5 else "", 13, Color("c3cad9"), true)
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.custom_minimum_size.x = 320.0
    col.add_child(desc)
    col.add_child(P.espaco_elastico() if false else _espaco(6))

    var linha_qtd := HBoxContainer.new()
    var lq := P.rotulo("Quantidade", 13, P.MUTED)
    lq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha_qtd.add_child(lq)
    linha_qtd.add_child(P.rotulo(_milhar(_progresso.quantidade(id)), 13, P.IVORY))
    col.add_child(linha_qtd)

    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 8)
    var usavel := _e_usavel(id)
    if usavel:
        var usar := _botao_acao("USAR", "primary")
        usar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        usar.pressed.connect(func(): _usar(id); _fechar_janela())
        acoes.add_child(usar)
    var dividir := _botao_acao("DIVIDIR", "ghost")
    dividir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    acoes.add_child(dividir)
    if _pode_descartar(id, String(ficha[4])):
        var desc_b := _botao_acao("", "danger")
        desc_b.custom_minimum_size.x = 46.0
        desc_b.pressed.connect(func(): _descartar(id); _fechar_janela())
        var lixo := Control.new()
        lixo.set_anchors_preset(Control.PRESET_FULL_RECT)
        lixo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        lixo.draw.connect(func():
            var c := lixo.size * 0.5
            var col2 := Color("e79ba0")
            lixo.draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 12)), col2, false, 1.6, true)
            lixo.draw_line(c + Vector2(-8, -4), c + Vector2(8, -4), col2, 1.6, true)
            lixo.draw_line(c + Vector2(-2, -7), c + Vector2(2, -7), col2, 1.6, true))
        desc_b.add_child(lixo)
        acoes.add_child(desc_b)
    col.add_child(_espaco(8))
    col.add_child(acoes)

    _pop.visible = true


func _fechar_janela() -> void:
    if _pop:
        _pop.visible = false


# ------------------------------------------------------------- acoes reais

func _e_usavel(id: String) -> bool:
    if id == "pocao_cura":
        return true
    if _progresso.ACORDES.has(id):
        return true
    for tipo in _progresso.PARTITURAS:
        if String(_progresso.PARTITURAS[tipo]["recurso"]) == id:
            return true
    return false


func _usar(id: String) -> void:
    var ficha := _ficha(id)
    if ficha.is_empty() or _progresso == null:
        return
    if id == "pocao_cura" and _progresso.quantidade(id) > 0:
        var hud := get_tree().get_first_node_in_group("player_hud")
        if hud and hud.has_method("curar"):
            hud.curar(hud.max_health * 0.35)
            _progresso.adicionar_recurso(id, -1)
            _avisar("Poção utilizada", "+35% de vida")
        return
    if _progresso.ACORDES.has(id):
        var fracao: float = _progresso.usar_acorde(id)
        if fracao > 0.0:
            var hud := get_tree().get_first_node_in_group("player_hud")
            if hud and hud.has_method("curar"):
                hud.curar(hud.max_health * fracao)
            if id == "acorde_vigor" and hud and hud.has_method("conceder_escudo"):
                hud.conceder_escudo(hud.max_health * 0.20)
            _avisar("Harmonia restaurada", "%s  ·  +%d%% de vida"
                % [String(ficha[1]), int(fracao * 100.0)])
        return
    for tipo in _progresso.PARTITURAS:
        if String(_progresso.PARTITURAS[tipo]["recurso"]) == id:
            _progresso.usar_partitura(String(tipo))
            _avisar("Experiência absorvida",
                "+%d XP de %s" % [int(_progresso.PARTITURAS[tipo]["xp"]), String(ficha[1])])
            return


func _descartar(id: String) -> void:
    if _progresso == null or id == "":
        return
    _progresso.adicionar_recurso(id, -1)
    _repintar()


func _pode_descartar(id: String, tipo: String) -> bool:
    if tipo == "ferramenta" or id in ["selo_regente", "nucleo_maestro",
            "emblema_nota_silenciada"]:
        return false
    if _diario:
        for missao in _diario.missoes:
            if int(missao["feito"]) >= int(missao["meta"]):
                continue
            if String(missao["alvo"]) == id:
                return false
    return true


func _avisar(sobre: String, texto: String) -> void:
    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar"):
        casca.avisar(sobre, texto)


# ------------------------------------------------------------- pecas soltas

func _chip_raridade(raridade: String, cor: Color) -> Control:
    var p := PanelContainer.new()
    var e := StyleBoxFlat.new()
    e.bg_color = Color(cor, 0.15)
    e.border_color = Color(cor, 0.55)
    e.set_border_width_all(1)
    e.set_corner_radius_all(6)
    e.content_margin_left = 11
    e.content_margin_right = 11
    e.content_margin_top = 4
    e.content_margin_bottom = 4
    p.add_theme_stylebox_override("panel", e)
    p.add_child(P.rotulo(raridade.to_upper(), 10, cor))
    return p


func _botao_acao(texto: String, variante: String) -> Button:
    var b := Button.new()
    b.text = texto
    b.custom_minimum_size.y = 44.0
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    b.add_theme_font_size_override("font_size", 14)
    var e := StyleBoxFlat.new()
    e.set_corner_radius_all(10)
    match variante:
        "primary":
            e.bg_color = Color("d3aa53")
            b.add_theme_color_override("font_color", Color("2a1e05"))
        "ghost":
            e.bg_color = Color("0e1c38")
            e.border_color = Color("2f4f86")
            e.set_border_width_all(1)
            b.add_theme_color_override("font_color", Color("bcd0f0"))
        _:
            e.bg_color = Color("1c0f13")
            e.border_color = Color("7a3b3b")
            e.set_border_width_all(1)
            b.add_theme_color_override("font_color", Color("e79ba0"))
    for est in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(est, e)
    return b


func _risco_dourado() -> Control:
    var c := Control.new()
    c.custom_minimum_size.y = 12.0
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.draw.connect(func():
        var y := c.size.y * 0.5
        var meio := c.size.x * 0.5
        var cor := Color("6a542c", 0.9)
        c.draw_line(Vector2(0, y), Vector2(meio - 8, y), cor, 1.0, true)
        c.draw_line(Vector2(meio + 8, y), Vector2(c.size.x, y), cor, 1.0, true)
        c.draw_colored_polygon(PackedVector2Array([
            Vector2(meio, y - 4), Vector2(meio + 4, y),
            Vector2(meio, y + 4), Vector2(meio - 4, y)]), P.GOLD))
    c.resized.connect(c.queue_redraw)
    return c


func _espaco(alt: float) -> Control:
    var c := Control.new()
    c.custom_minimum_size.y = alt
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return c


func _disco_com_icone(icone: String, lado: float) -> Control:
    var disco := Panel.new()
    disco.custom_minimum_size = Vector2(lado, lado)
    disco.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var e := StyleBoxFlat.new()
    e.bg_color = Color("0f1a33")
    e.border_color = P.GOLD
    e.set_border_width_all(2)
    e.set_corner_radius_all(int(lado * 0.5))
    disco.add_theme_stylebox_override("panel", e)
    var ic := _icone(icone, lado * 0.5, P.GOLD_BRIGHT)
    ic.set_anchors_preset(Control.PRESET_CENTER)
    disco.add_child(ic)
    return disco


## Um icone desenhado, no tamanho e cor pedidos. Nenhum depende de arte externa.
func _icone(qual: String, lado: float, cor: Color) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(lado, lado)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.draw.connect(func(): _desenhar_icone(c, qual, cor))
    return c


func _icone_de_filtro(nome: String) -> Control:
    var mapa := {"Todos": "grade", "Materiais": "hexagono",
        "Consumíveis": "frasco", "Missões": "pergaminho", "Valiosos": "bolsa"}
    var qual := String(mapa.get(nome, "grade"))
    var c := Control.new()
    c.custom_minimum_size = Vector2(24, 24)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.draw.connect(func():
        var ativo: bool = _filtro == nome
        _desenhar_icone(c, qual, Color("cfe2ff") if ativo else P.MUTED))
    return c


func _desenhar_icone(no: Control, qual: String, cor: Color) -> void:
    var s := no.size
    var c := s * 0.5
    var k := s.x / 24.0
    match qual:
        "grade":
            for p in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]:
                no.draw_rect(Rect2(c + p * k - Vector2(3.5, 3.5) * k, Vector2(7, 7) * k), cor, false, 1.5 * k, true)
        "hexagono", "material":
            var pts := PackedVector2Array()
            for i in 6:
                var a := PI / 6.0 + TAU * i / 6.0
                pts.append(c + Vector2(cos(a), sin(a)) * 9.0 * k)
            for i in 6:
                no.draw_line(pts[i], pts[(i + 1) % 6], cor, 1.6 * k, true)
        "frasco":
            no.draw_line(c + Vector2(-3, -8) * k, c + Vector2(-3, -2) * k, cor, 1.6 * k, true)
            no.draw_line(c + Vector2(3, -8) * k, c + Vector2(3, -2) * k, cor, 1.6 * k, true)
            no.draw_line(c + Vector2(-5, -8) * k, c + Vector2(5, -8) * k, cor, 1.6 * k, true)
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-3, -2) * k, c + Vector2(3, -2) * k,
                c + Vector2(7, 8) * k, c + Vector2(-7, 8) * k]), Color(cor, 0.0))
            no.draw_polyline(PackedVector2Array([
                c + Vector2(-3, -2) * k, c + Vector2(-7, 8) * k, c + Vector2(7, 8) * k,
                c + Vector2(3, -2) * k]), cor, 1.6 * k, true)
        "pergaminho":
            no.draw_rect(Rect2(c + Vector2(-7, -9) * k, Vector2(14, 18) * k), cor, false, 1.5 * k, true)
            for yy in [-4, 0, 4]:
                no.draw_line(c + Vector2(-4, yy) * k, c + Vector2(4, yy) * k, cor, 1.2 * k, true)
        "bolsa":
            no.draw_polyline(PackedVector2Array([
                c + Vector2(-7, -1) * k, c + Vector2(-5, 9) * k, c + Vector2(5, 9) * k,
                c + Vector2(7, -1) * k, c + Vector2(-7, -1) * k]), cor, 1.6 * k, true)
            no.draw_arc(c + Vector2(0, -1) * k, 4.0 * k, PI, TAU, 12, cor, 1.6 * k, true)
        "nota":
            no.draw_line(c + Vector2(3, -9) * k, c + Vector2(3, 5) * k, cor, 1.6 * k, true)
            no.draw_circle(c + Vector2(0, 6) * k, 3.0 * k, cor)
            no.draw_line(c + Vector2(3, -9) * k, c + Vector2(9, -7) * k, cor, 1.6 * k, true)
        "moeda":
            no.draw_circle(c, 9.0 * k, cor)
            no.draw_circle(c, 5.5 * k, Color(cor.darkened(0.3)))
        "coroa":
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-8, 6) * k, c + Vector2(-8, -4) * k, c + Vector2(-3, 1) * k,
                c + Vector2(0, -6) * k, c + Vector2(3, 1) * k, c + Vector2(8, -4) * k,
                c + Vector2(8, 6) * k]), cor)
        _:
            no.draw_circle(c, 8.0 * k, cor)


func _desenhar_estrela(no: Control, centro: Vector2, raio: float, cor: Color) -> void:
    var pts := PackedVector2Array()
    for i in 10:
        var r: float = raio if i % 2 == 0 else raio * 0.44
        var a: float = -PI * 0.5 + PI * float(i) / 5.0
        pts.append(centro + Vector2(cos(a), sin(a)) * r)
    no.draw_colored_polygon(pts, cor)


func _nome_da_categoria(tipo: String) -> String:
    match tipo:
        "material": return "Material"
        "consumivel": return "Consumível"
        "valioso": return "Valioso"
        "ferramenta": return "Ferramenta"
        "missao": return "Missão"
        _: return tipo.capitalize()


# ---------------------------------------------------------------- catalogo

func _ficha(id: String) -> Array:
    for it in CATALOGO.ITENS_DE_RECURSO:
        if String(it[0]) == id:
            return it
    return []


func _caminho_da_arte(caminho: String) -> String:
    return caminho if caminho.begins_with("res://") \
        else "res://textures/ui/kit/" + caminho + ".png"


func _curto(n: int) -> String:
    if n < 1000:
        return str(n)
    if n < 1000000:
        var mil: float = float(n) / 1000.0
        return ("%.0fk" % mil) if mil >= 10.0 else ("%.1fk" % mil).replace(".0", "")
    return "%.1fM" % (float(n) / 1000000.0)


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
