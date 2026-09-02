extends Control
class_name PaginaPersonagem

## A FICHA DO PERSONAGEM, no desenho do conceito novo.
##
## Tres faixas, sempre nesta ordem: menu vertical a esquerda, palco no meio,
## painel de detalhe a direita. O menu escolhe O QUE o painel da direita mostra;
## o cabecalho do painel — nome, estrelas, papel e Poder de Luta — e o rodape,
## com os materiais e o botao de ascender, nao mudam nunca. E o que faz a tela
## parecer a mesma tela em cinco assuntos diferentes, em vez de cinco telas.
##
## O texto e do jogo, o desenho e do conceito. Onde o conceito pedia um numero
## que o jogo nao tem, entrou o numero que o jogo tem — nao um numero inventado
## para preencher o lugar. As cinco estrelas sao as cinco ascensoes; a barra de
## EXP e a experiencia de verdade; os materiais sao os que a proxima ascensao
## cobra.

const T := preload("res://scripts/ui_tema.gd")
const PalcoScript := preload("res://scripts/palco_akles.gd")
const CATALOGO := preload("res://scripts/inventory_ui.gd")

## O fundo do conceito. Enquanto ele nao chega, o palco antigo segura o lugar —
## a tela nao pode depender de um arquivo que talvez ainda nao exista.
const FUNDO_NOVO := "res://textures/ui/concepts/personagem-bg.png"
const FUNDO_RESERVA := "res://textures/ui/concepts/character-stage-bg.png"

const ABAS := [
    ["atributos", "Atributos", "res://textures/ui/kit/nav/melodia.png"],
    ["arma", "Arma", "res://textures/ui/kit/equip/espada.png"],
    ["acessorios", "Acessórios", "res://textures/ui/kit/equip/amuleto.png"],
    ["talentos", "Talentos", "res://textures/ui/kit/nav/talentos.png"],
    ["perfil", "Perfil", "res://textures/ui/kit/nav/personagem.png"],
]

## Os seis numeros da direita, na ordem do conceito, com o desenho de cada icone.
const ESTATISTICAS := [
    ["vida_maxima", "Vida Máxima", "coracao"],
    ["ataque", "Ataque", "espada"],
    ["defesa", "Defesa", "escudo"],
    ["critico", "Chance Crítica", "estrela"],
    ["dano_critico", "Dano Crítico", "estouro"],
    ["poder_harmonico", "Poder Harmônico", "losango"],
]
const ATRIBUTOS := {"forca": "Força", "destreza": "Destreza",
    "vitalidade": "Vitalidade", "ressonancia": "Ressonância",
    "percepcao": "Percepção"}

## As cinco ascensoes da trilha. O jogo trava em 20 e 40; os outros tres marcos
## sao os degraus intermediarios que a ficha ja mostrava.
const MARCOS := [10, 20, 30, 40, 60]

var _progresso: Node
var _palco: PalcoAkles
var _palco_caixa: Control
var _aba := "atributos"
var _mostrando_atributos := false
var _botoes_aba: Dictionary = {}

var _nome: Label
var _papel: Label
var _estrelas: HBoxContainer
var _poder: Label
var _nivel: Label
var _xp: Label
var _barra: ProgressBar
var _miolo: VBoxContainer
var _botao_detalhes: Button
var _materiais: HBoxContainer
var _claves: Label
var _acao: Button
var _cartao_arma: VBoxContainer


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)


func ao_abrir() -> void:
    if _palco:
        _palco.ligar()
    _pintar()


func ao_fechar() -> void:
    if _palco:
        _palco.desligar()


# ------------------------------------------------------------------ montagem

func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 14)
    add_child(linha)

    linha.add_child(_montar_coluna_esquerda())
    linha.add_child(_montar_palco())
    linha.add_child(_montar_painel_direito())


