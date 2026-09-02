extends Control
class_name PaginaPersonagem

## A FICHA DO PERSONAGEM — NADA DE PAINEL.
##
## A tentativa anterior era tres paineis lado a lado, e era por isso que nao
## batia com o conceito. No desenho aprovado nao existe caixa nenhuma: o heroi
## ocupa o fundo de ponta a ponta e TUDO flutua por cima dele. O menu da esquerda
## nao tem moldura — so o item escolhido ganha um esmaecido azul que sai pela
## borda. A coluna da direita nao tem fundo: e texto sobre o cenario, com dois
## filetes finos isolando o bloco de nivel. O unico bloco com fundo na tela
## inteira e o cartao da arma, embaixo a esquerda.
##
## Era o pedido antigo do dono, que eu tinha ouvido e nao aplicado: "menos
## blocos e mais transparencias, sem barras separando".
##
## O personagem no meio e a ARTE DE CONCEITO, nao o modelo 3D. Ela ja estava no
## projeto servindo a caixa de dialogo, tem fundo transparente e e exatamente o
## desenho do conceito. Um SubViewport com luz e camera propria para mostrar
## parado o que uma imagem mostra melhor era custo sem ganho — ainda mais num
## celular que ja carrega o mundo inteiro atras desta tela.

const T := preload("res://scripts/ui_tema.gd")
const CATALOGO := preload("res://scripts/inventory_ui.gd")

## O cenario do conceito. O de estrelas com o circulo magico e o certo; o salao
## antigo fica como reserva enquanto ele nao entra no projeto.
const FUNDO := "res://textures/ui/concepts/personagem-bg.png"
const FUNDO_RESERVA := "res://textures/ui/concepts/character-stage-bg.png"
const CORPO := "res://textures/dialogo/akles_corpo.png"

const OURO := Color("d4af37")
const OURO_CLARO := Color("f3e5ab")
const AZUL_ATIVO := Color("3b82f6")

const ABAS := [
    ["atributos", "Atributos"], ["arma", "Arma"], ["acessorios", "Acessórios"],
    ["talentos", "Talentos"], ["perfil", "Perfil"],
]
const ESTATISTICAS := [
    ["vida_maxima", "Vida Máxima", "coracao", Color("4ade80")],
    ["ataque", "Ataque", "espada", Color("f87171")],
    ["defesa", "Defesa", "escudo", Color("60a5fa")],
    ["critico", "Chance Crítica", "raio", Color("facc15")],
    ["dano_critico", "Dano Crítico", "estouro", Color("fb923c")],
    ["poder_harmonico", "Poder Harmônico", "losango", Color("c084fc")],
]
const ATRIBUTOS := {"forca": "Força", "destreza": "Destreza",
    "vitalidade": "Vitalidade", "ressonancia": "Ressonância",
    "percepcao": "Percepção"}
## Os cinco degraus da trilha de maestria. Sao eles que acendem as estrelas.
const MARCOS := [10, 20, 30, 40, 60]
## Quantos discos a fileira de heróis mostra. Dois estao jogaveis; o resto sao
## lugares vazios e apagados, como no desenho — nao personagens fingidos.
const LUGARES_DE_HEROI := 10

var _progresso: Node
var _aba := "atributos"
var _mostrando_atributos := false
var _botoes_aba: Dictionary = {}

var _nome: Label
var _estrelas: HBoxContainer
var _poder: Label
var _nivel: Label
var _xp: Label
var _barra_cheia: ColorRect
var _miolo: VBoxContainer
var _botao_detalhes: Button
var _materiais: HBoxContainer
var _claves: Label
var _acao: Button
var _cartao_arma: VBoxContainer


## A casca le este metodo para ceder a tela inteira: sem cabecalho dela, sem
## margem. O topo desta pagina e desenhado aqui dentro.
func desenha_o_proprio_topo() -> bool:
    return true


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)


func ao_abrir() -> void:
    _pintar()


# ------------------------------------------------------------------ montagem

func _montar() -> void:
    _montar_cenario()
    _montar_topo()
    _montar_menu()
    _montar_coluna_direita()
    _montar_rodape_esquerdo()


