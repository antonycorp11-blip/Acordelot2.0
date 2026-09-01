extends RefCounted
class_name UiTema

## O DESIGN SYSTEM DA INTERFACE PRINCIPAL.
##
## Um lugar so para fonte, tamanho, cor, moldura e botao. Antes cada tela
## escolhia os seus: o inventario tinha um azul, os ajustes outro, a tela de
## missoes um terceiro, e cada uma inventava a propria altura de botao. E por
## isso que a interface parecia oito jogos diferentes.
##
## Quem desenha tela nova NAO escolhe numero: pede aqui.

# ---------------------------------------------------------------- a tela base
## A TELA DE PROJETO. Tudo e desenhado nestas medidas e depois escalado para o
## aparelho — e o que as telas v3 ja faziam, e agora vale para todas.
const CANVAS := Vector2(1600.0, 900.0)

# -------------------------------------------------------------------- as cores
const NAVY_FUNDO := Color(0.020, 0.035, 0.075, 0.98)
const NAVY_PAINEL := Color(0.035, 0.058, 0.105, 0.96)
const NAVY_CLARO := Color(0.070, 0.105, 0.175, 0.96)
const OURO := Color(0.85, 0.70, 0.36)
const OURO_FORTE := Color(0.97, 0.84, 0.47)
## O dourado com moderacao: aro fino, titulo e aba ativa. Nao preenchimento.
const OURO_ARO := Color(0.62, 0.50, 0.26, 0.85)
const TEXTO := Color(0.88, 0.91, 0.96)
const TEXTO_FRACO := Color(0.62, 0.68, 0.78)
const PERIGO := Color(0.72, 0.26, 0.26)
const SUCESSO := Color(0.52, 0.86, 0.54)
const ESCURECER := Color(0.01, 0.015, 0.03, 0.82)

## Raridade — o unico lugar onde entra cor forte, e so no aro do slot.
const RARIDADE := {
    "Comum": Color(0.42, 0.47, 0.55),
    "Incomum": Color(0.40, 0.74, 0.45),
    "Raro": Color(0.34, 0.60, 0.92),
    "Épico": Color(0.68, 0.42, 0.90),
    "Lendário": Color(0.94, 0.68, 0.26),
}

# ----------------------------------------------------------------- tipografia
## DUAS FAMILIAS, cada uma no seu lugar.
##
## A Cinzel e bonita e cansa: titulo em capitulares le bem, paragrafo nao. Corpo,
## numero e botao usam a fonte de interface do proprio motor, que e sem serifa e
## foi desenhada para ser lida em tamanho pequeno — que e o caso do celular.
enum { TITULO_PAGINA, TITULO_SECAO, NOME_ITEM, CORPO, BOTAO, LEGENDA, CONTADOR }

const CORPO_DO_TEXTO := {
    TITULO_PAGINA: 38, TITULO_SECAO: 28, NOME_ITEM: 24,
    CORPO: 20, BOTAO: 21, LEGENDA: 16, CONTADOR: 22,
}

static var _display: Font = null
static var _titulo: Font = null

static func fonte_display() -> Font:
    if _display == null:
        _display = load("res://fontes/CinzelDecorative.ttf")
    return _display

static func fonte_titulo() -> Font:
    if _titulo == null:
        _titulo = load("res://fontes/Cinzel.ttf")
    return _titulo

## Sem serifa, do proprio motor. Nao acrescenta arquivo ao pacote e e a mais
## legivel que o projeto tem para texto corrido e numero.
static func fonte_ui() -> Font:
    return ThemeDB.fallback_font


## `quebrar` so vale para texto corrido. Rotulo curto com quebra automatica
## mente sobre o proprio tamanho: o minimo dele e calculado na largura minima,
## como se fosse quebrar em cinco linhas, e a coluna inteira estica atras disso
## — foi assim que a ficha de personagem passou a exigir 886 px de altura.
static func rotulo(texto: String, estilo: int, cor := TEXTO, quebrar := false) -> Label:
    var l := Label.new()
    l.text = texto
    l.add_theme_font_size_override("font_size", int(CORPO_DO_TEXTO[estilo]))
    l.add_theme_color_override("font_color", cor)
    match estilo:
        TITULO_PAGINA:
            l.add_theme_font_override("font", fonte_display())
        TITULO_SECAO, NOME_ITEM:
            l.add_theme_font_override("font", fonte_titulo())
        _:
            l.add_theme_font_override("font", fonte_ui())
    if quebrar:
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.add_theme_constant_override("line_spacing", 6)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


