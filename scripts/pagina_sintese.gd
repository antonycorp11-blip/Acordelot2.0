extends Control
class_name PaginaSintese
## A oficina transforma exatamente 30 fragmentos puros da mesma altura em uma
## nota. Acordes e escalas sairam daqui: vivem na Forja de Escalas, como sistema
## separado, para o jogador entender cada degrau da progressao musical.
const P := preload("res://scripts/ui_proto.gd")

const NOTAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do": "Dó", "do_sustenido": "Dó#", "re": "Ré", "re_sustenido": "Ré#",
    "mi": "Mi", "fa": "Fá", "fa_sustenido": "Fá#", "sol": "Sol",
    "sol_sustenido": "Sol#", "la": "Lá", "la_sustenido": "Lá#", "si": "Si"}
const PUROS_POR_NOTA := 30

var _progresso: Node
var _escolhida := "do"
var _lista: GridContainer
var _forja_nome: Label
var _forja_pedra: TextureRect
var _forja_estado: Label
var _bolhas: HBoxContainer
var _purificar: Button
var _condensar: Button
var _direita: VBoxContainer
var _partituras: VBoxContainer
## As duas abas da tela, como na especificacao: notas e fragmentos de um lado,
## partituras e nivel do outro.
const KIT := "res://textures/ui/kit/sintese/"
var _aba := "partituras"
var _painel_notas: Control
var _painel_partituras: Control
var _botoes_de_aba: Dictionary = {}
var _pulso: Tween


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)


func ao_abrir() -> void:
    _trocar_aba(_aba)
    _pintar()

func subtitulo_da_pagina() -> String: return "Atelie de notas e fragmentos"


## Uma peca do kit da Sintese, no tamanho pedido.
func _peca(nome: String, tamanho: Vector2, esticar := true) -> TextureRect:
    var t := TextureRect.new()
    var caminho := KIT + nome + ".png"
    if ResourceLoader.exists(caminho):
        t.texture = load(caminho)
    t.custom_minimum_size = tamanho
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_SCALE if esticar \
        else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return t