## O cenario e o heroi, os dois de ponta a ponta e sem tocar em nada.
func _montar_cenario() -> void:
    var fundo := TextureRect.new()
    var caminho := FUNDO if ResourceLoader.exists(FUNDO) else FUNDO_RESERVA
    if ResourceLoader.exists(caminho):
        fundo.texture = load(caminho)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fundo)

    # O CORPO ANCORA PELO PE, NAO PELO CENTRO.
    #
    # O circulo magico do cenario esta no rodape da imagem. Centrar o heroi na
    # vertical o deixaria pairando acima dele em qualquer tela mais alta que
    # 16:9. Ancorado embaixo, os pes caem no circulo em toda proporcao.
    var heroi := TextureRect.new()
    if ResourceLoader.exists(CORPO):
        heroi.texture = load(CORPO)
    heroi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    heroi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    heroi.anchor_left = 0.5
    heroi.anchor_right = 0.5
    heroi.anchor_top = 0.0
    heroi.anchor_bottom = 1.0
    heroi.offset_left = -300.0
    heroi.offset_right = 300.0
    heroi.offset_top = 40.0
    heroi.offset_bottom = -56.0
    heroi.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(heroi)


func _montar_topo() -> void:
    var topo := Control.new()
    topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
    topo.offset_top = 18.0
    topo.offset_bottom = 92.0
    topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(topo)

    # --- emblema e titulo, a esquerda
    var titulo := HBoxContainer.new()
    titulo.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    titulo.offset_left = 30.0
    titulo.add_theme_constant_override("separation", 14)
    titulo.alignment = BoxContainer.ALIGNMENT_CENTER
    titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    topo.add_child(titulo)
    titulo.add_child(_disco_com_lira(54.0))
    var letra := T.rotulo_simples("PERSONAGEM", 30, OURO_CLARO)
    letra.add_theme_font_override("font", T.fonte_display())
    letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    titulo.add_child(letra)

    # --- a fileira de herois, centrada
    var fileira := HBoxContainer.new()
    fileira.set_anchors_preset(Control.PRESET_CENTER)
    fileira.grow_horizontal = Control.GROW_DIRECTION_BOTH
    fileira.grow_vertical = Control.GROW_DIRECTION_BOTH
    fileira.add_theme_constant_override("separation", 10)
    topo.add_child(fileira)
    for i in LUGARES_DE_HEROI:
        fileira.add_child(_disco_de_heroi(i))

    # --- fechar, a direita
    var fechar := Button.new()
    fechar.custom_minimum_size = Vector2(42, 42)
    fechar.focus_mode = Control.FOCUS_NONE
    fechar.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
    fechar.offset_left = -72.0
    fechar.offset_right = -30.0
    fechar.offset_top = -21.0
    fechar.offset_bottom = 21.0
    var aro := StyleBoxFlat.new()
    aro.bg_color = Color(0.02, 0.03, 0.07, 0.55)
    aro.border_color = OURO
    aro.set_border_width_all(1)
    aro.set_corner_radius_all(21)
    fechar.add_theme_stylebox_override("normal", aro)
    fechar.add_theme_stylebox_override("hover", aro)
    fechar.add_theme_stylebox_override("pressed", aro)
    fechar.add_theme_stylebox_override("focus", aro)
    var xis := Control.new()
    xis.set_anchors_preset(Control.PRESET_FULL_RECT)
    xis.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # O "X" e desenhado: a fonte padrao do motor nao tem o glifo, e foi por isso
    # que o fechar ja apareceu como quadrado vazio uma vez.
    xis.draw.connect(func() -> void:
        var c := xis.size * 0.5
        xis.draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), OURO, 2.0, true)
        xis.draw_line(c + Vector2(7, -7), c + Vector2(-7, 7), OURO, 2.0, true))
    fechar.add_child(xis)
    fechar.pressed.connect(func():
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("fechar_tudo"):
            casca.fechar_tudo())
    topo.add_child(fechar)


func _disco_com_lira(lado: float) -> Control:
    var disco := Panel.new()
    disco.custom_minimum_size = Vector2(lado, lado)
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.06, 0.12, 0.28, 0.55)
    e.border_color = OURO
    e.set_border_width_all(1)
    e.set_corner_radius_all(int(lado * 0.5))
    disco.add_theme_stylebox_override("panel", e)
    disco.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var lira := TextureRect.new()
    if ResourceLoader.exists("res://textures/ui/kit/nav/lira.png"):
        lira.texture = load("res://textures/ui/kit/nav/lira.png")
    lira.set_anchors_preset(Control.PRESET_FULL_RECT)
    lira.offset_left = 12.0
    lira.offset_top = 12.0
    lira.offset_right = -12.0
    lira.offset_bottom = -12.0
    lira.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    lira.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    lira.mouse_filter = Control.MOUSE_FILTER_IGNORE
    disco.add_child(lira)
    return disco