## O MENU VERTICAL, e embaixo dele a arma e o botao das musicas.
##
## No conceito o cartao da arma fica no pe da tela, na faixa que aqui pertence a
## navbar. Ele desce para o fim desta coluna: mesmo canto, mesma leitura, e sem
## disputar espaco com a navegacao que leva as outras telas.
func _montar_coluna_esquerda() -> Control:
    var coluna := VBoxContainer.new()
    coluna.custom_minimum_size.x = 268.0
    coluna.add_theme_constant_override("separation", 8)

    for dados in ABAS:
        var b := _pilula_de_aba(String(dados[0]), String(dados[1]), String(dados[2]))
        coluna.add_child(b)
        _botoes_aba[String(dados[0])] = b

    var elastico := Control.new()
    elastico.size_flags_vertical = Control.SIZE_EXPAND_FILL
    elastico.mouse_filter = Control.MOUSE_FILTER_IGNORE
    coluna.add_child(elastico)

    var arma := T.painel_do_proto(12)
    var dentro := HBoxContainer.new()
    dentro.add_theme_constant_override("separation", 10)
    arma.add_child(dentro)
    dentro.add_child(_arte("res://textures/ui/kit/equip/espada.png", 42.0))
    _cartao_arma = VBoxContainer.new()
    _cartao_arma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _cartao_arma.add_theme_constant_override("separation", 1)
    dentro.add_child(_cartao_arma)
    coluna.add_child(arma)

    var musicas := HBoxContainer.new()
    musicas.add_theme_constant_override("separation", 10)
    var disco := _botao_redondo("res://textures/ui/kit/nav/lira.png", 54.0)
    disco.tooltip_text = "Ligar ou desligar a trilha"
    disco.pressed.connect(_alternar_trilha)
    musicas.add_child(disco)
    var legenda := T.rotulo_simples("Músicas", 15, T.SOBRANCELHA)
    legenda.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    musicas.add_child(legenda)
    coluna.add_child(musicas)
    return coluna


func _pilula_de_aba(id: String, texto: String, icone: String) -> Button:
    var b := Button.new()
    b.custom_minimum_size.y = 52.0
    b.focus_mode = Control.FOCUS_NONE
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    b.pressed.connect(_escolher_aba.bind(id))

    var placa := Panel.new()
    placa.name = "Placa"
    placa.set_anchors_preset(Control.PRESET_FULL_RECT)
    placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(placa)

    var fila := HBoxContainer.new()
    fila.set_anchors_preset(Control.PRESET_FULL_RECT)
    fila.offset_left = 16.0
    fila.offset_right = -14.0
    fila.add_theme_constant_override("separation", 12)
    fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(fila)

    fila.add_child(_arte(icone, 30.0))
    var rotulo := T.rotulo_simples(texto, 21, T.CREME)
    rotulo.name = "Rotulo"
    rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila.add_child(rotulo)

    var seta := T.rotulo_simples("›", 24, T.OURO_FORTE)
    seta.name = "Seta"
    seta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fila.add_child(seta)
    return b


func _montar_palco() -> Control:
    _palco_caixa = Control.new()
    _palco_caixa.name = "Palco"
    _palco_caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _palco_caixa.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _palco_caixa.clip_contents = true

    var caminho := FUNDO_NOVO if ResourceLoader.exists(FUNDO_NOVO) else FUNDO_RESERVA
    var fundo := TextureRect.new()
    if ResourceLoader.exists(caminho):
        fundo.texture = load(caminho)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    # O fundo senta ATRAS do heroi, nao ao lado dele. Sem este recuo de brilho o
    # cenario disputa atencao com o personagem, que e o assunto da tela.
    fundo.modulate = Color(0.86, 0.90, 1.0, 0.94)
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _palco_caixa.add_child(fundo)

    _palco = PalcoScript.new(false)
    _palco.set_anchors_preset(Control.PRESET_FULL_RECT)
    _palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _palco_caixa.add_child(_palco)
    return _palco_caixa


