extends Control
class_name PaginaInventario

## A BOLSA — so a bolsa. Moldura, cabecalho, botao de fechar e navbar sao do
## shell; esta pagina entrega conteudo e mais nada.
##
## Layout: filtros a esquerda, grade no meio (o elemento principal, e por isso o
## que recebe o espaco que sobra) e detalhe a direita.

const T := preload("res://scripts/ui_tema.gd")
const CATALOGO := preload("res://scripts/inventory_ui.gd")

const COLUNAS := 6
const LADO_DO_SLOT := 96.0
const CAPACIDADE := 150

var _progresso: Node
var _diario: Node
var _filtro := "Todos"
var _selecionado := ""
var _grade: GridContainer
var _botoes_filtro: Dictionary = {}
var _rolagem: ScrollContainer

var _det_icone: TextureRect
var _det_nome: Label
var _det_tipo: Label
var _det_posse: Label
var _det_desc: Label
var _det_moldura: PanelContainer
var _botao_usar: Button
var _botao_descartar: Button
var _confirmacao: PanelContainer

var _selo_slots: Label
var _selo_claves: Label
var _selo_materiais: Label
var _selo_frag: Label


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _diario = get_node_or_null("/root/Diario")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_recarregar):
        _progresso.alterado.connect(_recarregar)


## O shell pendura isto no cabecalho, a direita do titulo. Os contadores ficam
## MENORES que o titulo de proposito: sao apoio, nao manchete.
func cabecalho_extra() -> Control:
    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 30)
    linha.alignment = BoxContainer.ALIGNMENT_END
    _selo_slots = _contador(linha, "res://textures/ui/kit/item/bolsa.png")
    _selo_claves = _contador(linha, "res://textures/ui/kit/item/moeda.png")
    _selo_materiais = _contador(linha, "res://textures/ui/kit/item/minerio.png")
    _selo_frag = _contador(linha, "res://textures/ui/kit/item/cristal_azul.png")
    _pintar_contadores()
    return linha


## Icone e numero com FOLGA entre eles. Antes o numero encostava no icone.
func _contador(pai: HBoxContainer, arte: String) -> Label:
    var caixa := HBoxContainer.new()
    caixa.add_theme_constant_override("separation", 10)
    caixa.alignment = BoxContainer.ALIGNMENT_CENTER
    var img := TextureRect.new()
    if ResourceLoader.exists(arte):
        img.texture = load(arte)
    img.custom_minimum_size = Vector2(34, 34)
    img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caixa.add_child(img)
    var n := T.rotulo("", T.CONTADOR, T.TEXTO)
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caixa.add_child(n)
    pai.add_child(caixa)
    return n


func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 18)
    add_child(linha)

    # ------------------------------------------------------------- filtros
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 220
    coluna.add_theme_constant_override("separation", 8)
    linha.add_child(coluna)
    for nome in CATALOGO.FILTROS:
        # ALTURA MENOR. Cinco palavras nao precisam de um botao de 66 px.
        var b := T.aba(String(nome), 40.0)
        b.pressed.connect(_escolher_filtro.bind(String(nome)))
        coluna.add_child(b)
        _botoes_filtro[String(nome)] = b
    coluna.add_child(T.espaco(8))

    # --------------------------------------------------------------- grade
    # A grade e o elemento principal, entao e ela que recebe o espaco que sobra.
    var caixa_grade := T.coluna(14)
    caixa_grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caixa_grade.size_flags_stretch_ratio = 2.4
    linha.add_child(caixa_grade)

    _rolagem = ScrollContainer.new()
    _rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    caixa_grade.add_child(_rolagem)

    _grade = GridContainer.new()
    _grade.columns = COLUNAS
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # ESPACAMENTO IGUAL nos dois eixos: era o que fazia a grade parecer torta.
    _grade.add_theme_constant_override("h_separation", 12)
    _grade.add_theme_constant_override("v_separation", 12)
    _rolagem.add_child(_grade)

    # ------------------------------------------------------------- detalhe
    linha.add_child(_montar_detalhe())
    _escolher_filtro("Todos")