## DEZ LUGARES, DOIS OCUPADOS.
##
## O desenho tem dez retratos. O jogo tem Akles e Wins — os outros oito ficam
## como lugares vazios e apagados, que e o que eles sao. Encher a fileira com
## rosto de personagem que nao existe seria enfeite passando por conteudo.
func _disco_de_heroi(indice: int) -> Control:
    var e_o_akles: bool = indice == 4
    var e_a_wins: bool = indice == 5
    var lado: float = 62.0 if e_o_akles else 48.0

    var b := Button.new()
    b.custom_minimum_size = Vector2(lado, lado)
    b.focus_mode = Control.FOCUS_NONE
    b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.08, 0.10, 0.16, 0.75)
    e.border_color = OURO if e_o_akles else Color(0.45, 0.48, 0.55, 0.85)
    e.set_border_width_all(2 if e_o_akles else 1)
    e.set_corner_radius_all(int(lado * 0.5))
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(estado, e)
    b.disabled = not (e_o_akles or e_a_wins)
    b.modulate.a = 1.0 if e_o_akles else (0.85 if e_a_wins else 0.45)

    if e_o_akles or e_a_wins:
        var folha := "res://textures/dialogo/akles_corpo.png" if e_o_akles \
            else "res://personagem/wins_retrato.png"
        if ResourceLoader.exists(folha):
            var recorte := Control.new()
            recorte.set_anchors_preset(Control.PRESET_FULL_RECT)
            recorte.offset_left = 3.0
            recorte.offset_top = 3.0
            recorte.offset_right = -3.0
            recorte.offset_bottom = -3.0
            recorte.clip_contents = true
            recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
            b.add_child(recorte)
            var rosto := TextureRect.new()
            var arte: Texture2D = load(folha)
            if e_o_akles:
                # So a cabeca, medida na arte de corpo inteiro.
                var corte := AtlasTexture.new()
                corte.atlas = arte
                corte.region = Rect2(arte.get_width() * 0.36, arte.get_height() * 0.015,
                    arte.get_width() * 0.28, arte.get_height() * 0.135)
                rosto.texture = corte
            else:
                rosto.texture = arte
            rosto.set_anchors_preset(Control.PRESET_FULL_RECT)
            rosto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            rosto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
            rosto.mouse_filter = Control.MOUSE_FILTER_IGNORE
            recorte.add_child(rosto)
        b.tooltip_text = "Akles" if e_o_akles else "Wins"
    return b


## O MENU FLUTUA. Sem painel, sem moldura: so o item escolhido ganha o esmaecido
## azul saindo pela borda esquerda, como no desenho.
func _montar_menu() -> void:
    var menu := VBoxContainer.new()
    menu.set_anchors_preset(Control.PRESET_CENTER_LEFT)
    menu.grow_vertical = Control.GROW_DIRECTION_BOTH
    menu.offset_left = 30.0
    menu.offset_right = 300.0
    menu.add_theme_constant_override("separation", 4)
    add_child(menu)
    for dados in ABAS:
        var b := _item_de_menu(String(dados[0]), String(dados[1]))
        menu.add_child(b)
        _botoes_aba[String(dados[0])] = b


