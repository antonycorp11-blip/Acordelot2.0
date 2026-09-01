extends Control
class_name PaginaInventario

## A BOLSA — so a bolsa. Moldura, cabecalho, botao de fechar e navbar sao do
## shell; esta pagina entrega conteudo e mais nada.
##
## Layout: filtros a esquerda, grade no meio (o elemento principal, e por isso o
## que recebe o espaco que sobra) e detalhe a direita.

const T := preload("res://scripts/ui_tema.gd")
const CATALOGO := preload("res://scripts/inventory_ui.gd")

## O SLOT MANTEM A PROPORCAO DA ARTE.
##
## `slot_azul.png` tem 94x121. Esticado para um quadrado, o bico de baixo achata
## e o aro engorda de um lado — a arte passa a parecer amassada. Aqui o slot
## nasce na proporcao do arquivo e o numero de colunas e que se ajusta para
## ocupar a largura, em vez de esticar cada peca.
const LADO_DO_SLOT := 112.0
const LARGURA_DO_SLOT := LADO_DO_SLOT * 94.0 / 121.0
const COLUNAS := 7
## Quantas fileiras a bolsa desenha mesmo estando vazia.
const FILEIRAS_VISIVEIS := 5
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
var _det_halo: TextureRect
var _det_faixa: HBoxContainer
var _botao_usar: Button
var _botao_descartar: Button
var _confirmacao: PanelContainer

var _selo_slots: Label
var _selo_claves: Label
var _selo_materiais: Label
var _selo_frag: Label
var _resumo: VBoxContainer
var _barra_lotacao: ProgressBar
var _rotulo_lotacao: Label
var _cabeca_da_grade: Control


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

    # ------------------------------------------------------- resumo da bolsa
    # O que a coluna da esquerda mostra e o que a bolsa REALMENTE tem. No
    # protótipo aqui mora a ficha do heroi; a ficha ja tem tela propria, e
    # repetir o retrato seria enfeite. O resumo, nao: e a resposta para "quanto
    # ainda cabe e do que eu tenho muito".
    var esq := T.painel_do_proto(16)
    esq.custom_minimum_size.x = 290
    linha.add_child(esq)
    var ce := VBoxContainer.new()
    ce.add_theme_constant_override("separation", 4)
    esq.add_child(ce)
    ce.add_child(T.cabeca_de_painel("Bolsa do Maestro", "Resumo"))
    ce.add_child(T.espaco(8))
    _resumo = VBoxContainer.new()
    _resumo.add_theme_constant_override("separation", 0)
    _resumo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ce.add_child(_resumo)
    ce.add_child(T.sobrancelha("Lotação"))
    _barra_lotacao = T.barra(Color(0.60, 0.47, 0.24), Color(0.94, 0.75, 0.36), 10.0)
    ce.add_child(_barra_lotacao)
    _rotulo_lotacao = T.rotulo_simples("", 15, T.SOBRANCELHA)
    ce.add_child(_rotulo_lotacao)

    # --------------------------------------------------------------- grade
    # A grade e o elemento principal, entao e ela que recebe o espaco que sobra.
    var caixa_grade := T.painel_do_proto(16)
    caixa_grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caixa_grade.size_flags_stretch_ratio = 2.4
    linha.add_child(caixa_grade)
    var cg := VBoxContainer.new()
    cg.add_theme_constant_override("separation", 8)
    caixa_grade.add_child(cg)
    _cabeca_da_grade = T.cabeca_de_painel("Coleção harmônica", "Fragmentos & relíquias", "0 / 0")
    cg.add_child(_cabeca_da_grade)

    # OS FILTROS VIRARAM FAIXA, e nao mais uma coluna inteira ao lado.
    #
    # Cinco palavras ocupavam 220 px de largura por 650 de altura para nada. Em
    # faixa eles ficam onde se procura por eles — encostados no que filtram — e
    # a grade herda a largura que sobrou.
    var faixa := HBoxContainer.new()
    faixa.add_theme_constant_override("separation", 8)
    cg.add_child(faixa)
    for nome in CATALOGO.FILTROS:
        var b := T.aba(String(nome), 40.0)
        b.alignment = HORIZONTAL_ALIGNMENT_CENTER
        b.pressed.connect(_escolher_filtro.bind(String(nome)))
        faixa.add_child(b)
        _botoes_filtro[String(nome)] = b

    _rolagem = ScrollContainer.new()
    _rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _grade = GridContainer.new()
    _grade.columns = COLUNAS
    # Slot de tamanho fixo com grade esticada deixaria uma faixa morta so de um
    # lado. Centrada, a sobra fica igual dos dois — e a grade parece de proposito.
    _grade.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    # ESPACAMENTO IGUAL nos dois eixos: era o que fazia a grade parecer torta.
    _grade.add_theme_constant_override("h_separation", 12)
    _grade.add_theme_constant_override("v_separation", 12)
    _rolagem.add_child(_grade)
    cg.add_child(_rolagem)

    # ------------------------------------------------------------- detalhe
    linha.add_child(_montar_detalhe())
    _escolher_filtro("Todos")


