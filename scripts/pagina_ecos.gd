extends Control
class_name PaginaEcos

## OS DOZE ECOS EM RODA, com o escolhido no meio.
##
## A versao anterior era uma grade de doze cartoes iguais. Tres defeitos, e o
## terceiro e bug de verdade:
##
## 1. A grade nao cabia: a terceira fileira ficava por baixo da navbar.
## 2. Nenhum lugar mostrava o que o Eco DA — funcao harmonica, licao e bonus
##    estao na tabela do Progresso desde sempre e a tela nao lia.
## 3. O rodape do cartao era um VBoxContainer de 46 px preso a `caixa`, fora do
##    `recorte` que tem `clip_contents`. Container cresce ate o tamanho minimo
##    dos filhos: com duas linhas de texto ele passava dos 46 px, vazava a borda
##    do cartao e escrevia por cima dela. Era o texto cortado na tela.
##
## A roda resolve os tres de uma vez. Doze e um numero de RELOGIO — e a escala
## cromatica e circular de verdade: depois do Si vem o Do de novo. Mostrar as
## notas em circulo nao e enfeite, e a forma correta do assunto. O escolhido
## ocupa o meio grande, o painel da direita conta o que ele e, e o carrossel
## embaixo deixa correr os doze com o polegar.

const T := preload("res://scripts/ui_tema.gd")

const NOTAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do": "Dó", "do_sustenido": "Dó#", "re": "Ré", "re_sustenido": "Ré#",
    "mi": "Mi", "fa": "Fá", "fa_sustenido": "Fá#", "sol": "Sol",
    "sol_sustenido": "Sol#", "la": "Lá", "la_sustenido": "Lá#", "si": "Si"}

## O disco de cada nota na roda e o tamanho do retrato do meio.
const LADO_DO_DISCO := 74.0
const LADO_NO_CARROSSEL := 66.0
## Fracao do menor lado da arena que vira o raio da roda.
const RAIO_DA_RODA := 0.40

var _progresso: Node
var _arena: Control
var _miolo: TextureRect
var _halo: TextureRect
var _nome_do_meio: Label
var _selo_equipado: Control
var _discos: Dictionary = {}
var _carrossel: HBoxContainer
var _detalhe: VBoxContainer
var _botao_equipar: Button
var _chips: HBoxContainer
var _escolhido := "do"


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)


func ao_abrir() -> void:
    var equipado := String(_progresso.eco_equipado.get("id", "")) if _progresso else ""
    if equipado != "":
        _escolhido = equipado
    _pintar()


## Os tres contadores sobem para o cabecalho da casca, ao lado do titulo — e
## exatamente onde eles estao no desenho aprovado. Aqui embaixo eles roubariam
## uma faixa inteira da altura, que e o que falta nesta tela.
func cabecalho_extra() -> Control:
    _chips = HBoxContainer.new()
    _chips.add_theme_constant_override("separation", 8)
    return _chips


# ------------------------------------------------------------------ montagem

func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 14)
    add_child(linha)

    var esquerda := VBoxContainer.new()
    esquerda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    esquerda.size_flags_stretch_ratio = 1.62
    esquerda.add_theme_constant_override("separation", 8)
    linha.add_child(esquerda)

    _arena = Control.new()
    _arena.name = "Arena"
    _arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _arena.mouse_filter = Control.MOUSE_FILTER_PASS
    # Rede de seguranca: nada da roda desenha fora da area dela, aconteca o que
    # acontecer com o layout acima.
    _arena.clip_contents = true
    _arena.resized.connect(_arrumar_a_roda)
    esquerda.add_child(_arena)

    _montar_o_meio()
    for id in NOTAS:
        var disco := _disco(String(id), LADO_DO_DISCO)
        _arena.add_child(disco)
        _discos[id] = disco

    esquerda.add_child(_montar_carrossel())
    linha.add_child(_montar_detalhe())


## O retrato grande, o halo por tras e o nome embaixo dele.
func _montar_o_meio() -> void:
    _halo = T.halo_redondo(Color(0.45, 0.62, 1.0), 0.34)
    _halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _arena.add_child(_halo)

    _miolo = TextureRect.new()
    _miolo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _miolo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _miolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _arena.add_child(_miolo)

    _nome_do_meio = T.rotulo_simples("", 34, T.OURO_FORTE)
    _nome_do_meio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _nome_do_meio.add_theme_font_override("font", T.fonte_display())
    _nome_do_meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _arena.add_child(_nome_do_meio)

    _selo_equipado = T.chip("EQUIPADO", T.OURO_FORTE)
    _selo_equipado.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _arena.add_child(_selo_equipado)