func _montar_painel_direito() -> Control:
    var painel := T.painel_do_proto(18)
    painel.custom_minimum_size.x = 540.0
    painel.clip_contents = true

    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 6)
    painel.add_child(coluna)

    # --- cabecalho: nome, estrelas, papel, e o disco do Poder de Luta
    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 12)
    coluna.add_child(topo)

    var ident := VBoxContainer.new()
    ident.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ident.add_theme_constant_override("separation", 2)
    topo.add_child(ident)
    _nome = T.titulo_do_proto("Akles", 36)
    ident.add_child(_nome)
    _estrelas = HBoxContainer.new()
    _estrelas.add_theme_constant_override("separation", 3)
    ident.add_child(_estrelas)
    var fila_papel := HBoxContainer.new()
    fila_papel.add_theme_constant_override("separation", 7)
    fila_papel.add_child(_arte("res://textures/ui/kit/nav/lira.png", 20.0))
    _papel = T.rotulo_simples("", 17, T.SOBRANCELHA)
    _papel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fila_papel.add_child(_papel)
    ident.add_child(fila_papel)

    topo.add_child(_montar_disco_de_poder())
    coluna.add_child(_divisoria())

    # --- nivel e experiencia
    var fila_nivel := HBoxContainer.new()
    fila_nivel.add_theme_constant_override("separation", 8)
    _nivel = T.rotulo_simples("", 22, T.CREME)
    _nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila_nivel.add_child(_nivel)
    _xp = T.rotulo_simples("", 17, T.TEXTO_FRACO)
    _xp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fila_nivel.add_child(_xp)
    coluna.add_child(fila_nivel)

    var fila_barra := HBoxContainer.new()
    fila_barra.add_theme_constant_override("separation", 8)
    fila_barra.add_child(T.rotulo_simples("EXP", 13, T.SOBRANCELHA))
    _barra = T.barra(Color(0.24, 0.62, 1.0), Color(0.60, 0.88, 1.0), 10.0)
    _barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    fila_barra.add_child(_barra)
    coluna.add_child(fila_barra)
    coluna.add_child(T.espaco(2))

    # --- o miolo, que troca com a aba escolhida
    # A MESMA ARMADILHA DOS ECOS, e pelo mesmo motivo.
    #
    # Sem rolagem, o VBox do miolo entrega um tamanho minimo que soma seis linhas
    # de estatistica, os materiais e o botao. O HBox de cima e obrigado a
    # respeitar o minimo de um filho: a linha inteira passava dos 629 px da area
    # e o rodape do painel, o cartao da arma e o botao de musicas ficavam
    # cortados embaixo. Com a rolagem, quem manda na altura e a area disponivel.
    var rolagem := ScrollContainer.new()
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(rolagem)

    _miolo = VBoxContainer.new()
    _miolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _miolo.add_theme_constant_override("separation", 2)
    rolagem.add_child(_miolo)

    _botao_detalhes = T.botao("Detalhes", T.SECUNDARIO, 34.0)
    _botao_detalhes.pressed.connect(_alternar_detalhes)
    coluna.add_child(_botao_detalhes)
    coluna.add_child(T.espaco(4))

    # --- materiais da ascensao e o botao
    coluna.add_child(T.sobrancelha("Materiais de Ascensão"))
    _materiais = HBoxContainer.new()
    _materiais.add_theme_constant_override("separation", 10)
    coluna.add_child(_materiais)
    coluna.add_child(T.espaco(4))

    var rodape := HBoxContainer.new()
    rodape.add_theme_constant_override("separation", 12)
    var moeda := HBoxContainer.new()
    moeda.add_theme_constant_override("separation", 7)
    moeda.add_child(_arte("res://textures/ui/kit/item/moeda.png", 28.0))
    _claves = T.rotulo_simples("0", 22, T.OURO_FORTE)
    _claves.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    moeda.add_child(_claves)
    rodape.add_child(moeda)
    _acao = T.botao("ASCENDER", T.PRIMARIO, 50.0)
    _acao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _acao.pressed.connect(_agir)
    rodape.add_child(_acao)
    coluna.add_child(rodape)
    return painel


## O disco do Poder de Luta: aro dourado, lira dentro e o numero grande ao lado.
func _montar_disco_de_poder() -> Control:
    var caixa := HBoxContainer.new()
    caixa.add_theme_constant_override("separation", 10)

    var disco := Panel.new()
    disco.custom_minimum_size = Vector2(56, 56)
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.05, 0.09, 0.18, 0.95)
    e.border_color = T.OURO
    e.set_border_width_all(2)
    e.set_corner_radius_all(32)
    disco.add_theme_stylebox_override("panel", e)
    var lira := _arte("res://textures/ui/kit/nav/lira.png", 36.0)
    lira.set_anchors_preset(Control.PRESET_FULL_RECT)
    lira.offset_left = 12.0
    lira.offset_top = 12.0
    lira.offset_right = -12.0
    lira.offset_bottom = -12.0
    disco.add_child(lira)
    caixa.add_child(disco)

    var numeros := VBoxContainer.new()
    numeros.add_theme_constant_override("separation", 0)
    numeros.alignment = BoxContainer.ALIGNMENT_CENTER
    var titulo := T.sobrancelha("Poder de Luta")
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    numeros.add_child(titulo)
    _poder = T.rotulo_simples("0", 34, T.OURO_FORTE)
    _poder.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _poder.add_theme_font_override("font", T.fonte_display())
    numeros.add_child(_poder)
    caixa.add_child(numeros)
    return caixa