func _montar_detalhe() -> Control:
    var painel := T.painel_do_proto(16)
    painel.custom_minimum_size.x = 360

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 4)
    painel.add_child(col)

    # A ETIQUETA DE RARIDADE NO ALTO, como no protótipo: ela responde "quanto
    # vale isto" antes de o olho chegar no nome.
    _det_faixa = HBoxContainer.new()
    _det_faixa.add_theme_constant_override("separation", 8)
    col.add_child(_det_faixa)
    col.add_child(T.espaco(4))

    # A VITRINE DO ITEM.
    #
    # O item aparecia como uma miniatura de 86 px ao lado do nome, e o resto da
    # coluna era vazio ate o botao de descartar la embaixo. Agora ele e exibido:
    # arte grande, centrada, com um halo na cor da raridade atras. E o que faz
    # a coluna deixar de ser uma legenda e virar a peca principal da direita.
    var vitrine := CenterContainer.new()
    col.add_child(vitrine)

    _det_moldura = PanelContainer.new()
    _det_moldura.custom_minimum_size = Vector2(196, 196)
    _det_moldura.add_theme_stylebox_override("panel",
        T.estilo_do_kit("slot_dourado", Vector4i(24, 22, 24, 30), Vector4i(14, 14, 14, 20)))
    vitrine.add_child(_det_moldura)

    _det_halo = T.halo_redondo(Color(1, 1, 1), 0.34)
    _det_moldura.add_child(_det_halo)

    _det_icone = TextureRect.new()
    _det_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _det_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _det_moldura.add_child(_det_icone)

    col.add_child(T.espaco(12))
    # HIERARQUIA: nome grande, categoria pequena, quantidade em destaque.
    _det_nome = T.rotulo("", T.TITULO_SECAO, T.OURO_FORTE)
    _det_nome.add_theme_font_override("font", T.fonte_display())
    _det_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _det_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(_det_nome)
    _det_tipo = T.rotulo("", T.LEGENDA, T.TEXTO_FRACO)
    _det_tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(_det_tipo)
    col.add_child(T.espaco(6))
    _det_posse = T.rotulo("", T.NOME_ITEM, T.OURO)
    _det_posse.autowrap_mode = TextServer.AUTOWRAP_OFF
    _det_posse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(_det_posse)

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
    _botao_usar = T.botao("Usar", T.PRIMARIO, 54.0)
    _botao_usar.pressed.connect(_usar)
    col.add_child(_botao_usar)

    _botao_descartar = T.botao("Descartar", T.PERIGOSO, 54.0)
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
    # A BOLSA MOSTRA OS ESPACOS QUE TEM.
    #
    # Com nove itens numa area de cinco fileiras, a grade terminava na segunda
    # linha e o resto da tela era um vazio azul — parecia pagina inacabada. Toda
    # bolsa de RPG desenha os compartimentos livres: preenche o quadro, mostra
    # quanto ainda cabe e o item novo aparece num lugar que ja estava la.
    var vazios: int = maxi(FILEIRAS_VISIVEIS * COLUNAS - itens.size(), 0)
    for i in vazios:
        _grade.add_child(_slot_vazio())
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

    if _resumo:
        for antigo in _resumo.get_children():
            _resumo.remove_child(antigo)
            antigo.queue_free()
        var tipos := 0
        var consumiveis := 0
        for it in CATALOGO.ITENS_DE_RECURSO:
            var q: int = _progresso.quantidade(String(it[0]))
            if q <= 0:
                continue
            tipos += 1
            if String(it[4]) == "consumivel":
                consumiveis += q
        for par in [["Claves", _milhar(_progresso.quantidade("claves"))],
                ["Materiais", _milhar(materiais)],
                ["Fragmentos", _milhar(fragmentos)],
                ["Consumíveis", _milhar(consumiveis)],
                ["Tipos guardados", str(tipos)]]:
            var l := T.linha_de_status(String(par[0]), String(par[1]))
            l.size_flags_vertical = Control.SIZE_EXPAND_FILL
            _resumo.add_child(l)
    if _barra_lotacao:
        _barra_lotacao.value = clampf(float(ocupados) / float(CAPACIDADE), 0.0, 1.0)
    if _rotulo_lotacao:
        _rotulo_lotacao.text = "%d de %d espaços ocupados" % [ocupados, CAPACIDADE]
    if _cabeca_da_grade:
        for filho in _cabeca_da_grade.get_children():
            if filho is Label and (filho as Label).text.contains("/"):
                (filho as Label).text = "%d / %d" % [ocupados, CAPACIDADE]


