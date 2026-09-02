extends Control
class_name PaginaInventario
## O INVENTARIO NO FORMATO APROVADO: perfil a esquerda, colecao no meio,
## detalhe a direita.
##
## O desenho e o do prototipo do Codex — painel com fio de bronze, sobrancelha,
## cartao de item com a nota no canto, barra de lotacao no rodape. O CONTEUDO e
## do jogo: quantidade, raridade e tipo saem do catalogo, a vida sai da HUD, o
## poder sai do Progresso. Onde ele mostrava atributo de item ("+21 de poder"),
## aqui vai o que o item realmente tem — porque item neste jogo e contagem, nao
## equipamento, e desenhar atributo que nao existe e botao que nao faz nada.
const P := preload("res://scripts/ui_proto.gd")
const PalcoScript := preload("res://scripts/palco_akles.gd")
const CATALOGO := preload("res://scripts/inventory_ui.gd")

const COLUNAS := 4
const CAPACIDADE := 150

var _progresso: Node
var _diario: Node
var _filtro := "Todos"
var _selecionado := ""

var _grade: GridContainer
var _botoes_filtro: Dictionary = {}
var _palco: PalcoAkles
var _barra_vida: Control
var _barra_xp: Control
var _caixa_perfil: VBoxContainer
var _equipados: HBoxContainer
var _poder: Label
var _lotacao: ProgressBar
var _rodape: Label
var _titulo_colecao: Control
var _caixa_detalhe: VBoxContainer

var _det_nome: Label
var _det_posse: Label
var _botao_usar: Button
var _botao_descartar: Button
var _confirmacao: PanelContainer
var _selo_claves: Label
var _selos: HBoxContainer


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _diario = get_node_or_null("/root/Diario")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_repintar):
        _progresso.alterado.connect(_repintar)


func ao_abrir() -> void:
    if _palco:
        _palco.ligar()
    _repintar()


func ao_fechar() -> void:
    if _palco:
        _palco.desligar()


func cabecalho_extra() -> Control:
    _selos = HBoxContainer.new()
    _selos.add_theme_constant_override("separation", 18)
    _selo_claves = P.rotulo("", 15, P.GOLD_BRIGHT)
    _selos.add_child(_selo_claves)
    return _selos


func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 12)
    add_child(linha)

    # ------------------------------------------------------------- perfil
    var perfil := P.painel()
    perfil.custom_minimum_size.x = 250
    linha.add_child(perfil)
    _caixa_perfil = VBoxContainer.new()
    _caixa_perfil.add_theme_constant_override("separation", 9)
    perfil.add_child(P.recheio(_caixa_perfil, 15))

    _palco = PalcoScript.new(true)
    _palco.custom_minimum_size = Vector2(205, 172)
    _caixa_perfil.add_child(_palco)
    var nome := P.rotulo("Akles", 27, P.IVORY)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caixa_perfil.add_child(nome)
    var papel := P.rotulo("Maestro da Vigília", 12, P.GOLD)
    papel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caixa_perfil.add_child(papel)
    _barra_vida = P.linha_de_barra("♥", 1.0, P.VERMELHO, "")
    _caixa_perfil.add_child(_barra_vida)
    _barra_xp = P.linha_de_barra("♪", 0.0, P.CYAN, "")
    _caixa_perfil.add_child(_barra_xp)
    _caixa_perfil.add_child(P.risco())
    _caixa_perfil.add_child(P.sobrancelha("EQUIPADO"))
    _equipados = HBoxContainer.new()
    _equipados.add_theme_constant_override("separation", 6)
    _caixa_perfil.add_child(_equipados)
    _caixa_perfil.add_child(P.espaco_elastico())
    _poder = P.rotulo("", 12, P.GOLD_BRIGHT)
    _poder.add_theme_stylebox_override("normal", P.estilo(Color("0a1426"), Color("7c6239"), 1, 2))
    _caixa_perfil.add_child(_poder)

    # ---------------------------------------------------------- colecao
    var colecao := P.painel()
    colecao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(colecao)
    var cc := VBoxContainer.new()
    cc.add_theme_constant_override("separation", 8)
    colecao.add_child(P.recheio(cc, 16))
    _titulo_colecao = P.cabecalho("COLEÇÃO HARMÔNICA", "Fragmentos & relíquias", "")
    cc.add_child(_titulo_colecao)

    var filtros := HBoxContainer.new()
    filtros.add_theme_constant_override("separation", 8)
    cc.add_child(filtros)
    for nome_filtro in CATALOGO.FILTROS:
        var b := P.botao(String(nome_filtro))
        b.custom_minimum_size.y = 38
        b.pressed.connect(_escolher_filtro.bind(String(nome_filtro)))
        filtros.add_child(b)
        _botoes_filtro[String(nome_filtro)] = b

    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cc.add_child(rol)
    _grade = GridContainer.new()
    _grade.columns = COLUNAS
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grade.add_theme_constant_override("h_separation", 9)
    _grade.add_theme_constant_override("v_separation", 9)
    rol.add_child(_grade)

    _lotacao = ProgressBar.new()
    _lotacao.max_value = 1.0
    _lotacao.show_percentage = false
    _lotacao.custom_minimum_size.y = 7
    _lotacao.add_theme_stylebox_override("background", P.estilo(Color("07101f"), Color("66522f"), 1, 1))
    _lotacao.add_theme_stylebox_override("fill", P.estilo(P.GOLD, P.GOLD_BRIGHT, 0, 1))
    cc.add_child(_lotacao)
    _rodape = P.rotulo("", 10, P.MUTED, true)
    _rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cc.add_child(_rodape)

    # ---------------------------------------------------------- detalhe
    var detalhe := P.painel()
    detalhe.custom_minimum_size.x = 310
    linha.add_child(detalhe)
    _caixa_detalhe = VBoxContainer.new()
    _caixa_detalhe.add_theme_constant_override("separation", 9)
    detalhe.add_child(P.recheio(_caixa_detalhe, 16))

    _escolher_filtro("Todos")