## O risco de secao do conceito: fio dourado com losango no meio.
func _divisoria() -> Control:
    var c := Control.new()
    c.custom_minimum_size.y = 12.0
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.draw.connect(func() -> void:
        var y := c.size.y * 0.5
        var meio := c.size.x * 0.5
        var cor := Color(T.OURO.r, T.OURO.g, T.OURO.b, 0.45)
        c.draw_line(Vector2(0, y), Vector2(meio - 9.0, y), cor, 1.0, true)
        c.draw_line(Vector2(meio + 9.0, y), Vector2(c.size.x, y), cor, 1.0, true)
        c.draw_colored_polygon(PackedVector2Array([
            Vector2(meio, y - 4.0), Vector2(meio + 4.0, y),
            Vector2(meio, y + 4.0), Vector2(meio - 4.0, y)]), T.OURO_FORTE))
    c.resized.connect(c.queue_redraw)
    return c


func _arte(caminho: String, lado: float) -> TextureRect:
    var t := TextureRect.new()
    if caminho != "" and ResourceLoader.exists(caminho):
        t.texture = load(caminho)
    t.custom_minimum_size = Vector2(lado, lado)
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return t


func _botao_redondo(icone: String, lado: float) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(lado, lado)
    b.focus_mode = Control.FOCUS_NONE
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.05, 0.09, 0.18, 0.94)
    e.border_color = T.OURO
    e.set_border_width_all(2)
    e.set_corner_radius_all(int(lado * 0.5))
    b.add_theme_stylebox_override("normal", e)
    b.add_theme_stylebox_override("hover", e)
    b.add_theme_stylebox_override("pressed", e)
    b.add_theme_stylebox_override("focus", e)
    var img := _arte(icone, lado - 20.0)
    img.set_anchors_preset(Control.PRESET_FULL_RECT)
    img.offset_left = 10.0
    img.offset_top = 10.0
    img.offset_right = -10.0
    img.offset_bottom = -10.0
    b.add_child(img)
    return b


# --------------------------------------------------------------------- estado

func _escolher_aba(id: String) -> void:
    if id == "talentos":
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("abrir"):
            casca.abrir("talentos")
        return
    _aba = id
    _mostrando_atributos = false
    _pintar()


func _alternar_detalhes() -> void:
    _mostrando_atributos = not _mostrando_atributos
    _pintar()


func _alternar_trilha() -> void:
    var trilha := get_node_or_null("/root/Trilha")
    if trilha and trilha.has_method("ligar"):
        trilha.ligar(not bool(trilha.get("tocando")))


func _pintar() -> void:
    if _progresso == null:
        return
    var stats: Dictionary = _progresso.estatisticas()

    _nome.text = "Akles"
    _papel.text = "Maestro da Vigília"
    _poder.text = _milhar(int(_progresso.poder_de_luta_da_conta()))
    _claves.text = _milhar(_progresso.quantidade("claves"))
    _pintar_estrelas()
    _pintar_nivel()
    _pintar_arma()
    _pintar_materiais()
    _pintar_acao()
    _pintar_abas()
    _pintar_miolo(stats)


## CINCO ESTRELAS, CINCO ASCENSOES. O conceito pede cinco estrelas e o jogo tem
## cinco marcos de maestria — 10, 20, 30, 40 e 60. Amarrar uma coisa na outra e
## o que impede a estrela de virar enfeite: ela acende quando voce passou o
## marco, e nao porque o desenho tinha cinco.
func _pintar_estrelas() -> void:
    for velha in _estrelas.get_children():
        _estrelas.remove_child(velha)
        velha.queue_free()
    for marco in MARCOS:
        var acesa: bool = int(_progresso.nivel) >= int(marco)
        var estrela := Control.new()
        estrela.custom_minimum_size = Vector2(22, 22)
        estrela.mouse_filter = Control.MOUSE_FILTER_IGNORE
        estrela.tooltip_text = "Nível %d" % marco
        estrela.draw.connect(func() -> void:
            _desenhar_estrela(estrela, 9.5,
                T.OURO_FORTE if acesa else Color(0.30, 0.34, 0.44)))
        _estrelas.add_child(estrela)