# ------------------------------------------------------------------- o kit
## O KIT DE ARTE QUE JA ESTAVA NO PROJETO.
##
## `textures/ui/kit` tem moldura ornamentada, placa de titulo, botao dourado,
## slot por raridade, ficha de contador, barra de experiencia e moldura de
## retrato — tudo pintado e nada em uso: a interface estava desenhada so com
## retangulo de cor. Aqui essas pecas viram estilo, num lugar so, e toda tela
## que pede um botao ou um painel recebe a arte junto.
const KIT := "res://textures/ui/kit/"

static var _texturas: Dictionary = {}

static func arte(nome: String) -> Texture2D:
    if not _texturas.has(nome):
        var caminho := KIT + nome + ".png"
        _texturas[nome] = load(caminho) if ResourceLoader.exists(caminho) else null
    return _texturas[nome]


## Estilo de nove fatias a partir de uma arte do kit. `borda` diz quanto de cada
## lado e canto ornamentado e nao pode esticar; `margem` e o respiro interno.
static func estilo_do_kit(nome: String, borda: Vector4i, margem: Vector4i) -> StyleBox:
    var tex := arte(nome)
    if tex == null:
        return painel(NAVY_PAINEL, OURO_ARO, 10, 1, 14)
    var e := StyleBoxTexture.new()
    e.texture = tex
    e.texture_margin_left = borda.x
    e.texture_margin_top = borda.y
    e.texture_margin_right = borda.z
    e.texture_margin_bottom = borda.w
    e.content_margin_left = margem.x
    e.content_margin_top = margem.y
    e.content_margin_right = margem.z
    e.content_margin_bottom = margem.w
    return e


## ARTE ORNAMENTADA NAO SE ESTICA.
##
## A moldura pintada tem 429x314. Esticada para 1600x900 por nove fatias, o
## miolo de cada borda vira um borrao alongado e a peca central incha no meio da
## tela: ficou exagerada e chapada, que e o oposto do que a arte e. A regra aqui
## passa a ser: SUPERFICIE lisa desenhada em codigo, e o ornamento aplicado por
## cima em TAMANHO NATIVO, onde ele cabe inteiro. E assim que ele continua
## nitido em qualquer resolucao.
static func moldura_da_tela() -> StyleBox:
    var e := painel(Color(0.028, 0.048, 0.095, 0.985), OURO_ARO, 16, 2, 0)
    e.content_margin_left = 26
    e.content_margin_right = 26
    e.content_margin_top = 18
    e.content_margin_bottom = 18
    e.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
    e.shadow_size = 16
    return e


## Poe os quatro cantos ornamentados do kit sobre um painel, cada um no seu
## tamanho de arquivo e espelhado para o canto certo. Nada estica.
static func ornamentar_cantos(pai: Control, nome := "moldura_canto_01") -> void:
    var tex := arte(nome)
    if tex == null:
        return
    var medida := Vector2(tex.get_width(), tex.get_height())
    for canto in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
        var t := TextureRect.new()
        t.texture = tex
        t.custom_minimum_size = medida
        t.size = medida
        t.flip_h = canto.x == 1
        t.flip_v = canto.y == 1
        t.mouse_filter = Control.MOUSE_FILTER_IGNORE
        t.modulate = Color(1, 1, 1, 0.9)
        t.anchor_left = float(canto.x)
        t.anchor_right = float(canto.x)
        t.anchor_top = float(canto.y)
        t.anchor_bottom = float(canto.y)
        t.offset_left = 4.0 if canto.x == 0 else -medida.x - 4.0
        t.offset_right = t.offset_left + medida.x
        t.offset_top = 4.0 if canto.y == 0 else -medida.y - 4.0
        t.offset_bottom = t.offset_top + medida.y
        pai.add_child(t)


## A placa que fica atras do titulo da pagina.
static func placa_de_titulo() -> StyleBox:
    return estilo_do_kit("moldura_placa_titulo", Vector4i(62, 30, 62, 30), Vector4i(40, 6, 40, 10))


## O aro do slot, na cor da raridade. O kit tem quatro; o resto do jogo mapeia
## nelas em vez de inventar um quinto.
const SLOT_DA_RARIDADE := {
    "Comum": "slot_azul", "Incomum": "slot_verde", "Raro": "slot_azul",
    "Épico": "slot_roxo", "Lendário": "slot_dourado", "Valioso": "slot_dourado",
}

static func slot(raridade: String) -> Texture2D:
    return arte(String(SLOT_DA_RARIDADE.get(raridade, "slot_azul")))