func _escolher_filtro(nome: String) -> void:
    _filtro = nome
    for chave in _botoes_filtro:
        var b: Button = _botoes_filtro[chave]
        b.add_theme_stylebox_override("normal",
            P.estilo_de_botao("gold" if String(chave) == nome else "quiet"))
    _repintar()


func _selecionar(id: String) -> void:
    _selecionado = id
    _repintar()


func _repintar() -> void:
    if _progresso == null or _grade == null:
        return
    _pintar_perfil()
    _pintar_grade()
    _pintar_detalhe()


func _pintar_perfil() -> void:
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud:
        var vida: float = float(hud.current_health)
        var maxima: float = maxf(float(hud.max_health), 1.0)
        _atualizar_barra(_barra_vida, vida / maxima, "%d" % int(vida))
    var falta := float(_progresso.xp_para_nivel())
    _atualizar_barra(_barra_xp, float(_progresso.experiencia) / maxf(falta, 1.0),
        "Nv %d" % _progresso.nivel)
    _poder.text = "✣  Poder de luta        %s" % _milhar(
        int(_progresso.poder_de_luta_detalhado()["total"]))

    for antigo in _equipados.get_children():
        _equipados.remove_child(antigo)
        antigo.queue_free()
    # O QUE ESTA EQUIPADO DE VERDADE: o Eco escolhido e o Ressonador, que sao as
    # duas unicas coisas que o jogo deixa vestir hoje. Slot vazio inventado nao
    # entra — quando houver equipamento, ele aparece aqui.
    var eco := String(_progresso.eco_equipado.get("id", ""))
    if eco != "":
        var ficha_eco: Dictionary = _progresso.ficha_do_eco(eco)
        _equipados.add_child(_selo_pequeno(
            "res://textures/ui/kit/item/cristal_%s.png" % _nota_do_cristal(eco),
            String(ficha_eco.get("nome", eco)), P.RARIDADE.get(
                String(ficha_eco.get("raridade", "Comum")), P.MUTED)))
    if _progresso.quantidade("ressonador") > 0:
        _equipados.add_child(_selo_pequeno("res://textures/ui/kit/item/runa.png",
            "Ressonador", P.CYAN))
    if _equipados.get_child_count() == 0:
        _equipados.add_child(P.rotulo("Nada equipado", 11, P.MUTED))


func _atualizar_barra(linha: Control, fracao: float, texto: String) -> void:
    for filho in linha.get_children():
        if filho is ProgressBar:
            (filho as ProgressBar).value = clampf(fracao, 0.0, 1.0)
        elif filho is Label and (filho as Label).get_index() == 2:
            (filho as Label).text = texto


func _selo_pequeno(caminho: String, dica: String, cor: Color) -> Control:
    var p := PanelContainer.new()
    p.custom_minimum_size = Vector2(58, 58)
    p.tooltip_text = dica
    p.add_theme_stylebox_override("panel", P.estilo(Color("0a1020"), cor, 1, 1))
    p.add_child(P.arte(caminho, Vector2(46, 46)))
    return p


func _nota_do_cristal(id: String) -> String:
    return id.replace("_sustenido", "")