func _desenhar_estrela(no: Control, raio: float, cor: Color) -> void:
    var centro := no.size * 0.5
    var pontos := PackedVector2Array()
    for i in 10:
        var r: float = raio if i % 2 == 0 else raio * 0.44
        var a: float = -PI * 0.5 + PI * float(i) / 5.0
        pontos.append(centro + Vector2(cos(a), sin(a)) * r)
    no.draw_colored_polygon(pontos, cor)


func _pintar_nivel() -> void:
    var teto: int = int(_progresso.NIVEL_MAXIMO)
    _nivel.text = "Nível %d / %d" % [_progresso.nivel, teto]
    var falta: float = maxf(float(_progresso.xp_para_nivel()), 1.0)
    _xp.text = "%s / %s" % [_milhar(_progresso.experiencia), _milhar(int(falta))]
    _barra.value = clampf(float(_progresso.experiencia) / falta, 0.0, 1.0) * _barra.max_value


func _pintar_arma() -> void:
    for velho in _cartao_arma.get_children():
        _cartao_arma.remove_child(velho)
        velho.queue_free()
    _cartao_arma.add_child(T.rotulo_simples("Espadachim da Harmonia", 15, T.CREME))
    _cartao_arma.add_child(T.rotulo_simples(
        String(_progresso.arma_equipada), 14, T.TEXTO_FRACO))
    _cartao_arma.add_child(T.rotulo_simples(
        "Nível da Arma %d" % int(_progresso.nivel_da_arma), 14, T.SOBRANCELHA))


## Os quatro quadros do conceito mostram o que a PROXIMA ascensao cobra. Quando
## nao ha ascensao pendente, eles mostram o que a proxima trava vai pedir — e
## nunca um quadro vazio inventado so para fechar a fileira de quatro.
func _pintar_materiais() -> void:
    for velho in _materiais.get_children():
        _materiais.remove_child(velho)
        velho.queue_free()
    var pedidos: Dictionary = _progresso.requisitos_da_ascensao()
    if pedidos.is_empty():
        for trava in _progresso.TRAVAS_DE_ASCENSAO:
            if int(_progresso.nivel) < int(trava):
                pedidos = (_progresso.REQUISITOS_ASCENSAO.get(trava, {}) as Dictionary)
                break
    if pedidos.is_empty():
        _materiais.add_child(T.rotulo_simples(
            "Nenhuma ascensão pendente.", 15, T.TEXTO_FRACO))
        return
    for id in pedidos:
        _materiais.add_child(_quadro_de_material(String(id), int(pedidos[id])))


func _quadro_de_material(id: String, quanto: int) -> Control:
    var tem: int = _progresso.quantidade(id)
    var caixa := VBoxContainer.new()
    caixa.add_theme_constant_override("separation", 2)

    var moldura := Panel.new()
    moldura.custom_minimum_size = Vector2(52, 52)
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.04, 0.07, 0.14, 0.95)
    e.border_color = T.OURO if tem >= quanto else T.BRONZE
    e.set_border_width_all(2)
    e.set_corner_radius_all(6)
    moldura.add_theme_stylebox_override("panel", e)

    var arte := ""
    for dados in CATALOGO.ITENS_DE_RECURSO:
        if String(dados[0]) == id:
            var caminho := String(dados[2])
            arte = caminho if caminho.begins_with("res://") \
                else "res://textures/ui/kit/%s.png" % caminho
            break
    var img := _arte(arte, 46.0)
    img.set_anchors_preset(Control.PRESET_FULL_RECT)
    img.offset_left = 9.0
    img.offset_top = 9.0
    img.offset_right = -9.0
    img.offset_bottom = -9.0
    moldura.add_child(img)
    caixa.add_child(moldura)

    var conta := T.rotulo_simples("%d / %d" % [tem, quanto], 15,
        T.GANHO if tem >= quanto else T.TEXTO_FRACO)
    conta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caixa.add_child(conta)
    return caixa


func _pintar_acao() -> void:
    if _progresso.esta_em_trava_de_ascensao():
        _acao.text = "ASCENDER"
        _acao.disabled = not _progresso.pode_pagar(_progresso.requisitos_da_ascensao())
    elif _progresso.pode_subir_nivel():
        _acao.text = "SUBIR DE NÍVEL"
        _acao.disabled = false
    else:
        _acao.text = "ASCENDER"
        _acao.disabled = true


func _agir() -> void:
    if _progresso.esta_em_trava_de_ascensao():
        _progresso.tentar_ascensao()
    else:
        _progresso.subir_nivel()