func _montar() -> void:
    var pilha := VBoxContainer.new()
    pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
    pilha.add_theme_constant_override("separation", 10)
    add_child(pilha)

    # AS DUAS ABAS, como na folha: 56 px de altura, 16 de espaco entre elas.
    var abas := HBoxContainer.new()
    abas.alignment = BoxContainer.ALIGNMENT_CENTER
    abas.add_theme_constant_override("separation", 16)
    pilha.add_child(abas)
    for dados in [["notas", "NOTAS E FRAGMENTOS"], ["partituras", "PARTITURAS E NÍVEL"]]:
        var b := Button.new()
        b.custom_minimum_size = Vector2(296, 56)
        b.focus_mode = Control.FOCUS_NONE
        b.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
        b.add_theme_font_size_override("font_size", 17)
        for estado in ["normal", "hover", "pressed", "focus"]:
            b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
        var arte := _peca("aba_ativa", Vector2(296, 56))
        arte.name = "Ativa"
        arte.set_anchors_preset(Control.PRESET_FULL_RECT)
        arte.show_behind_parent = true
        b.add_child(arte)
        var apagada := _peca("aba_inativa", Vector2(296, 56))
        apagada.name = "Inativa"
        apagada.set_anchors_preset(Control.PRESET_FULL_RECT)
        apagada.show_behind_parent = true
        b.add_child(apagada)
        b.text = String(dados[1])
        b.pressed.connect(_trocar_aba.bind(String(dados[0])))
        abas.add_child(b)
        _botoes_de_aba[String(dados[0])] = b

    _painel_partituras = _montar_partituras()
    _painel_partituras.size_flags_vertical = Control.SIZE_EXPAND_FILL
    pilha.add_child(_painel_partituras)

    var linha := HBoxContainer.new()
    linha.size_flags_vertical = Control.SIZE_EXPAND_FILL
    linha.add_theme_constant_override("separation", 20)
    pilha.add_child(linha)
    _painel_notas = linha

    var esq := P.painel()
    # 470 + o palco + a coluna das partituras nao cabe em 1614. A lista de doze
    # notas nunca precisou de 470: ela e nome e dois numeros por linha.
    esq.custom_minimum_size.x = 330
    linha.add_child(esq)
    var ce := VBoxContainer.new()
    ce.add_theme_constant_override("separation", 10)
    esq.add_child(P.recheio(ce, 14))
    ce.add_child(P.cabecalho("SELECIONAR NOTA", "Famílias harmônicas", "12"))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ce.add_child(rol)
    _lista = GridContainer.new()
    _lista.columns = 3
    _lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _lista.add_theme_constant_override("h_separation", 10)
    _lista.add_theme_constant_override("v_separation", 10)
    rol.add_child(_lista)
    ce.add_child(P.rotulo("Fragmentos purificados da mesma família formam uma Nota Sintetizada.", 9, P.MUTED, true))

    var meio := P.painel(Color("08162ce8"))
    meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(meio)
    var conceito := TextureRect.new()
    conceito.texture = load("res://textures/ui/concepts/synthesis-forge-bg.png")
    conceito.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    conceito.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    conceito.modulate = Color(0.82, 0.88, 1.0, 0.62)
    conceito.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meio.add_child(conceito)
    # O MIOLO ROLA. Medido na auditoria: o conteudo passa 372 px por baixo da
    # area util, e a pagina tem recorte — ou seja, o que sobra e simplesmente
    # cortado. Reduzir largura nao resolve transbordamento vertical, que foi a
    # minha primeira tentativa.
    var rolagem_meio := ScrollContainer.new()
    rolagem_meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rolagem_meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rolagem_meio.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var cm := VBoxContainer.new()
    cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cm.add_theme_constant_override("separation", 6)
    rolagem_meio.add_child(cm)
    meio.add_child(P.recheio(rolagem_meio, 16))
    var instrucao := P.sobrancelha("PURIFIQUE FRAGMENTOS CORROMPIDOS PARA SINTETIZAR NOVAS NOTAS")
    instrucao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cm.add_child(instrucao)
    _forja_nome = P.rotulo("", 27, P.IVORY)
    _forja_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cm.add_child(_forja_nome)
    _forja_estado = P.rotulo("", 12, P.GREEN)
    _forja_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cm.add_child(_forja_estado)
    _bolhas = HBoxContainer.new()
    _bolhas.add_theme_constant_override("separation", 28)
    _bolhas.alignment = BoxContainer.ALIGNMENT_CENTER
    _bolhas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cm.add_child(_bolhas)
    _forja_pedra = P.arte("", Vector2.ZERO)
    _forja_pedra.visible = false
    cm.add_child(_forja_pedra)
    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 28)
    cm.add_child(acoes)
    _purificar = P.botao("PURIFICAR  ·  CLAVES", "violet")
    _purificar.custom_minimum_size.y = 58
    _purificar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _purificar.pressed.connect(_ao_purificar)
    acoes.add_child(_purificar)
    _condensar = P.botao("SINTETIZAR NOTA", "gold")
    _condensar.custom_minimum_size.y = 58
    _condensar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _condensar.pressed.connect(_ao_condensar)
    acoes.add_child(_condensar)

    var rol_d := ScrollContainer.new()
    rol_d.custom_minimum_size.y = 110
    rol_d.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    cm.add_child(rol_d)
    _direita = VBoxContainer.new()
    _direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _direita.add_theme_constant_override("separation", 3)
    rol_d.add_child(_direita)

    # AS PARTITURAS TINHAM SUMIDO DA TELA.
    #
    # `_cartao_da_partitura` e `_cartao_do_acorde` continuavam escritos no
    # arquivo e ninguem os chamava: a reescrita da Sintese ficou so com o painel
    # de notas e fragmentos, e o unico caminho de Claves para experiencia
    # desapareceu da interface. O sistema estava inteiro no Progresso o tempo
    # todo — faltava a coluna que o mostra.
    var dir := P.painel()
    dir.custom_minimum_size.x = 300
    linha.add_child(dir)
    var cd := VBoxContainer.new()
    cd.add_theme_constant_override("separation", 8)
    dir.add_child(P.recheio(cd, 14))
    cd.add_child(P.cabecalho("CLAVES EM EXPERIÊNCIA", "Partituras", ""))
    var rol_p := ScrollContainer.new()
    rol_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rol_p.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    cd.add_child(rol_p)
    _partituras = VBoxContainer.new()
    _partituras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _partituras.add_theme_constant_override("separation", 8)
    rol_p.add_child(_partituras)