## A RODA SE ARRUMA A PARTIR DO RETANGULO DA ARENA, e nao de posicoes escritas.
##
## Doze pontos num circulo, comecando no topo e girando pelo relogio — que e a
## ordem cromatica ascendente. Sai do tamanho real do no, entao a mesma conta
## serve para celular deitado e para tela de computador sem numero solto.
func _arrumar_a_roda() -> void:
    if _arena == null or _arena.size.x < 50.0:
        return
    var centro := _arena.size * 0.5
    # A RODA E UMA ELIPSE, e nao um circulo.
    #
    # Com raio unico saido do menor lado, a roda ficava um circulo pequeno no
    # meio de uma area larga: sobrava meia tela vazia dos dois lados. A elipse
    # usa a largura que existe e mantem a altura que cabe — a ordem das notas,
    # que e o que importa aqui, nao muda.
    var raio_x: float = _arena.size.x * RAIO_DA_RODA * 0.92
    var raio_y: float = _arena.size.y * RAIO_DA_RODA
    for i in NOTAS.size():
        var disco: Control = _discos.get(NOTAS[i])
        if disco == null:
            continue
        var angulo: float = -PI * 0.5 + TAU * float(i) / float(NOTAS.size())
        disco.position = centro + Vector2(cos(angulo) * raio_x, sin(angulo) * raio_y) \
            - disco.size * 0.5

    var lado: float = minf(_arena.size.x * 0.42, _arena.size.y * 0.58)
    _miolo.size = Vector2(lado, lado)
    _miolo.position = centro - _miolo.size * 0.5 - Vector2(0.0, 12.0)
    _halo.size = Vector2(lado * 1.25, lado * 1.25)
    _halo.position = centro - _halo.size * 0.5 - Vector2(0.0, 12.0)
    # O nome e o selo moram entre o retrato e a borda de baixo da elipse. A
    # conta usa `raio_y` de proposito: encostar no disco de baixo era questao de
    # dois pixels quando a area mudava de proporcao.
    var fim_do_nome: float = minf(centro.y + lado * 0.40, centro.y + raio_y - 96.0)
    _nome_do_meio.size = Vector2(_arena.size.x, 40.0)
    _nome_do_meio.position = Vector2(0.0, fim_do_nome)
    _selo_equipado.position = Vector2(
        centro.x - _selo_equipado.size.x * 0.5, fim_do_nome + 40.0)


## Um disco da roda: o retrato recortado num circulo com aro da raridade.
func _disco(id: String, lado: float) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(lado, lado)
    b.size = Vector2(lado, lado)
    b.focus_mode = Control.FOCUS_NONE
    b.tooltip_text = String(ROTULO.get(id, id))
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    b.pressed.connect(_escolher.bind(id))

    var aro := Panel.new()
    aro.name = "Aro"
    aro.set_anchors_preset(Control.PRESET_FULL_RECT)
    aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(aro)

    # O RETRATO PRECISA DE UM RECORTE PROPRIO.
    #
    # A arte do Eco e 4:3 e o disco e quadrado. Sem um Control com
    # `clip_contents` no meio, a imagem transborda o aro — e foi transbordamento
    # parecido que fez o texto do cartao antigo escrever por cima da borda.
    var recorte := Control.new()
    recorte.set_anchors_preset(Control.PRESET_FULL_RECT)
    recorte.offset_left = 3.0
    recorte.offset_top = 3.0
    recorte.offset_right = -3.0
    recorte.offset_bottom = -3.0
    recorte.clip_contents = true
    recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(recorte)

    var face := TextureRect.new()
    face.name = "Face"
    face.set_anchors_preset(Control.PRESET_FULL_RECT)
    face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    face.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var caminho := "res://textures/ui/ecos/%s.png" % id
    if ResourceLoader.exists(caminho):
        face.texture = load(caminho)
    recorte.add_child(face)

    var sigla := T.rotulo_simples(String(ROTULO.get(id, id)), 13, T.CREME)
    sigla.name = "Sigla"
    sigla.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    sigla.offset_top = -19.0
    sigla.offset_bottom = -1.0
    sigla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sigla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    sigla.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sigla.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.95))
    sigla.add_theme_constant_override("outline_size", 5)
    b.add_child(sigla)
    return b


func _montar_carrossel() -> Control:
    var rolagem := ScrollContainer.new()
    rolagem.custom_minimum_size.y = LADO_NO_CARROSSEL + 16.0
    rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var caixa := PanelContainer.new()
    caixa.add_theme_stylebox_override("panel",
        T.painel(Color(0.02, 0.035, 0.07, 0.80), T.BRONZE, 4, 1, 8))
    caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    _carrossel = HBoxContainer.new()
    _carrossel.add_theme_constant_override("separation", 10)
    _carrossel.alignment = BoxContainer.ALIGNMENT_CENTER
    _carrossel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rolagem.add_child(_carrossel)
    caixa.add_child(rolagem)
    return caixa