func _item_de_menu(id: String, texto: String) -> Button:
    var b := Button.new()
    b.custom_minimum_size.y = 56.0
    b.focus_mode = Control.FOCUS_NONE
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    b.pressed.connect(_escolher_aba.bind(id))

    # O esmaecido do item ativo: azul na esquerda que some para a direita, com o
    # filete vertical na borda. Desenhado, porque um degrade em StyleBoxFlat nao
    # existe e uma textura para isso seria arquivo a mais no pacote.
    var brilho := Control.new()
    brilho.name = "Brilho"
    brilho.set_anchors_preset(Control.PRESET_FULL_RECT)
    brilho.offset_left = -34.0
    brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
    brilho.visible = false
    brilho.draw.connect(func() -> void:
        var passos := 22
        for i in passos:
            var f := float(i) / float(passos)
            var x := brilho.size.x * f
            var largura := brilho.size.x / float(passos) + 1.0
            brilho.draw_rect(Rect2(x, 0.0, largura, brilho.size.y),
                Color(0.23, 0.42, 0.85, 0.42 * (1.0 - f)))
        brilho.draw_rect(Rect2(0.0, 0.0, 4.0, brilho.size.y), Color(0.38, 0.65, 1.0, 0.95)))
    brilho.resized.connect(brilho.queue_redraw)
    b.add_child(brilho)

    var fila := HBoxContainer.new()
    fila.set_anchors_preset(Control.PRESET_FULL_RECT)
    fila.offset_left = 12.0
    fila.add_theme_constant_override("separation", 14)
    fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(fila)

    var marca := Control.new()
    marca.custom_minimum_size = Vector2(26, 26)
    marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
    marca.name = "Marca"
    marca.draw.connect(func(): _desenhar_icone(marca, id,
        Color(0.75, 0.85, 1.0) if id == _aba else Color(0.60, 0.65, 0.74)))
    fila.add_child(marca)

    var rotulo := T.rotulo_simples(texto, 23, T.CREME)
    rotulo.name = "Rotulo"
    rotulo.add_theme_font_override("font", T.fonte_display())
    rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fila.add_child(rotulo)
    return b


## A COLUNA DA DIREITA TAMBEM FLUTUA. Nenhum fundo: texto sobre o cenario, com
## dois filetes finos isolando o bloco de nivel — e so.
func _montar_coluna_direita() -> void:
    var coluna := VBoxContainer.new()
    coluna.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
    coluna.offset_left = -390.0
    coluna.offset_right = -30.0
    coluna.offset_top = 112.0
    coluna.offset_bottom = -104.0
    coluna.add_theme_constant_override("separation", 5)
    add_child(coluna)

    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 10)
    coluna.add_child(topo)

    var ident := VBoxContainer.new()
    ident.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ident.add_theme_constant_override("separation", 3)
    topo.add_child(ident)
    _nome = T.rotulo_simples("Akles", 40, Color.WHITE)
    _nome.add_theme_font_override("font", T.fonte_display())
    ident.add_child(_nome)
    _estrelas = HBoxContainer.new()
    _estrelas.add_theme_constant_override("separation", 3)
    ident.add_child(_estrelas)

    var lado := VBoxContainer.new()
    lado.add_theme_constant_override("separation", 1)
    lado.alignment = BoxContainer.ALIGNMENT_END
    var rotulo_poder := T.rotulo_simples("PODER DE LUTA", 13, Color(0.62, 0.67, 0.76))
    rotulo_poder.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    lado.add_child(rotulo_poder)
    _poder = T.rotulo_simples("0", 32, OURO)
    _poder.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _poder.add_theme_font_override("font", T.fonte_display())
    lado.add_child(_poder)
    topo.add_child(lado)

    var harmonia := T.rotulo_simples("Poder da Harmonia", 15, Color(0.62, 0.67, 0.76))
    coluna.add_child(harmonia)
    coluna.add_child(T.espaco(4))

    # --- bloco de nivel, entre dois filetes
    coluna.add_child(_filete())
    coluna.add_child(T.espaco(3))
    var fila_nivel := HBoxContainer.new()
    fila_nivel.add_theme_constant_override("separation", 8)
    _nivel = T.rotulo_simples("", 22, Color.WHITE)
    _nivel.add_theme_font_override("font", T.fonte_display())
    _nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila_nivel.add_child(_nivel)
    _xp = T.rotulo_simples("", 15, Color(0.62, 0.67, 0.76))
    _xp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fila_nivel.add_child(_xp)
    coluna.add_child(fila_nivel)

    var trilho := ColorRect.new()
    trilho.color = Color(0.10, 0.12, 0.18, 0.9)
    trilho.custom_minimum_size.y = 6.0
    coluna.add_child(trilho)
    _barra_cheia = ColorRect.new()
    _barra_cheia.color = Color(0.38, 0.65, 0.98)
    _barra_cheia.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    _barra_cheia.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trilho.add_child(_barra_cheia)
    coluna.add_child(T.espaco(3))
    coluna.add_child(_filete())
    coluna.add_child(T.espaco(4))

    _miolo = VBoxContainer.new()
    _miolo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _miolo.add_theme_constant_override("separation", 1)
    coluna.add_child(_miolo)

    _botao_detalhes = _botao_de_contorno("Detalhes")
    _botao_detalhes.pressed.connect(_alternar_detalhes)
    coluna.add_child(_botao_detalhes)
    coluna.add_child(T.espaco(6))

    coluna.add_child(T.rotulo_simples("MATERIAIS DE ASCENSÃO", 13,
        Color(0.62, 0.67, 0.76)))
    _materiais = HBoxContainer.new()
    _materiais.add_theme_constant_override("separation", 10)
    coluna.add_child(_materiais)
    coluna.add_child(T.espaco(6))

    var rodape := HBoxContainer.new()
    rodape.add_theme_constant_override("separation", 12)
    var moeda := HBoxContainer.new()
    moeda.add_theme_constant_override("separation", 6)
    var disco_moeda := Panel.new()
    disco_moeda.custom_minimum_size = Vector2(22, 22)
    disco_moeda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var em := StyleBoxFlat.new()
    em.bg_color = OURO
    em.set_corner_radius_all(11)
    disco_moeda.add_theme_stylebox_override("panel", em)
    moeda.add_child(disco_moeda)
    _claves = T.rotulo_simples("0", 17, Color.WHITE)
    _claves.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    moeda.add_child(_claves)
    rodape.add_child(moeda)

    _acao = _botao_dourado("ASCENDER")
    _acao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _acao.pressed.connect(_agir)
    rodape.add_child(_acao)
    coluna.add_child(rodape)