func _pintar_abas() -> void:
    for id in _botoes_aba:
        var b: Button = _botoes_aba[id]
        var escolhida: bool = String(id) == _aba
        var placa := b.get_node_or_null("Placa") as Panel
        if placa:
            var e := StyleBoxFlat.new()
            e.bg_color = Color(0.09, 0.16, 0.30, 0.95) if escolhida \
                else Color(0.03, 0.05, 0.10, 0.60)
            e.border_color = T.OURO_FORTE if escolhida else Color(0.24, 0.30, 0.40, 0.7)
            e.set_border_width_all(2 if escolhida else 1)
            e.set_corner_radius_all(6)
            placa.add_theme_stylebox_override("panel", e)
        var rotulo := b.find_child("Rotulo", true, false) as Label
        if rotulo:
            rotulo.add_theme_color_override("font_color",
                T.OURO_FORTE if escolhida else T.CREME)
        var seta := b.find_child("Seta", true, false) as Label
        if seta:
            seta.visible = escolhida


func _pintar_miolo(stats: Dictionary) -> void:
    for velho in _miolo.get_children():
        _miolo.remove_child(velho)
        velho.queue_free()
    match _aba:
        "arma": _miolo_da_arma()
        "acessorios": _miolo_dos_acessorios()
        "perfil": _miolo_do_perfil()
        _:
            if _mostrando_atributos:
                _miolo_dos_atributos()
            else:
                _miolo_das_estatisticas(stats)
    _botao_detalhes.visible = _aba == "atributos"
    _botao_detalhes.text = "Ver estatísticas" if _mostrando_atributos else "Detalhes"


func _miolo_das_estatisticas(stats: Dictionary) -> void:
    for dados in ESTATISTICAS:
        var chave := String(dados[0])
        var valor: float = float(stats.get(chave, 0))
        # Formatar PRIMEIRO, trocar o ponto pela virgula DEPOIS. Ao contrario, o
        # `.replace` corria na mascara e "%.1f%%" virava "%,1f%%" — que nao e
        # formato nenhum e ia escrito assim para a tela.
        var texto: String = _milhar(int(valor))
        if chave in ["critico", "dano_critico"]:
            texto = ("%.1f" % valor).replace(".", ",") + "%"
        _miolo.add_child(_linha_de_numero(String(dados[2]), String(dados[1]), texto))


func _linha_de_numero(icone: String, titulo: String, valor: String) -> Control:
    var fila := HBoxContainer.new()
    fila.custom_minimum_size.y = 32.0
    fila.add_theme_constant_override("separation", 10)
    var marca := Control.new()
    marca.custom_minimum_size = Vector2(24, 24)
    marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
    marca.draw.connect(func(): _desenhar_icone(marca, icone))
    fila.add_child(marca)
    var t := T.rotulo_simples(titulo, 19, T.TEXTO)
    t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila.add_child(t)
    var v := T.rotulo_simples(valor, 20, T.CREME)
    v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fila.add_child(v)
    return fila


## OS SEIS ICONES SAO DESENHADOS.
##
## Nao ha coracao, escudo nem raio no kit, e escrever o simbolo num Label
## dependeria de a fonte ter o glifo — a padrao nao tem, e foi assim que o botao
## de fechar virou um quadrado vazio. Seis formas simples resolvem sem arte nova
## e sem risco de tofu.
func _desenhar_icone(no: Control, qual: String) -> void:
    var c := no.size * 0.5
    var cor := T.OURO
    match qual:
        "coracao":
            no.draw_circle(c + Vector2(-4, -2), 5.0, cor)
            no.draw_circle(c + Vector2(4, -2), 5.0, cor)
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-8.6, 0), c + Vector2(8.6, 0), c + Vector2(0, 10)]), cor)
        "espada":
            no.draw_line(c + Vector2(-6, 8), c + Vector2(6, -8), cor, 2.6, true)
            no.draw_line(c + Vector2(-5, -1), c + Vector2(1, 5), cor, 2.2, true)
        "escudo":
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-8, -8), c + Vector2(8, -8),
                c + Vector2(8, 1), c + Vector2(0, 10), c + Vector2(-8, 1)]), cor)
        "estrela":
            _desenhar_estrela(no, 9.0, cor)
        "estouro":
            for i in 8:
                var a: float = TAU * float(i) / 8.0
                no.draw_line(c + Vector2(cos(a), sin(a)) * 3.0,
                    c + Vector2(cos(a), sin(a)) * 9.5, cor, 2.0, true)
        _:
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(0, -9), c + Vector2(8, 0),
                c + Vector2(0, 9), c + Vector2(-8, 0)]), cor)