func _cristal(nota: String) -> String:
    return "res://textures/ui/kit/item/cristal_%s.png" % nota.replace("_sustenido", "")


func _linha_da_nota(nota: String) -> Control:
    var corrompido: int = _progresso.quantidade("fragmento_corrompido_" + nota)
    var limpo: int = _progresso.quantidade("fragmento_" + nota)
    var pronta: int = _progresso.quantidade("nota_" + nota)
    var ativa: bool = nota == _escolhida

    var b := P.botao("", "item")
    b.custom_minimum_size = Vector2(132, 142)
    b.add_theme_stylebox_override("normal", P.estilo(
        Color("0d1b30d9") if ativa else Color("07101fdc"),
        P.GOLD_BRIGHT if ativa else Color("56462f"), 2 if ativa else 1, 1))
    b.pressed.connect(func(): _escolher(nota))

    var caixa := VBoxContainer.new()
    caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
    caixa.add_theme_constant_override("separation", 8)
    caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(caixa)
    var pedra := P.arte(_cristal(nota), Vector2(62, 62))
    pedra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    pedra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    pedra.modulate = Color(1, 1, 1, 1.0 if corrompido + limpo + pronta > 0 else 0.4)
    caixa.add_child(pedra)
    var nome := P.rotulo(String(ROTULO.get(nota, nota)), 14, P.GOLD_BRIGHT if ativa else P.IVORY)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caixa.add_child(nome)
    var contas := Label.new()
    contas.text = "CORR. %d\nPURO %d  ·  NOTA %d" % [corrompido, limpo, pronta]
    contas.add_theme_font_size_override("font_size", 14)
    contas.add_theme_color_override("font_color", P.MUTED)
    contas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caixa.add_child(contas)
    return b


func _bolha(rotulo: String, quanto: int, cor: Color) -> Control:
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 2)
    var disco := PanelContainer.new()
    disco.custom_minimum_size = Vector2(190, 235)
    disco.add_theme_stylebox_override("panel", P.estilo(
        Color(cor.r * 0.16, cor.g * 0.16, cor.b * 0.20, 0.9),
        Color(cor.r, cor.g, cor.b, 0.8 if quanto > 0 else 0.3), 1, 8))
    var dentro := VBoxContainer.new()
    dentro.alignment = BoxContainer.ALIGNMENT_CENTER
    dentro.add_child(P.espaco_elastico())
    var pedra := P.arte(_cristal(_escolhida), Vector2(130, 130))
    pedra.modulate = Color(cor.r, cor.g, cor.b, 1.0 if quanto > 0 else 0.28)
    dentro.add_child(pedra)
    var n := P.rotulo("POSSUI  %d" % quanto, 11, P.IVORY if quanto > 0 else P.MUTED)
    n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dentro.add_child(n)
    dentro.add_child(P.espaco_elastico())
    disco.add_child(dentro)
    col.add_child(disco)
    var r := P.sobrancelha(rotulo)
    r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(r)
    return col


func _escolher(nota: String) -> void:
    _escolhida = nota
    _pintar()
    if _pulso and _pulso.is_valid(): _pulso.kill()
    _forja_pedra.pivot_offset = _forja_pedra.size * 0.5
    _forja_pedra.scale = Vector2(0.94, 0.94)
    _pulso = create_tween()
    _pulso.tween_property(_forja_pedra, "scale", Vector2.ONE, 0.22) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ao_purificar() -> void:
    if _progresso == null: return
    _progresso.purificar_fragmento(_escolhida)
    _avisar("Fragmento purificado",
        "%s pronto para condensar" % String(ROTULO.get(_escolhida, _escolhida)))


func _ao_condensar() -> void:
    if _progresso == null: return
    _progresso.sintetizar_nota(_escolhida)
    _avisar("Harmonia fortalecida",
        "Nota de %s condensada" % String(ROTULO.get(_escolhida, _escolhida)))


func _avisar(sobre: String, texto: String) -> void:
    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar"):
        casca.avisar(sobre, texto)


