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
var _lista: VBoxContainer
var _forja_nome: Label
var _forja_pedra: TextureRect
var _forja_estado: Label
var _bolhas: HBoxContainer
var _purificar: Button
var _condensar: Button
var _direita: VBoxContainer
var _pulso: Tween


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)


func ao_abrir() -> void:
    _pintar()


func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 12)
    add_child(linha)

    var esq := P.painel()
    esq.custom_minimum_size.x = 268
    linha.add_child(esq)
    var ce := VBoxContainer.new()
    ce.add_theme_constant_override("separation", 6)
    esq.add_child(P.recheio(ce, 14))
    ce.add_child(P.cabecalho("NOTAS DESCOBERTAS", "Receitas", "12"))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ce.add_child(rol)
    _lista = VBoxContainer.new()
    _lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _lista.add_theme_constant_override("separation", 6)
    rol.add_child(_lista)

    var meio := P.painel(Color("08162ce8"))
    meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(meio)
    var conceito := TextureRect.new()
    conceito.texture = load("res://textures/ui/concepts/synthesis-forge-bg.png")
    conceito.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    conceito.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    conceito.modulate = Color(0.72, 0.78, 0.94, 0.28)
    conceito.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meio.add_child(conceito)
    var cm := VBoxContainer.new()
    cm.add_theme_constant_override("separation", 6)
    meio.add_child(P.recheio(cm, 16))
    cm.add_child(P.sobrancelha("1 NOTA = 30 FRAGMENTOS DA MESMA FAMÍLIA"))
    _forja_nome = P.rotulo("", 27, P.IVORY)
    cm.add_child(_forja_nome)
    _forja_pedra = P.arte("", Vector2(0, 230))
    _forja_pedra.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cm.add_child(_forja_pedra)
    _forja_estado = P.rotulo("", 12, P.GREEN)
    _forja_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cm.add_child(_forja_estado)
    _bolhas = HBoxContainer.new()
    _bolhas.add_theme_constant_override("separation", 14)
    _bolhas.alignment = BoxContainer.ALIGNMENT_CENTER
    cm.add_child(_bolhas)
    cm.add_child(P.espaco_elastico())
    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 10)
    cm.add_child(acoes)
    _purificar = P.botao("Purificar fragmento", "primary")
    _purificar.custom_minimum_size.y = 48
    _purificar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _purificar.pressed.connect(_ao_purificar)
    acoes.add_child(_purificar)
    _condensar = P.botao("Formar nota", "violet")
    _condensar.custom_minimum_size.y = 48
    _condensar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _condensar.pressed.connect(_ao_condensar)
    acoes.add_child(_condensar)

    var dir := P.painel()
    dir.custom_minimum_size.x = 300
    linha.add_child(dir)
    var rol_d := ScrollContainer.new()
    rol_d.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var folga := P.recheio(rol_d, 14)
    # A barra de rolagem ocupa a direita e encostava nos numeros. Estes doze
    # pixels a mais sao o lugar dela.
    folga.add_theme_constant_override("margin_right", 26)
    dir.add_child(folga)
    _direita = VBoxContainer.new()
    _direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _direita.add_theme_constant_override("separation", 8)
    rol_d.add_child(_direita)


func _cristal(nota: String) -> String:
    return "res://textures/ui/kit/item/cristal_%s.png" % nota.replace("_sustenido", "")


func _linha_da_nota(nota: String) -> Control:
    var corrompido: int = _progresso.quantidade("fragmento_corrompido_" + nota)
    var limpo: int = _progresso.quantidade("fragmento_" + nota)
    var pronta: int = _progresso.quantidade("nota_" + nota)
    var ativa: bool = nota == _escolhida

    var b := P.botao("", "item")
    b.custom_minimum_size.y = 56
    b.add_theme_stylebox_override("normal", P.estilo(
        Color("0d1b30d9") if ativa else Color("07101fdc"),
        P.GOLD_BRIGHT if ativa else Color("56462f"), 2 if ativa else 1, 1))
    b.pressed.connect(func(): _escolher(nota))

    var caixa := HBoxContainer.new()
    caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
    caixa.add_theme_constant_override("separation", 8)
    caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(caixa)
    var pedra := P.arte(_cristal(nota), Vector2(34, 34))
    pedra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    pedra.modulate = Color(1, 1, 1, 1.0 if corrompido + limpo + pronta > 0 else 0.4)
    caixa.add_child(pedra)
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    col.add_theme_constant_override("separation", 1)
    caixa.add_child(col)
    col.add_child(P.rotulo(String(ROTULO.get(nota, nota)), 14,
        P.GOLD_BRIGHT if ativa else P.IVORY))
    col.add_child(P.rotulo("%d puro · %d nota" % [limpo, pronta], 9, P.MUTED))
    caixa.add_child(P.rotulo("%d / %d" % [limpo, PUROS_POR_NOTA], 11,
        P.GREEN if limpo >= PUROS_POR_NOTA else P.MUTED))
    return b


func _bolha(rotulo: String, quanto: int, cor: Color) -> Control:
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 2)
    var disco := PanelContainer.new()
    disco.custom_minimum_size = Vector2(66, 66)
    disco.add_theme_stylebox_override("panel", P.estilo(
        Color(cor.r * 0.16, cor.g * 0.16, cor.b * 0.20, 0.9),
        Color(cor.r, cor.g, cor.b, 0.8 if quanto > 0 else 0.3), 1, 33))
    var n := P.rotulo(str(quanto), 22, P.IVORY if quanto > 0 else P.MUTED)
    n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    disco.add_child(n)
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