## O PAINEL DA DIREITA NAO PODE MANDAR NA ALTURA DA LINHA.
##
## Sem a rolagem no meio, o VBox do detalhe entregava um tamanho minimo de 755
## px — titulo, licao quebrada em quatro linhas, quatro bonus e um paragrafo. O
## HBox de cima e obrigado a respeitar o minimo de um filho, entao a linha
## inteira virava 755 px numa area de 629, a arena esticava junto e a metade de
## baixo da roda ia parar atras da navbar. Era esse o defeito: nao era a conta
## do circulo, era um filho empurrando o pai.
##
## Com a rolagem, o minimo do painel deixa de depender do texto que cabe dentro
## dele. Quem manda na altura passa a ser a area disponivel, que e o certo.
func _montar_detalhe() -> Control:
    var painel := T.painel_do_proto(18)
    painel.custom_minimum_size.x = 430.0
    painel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    painel.clip_contents = true

    var rolagem := ScrollContainer.new()
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    painel.add_child(rolagem)

    _detalhe = VBoxContainer.new()
    _detalhe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detalhe.add_theme_constant_override("separation", 9)
    rolagem.add_child(_detalhe)
    return painel


# --------------------------------------------------------------------- estado

func _escolher(id: String) -> void:
    _escolhido = id
    _pintar()


func _pintar() -> void:
    if _progresso == null or _arena == null:
        return
    var achados: Array = _progresso.ecos_descobertos
    var equipado := String(_progresso.eco_equipado.get("id", ""))
    _pintar_chips(achados)
    _pintar_discos(achados, equipado)
    _pintar_carrossel(achados, equipado)
    _pintar_meio(achados, equipado)
    _pintar_detalhe(achados, equipado)
    _arrumar_a_roda()


func _pintar_chips(achados: Array) -> void:
    if _chips == null:
        return
    for velho in _chips.get_children():
        _chips.remove_child(velho)
        velho.queue_free()
    var naturais := 0
    for nota in _progresso.NATURAIS:
        if nota in achados:
            naturais += 1
    var total: int = _progresso.ECOS.size()
    _chips.add_child(T.chip("Coleção  %d / %d" % [achados.size(), total],
        T.OURO_FORTE if achados.size() >= total else T.SOBRANCELHA.lightened(0.3)))
    _chips.add_child(T.chip("Escala diatônica  %d / 7" % naturais,
        T.GANHO if naturais >= 7 else T.SOBRANCELHA))
    _chips.add_child(T.chip("Cromática  %d / %d" % [achados.size(), total],
        T.GANHO if achados.size() >= total else T.SOBRANCELHA))


func _cor_da_raridade(id: String) -> Color:
    var ficha: Dictionary = _progresso.ficha_do_eco(id)
    return T.RARIDADE.get(String(ficha.get("raridade", "Comum")), T.SOBRANCELHA)


func _vestir_disco(disco: Control, id: String, tem: bool, escolhido: bool,
        e_o_equipado: bool) -> void:
    var cor: Color = _cor_da_raridade(id) if tem else Color(0.26, 0.31, 0.40)
    var aro := disco.get_node_or_null("Aro") as Panel
    if aro:
        var e := StyleBoxFlat.new()
        e.bg_color = Color(0.03, 0.05, 0.10, 0.94)
        e.border_color = T.OURO_FORTE if e_o_equipado else cor
        e.set_border_width_all(3 if escolhido or e_o_equipado else 2)
        e.set_corner_radius_all(int(disco.size.x * 0.5))
        aro.add_theme_stylebox_override("panel", e)
    var face := disco.find_child("Face", true, false) as TextureRect
    if face:
        face.modulate = Color(1, 1, 1, 1) if tem else Color(0.17, 0.20, 0.28, 1)
    var sigla := disco.find_child("Sigla", true, false) as Label
    if sigla:
        sigla.add_theme_color_override("font_color", T.CREME if tem else Color(0.42, 0.47, 0.56))
    disco.modulate.a = 1.0 if tem or escolhido else 0.86


func _pintar_discos(achados: Array, equipado: String) -> void:
    for id in NOTAS:
        var disco: Control = _discos.get(id)
        if disco:
            _vestir_disco(disco, String(id), id in achados, id == _escolhido, id == equipado)


func _pintar_carrossel(achados: Array, equipado: String) -> void:
    for velho in _carrossel.get_children():
        _carrossel.remove_child(velho)
        velho.queue_free()
    for id in NOTAS:
        var disco := _disco(String(id), LADO_NO_CARROSSEL)
        _carrossel.add_child(disco)
        _vestir_disco(disco, String(id), id in achados, id == _escolhido, id == equipado)