func _pintar_grade() -> void:
    for antigo in _grade.get_children():
        _grade.remove_child(antigo)
        antigo.queue_free()
    var itens := _itens_visiveis()
    if _selecionado == "" or _progresso.quantidade(_selecionado) <= 0:
        _selecionado = String(itens[0][0]) if not itens.is_empty() else ""
    for it in itens:
        _grade.add_child(_cartao(it))

    var ocupados := 0
    for it in CATALOGO.ITENS_DE_RECURSO:
        if _progresso.quantidade(String(it[0])) > 0:
            ocupados += 1
    _lotacao.value = clampf(float(ocupados) / float(CAPACIDADE), 0.0, 1.0)
    _rodape.text = "%d de %d espaços ocupados" % [ocupados, CAPACIDADE]
    if _selo_claves:
        _selo_claves.text = "◉  %s Claves" % _milhar(_progresso.quantidade("claves"))
    for filho in _titulo_colecao.get_children():
        if filho is Label and (filho as Label).get_index() == 1:
            (filho as Label).text = "▣  %d / %d" % [ocupados, CAPACIDADE]


## O CARTAO DO ITEM: etiqueta em cima, arte no meio, quantidade embaixo. E o
## desenho aprovado, e nele nada se cruza — o numero tem linha propria.
func _cartao(it: Array) -> Button:
    var id := String(it[0])
    var raridade := String(it[3])
    var cor: Color = P.RARIDADE.get(raridade, P.MUTED)
    var escolhido: bool = id == _selecionado

    var b := P.botao("", "item")
    # As quatro colunas DIVIDEM a largura. Com largura minima fixa a quarta
    # sobrava para fora e era cortada pela rolagem.
    b.custom_minimum_size = Vector2(110, 132)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.clip_contents = true
    b.add_theme_stylebox_override("normal", P.estilo(Color(cor, 0.055),
        P.GOLD_BRIGHT if escolhido else Color("5c4a31"), 2 if escolhido else 1, 1))
    b.add_theme_stylebox_override("hover", P.estilo(Color(cor, 0.14), cor, 2, 1))

    var col := VBoxContainer.new()
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
    col.add_child(P.rotulo(raridade.to_upper(), 10, cor))
    var img := P.arte(_caminho_da_arte(String(it[2])), Vector2(100, 78))
    img.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(img)
    var qtd := P.rotulo(_curto(_progresso.quantidade(id)), 13, P.IVORY)
    qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    col.add_child(qtd)
    b.add_child(col)
    b.pressed.connect(_selecionar.bind(id))
    return b


func _pintar_detalhe() -> void:
    for antigo in _caixa_detalhe.get_children():
        _caixa_detalhe.remove_child(antigo)
        antigo.queue_free()
    var ficha := _ficha(_selecionado)
    if ficha.is_empty():
        _caixa_detalhe.add_child(P.rotulo("Bolsa vazia", 20, P.IVORY))
        _caixa_detalhe.add_child(P.rotulo(
            "Derrote Shikers e recolha o que eles deixam.", 11, P.MUTED, true))
        _botao_usar = null
        _botao_descartar = null
        return

    var raridade := String(ficha[3])
    var tipo := String(ficha[4])
    var cor: Color = P.RARIDADE.get(raridade, P.MUTED)
    var quanto: int = _progresso.quantidade(_selecionado)

    _caixa_detalhe.add_child(P.rotulo(raridade.to_upper(), 11, cor))
    var heroi := P.arte(_caminho_da_arte(String(ficha[2])), Vector2(225, 200))
    heroi.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _caixa_detalhe.add_child(heroi)
    _caixa_detalhe.add_child(P.sobrancelha(tipo.to_upper()))
    _det_nome = P.rotulo(String(ficha[1]), 26, P.IVORY, true)
    _caixa_detalhe.add_child(_det_nome)
    _caixa_detalhe.add_child(P.rotulo(String(ficha[5]), 11, P.MUTED, true))
    _caixa_detalhe.add_child(P.risco())

    # As linhas de status trazem o que o item TEM. Um fragmento nao carrega
    # atributo neste jogo; carregar-lhe um numero inventado seria mentira com
    # cara de sistema.
    _det_posse = P.rotulo(_milhar(quanto), 12, P.IVORY)
    var linha_posse := P.linha_de_status("▣", "Quantidade", _milhar(quanto))
    _caixa_detalhe.add_child(linha_posse)
    _caixa_detalhe.add_child(P.linha_de_status("♦", "Raridade", raridade))
    _caixa_detalhe.add_child(P.linha_de_status("✣", "Categoria", tipo.capitalize()))
    if _progresso.ACORDES.has(_selecionado):
        var cura: float = float(_progresso.CURA_DO_ACORDE.get(_selecionado, 0.0))
        _caixa_detalhe.add_child(P.linha_de_status("♡", "Restaura", "%d%% da vida" % int(cura * 100.0)))
    _caixa_detalhe.add_child(P.espaco_elastico())

    var usavel: bool = tipo == "consumivel"
    _botao_usar = P.botao("Usar", "primary")
    _botao_usar.custom_minimum_size.y = 48
    _botao_usar.visible = usavel
    _botao_usar.disabled = not usavel
    _botao_usar.pressed.connect(_usar)
    _caixa_detalhe.add_child(_botao_usar)

    _botao_descartar = P.botao("Descartar", "danger")
    _botao_descartar.custom_minimum_size.y = 42
    _botao_descartar.disabled = not _pode_descartar(_selecionado, tipo)
    _botao_descartar.tooltip_text = "" if not _botao_descartar.disabled \
        else "Item preso a uma tarefa ou a uma ascensão."
    _botao_descartar.pressed.connect(_pedir_confirmacao)
    _caixa_detalhe.add_child(_botao_descartar)

    _confirmacao = _montar_confirmacao()
    _caixa_detalhe.add_child(_confirmacao)