func _pintar() -> void:
    if _progresso == null or _lista == null: return
    var claves: int = _progresso.quantidade("claves")

    for antigo in _lista.get_children():
        _lista.remove_child(antigo)
        antigo.queue_free()
    for nota in NOTAS:
        _lista.add_child(_linha_da_nota(String(nota)))

    var corrompido: int = _progresso.quantidade("fragmento_corrompido_" + _escolhida)
    var limpo: int = _progresso.quantidade("fragmento_" + _escolhida)
    var pronta: int = _progresso.quantidade("nota_" + _escolhida)
    _forja_nome.text = "Nota de %s" % String(ROTULO.get(_escolhida, _escolhida))
    var tex := _cristal(_escolhida)
    _forja_pedra.texture = load(tex) if ResourceLoader.exists(tex) else null
    _forja_pedra.modulate = Color(1, 1, 1, 1.0 if corrompido + limpo + pronta > 0 else 0.35)
    _forja_estado.text = "HARMONIA PERFEITA" if limpo >= PUROS_POR_NOTA else (
        "PRONTO PARA PURIFICAR" if corrompido > 0 else "SEM FRAGMENTOS")
    _forja_estado.add_theme_color_override("font_color",
        P.GREEN if limpo >= PUROS_POR_NOTA else (P.CYAN if corrompido > 0 else P.MUTED))

    for antigo in _bolhas.get_children():
        _bolhas.remove_child(antigo)
        antigo.queue_free()
    _bolhas.add_child(_bolha("CORROMPIDO", corrompido, Color("d96a5a")))
    _bolhas.add_child(_bolha("PURO", limpo, P.CYAN))
    _bolhas.add_child(_bolha("NOTA", pronta, P.GOLD_BRIGHT))

    _purificar.disabled = corrompido < 1 or claves < _progresso.CUSTO_PURIFICAR_FRAGMENTO
    _purificar.tooltip_text = "1 corrompido + %d Claves" % _progresso.CUSTO_PURIFICAR_FRAGMENTO
    _condensar.disabled = limpo < PUROS_POR_NOTA
    _condensar.tooltip_text = "%d fragmentos puros da mesma nota" % PUROS_POR_NOTA

    for antigo in _direita.get_children():
        _direita.remove_child(antigo)
        antigo.queue_free()
    _direita.add_child(P.cabecalho("RESULTADO DA FORMAÇÃO", "Nota pronta", ""))
    _direita.add_child(P.arte(_cristal(_escolhida), Vector2(220, 190)))
    _direita.add_child(P.rotulo("NOTA DE %s" % String(ROTULO.get(_escolhida, _escolhida)).to_upper(), 22, P.GOLD_BRIGHT))
    _direita.add_child(P.risco())
    _direita.add_child(P.linha_de_status("◉", "Purificar", "%d Claves" % _progresso.CUSTO_PURIFICAR_FRAGMENTO))
    _direita.add_child(P.linha_de_status("▣", "Fragmentos por nota", str(PUROS_POR_NOTA)))
    _direita.add_child(P.linha_de_status("♪", "Notas no inventário", str(pronta)))
    _direita.add_child(P.linha_de_status("◉", "Claves em mãos", _milhar(claves)))
    _direita.add_child(P.risco())
    _direita.add_child(P.sobrancelha("PRÓXIMO PASSO"))
    _direita.add_child(P.rotulo("Leve sete notas à Forja de Escalas. Tons e semitons definem quais acordes, buffs e skills podem nascer.", 11, P.MUTED, true))
    _direita.add_child(P.espaco_elastico())

    _pintar_partituras()
    if _partituras:
        for velho in _partituras.get_children():
            _partituras.remove_child(velho)
            velho.queue_free()
        for tipo in _progresso.PARTITURAS:
            _partituras.add_child(_cartao_da_partitura(String(tipo)))
        _partituras.add_child(P.risco())
        _partituras.add_child(P.sobrancelha("ACORDES"))
        for id in _progresso.ACORDES:
            _partituras.add_child(_cartao_do_acorde(String(id)))