func _pintar_meio(achados: Array, equipado: String) -> void:
    var tem: bool = _escolhido in achados
    var caminho := "res://textures/ui/ecos/%s.png" % _escolhido
    _miolo.texture = load(caminho) if ResourceLoader.exists(caminho) else null
    _miolo.modulate = Color(1, 1, 1, 1) if tem else Color(0.20, 0.24, 0.33, 1)
    var ficha: Dictionary = _progresso.ficha_do_eco(_escolhido)
    _nome_do_meio.text = String(ficha.get("nome", ROTULO.get(_escolhido, _escolhido)))
    _nome_do_meio.add_theme_color_override("font_color",
        T.OURO_FORTE if tem else Color(0.45, 0.51, 0.62))
    _halo.modulate = _cor_da_raridade(_escolhido) if tem else Color(0.3, 0.34, 0.45)
    _selo_equipado.visible = _escolhido == equipado


func _pintar_detalhe(achados: Array, equipado: String) -> void:
    for velho in _detalhe.get_children():
        _detalhe.remove_child(velho)
        velho.queue_free()
    var ficha: Dictionary = _progresso.ficha_do_eco(_escolhido)
    var tem: bool = _escolhido in achados

    var fila_raridade := HBoxContainer.new()
    fila_raridade.add_child(T.chip(String(ficha.get("raridade", "—")).to_upper(),
        _cor_da_raridade(_escolhido)))
    var sobra := Control.new()
    sobra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila_raridade.add_child(sobra)
    _detalhe.add_child(fila_raridade)
    _detalhe.add_child(T.titulo_do_proto(
        String(ficha.get("nome", ROTULO.get(_escolhido, _escolhido))), 34))
    _detalhe.add_child(T.espaco(2))

    _detalhe.add_child(T.sobrancelha("Função musical"))
    _detalhe.add_child(T.rotulo_simples("%s  ·  %s" % [
        String(ficha.get("grau", "—")), String(ficha.get("funcao", "—"))], 19, T.CIANO))
    var licao := T.rotulo(String(ficha.get("licao", "")), T.CORPO,
        T.TEXTO_FRACO, true)
    licao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detalhe.add_child(licao)
    _detalhe.add_child(T.espaco(6))

    # O QUE ELE DA, item por item. A tabela do Progresso ja tinha estes numeros
    # e nenhuma tela os mostrava — o jogador equipava no escuro.
    _detalhe.add_child(T.sobrancelha("Bônus deste Eco"))
    var bonus: Dictionary = ficha.get("bonus", {})
    if bonus.is_empty():
        _detalhe.add_child(T.rotulo_simples("—", 15, T.TEXTO_FRACO))
    for chave in bonus:
        _detalhe.add_child(T.linha_de_status(_nome_do_atributo(String(chave)),
            "+%s" % _numero(bonus[chave])))
    _detalhe.add_child(T.espaco(6))

    _detalhe.add_child(T.sobrancelha("Fechar a escala"))
    var naturais := 0
    for nota in _progresso.NATURAIS:
        if nota in achados:
            naturais += 1
    _detalhe.add_child(T.rotulo_simples(
        "Diatônica %d/7  ·  Cromática %d/%d" % [naturais, achados.size(),
            _progresso.ECOS.size()], 15, T.GANHO if naturais >= 7 else T.TEXTO_FRACO))
    _detalhe.add_child(T.espaco(0))
    _detalhe.add_child(T.rotulo(
        "As sete naturais fecham a escala diatônica; as doze fecham a cromática. "
        + "Cada fechamento vale um bônus permanente, mesmo sem equipar.",
        T.CORPO, T.TEXTO_FRACO, true))

    var elastico := Control.new()
    elastico.size_flags_vertical = Control.SIZE_EXPAND_FILL
    elastico.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _detalhe.add_child(elastico)

    _botao_equipar = T.botao(
        "EQUIPADO" if _escolhido == equipado else "EQUIPAR", 0, 52.0)
    _botao_equipar.disabled = not tem or _escolhido == equipado
    if not tem:
        _botao_equipar.text = "AINDA NÃO RESSOADO"
    _botao_equipar.pressed.connect(_equipar)
    _detalhe.add_child(_botao_equipar)


func _equipar() -> void:
    if _progresso == null:
        return
    if _progresso.equipar_eco({"id": _escolhido}):
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("avisar"):
            var ficha: Dictionary = _progresso.ficha_do_eco(_escolhido)
            casca.avisar("Eco equipado", String(ficha.get("nome", _escolhido)))


func _nome_do_atributo(chave: String) -> String:
    match chave:
        "vida_maxima": return "Vida máxima"
        "poder_harmonico": return "Poder harmônico"
        "dano_critico": return "Dano crítico"
        "critico": return "Taxa crítica"
        "ataque": return "Ataque"
        "defesa": return "Defesa"
        _: return chave.capitalize()


func _numero(valor) -> String:
    var f := float(valor)
    return str(int(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f