# ------------------------------------------------------------------- slots

func _slot(it: Array) -> Control:
    var id := String(it[0])
    var raridade := String(it[3])
    var quanto: int = _progresso.quantidade(id)

    var caixa := PanelContainer.new()
    caixa.custom_minimum_size = Vector2(LARGURA_DO_SLOT, LADO_DO_SLOT)
    caixa.set_meta("id", id)
    _pintar_slot(caixa, id == _selecionado, raridade)

    # O NUMERO NAO FLUTUA SOBRE O DESENHO: ELE TEM FAIXA PROPRIA.
    #
    # Antes a quantidade era ancorada por cima do slot e so uma margem embaixo
    # tentava segurar o icone longe dela — bastava a arte crescer para "35K"
    # cair em cima da moeda. Empilhados, icone e numero nao tem como se cruzar.
    var pilha := VBoxContainer.new()
    pilha.add_theme_constant_override("separation", 0)
    pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caixa.add_child(pilha)

    var margem := MarginContainer.new()
    margem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    for lado in ["margin_left", "margin_right", "margin_top"]:
        margem.add_theme_constant_override(lado, 8)
    margem.add_theme_constant_override("margin_bottom", 2)
    pilha.add_child(margem)

    var img := TextureRect.new()
    img.texture = _arte(String(it[2]))
    img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margem.add_child(img)

    var numero := T.rotulo(_curto(quanto), T.LEGENDA, Color(0.99, 0.95, 0.84))
    numero.custom_minimum_size.y = 22
    numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    numero.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.95))
    numero.add_theme_constant_override("outline_size", 4)
    var faixa := MarginContainer.new()
    faixa.add_theme_constant_override("margin_right", 8)
    faixa.add_theme_constant_override("margin_bottom", 4)
    faixa.add_child(numero)
    pilha.add_child(faixa)

    var toque := Button.new()
    toque.set_anchors_preset(Control.PRESET_FULL_RECT)
    toque.focus_mode = Control.FOCUS_NONE
    for estado in ["normal", "hover", "pressed", "focus"]:
        toque.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    toque.pressed.connect(_selecionar.bind(id))
    caixa.add_child(toque)
    return caixa