func _cartao_do_acorde(id: String) -> Control:
    var receita: Dictionary = _progresso.ACORDES[id]
    var pode: bool = _progresso.pode_montar_acorde(id)
    var p := P.painel(Color("0d1b30d9") if pode else Color("07101fbb"))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 3)
    p.add_child(col)
    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 6)
    col.add_child(topo)
    var t := P.rotulo(String(receita["nome"]), 13, P.GOLD_BRIGHT)
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topo.add_child(t)
    topo.add_child(P.rotulo(String(receita["graus"]), 10, P.CYAN))
    var notas := HBoxContainer.new()
    notas.add_theme_constant_override("separation", 4)
    col.add_child(notas)
    for nota in receita["notas"]:
        var pedra := P.arte(_cristal(String(nota)), Vector2(24, 24))
        pedra.modulate = Color(1, 1, 1,
            0.35 if _progresso.quantidade("nota_" + String(nota)) < 1 else 1.0)
        pedra.tooltip_text = String(ROTULO.get(nota, nota))
        notas.add_child(pedra)
    var custo := P.rotulo("%d Claves · tem %d" % [int(receita["custo_claves"]),
        _progresso.quantidade(id)], 9, P.MUTED)
    custo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    custo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    notas.add_child(custo)
    var b := P.botao("Montar acorde", "gold")
    b.custom_minimum_size.y = 32
    b.disabled = not pode
    b.tooltip_text = "%s\n%s" % [String(receita["licao"]), String(receita["efeito"])]
    b.pressed.connect(func():
        if _progresso.montar_acorde(id):
            _avisar("Acorde montado", "%s · %s" % [String(receita["nome"]),
                String(receita["graus"])]))
    col.add_child(b)
    return p


func _cartao_da_partitura(tipo: String) -> Control:
    var receita: Dictionary = _progresso.PARTITURAS[tipo]
    var pode: bool = _progresso.quantidade("claves") >= int(receita["custo"])
    var tem: int = _progresso.quantidade(String(receita["recurso"]))
    var p := P.painel(Color("0d1b30d9") if pode else Color("07101fbb"))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 3)
    p.add_child(col)
    col.add_child(P.rotulo(String(receita["nome"]), 13, P.GOLD_BRIGHT))
    col.add_child(P.rotulo("%d Claves → %d XP · tem %d"
        % [int(receita["custo"]), int(receita["xp"]), tem], 9, P.MUTED))
    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 6)
    col.add_child(acoes)
    var forjar := P.botao("Forjar")
    forjar.custom_minimum_size.y = 30
    forjar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    forjar.disabled = not pode
    forjar.pressed.connect(func():
        _progresso.criar_partitura(tipo)
        _avisar("Partitura forjada", String(receita["nome"])))
    acoes.add_child(forjar)
    var usar := P.botao("Usar", "primary")
    usar.custom_minimum_size.y = 30
    usar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    usar.disabled = tem <= 0
    usar.pressed.connect(func():
        _progresso.usar_partitura(tipo)
        _avisar("Experiência absorvida", "+%d XP" % int(receita["xp"])))
    acoes.add_child(usar)
    return p


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


# ------------------------------------------------------ aba de partituras
## A ABA "PARTITURAS E NIVEL", na medida da folha: tres cartoes de 564 por 328
## com 24 de vao, e embaixo a Ascensao Harmonica ao lado do Bonus de Nivel.
##
## Ela existia no Progresso o tempo todo — `criar_partitura` e `usar_partitura`
## nunca sairam de la. O que faltava era a tela: a reescrita anterior ficou so
## com notas e fragmentos e o unico caminho de Claves para experiencia
## desapareceu da interface.
const CORES_DA_PARTITURA := {"menor": "azul", "harmonica": "dourado",
    "magistral": "roxo"}

var _cartoes_de_partitura: Dictionary = {}
var _nivel_atual: Label
var _xp_atual: Label
var _barra_de_xp: Control
var _bonus: VBoxContainer


func _montar_partituras() -> Control:
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 16)

    var cartoes := HBoxContainer.new()
    cartoes.add_theme_constant_override("separation", 24)
    cartoes.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(cartoes)
    for tipo in ["menor", "harmonica", "magistral"]:
        var c := _cartao_grande(tipo)
        cartoes.add_child(c)
        _cartoes_de_partitura[tipo] = c

    var baixo := HBoxContainer.new()
    baixo.add_theme_constant_override("separation", 16)
    baixo.custom_minimum_size.y = 250
    col.add_child(baixo)
    baixo.add_child(_montar_ascensao())
    baixo.add_child(_montar_bonus())
    return col