# -------------------------------------------------------------------- molduras
static func painel(fundo: Color, aro: Color, raio := 10, espessura := 1,
        margem := 16) -> StyleBoxFlat:
    var e := StyleBoxFlat.new()
    e.bg_color = fundo
    e.border_color = aro
    e.set_border_width_all(espessura)
    e.set_corner_radius_all(raio)
    e.content_margin_left = margem
    e.content_margin_right = margem
    e.content_margin_top = margem
    e.content_margin_bottom = margem
    return e


static func painel_principal() -> StyleBox:
    return moldura_da_tela()


static func painel_secundario(margem := 14) -> StyleBoxFlat:
    return painel(NAVY_PAINEL, Color(0.24, 0.31, 0.44, 0.75), 10, 1, margem)


## COLUNA SEM CAIXA. A moldura da tela ja e uma superficie; repetir painel
## dentro de painel dentro de painel polui e encolhe o conteudo. Aqui fica so o
## respiro: as areas se separam por espaco e hierarquia de texto, nao por borda.
static func coluna(margem := 18) -> MarginContainer:
    var c := MarginContainer.new()
    for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        c.add_theme_constant_override(lado, margem)
    return c


# --------------------------------------------------------------------- botoes
enum { PRIMARIO, SECUNDARIO, PERIGOSO, ABA }

static func botao(texto: String, tipo := SECUNDARIO, altura := 46.0) -> Button:
    var b := Button.new()
    b.text = texto
    b.custom_minimum_size.y = altura
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_override("font", fonte_ui())
    b.add_theme_font_size_override("font_size", int(CORPO_DO_TEXTO[BOTAO]))
    # CADA TIPO DE BOTAO TEM A SUA ARTE. O kit ja trazia a barra dourada, a azul,
    # a roxa e a vermelha; o botao era um retangulo com borda de um pixel.
    var arte_do_botao := "botao_azul"
    var letra := TEXTO
    match tipo:
        PRIMARIO:
            arte_do_botao = "botao_dourado"; letra = Color(0.24, 0.16, 0.03)
        PERIGOSO:
            arte_do_botao = "botao_vermelho"; letra = Color(1.0, 0.90, 0.88)
        ABA:
            arte_do_botao = "botao_azul_claro"; letra = TEXTO
        _:
            arte_do_botao = "botao_azul"; letra = Color(0.90, 0.94, 1.0)
    b.add_theme_color_override("font_color", letra)
    b.add_theme_color_override("font_hover_color", letra.lightened(0.25))
    b.add_theme_color_override("font_pressed_color", letra.lightened(0.35))
    b.add_theme_color_override("font_disabled_color", Color(letra.r, letra.g, letra.b, 0.34))

    # A ARTE SO ENTRA SE COUBER SEM ACHATAR.
    #
    # A barra pintada tem 53 px de altura. Enfiada num botao de 32 ela nao
    # encolhe: ela AMASSA, e o ornamento das pontas vira um risco. Abaixo da
    # altura da arte o botao volta a ser superficie lisa, que em tamanho pequeno
    # fica melhor do que ornamento espremido.
    if altura < 50.0:
        return _botao_liso(b, tipo, letra)
    var borda := Vector4i(46, 16, 46, 16)
    var respiro := Vector4i(20, 6, 20, 8)
    var normal := estilo_do_kit(arte_do_botao, borda, respiro)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("focus", normal)
    var sobre := estilo_do_kit(arte_do_botao, borda, respiro)
    if sobre is StyleBoxTexture:
        (sobre as StyleBoxTexture).modulate_color = Color(1.18, 1.16, 1.10)
    b.add_theme_stylebox_override("hover", sobre)
    var apertado := estilo_do_kit(arte_do_botao, borda, respiro)
    if apertado is StyleBoxTexture:
        (apertado as StyleBoxTexture).modulate_color = Color(0.82, 0.80, 0.76)
    b.add_theme_stylebox_override("pressed", apertado)
    var apagado := estilo_do_kit(arte_do_botao, borda, respiro)
    if apagado is StyleBoxTexture:
        (apagado as StyleBoxTexture).modulate_color = Color(0.52, 0.55, 0.60, 0.75)
    b.add_theme_stylebox_override("disabled", apagado)
    return b