func _filete() -> Control:
    var f := ColorRect.new()
    f.color = Color(0.35, 0.39, 0.47, 0.42)
    f.custom_minimum_size.y = 1.0
    f.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return f


func _botao_de_contorno(texto: String) -> Button:
    var b := Button.new()
    b.text = texto
    b.custom_minimum_size.y = 34.0
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_override("font", T.fonte_ui())
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_color_override("font_color", Color(0.85, 0.88, 0.93))
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.05, 0.07, 0.12, 0.55)
    e.border_color = Color(0.45, 0.49, 0.57, 0.9)
    e.set_border_width_all(1)
    e.set_corner_radius_all(17)
    for estado in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(estado, e)
    return b


func _botao_dourado(texto: String) -> Button:
    var b := Button.new()
    b.text = texto
    b.custom_minimum_size.y = 44.0
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_override("font", T.fonte_display())
    b.add_theme_font_size_override("font_size", 20)
    b.add_theme_color_override("font_color", Color(0.10, 0.08, 0.02))
    b.add_theme_color_override("font_disabled_color", Color(0.30, 0.27, 0.18))
    var e := StyleBoxFlat.new()
    e.bg_color = OURO
    e.border_color = OURO_CLARO
    e.set_border_width_all(1)
    e.set_corner_radius_all(22)
    b.add_theme_stylebox_override("normal", e)
    b.add_theme_stylebox_override("hover", e)
    b.add_theme_stylebox_override("pressed", e)
    b.add_theme_stylebox_override("focus", e)
    var apagado := e.duplicate() as StyleBoxFlat
    apagado.bg_color = Color(0.34, 0.30, 0.18, 0.75)
    apagado.border_color = Color(0.45, 0.40, 0.25, 0.6)
    b.add_theme_stylebox_override("disabled", apagado)
    return b