func _montar_detalhe() -> Control:
    var painel := T.coluna(18)
    painel.custom_minimum_size.x = 380
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 4)
    painel.add_child(col)

    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 16)
    col.add_child(topo)

    _det_moldura = PanelContainer.new()
    _det_moldura.custom_minimum_size = Vector2(86, 86)
    _det_moldura.add_theme_stylebox_override("panel",
        T.painel(T.NAVY_CLARO, T.OURO_ARO, 8, 2, 6))
    topo.add_child(_det_moldura)
    _det_icone = TextureRect.new()
    _det_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _det_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _det_moldura.add_child(_det_icone)

    var nomes := VBoxContainer.new()
    nomes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nomes.alignment = BoxContainer.ALIGNMENT_CENTER
    nomes.add_theme_constant_override("separation", 3)
    topo.add_child(nomes)
    # HIERARQUIA: nome grande, categoria pequena, quantidade normal.
    _det_nome = T.rotulo("", T.NOME_ITEM, T.OURO_FORTE)
    _det_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    nomes.add_child(_det_nome)
    _det_tipo = T.rotulo("", T.LEGENDA, T.TEXTO_FRACO)
    nomes.add_child(_det_tipo)
    _det_posse = T.rotulo("", T.CORPO, T.TEXTO)
    _det_posse.autowrap_mode = TextServer.AUTOWRAP_OFF
    nomes.add_child(_det_posse)

    col.add_child(T.espaco(10))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(rol)
    # Descricao em caixa normal, com quebra de linha e entrelinha: MAIUSCULA em
    # texto corrido cansa e e mais lenta de ler.
    _det_desc = T.rotulo("", T.CORPO, T.TEXTO_FRACO, true)
    _det_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rol.add_child(_det_desc)

    col.add_child(T.espaco(10))
    _botao_usar = T.botao("Usar", T.PRIMARIO)
    _botao_usar.pressed.connect(_usar)
    col.add_child(_botao_usar)

    _botao_descartar = T.botao("Descartar", T.PERIGOSO)
    _botao_descartar.pressed.connect(_pedir_confirmacao)
    col.add_child(_botao_descartar)

    # NAO HA "DIVIDIR". O inventario guarda uma CONTAGEM por recurso, nao pilhas
    # separadas: nao existe o que dividir. Um botao que nunca faz nada e pior
    # que a ausencia dele.
    _confirmacao = _montar_confirmacao()
    col.add_child(_confirmacao)
    return painel


## A confirmacao continua sendo uma superficie de verdade: ela precisa saltar
## do resto justamente por interromper uma acao que nao tem volta.
func _montar_confirmacao() -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel",
        T.painel(Color(0.16, 0.05, 0.05, 0.96), T.PERIGO, 8, 1, 12))
    p.visible = false
    var c := VBoxContainer.new()
    c.add_theme_constant_override("separation", 8)
    p.add_child(c)
    c.add_child(T.rotulo("Descartar de vez?", T.CORPO, Color(1.0, 0.88, 0.86)))
    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 8)
    c.add_child(linha)
    var sim := T.botao("Sim", T.PERIGOSO, 40.0)
    sim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sim.pressed.connect(_descartar)
    linha.add_child(sim)
    var nao := T.botao("Não", T.SECUNDARIO, 40.0)
    nao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nao.pressed.connect(func(): _confirmacao.visible = false)
    linha.add_child(nao)
    return p


# ------------------------------------------------------------------- dados

func ao_abrir() -> void:
    _recarregar()


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
        var id := String(it[0])
        var quanto: int = _progresso.quantidade(id)
        if quanto <= 0:
            continue
        if _filtro != "Todos":
            var tipo := String(CATALOGO.TIPO_DO_FILTRO.get(_filtro, ""))
            if String(it[4]) != tipo:
                continue
        saida.append(it)
    return saida


func _escolher_filtro(nome: String) -> void:
    _filtro = nome
    for chave in _botoes_filtro:
        T.pintar_aba(_botoes_filtro[chave], String(chave) == nome)
    _recarregar()


func _recarregar() -> void:
    if _grade == null:
        return
    for antigo in _grade.get_children():
        antigo.queue_free()
    var itens := _itens_visiveis()
    for it in itens:
        _grade.add_child(_slot(it))
    if _selecionado == "" or _progresso.quantidade(_selecionado) <= 0:
        _selecionado = String(itens[0][0]) if not itens.is_empty() else ""
    _pintar_detalhe()
    _pintar_contadores()


func _pintar_contadores() -> void:
    if _progresso == null or _selo_slots == null:
        return
    var ocupados := 0
    var materiais := 0
    var fragmentos := 0
    for it in CATALOGO.ITENS_DE_RECURSO:
        var quanto: int = _progresso.quantidade(String(it[0]))
        if quanto <= 0:
            continue
        ocupados += 1
        if String(it[4]) == "material":
            materiais += quanto
        if String(it[0]).begins_with("fragmento"):
            fragmentos += quanto
    _selo_slots.text = "%d / %d" % [ocupados, CAPACIDADE]
    _selo_claves.text = _milhar(_progresso.quantidade("claves"))
    _selo_materiais.text = _milhar(materiais)
    _selo_frag.text = _milhar(fragmentos)


# ------------------------------------------------------------------- slots