func _slot_vazio() -> Control:
    var caixa := PanelContainer.new()
    caixa.custom_minimum_size = Vector2(LARGURA_DO_SLOT, LADO_DO_SLOT)
    caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var estilo := T.estilo_do_kit("slot_azul", Vector4i(24, 22, 24, 30), Vector4i(6, 6, 6, 26))
    if estilo is StyleBoxTexture:
        # Apagado, para nao competir com quem tem item dentro.
        (estilo as StyleBoxTexture).modulate_color = Color(0.42, 0.46, 0.55, 0.42)
    caixa.add_theme_stylebox_override("panel", estilo)
    return caixa


## A raridade entra como ARO FINO, nao como preenchimento: e a unica cor forte
## do slot e ja se le antes de qualquer texto. O item escolhido ganha aro
## dourado e fundo mais claro, para nao depender de distinguir dois azuis.
func _pintar_slot(caixa: PanelContainer, escolhido: bool, raridade: String) -> void:
    # O SLOT AGORA E A ARTE DO KIT.
    #
    # `slot_azul`, `slot_verde`, `slot_roxo` e `slot_dourado` estavam no projeto
    # desde sempre, pintados, e o inventario desenhava um retangulo com borda de
    # um pixel no lugar deles. A raridade escolhe o aro; o item selecionado
    # recebe o dourado, que e um estado que se le de longe.
    var nome := "slot_dourado" if escolhido else String(
        T.SLOT_DA_RARIDADE.get(raridade, "slot_azul"))
    caixa.add_theme_stylebox_override("panel",
        T.estilo_do_kit(nome, Vector4i(24, 22, 24, 30), Vector4i(6, 6, 6, 26)))


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
    # Raridade e tipo as vezes tem o MESMO nome ("Valioso  •  Valioso"), e
    # repetir a palavra so gasta a linha. Quando coincidem, mostra uma vez.
    var raridade := String(ficha[3]) if tem else ""
    var tipo := String(ficha[4]).capitalize() if tem else ""
    _det_tipo.text = "" if not tem else (raridade if raridade == tipo else "%s  •  %s" % [raridade, tipo])
    _det_posse.text = "%s" % _milhar(_progresso.quantidade(_selecionado)) if tem else ""
    _det_desc.text = String(ficha[5]) if tem else "Derrote Shikers e recolha o que eles deixam."
    var cor: Color = T.RARIDADE.get(raridade, T.RARIDADE["Comum"])
    for antigo in _det_faixa.get_children():
        _det_faixa.remove_child(antigo)
        antigo.queue_free()
    if tem:
        _det_faixa.add_child(T.chip(raridade, cor))
        # "VALIOSO  VALIOSO" nao diz nada duas vezes: a segunda etiqueta so
        # aparece quando o tipo do item e diferente da raridade dele.
        if String(ficha[4]).to_upper() != raridade.to_upper():
            _det_faixa.add_child(T.chip(String(ficha[4]), T.SOBRANCELHA.lightened(0.2)))
    _det_halo.modulate = Color(cor.r, cor.g, cor.b, 1.0 if tem else 0.0)
    _det_moldura.add_theme_stylebox_override("panel", T.estilo_do_kit(
        String(T.SLOT_DA_RARIDADE.get(raridade, "slot_dourado")) if tem else "slot_azul",
        Vector4i(24, 22, 24, 30), Vector4i(14, 14, 14, 20)))

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


func _avisar(sobre: String, texto: String) -> void:
    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar"):
        casca.avisar(sobre, texto)


func _usar() -> void:
    var ficha := _ficha(_selecionado)
    if ficha.is_empty() or _progresso == null:
        return
    for tipo in _progresso.PARTITURAS:
        if String(_progresso.PARTITURAS[tipo]["recurso"]) == _selecionado:
            _progresso.usar_partitura(String(tipo))
            _avisar("Experiência absorvida",
                "+%d XP de %s" % [int(_progresso.PARTITURAS[tipo]["xp"]), String(ficha[1])])
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