func _cartao_grande(tipo: String) -> Control:
    var cor := String(CORES_DA_PARTITURA.get(tipo, "azul"))
    var receita: Dictionary = _progresso.PARTITURAS[tipo]
    var caixa := Control.new()
    caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caixa.custom_minimum_size.y = 236

    var moldura := _peca("cartao_" + cor, Vector2(0, 0))
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    caixa.add_child(moldura)

    var dentro := VBoxContainer.new()
    dentro.set_anchors_preset(Control.PRESET_FULL_RECT)
    dentro.offset_left = 26.0
    dentro.offset_right = -26.0
    dentro.offset_top = 18.0
    dentro.offset_bottom = -18.0
    dentro.add_theme_constant_override("separation", 4)
    caixa.add_child(dentro)

    var titulo := P.rotulo(String(receita["nome"]).to_upper(), 19, P.GOLD_BRIGHT)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dentro.add_child(titulo)
    dentro.add_child(P.linha_de_status("◉", "Claves", _milhar(int(receita["custo"]))))
    dentro.add_child(P.linha_de_status("XP", "Experiência", "%d XP" % int(receita["xp"])))
    var possui := P.rotulo("", 13, P.MUTED)
    possui.name = "Possui"
    possui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dentro.add_child(possui)
    dentro.add_child(P.espaco_elastico())

    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 10)
    acoes.alignment = BoxContainer.ALIGNMENT_CENTER
    dentro.add_child(acoes)
    acoes.add_child(_botao_do_kit("criar", cor, "CRIAR", _ao_criar.bind(tipo)))
    acoes.add_child(_botao_do_kit("usar", cor, "USAR", _ao_usar.bind(tipo)))
    return caixa


func _botao_do_kit(acao: String, cor: String, texto: String, quando: Callable) -> Button:
    var b := Button.new()
    b.name = acao.capitalize()
    b.custom_minimum_size = Vector2(120, 44)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    b.add_theme_font_size_override("font_size", 15)
    b.text = texto
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    var arte := _peca("%s_%s" % [acao, cor], Vector2(120, 44))
    arte.name = "Aceso"
    arte.set_anchors_preset(Control.PRESET_FULL_RECT)
    arte.show_behind_parent = true
    b.add_child(arte)
    var apagado := _peca("%s_apagado" % acao, Vector2(120, 44))
    apagado.name = "Apagado"
    apagado.set_anchors_preset(Control.PRESET_FULL_RECT)
    apagado.show_behind_parent = true
    b.add_child(apagado)
    b.pressed.connect(quando)
    return b


func _montar_ascensao() -> Control:
    var p := P.painel()
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    p.size_flags_stretch_ratio = 2.2
    var c := VBoxContainer.new()
    c.add_theme_constant_override("separation", 6)
    p.add_child(P.recheio(c, 16))
    c.add_child(P.cabecalho("SUBA DE NÍVEL", "Ascensão Harmônica", ""))
    var fila := HBoxContainer.new()
    fila.add_theme_constant_override("separation", 16)
    c.add_child(fila)
    _nivel_atual = P.rotulo("", 30, P.GOLD_BRIGHT)
    fila.add_child(_nivel_atual)
    var coluna := VBoxContainer.new()
    coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila.add_child(coluna)
    _xp_atual = P.rotulo("", 13, P.IVORY)
    coluna.add_child(_xp_atual)
    var trilho := ColorRect.new()
    trilho.color = Color("0b1324")
    trilho.custom_minimum_size.y = 12
    coluna.add_child(trilho)
    _barra_de_xp = ColorRect.new()
    (_barra_de_xp as ColorRect).color = Color("3da8ff")
    _barra_de_xp.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    _barra_de_xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trilho.add_child(_barra_de_xp)
    c.add_child(_peca("trilho_marcos", Vector2(0, 92)))
    return p