## O unico bloco com fundo da tela inteira, como no desenho.
func _montar_rodape_esquerdo() -> void:
    var canto := HBoxContainer.new()
    canto.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    canto.grow_vertical = Control.GROW_DIRECTION_BEGIN
    canto.offset_left = 30.0
    canto.offset_top = -96.0
    canto.offset_bottom = -22.0
    canto.add_theme_constant_override("separation", 20)
    add_child(canto)

    var musicas := VBoxContainer.new()
    musicas.add_theme_constant_override("separation", 2)
    musicas.alignment = BoxContainer.ALIGNMENT_CENTER
    var disco := Button.new()
    disco.custom_minimum_size = Vector2(46, 46)
    disco.focus_mode = Control.FOCUS_NONE
    disco.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.05, 0.07, 0.12, 0.55)
    e.border_color = Color(0.45, 0.49, 0.57, 0.9)
    e.set_border_width_all(1)
    e.set_corner_radius_all(23)
    for estado in ["normal", "hover", "pressed", "focus"]:
        disco.add_theme_stylebox_override(estado, e)
    var lira := TextureRect.new()
    if ResourceLoader.exists("res://textures/ui/kit/nav/lira.png"):
        lira.texture = load("res://textures/ui/kit/nav/lira.png")
    lira.set_anchors_preset(Control.PRESET_FULL_RECT)
    lira.offset_left = 11.0
    lira.offset_top = 11.0
    lira.offset_right = -11.0
    lira.offset_bottom = -11.0
    lira.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    lira.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    lira.mouse_filter = Control.MOUSE_FILTER_IGNORE
    disco.add_child(lira)
    disco.pressed.connect(_alternar_trilha)
    musicas.add_child(disco)
    var rotulo := T.rotulo_simples("Músicas", 13, Color(0.62, 0.67, 0.76))
    rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    musicas.add_child(rotulo)
    canto.add_child(musicas)

    var cartao := PanelContainer.new()
    cartao.custom_minimum_size.x = 300.0
    cartao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var ec := StyleBoxFlat.new()
    ec.bg_color = Color(0.04, 0.06, 0.11, 0.72)
    ec.border_color = Color(0.40, 0.44, 0.52, 0.55)
    ec.set_border_width_all(1)
    ec.set_corner_radius_all(8)
    ec.content_margin_left = 14
    ec.content_margin_right = 14
    ec.content_margin_top = 10
    ec.content_margin_bottom = 10
    cartao.add_theme_stylebox_override("panel", ec)
    var dentro := HBoxContainer.new()
    dentro.add_theme_constant_override("separation", 12)
    cartao.add_child(dentro)
    var espada := TextureRect.new()
    if ResourceLoader.exists("res://textures/ui/kit/equip/espada.png"):
        espada.texture = load("res://textures/ui/kit/equip/espada.png")
    espada.custom_minimum_size = Vector2(38, 38)
    espada.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    espada.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    espada.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    dentro.add_child(espada)
    _cartao_arma = VBoxContainer.new()
    _cartao_arma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _cartao_arma.add_theme_constant_override("separation", 1)
    dentro.add_child(_cartao_arma)
    canto.add_child(cartao)


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
    _poder.text = _milhar(int(_progresso.poder_de_luta_da_conta()))
    _claves.text = _milhar(_progresso.quantidade("claves"))
    _pintar_estrelas()
    _pintar_nivel()
    _pintar_arma()
    _pintar_materiais()
    _pintar_acao()
    _pintar_menu()
    _pintar_miolo(_progresso.estatisticas())


func _pintar_estrelas() -> void:
    for velha in _estrelas.get_children():
        _estrelas.remove_child(velha)
        velha.queue_free()
    for marco in MARCOS:
        var acesa: bool = int(_progresso.nivel) >= int(marco)
        var estrela := Control.new()
        estrela.custom_minimum_size = Vector2(19, 19)
        estrela.mouse_filter = Control.MOUSE_FILTER_IGNORE
        estrela.tooltip_text = "Nível %d" % marco
        estrela.draw.connect(func(): _desenhar_estrela(estrela, 8.5,
            OURO if acesa else Color(0.30, 0.33, 0.40)))
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
    _nivel.text = "Nível %d / %d" % [_progresso.nivel, int(_progresso.NIVEL_MAXIMO)]
    var falta: float = maxf(float(_progresso.xp_para_nivel()), 1.0)
    _xp.text = "%s / %s" % [_milhar(_progresso.experiencia), _milhar(int(falta))]
    _barra_cheia.anchor_right = clampf(float(_progresso.experiencia) / falta, 0.0, 1.0)


func _pintar_arma() -> void:
    for velho in _cartao_arma.get_children():
        _cartao_arma.remove_child(velho)
        velho.queue_free()
    _cartao_arma.add_child(T.rotulo_simples("Espadachim da Harmonia", 16, Color.WHITE))
    _cartao_arma.add_child(T.rotulo_simples(
        String(_progresso.arma_equipada), 14, Color(0.62, 0.67, 0.76)))
    _cartao_arma.add_child(T.rotulo_simples(
        "Nível da Arma %d" % int(_progresso.nivel_da_arma), 13, Color(0.55, 0.60, 0.70)))


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
        _materiais.add_child(T.rotulo_simples("Nenhuma ascensão pendente.", 14,
            Color(0.55, 0.60, 0.70)))
        return
    for id in pedidos:
        _materiais.add_child(_quadro_de_material(String(id), int(pedidos[id])))