## Botao sem arte: para tamanho pequeno, e para o que nao e acao principal.
static func _botao_liso(b: Button, tipo: int, letra: Color) -> Button:
    var fundo := NAVY_CLARO
    var aro := Color(0.30, 0.40, 0.56, 0.85)
    match tipo:
        PRIMARIO:
            fundo = Color(0.20, 0.16, 0.06, 0.96); aro = OURO
        PERIGOSO:
            fundo = Color(0.17, 0.05, 0.05, 0.96); aro = PERIGO
    b.add_theme_color_override("font_color", letra if tipo != PRIMARIO else Color(1.0, 0.95, 0.82))
    b.add_theme_color_override("font_disabled_color", Color(letra.r, letra.g, letra.b, 0.32))
    b.add_theme_stylebox_override("normal", painel(fundo, aro, 8, 1, 12))
    b.add_theme_stylebox_override("focus", painel(fundo, aro, 8, 1, 12))
    b.add_theme_stylebox_override("hover", painel(fundo.lightened(0.10), aro.lightened(0.15), 8, 1, 12))
    b.add_theme_stylebox_override("pressed", painel(fundo.lightened(0.18), aro.lightened(0.25), 8, 2, 12))
    b.add_theme_stylebox_override("disabled",
        painel(Color(fundo.r, fundo.g, fundo.b, 0.45), Color(aro.r, aro.g, aro.b, 0.28), 8, 1, 12))
    return b


## Aba de filtro: baixa, texto centrado, e o estado escolhido se anuncia pelo aro
## dourado e pelo fundo mais claro — nao por um tom de azul quase igual.
static func aba(texto: String, altura := 40.0) -> Button:
    var b := botao(texto, SECUNDARIO, altura)
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.add_theme_font_size_override("font_size", int(CORPO_DO_TEXTO[CORPO]))
    return b


static func pintar_aba(b: Button, escolhida: bool) -> void:
    var fundo: Color = Color(0.13, 0.19, 0.30, 0.98) if escolhida else NAVY_CLARO
    var aro: Color = OURO if escolhida else Color(0.28, 0.36, 0.50, 0.70)
    for estado in ["normal", "focus"]:
        b.add_theme_stylebox_override(estado, painel(fundo, aro, 8, 2 if escolhida else 1, 12))
    b.add_theme_stylebox_override("hover", painel(fundo.lightened(0.08), aro, 8, 2 if escolhida else 1, 12))
    b.add_theme_color_override("font_color", OURO_FORTE if escolhida else TEXTO)


## Um risco fino de separacao. Substitui os tres estilos de divisoria que
## andavam espalhados pelas telas.
static func separador(margem_vertical := 10) -> Control:
    var caixa := VBoxContainer.new()
    caixa.add_theme_constant_override("separation", 0)
    var cima := Control.new()
    cima.custom_minimum_size.y = margem_vertical
    caixa.add_child(cima)
    var risco := ColorRect.new()
    risco.color = OURO_ARO
    risco.custom_minimum_size.y = 1
    caixa.add_child(risco)
    var baixo := Control.new()
    baixo.custom_minimum_size.y = margem_vertical
    caixa.add_child(baixo)
    caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return caixa


static func espaco(altura: float) -> Control:
    var c := Control.new()
    c.custom_minimum_size.y = altura
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return c