func _slot(it: Array) -> Control:
    var id := String(it[0])
    var raridade := String(it[3])
    var quanto: int = _progresso.quantidade(id)

    var caixa := PanelContainer.new()
    caixa.custom_minimum_size = Vector2(LADO_DO_SLOT, LADO_DO_SLOT)
    caixa.set_meta("id", id)
    _pintar_slot(caixa, id == _selecionado, raridade)

    # O icone tem MARGEM propria e nunca encosta na borda nem no numero.
    var margem := MarginContainer.new()
    for lado in ["margin_left", "margin_right", "margin_top"]:
        margem.add_theme_constant_override(lado, 10)
    # Espaco reservado embaixo SO para a quantidade: e assim que o numero deixa
    # de ficar por cima do desenho, como acontecia com as 35 mil Claves.
    margem.add_theme_constant_override("margin_bottom", 24)
    caixa.add_child(margem)

    var img := TextureRect.new()
    img.texture = _arte(String(it[2]))
    img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margem.add_child(img)

    var numero := T.rotulo(_curto(quanto), T.LEGENDA, Color(0.99, 0.95, 0.84))
    numero.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    numero.offset_left = 6.0
    numero.offset_right = -8.0
    numero.offset_top = -24.0
    numero.offset_bottom = -4.0
    numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    numero.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.95))
    numero.add_theme_constant_override("outline_size", 4)
    caixa.add_child(numero)

    var toque := Button.new()
    toque.set_anchors_preset(Control.PRESET_FULL_RECT)
    toque.focus_mode = Control.FOCUS_NONE
    for estado in ["normal", "hover", "pressed", "focus"]:
        toque.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    toque.pressed.connect(_selecionar.bind(id))
    caixa.add_child(toque)
    return caixa


## A raridade entra como ARO FINO, nao como preenchimento: e a unica cor forte
## do slot e ja se le antes de qualquer texto. O item escolhido ganha aro
## dourado e fundo mais claro, para nao depender de distinguir dois azuis.
func _pintar_slot(caixa: PanelContainer, escolhido: bool, raridade: String) -> void:
    var cor: Color = T.RARIDADE.get(raridade, T.RARIDADE["Comum"])
    var fundo: Color = Color(0.10, 0.15, 0.24, 0.96) if escolhido else T.NAVY_PAINEL
    caixa.add_theme_stylebox_override("panel",
        T.painel(fundo, T.OURO if escolhido else cor, 8, 2 if escolhido else 1, 0))


func _selecionar(id: String) -> void:
    _selecionado = id
    _confirmacao.visible = false
    for filho in _grade.get_children():
        var c := filho as PanelContainer
        if c == null:
            continue
        var meu := String(c.get_meta("id", ""))
        var ficha := _ficha(meu)
        _pintar_slot(c, meu == id, String(ficha[3]) if not ficha.is_empty() else "Comum")
    _pintar_detalhe()


func _pintar_detalhe() -> void:
    var ficha := _ficha(_selecionado)
    var tem := not ficha.is_empty()
    _det_icone.texture = _arte(String(ficha[2])) if tem else null
    _det_nome.text = String(ficha[1]) if tem else "Bolsa vazia"
    _det_tipo.text = "%s  •  %s" % [String(ficha[3]), String(ficha[4]).capitalize()] if tem else ""
    _det_posse.text = "Possui  %s" % _milhar(_progresso.quantidade(_selecionado)) if tem else ""
    _det_desc.text = String(ficha[5]) if tem else "Derrote Shikers e recolha o que eles deixam."
    if tem:
        var cor: Color = T.RARIDADE.get(String(ficha[3]), T.RARIDADE["Comum"])
        _det_moldura.add_theme_stylebox_override("panel", T.painel(T.NAVY_CLARO, cor, 8, 2, 6))

    # AS ACOES SO EXISTEM QUANDO FAZEM SENTIDO.
    var usavel: bool = tem and String(ficha[4]) == "consumivel"
    _botao_usar.visible = usavel
    _botao_usar.disabled = not usavel
    if usavel:
        _botao_usar.text = "Usar  (%s)" % String(ficha[1])
    _botao_descartar.disabled = not (tem and _pode_descartar(String(ficha[0]), String(ficha[4])))
    _botao_descartar.tooltip_text = "" if not _botao_descartar.disabled \
        else "Item preso a uma tarefa ou a uma ascensao."
    _confirmacao.visible = false


## Nao se descarta ferramenta, item de ascensao, nem o que uma tarefa do dia
## ainda esta pedindo — descartar ali quebraria o que o jogador esta fazendo.
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


func _usar() -> void:
    var ficha := _ficha(_selecionado)
    if ficha.is_empty() or _progresso == null:
        return
    for tipo in _progresso.PARTITURAS:
        if String(_progresso.PARTITURAS[tipo]["recurso"]) == _selecionado:
            _progresso.usar_partitura(String(tipo))
            return


func _pedir_confirmacao() -> void:
    _confirmacao.visible = true


func _descartar() -> void:
    _confirmacao.visible = false
    if _progresso and _selecionado != "":
        _progresso.adicionar_recurso(_selecionado, -1)


# ------------------------------------------------------------------ auxilio

func _arte(caminho: String):
    var certo := caminho if caminho.begins_with("res://") \
        else "res://textures/ui/kit/" + caminho + ".png"
    return load(certo) if ResourceLoader.exists(certo) else null


## Quatro digitos nao cabem no canto de um slot de 96 px.
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