func _quadro_de_material(id: String, quanto: int) -> Control:
    var tem: int = _progresso.quantidade(id)
    var caixa := VBoxContainer.new()
    caixa.add_theme_constant_override("separation", 2)
    var moldura := Panel.new()
    moldura.custom_minimum_size = Vector2(54, 54)
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.07, 0.09, 0.14, 0.80)
    e.border_color = OURO if tem >= quanto else Color(0.42, 0.46, 0.54, 0.9)
    e.set_border_width_all(1)
    e.set_corner_radius_all(5)
    moldura.add_theme_stylebox_override("panel", e)
    var arte := ""
    for dados in CATALOGO.ITENS_DE_RECURSO:
        if String(dados[0]) == id:
            var caminho := String(dados[2])
            arte = caminho if caminho.begins_with("res://") \
                else "res://textures/ui/kit/%s.png" % caminho
            break
    if ResourceLoader.exists(arte):
        var img := TextureRect.new()
        img.texture = load(arte)
        img.set_anchors_preset(Control.PRESET_FULL_RECT)
        img.offset_left = 8.0
        img.offset_top = 8.0
        img.offset_right = -8.0
        img.offset_bottom = -8.0
        img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        img.mouse_filter = Control.MOUSE_FILTER_IGNORE
        moldura.add_child(img)
    caixa.add_child(moldura)
    var conta := T.rotulo_simples("%d / %d" % [tem, quanto], 14,
        Color.WHITE if tem >= quanto else Color(0.62, 0.67, 0.76))
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


func _pintar_menu() -> void:
    for id in _botoes_aba:
        var b: Button = _botoes_aba[id]
        var escolhida: bool = String(id) == _aba
        var brilho := b.get_node_or_null("Brilho") as Control
        if brilho:
            brilho.visible = escolhida
        var rotulo := b.find_child("Rotulo", true, false) as Label
        if rotulo:
            rotulo.add_theme_color_override("font_color",
                Color.WHITE if escolhida else Color(0.60, 0.65, 0.74))
        var marca := b.find_child("Marca", true, false) as Control
        if marca:
            marca.queue_redraw()


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
        var texto := _milhar(int(valor))
        if chave in ["critico", "dano_critico"]:
            texto = ("%.1f" % valor).replace(".", ",") + "%"
        _miolo.add_child(_linha(String(dados[2]), String(dados[1]), texto, dados[3]))


func _linha(icone: String, titulo: String, valor: String, cor: Color) -> Control:
    var fila := HBoxContainer.new()
    fila.custom_minimum_size.y = 31.0
    fila.add_theme_constant_override("separation", 9)
    var marca := Control.new()
    marca.custom_minimum_size = Vector2(20, 20)
    marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
    marca.draw.connect(func(): _desenhar_icone(marca, icone, cor))
    fila.add_child(marca)
    var t := T.rotulo_simples(titulo, 17, Color(0.80, 0.84, 0.90))
    t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fila.add_child(t)
    var v := T.rotulo_simples(valor, 18, Color.WHITE)
    v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fila.add_child(v)
    return fila


## Os icones sao desenhados: nao ha coracao nem escudo no kit, e escrever o
## simbolo num Label dependeria de a fonte ter o glifo — a padrao nao tem.
func _desenhar_icone(no: Control, qual: String, cor: Color) -> void:
    var c := no.size * 0.5
    var k: float = no.size.x / 26.0
    match qual:
        "coracao", "vida_maxima":
            no.draw_circle(c + Vector2(-4, -2) * k, 5.0 * k, cor)
            no.draw_circle(c + Vector2(4, -2) * k, 5.0 * k, cor)
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-8.6, 0) * k, c + Vector2(8.6, 0) * k, c + Vector2(0, 10) * k]), cor)
        "espada", "arma":
            no.draw_line(c + Vector2(-6, 8) * k, c + Vector2(6, -8) * k, cor, 2.4 * k, true)
            no.draw_line(c + Vector2(-5, -1) * k, c + Vector2(1, 5) * k, cor, 2.0 * k, true)
        "escudo":
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-8, -8) * k, c + Vector2(8, -8) * k,
                c + Vector2(8, 1) * k, c + Vector2(0, 10) * k, c + Vector2(-8, 1) * k]), cor)
        "raio":
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(2, -9) * k, c + Vector2(-6, 1) * k, c + Vector2(-1, 1) * k,
                c + Vector2(-2, 9) * k, c + Vector2(6, -1) * k, c + Vector2(1, -1) * k]), cor)
        "estouro":
            for i in 8:
                var a: float = TAU * float(i) / 8.0
                no.draw_line(c + Vector2(cos(a), sin(a)) * 3.0 * k,
                    c + Vector2(cos(a), sin(a)) * 9.5 * k, cor, 1.8 * k, true)
        "atributos":
            no.draw_arc(c, 8.0 * k, 0.0, TAU, 24, cor, 1.6 * k, true)
            no.draw_circle(c, 3.0 * k, cor)
        "acessorios":
            no.draw_arc(c, 7.5 * k, 0.0, TAU, 24, cor, 1.6 * k, true)
        "talentos":
            _desenhar_estrela(no, 9.0 * k, cor)
        "perfil":
            no.draw_circle(c + Vector2(0, -3) * k, 4.2 * k, cor)
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-7, 9) * k, c + Vector2(-5, 2) * k,
                c + Vector2(5, 2) * k, c + Vector2(7, 9) * k]), cor)
        _:
            no.draw_colored_polygon(PackedVector2Array([
                c + Vector2(0, -9) * k, c + Vector2(8, 0) * k,
                c + Vector2(0, 9) * k, c + Vector2(-8, 0) * k]), cor)