# ------------------------------------------------------------------- o fundo
## FUNDO EM CAMADAS, TUDO PROCEDURAL.
##
## O painel era um azul chapado, e azul chapado em tela grande parece protótipo:
## sem profundidade, sem foco, sem textura. Aqui vao quatro camadas finas que
## nascem em codigo — nenhum arquivo novo no pacote: um degrade que escurece
## para baixo, um halo dourado atras do titulo, uma vinheta que fecha os cantos
## e um grao fraquissimo por cima para o azul nao parecer plastico.
##
## Todas ignoram o mouse e nenhuma tem tamanho minimo, entao nao interferem em
## layout nenhum.
static func fundo_em_camadas(pai: Control) -> void:
    # PRIMEIRO, UM INTERIOR OPACO.
    #
    # O miolo da moldura pintada nao e totalmente opaco, entao o jogo atras
    # aparecia por dentro do menu: o nome da zona e os botoes redondos do HUD
    # ficavam escritos por cima da ficha. Este retangulo tapa o miolo e para
    # ANTES do ouro, para a borda ornamentada continuar recortada contra o mundo.
    var miolo := ColorRect.new()
    miolo.color = Color(0.028, 0.048, 0.095, 1.0)
    miolo.set_anchors_preset(Control.PRESET_FULL_RECT)
    miolo.offset_left = 26.0
    miolo.offset_top = 24.0
    miolo.offset_right = -26.0
    miolo.offset_bottom = -24.0
    miolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    miolo.z_index = -2
    pai.add_child(miolo)

    var degrade := Gradient.new()
    degrade.set_color(0, Color(0.10, 0.16, 0.30, 0.55))
    degrade.set_color(1, Color(0.01, 0.02, 0.05, 0.75))
    var tex_degrade := GradientTexture2D.new()
    tex_degrade.gradient = degrade
    tex_degrade.width = 8
    tex_degrade.height = 256
    tex_degrade.fill_from = Vector2(0.0, 0.0)
    tex_degrade.fill_to = Vector2(0.0, 1.0)
    pai.add_child(_camada(tex_degrade, 1.0))

    var halo := Gradient.new()
    halo.set_color(0, Color(0.85, 0.68, 0.32, 0.20))
    halo.set_color(1, Color(0.85, 0.68, 0.32, 0.0))
    var tex_halo := GradientTexture2D.new()
    tex_halo.gradient = halo
    tex_halo.width = 256
    tex_halo.height = 256
    tex_halo.fill = GradientTexture2D.FILL_RADIAL
    tex_halo.fill_from = Vector2(0.5, 0.5)
    tex_halo.fill_to = Vector2(1.0, 0.5)
    var brilho := _camada(tex_halo, 1.0)
    brilho.set_anchors_preset(Control.PRESET_TOP_WIDE)
    brilho.anchor_bottom = 0.42
    pai.add_child(brilho)

    var vinheta := Gradient.new()
    vinheta.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
    vinheta.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
    vinheta.colors = PackedColorArray([
        Color(0.0, 0.0, 0.0, 0.0),
        Color(0.0, 0.01, 0.03, 0.10),
        Color(0.0, 0.01, 0.03, 0.55)])
    var tex_vinheta := GradientTexture2D.new()
    tex_vinheta.gradient = vinheta
    tex_vinheta.width = 256
    tex_vinheta.height = 256
    tex_vinheta.fill = GradientTexture2D.FILL_RADIAL
    tex_vinheta.fill_from = Vector2(0.5, 0.5)
    tex_vinheta.fill_to = Vector2(1.0, 1.0)
    pai.add_child(_camada(tex_vinheta, 1.0))

    var ruido := FastNoiseLite.new()
    ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    ruido.frequency = 0.28
    var tex_ruido := NoiseTexture2D.new()
    tex_ruido.noise = ruido
    tex_ruido.width = 256
    tex_ruido.height = 256
    tex_ruido.seamless = true
    var grao := _camada(tex_ruido, 0.055)
    grao.stretch_mode = TextureRect.STRETCH_TILE
    pai.add_child(grao)


static func _camada(tex: Texture2D, alfa: float) -> TextureRect:
    var t := TextureRect.new()
    t.texture = tex
    t.set_anchors_preset(Control.PRESET_FULL_RECT)
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.modulate.a = alfa
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    t.z_index = -1
    return t


## Halo redondo para por atras de um item, um retrato, uma recompensa.
static func halo_redondo(cor: Color, forca := 0.30) -> TextureRect:
    var g := Gradient.new()
    g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    g.colors = PackedColorArray([
        Color(cor.r, cor.g, cor.b, forca),
        Color(cor.r, cor.g, cor.b, forca * 0.35),
        Color(cor.r, cor.g, cor.b, 0.0)])
    var tex := GradientTexture2D.new()
    tex.gradient = g
    tex.width = 128
    tex.height = 128
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    return _camada(tex, 1.0)


# ------------------------------------------------------------ botao de fechar
## O X E DESENHADO, NAO ESCRITO.
##
## Estava escrito com o caractere "✕", que a fonte de interface do motor nao
## tem: no aparelho o botao mostrava o quadradinho de glifo faltante. Duas
## linhas desenhadas nao dependem de fonte nenhuma e ficam iguais em todo lugar.
static func botao_fechar(ao_fechar: Callable) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(52, 52)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_stylebox_override("normal", painel(Color(0.17, 0.05, 0.05, 0.94), PERIGO, 8, 1, 0))
    b.add_theme_stylebox_override("hover", painel(Color(0.26, 0.08, 0.08, 0.97), PERIGO.lightened(0.25), 8, 1, 0))
    b.add_theme_stylebox_override("pressed", painel(Color(0.32, 0.10, 0.10, 1.0), PERIGO.lightened(0.35), 8, 2, 0))
    b.pressed.connect(ao_fechar)

    var risco := Control.new()
    risco.set_anchors_preset(Control.PRESET_FULL_RECT)
    risco.mouse_filter = Control.MOUSE_FILTER_IGNORE
    risco.draw.connect(func() -> void:
        var m := 18.0
        var r := risco.size
        var cor := Color(1.0, 0.84, 0.82)
        risco.draw_line(Vector2(m, m), Vector2(r.x - m, r.y - m), cor, 2.5, true)
        risco.draw_line(Vector2(r.x - m, m), Vector2(m, r.y - m), cor, 2.5, true))
    b.add_child(risco)
    return b