func _montar_bonus() -> Control:
    var p := Control.new()
    p.custom_minimum_size.x = 300
    var moldura := _peca("painel_bonus", Vector2(0, 0))
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    p.add_child(moldura)
    _bonus = VBoxContainer.new()
    _bonus.set_anchors_preset(Control.PRESET_FULL_RECT)
    _bonus.offset_left = 22.0
    _bonus.offset_right = -22.0
    _bonus.offset_top = 18.0
    _bonus.offset_bottom = -18.0
    _bonus.add_theme_constant_override("separation", 2)
    p.add_child(_bonus)
    return p


func _trocar_aba(qual: String) -> void:
    _aba = qual
    if _painel_notas:
        _painel_notas.visible = qual == "notas"
    if _painel_partituras:
        _painel_partituras.visible = qual == "partituras"
    for id in _botoes_de_aba:
        var b: Button = _botoes_de_aba[id]
        var escolhida: bool = String(id) == qual
        var a := b.get_node_or_null("Ativa") as Control
        var i := b.get_node_or_null("Inativa") as Control
        if a: a.visible = escolhida
        if i: i.visible = not escolhida
        b.add_theme_color_override("font_color",
            P.GOLD_BRIGHT if escolhida else P.MUTED)


func _ao_criar(tipo: String) -> void:
    if _progresso.criar_partitura(tipo):
        _avisar("Partitura criada", String(_progresso.PARTITURAS[tipo]["nome"]))
    _pintar()


func _ao_usar(tipo: String) -> void:
    if _progresso.usar_partitura(tipo):
        _avisar("Experiência absorvida",
            "+%d XP" % int(_progresso.PARTITURAS[tipo]["xp"]))
    _pintar()


## Repinta a aba de partituras. Chamada de dentro do `_pintar` geral.
func _pintar_partituras() -> void:
    if _cartoes_de_partitura.is_empty() or _progresso == null:
        return
    for tipo in _cartoes_de_partitura:
        var c: Control = _cartoes_de_partitura[tipo]
        var receita: Dictionary = _progresso.PARTITURAS[tipo]
        var recurso := String(receita["recurso"])
        var tem: int = _progresso.quantidade(recurso)
        var possui := c.find_child("Possui", true, false) as Label
        if possui:
            possui.text = "Possui: %d" % tem
        var pode_criar: bool = _progresso.quantidade("claves") >= int(receita["custo"])
        _vestir_botao(c.find_child("Criar", true, false) as Button, pode_criar)
        _vestir_botao(c.find_child("Usar", true, false) as Button, tem > 0)

    _nivel_atual.text = str(_progresso.nivel)
    var falta: float = maxf(float(_progresso.xp_para_nivel()), 1.0)
    _xp_atual.text = "%s / %s XP" % [_milhar(_progresso.experiencia), _milhar(int(falta))]
    _barra_de_xp.anchor_right = clampf(float(_progresso.experiencia) / falta, 0.0, 1.0)

    for velho in _bonus.get_children():
        _bonus.remove_child(velho)
        velho.queue_free()
    var proxima := 0
    for trava in _progresso.TRAVAS_DE_ASCENSAO:
        if int(_progresso.nivel) < int(trava) or not bool(_progresso.ascensoes.get(trava, false)):
            proxima = int(trava)
            break
    _bonus.add_child(P.rotulo("BÔNUS DE NÍVEL %d" % proxima, 17, P.GOLD_BRIGHT))
    _bonus.add_child(P.risco())
    for par in [["Poder Harmônico", "+80"], ["Vida Máxima", "+300"], ["Ataque", "+25"],
            ["Defesa", "+20"], ["Chance Crítica", "+2,0%"], ["Dano Crítico", "+5,0%"]]:
        _bonus.add_child(P.linha_de_status("◆", String(par[0]), String(par[1])))
    _bonus.add_child(P.espaco_elastico())


func _vestir_botao(b: Button, pode: bool) -> void:
    if b == null:
        return
    b.disabled = not pode
    var aceso := b.get_node_or_null("Aceso") as Control
    var apagado := b.get_node_or_null("Apagado") as Control
    if aceso: aceso.visible = pode
    if apagado: apagado.visible = not pode
    b.add_theme_color_override("font_color", P.IVORY if pode else P.MUTED)