func _miolo_dos_atributos() -> void:
    _miolo.add_child(T.rotulo_simples(
        "%d ponto(s) a distribuir" % int(_progresso.pontos_de_atributo), 15,
        Color(0.49, 0.87, 0.39) if int(_progresso.pontos_de_atributo) > 0
        else Color(0.62, 0.67, 0.76)))
    for id in ATRIBUTOS:
        var fila := HBoxContainer.new()
        fila.custom_minimum_size.y = 34.0
        fila.add_theme_constant_override("separation", 9)
        var nome := T.rotulo_simples(String(ATRIBUTOS[id]), 17, Color(0.80, 0.84, 0.90))
        nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        fila.add_child(nome)
        var valor := T.rotulo_simples(str(_progresso.valor_atributo(String(id))), 18, Color.WHITE)
        valor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        fila.add_child(valor)
        var mais := _botao_de_contorno("+")
        mais.custom_minimum_size = Vector2(34, 28)
        mais.disabled = int(_progresso.pontos_de_atributo) <= 0
        mais.pressed.connect(func(): _progresso.investir_atributo(String(id)))
        fila.add_child(mais)
        _miolo.add_child(fila)


func _miolo_da_arma() -> void:
    _miolo.add_child(T.rotulo_simples(String(_progresso.arma_equipada), 21, Color.WHITE))
    _miolo.add_child(_linha("espada", "Nível da Arma",
        str(int(_progresso.nivel_da_arma)), Color("f87171")))
    _miolo.add_child(_linha("losango", "Poder que ela soma",
        _milhar(int(_progresso.nivel_da_arma) * 75 + 125), Color("c084fc")))


func _miolo_dos_acessorios() -> void:
    for slot in _progresso.SLOTS_ACESSORIOS:
        var id := String(_progresso.acessorios_equipados.get(slot, ""))
        var ficha: Dictionary = _progresso.ACESSORIOS.get(id, {})
        var fila := HBoxContainer.new()
        fila.custom_minimum_size.y = 31.0
        fila.add_theme_constant_override("separation", 9)
        var nome := T.rotulo_simples(String(slot), 15, Color(0.62, 0.67, 0.76))
        nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        nome.custom_minimum_size.x = 96.0
        fila.add_child(nome)
        var conteudo := T.rotulo_simples(String(ficha.get("nome", "vazio")), 16,
            T.RARIDADE.get(String(ficha.get("raridade", "")), Color(0.55, 0.60, 0.70)))
        conteudo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        fila.add_child(conteudo)
        _miolo.add_child(fila)


func _miolo_do_perfil() -> void:
    _miolo.add_child(_linha("talentos", "Ascensão do nível 20",
        "feita" if bool(_progresso.ascensoes.get(20, false)) else "pendente",
        Color("facc15")))
    _miolo.add_child(_linha("talentos", "Ascensão do nível 40",
        "feita" if bool(_progresso.ascensoes.get(40, false)) else "pendente",
        Color("facc15")))
    var vividos := 0
    for chave in _progresso.marcos:
        if bool(_progresso.marcos[chave]):
            vividos += 1
    _miolo.add_child(_linha("perfil", "Marcos da história", str(vividos), Color("60a5fa")))
    _miolo.add_child(_linha("losango", "Ecos descobertos",
        "%d / 12" % _progresso.ecos_descobertos.size(), Color("c084fc")))


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