func _miolo_dos_atributos() -> void:
    _miolo.add_child(T.rotulo_simples(
        "%d ponto(s) a distribuir" % int(_progresso.pontos_de_atributo), 16,
        T.GANHO if int(_progresso.pontos_de_atributo) > 0 else T.TEXTO_FRACO))
    for id in ATRIBUTOS:
        var fila := HBoxContainer.new()
        fila.custom_minimum_size.y = 42.0
        fila.add_theme_constant_override("separation", 10)
        var nome := T.rotulo_simples(String(ATRIBUTOS[id]), 19, T.TEXTO)
        nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        fila.add_child(nome)
        var valor := T.rotulo_simples(str(_progresso.valor_atributo(String(id))), 20, T.CREME)
        valor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        fila.add_child(valor)
        var mais := T.botao("+", T.SECUNDARIO, 34.0)
        mais.custom_minimum_size.x = 40.0
        mais.disabled = int(_progresso.pontos_de_atributo) <= 0
        mais.pressed.connect(func(): _progresso.investir_atributo(String(id)))
        fila.add_child(mais)
        _miolo.add_child(fila)


func _miolo_da_arma() -> void:
    _miolo.add_child(T.sobrancelha("Arma equipada"))
    _miolo.add_child(T.rotulo_simples(String(_progresso.arma_equipada), 24, T.CREME))
    _miolo.add_child(_linha_de_numero("espada", "Nível da Arma",
        str(int(_progresso.nivel_da_arma))))
    _miolo.add_child(_linha_de_numero("losango", "Poder que ela soma",
        _milhar(int(_progresso.nivel_da_arma) * 75 + 125)))
    _miolo.add_child(T.espaco(6))
    _miolo.add_child(T.rotulo(
        "A Espada do Despertar é a única arma do jogo por enquanto. Subir o nível "
        + "dela ainda não tem receita — quando tiver, o botão nasce aqui.",
        T.CORPO, T.TEXTO_FRACO, true))


func _miolo_dos_acessorios() -> void:
    _miolo.add_child(T.sobrancelha("Acessórios de ressonância"))
    for slot in _progresso.SLOTS_ACESSORIOS:
        var id := String(_progresso.acessorios_equipados.get(slot, ""))
        var ficha: Dictionary = _progresso.ACESSORIOS.get(id, {})
        var fila := HBoxContainer.new()
        fila.custom_minimum_size.y = 44.0
        fila.add_theme_constant_override("separation", 10)
        var nome := T.rotulo_simples(String(slot), 17, T.SOBRANCELHA)
        nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        nome.custom_minimum_size.x = 110.0
        fila.add_child(nome)
        var conteudo := T.rotulo_simples(
            String(ficha.get("nome", "vazio")), 18,
            T.RARIDADE.get(String(ficha.get("raridade", "")), T.TEXTO_FRACO))
        conteudo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        fila.add_child(conteudo)
        _miolo.add_child(fila)


func _miolo_do_perfil() -> void:
    _miolo.add_child(T.sobrancelha("Trilha de maestria"))
    var fila := HBoxContainer.new()
    fila.add_theme_constant_override("separation", 8)
    for marco in MARCOS:
        var passou: bool = int(_progresso.nivel) >= int(marco)
        var chip := T.chip(str(marco), T.OURO_FORTE if passou else T.TEXTO_FRACO)
        fila.add_child(chip)
    _miolo.add_child(fila)
    _miolo.add_child(T.espaco(4))
    _miolo.add_child(_linha_de_numero("losango", "Ascensão do nível 20",
        "feita" if bool(_progresso.ascensoes.get(20, false)) else "pendente"))
    _miolo.add_child(_linha_de_numero("losango", "Ascensão do nível 40",
        "feita" if bool(_progresso.ascensoes.get(40, false)) else "pendente"))
    _miolo.add_child(T.espaco(4))
    _miolo.add_child(T.sobrancelha("Marcos da história"))
    var vividos := 0
    for chave in _progresso.marcos:
        if bool(_progresso.marcos[chave]):
            vividos += 1
    _miolo.add_child(T.rotulo_simples(
        "%d marco(s) vivido(s)" % vividos, 18, T.TEXTO))


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