func _montar_confirmacao() -> PanelContainer:
    var p := PanelContainer.new()
    p.visible = false
    p.add_theme_stylebox_override("panel", P.estilo(Color("2a0d10ee"), Color("d2696e"), 1, 2))
    var c := VBoxContainer.new()
    c.add_theme_constant_override("separation", 6)
    p.add_child(c)
    c.add_child(P.rotulo("Descartar de vez?", 12, Color("ffd7d5")))
    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 6)
    c.add_child(linha)
    var sim := P.botao("Sim", "danger")
    sim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sim.pressed.connect(_descartar)
    linha.add_child(sim)
    var nao := P.botao("Não")
    nao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nao.pressed.connect(func(): p.visible = false)
    linha.add_child(nao)
    return p


func _pedir_confirmacao() -> void:
    if _confirmacao:
        _confirmacao.visible = true


func _descartar() -> void:
    if _progresso == null or _selecionado == "":
        return
    _progresso.adicionar_recurso(_selecionado, -1)
    if _confirmacao:
        _confirmacao.visible = false
    _repintar()


func _usar() -> void:
    var ficha := _ficha(_selecionado)
    if ficha.is_empty() or _progresso == null:
        return
    if _progresso.ACORDES.has(_selecionado):
        var fracao: float = _progresso.usar_acorde(_selecionado)
        if fracao > 0.0:
            var hud := get_tree().get_first_node_in_group("player_hud")
            if hud and hud.has_method("curar"):
                hud.curar(hud.max_health * fracao)
            if _selecionado == "acorde_vigor" and hud and hud.has_method("conceder_escudo"):
                hud.conceder_escudo(hud.max_health * 0.20)
            _avisar("Harmonia restaurada", "%s  ·  +%d%% de vida"
                % [String(ficha[1]), int(fracao * 100.0)])
        return
    for tipo in _progresso.PARTITURAS:
        if String(_progresso.PARTITURAS[tipo]["recurso"]) == _selecionado:
            _progresso.usar_partitura(String(tipo))
            _avisar("Experiência absorvida",
                "+%d XP de %s" % [int(_progresso.PARTITURAS[tipo]["xp"]), String(ficha[1])])
            return


func _pode_descartar(id: String, tipo: String) -> bool:
    if tipo == "ferramenta" or id in ["selo_regente", "nucleo_maestro"]:
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


func _ficha(id: String) -> Array:
    for it in CATALOGO.ITENS_DE_RECURSO:
        if String(it[0]) == id:
            return it
    return []


func _itens_visiveis() -> Array:
    var saida: Array = []
    if _progresso == null:
        return saida
    for it in CATALOGO.ITENS_DE_RECURSO:
        if _progresso.quantidade(String(it[0])) <= 0:
            continue
        if _filtro != "Todos":
            if String(it[4]) != String(CATALOGO.TIPO_DO_FILTRO.get(_filtro, "")):
                continue
        saida.append(it)
    return saida


func _caminho_da_arte(caminho: String) -> String:
    return caminho if caminho.begins_with("res://") \
        else "res://textures/ui/kit/" + caminho + ".png"


func _curto(n: int) -> String:
    if n < 1000:
        return str(n)
    if n < 1000000:
        var mil: float = float(n) / 1000.0
        return ("%.0fK" % mil) if mil >= 10.0 else ("%.1fK" % mil).replace(".", ",")
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
