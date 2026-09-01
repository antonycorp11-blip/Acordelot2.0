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
    TITULO_PAGINA: 44, TITULO_SECAO: 28, NOME_ITEM: 24,
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


static func painel_principal() -> StyleBoxFlat:
    var e := painel(NAVY_FUNDO, OURO_ARO, 14, 2, 0)
    e.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
    e.shadow_size = 14
    return e


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
    var fundo: Color
    var aro: Color
    var letra: Color
    match tipo:
        PRIMARIO:
            fundo = Color(0.20, 0.16, 0.06, 0.96); aro = OURO; letra = Color(1.0, 0.95, 0.82)
        PERIGOSO:
            fundo = Color(0.17, 0.05, 0.05, 0.96); aro = PERIGO; letra = Color(1.0, 0.86, 0.84)
        _:
            fundo = NAVY_CLARO; aro = Color(0.30, 0.40, 0.56, 0.85); letra = TEXTO
    b.add_theme_color_override("font_color", letra)
    b.add_theme_color_override("font_disabled_color", Color(letra.r, letra.g, letra.b, 0.32))
    b.add_theme_stylebox_override("normal", painel(fundo, aro, 8, 1, 12))
    b.add_theme_stylebox_override("hover", painel(fundo.lightened(0.10), aro.lightened(0.15), 8, 1, 12))
    b.add_theme_stylebox_override("pressed", painel(fundo.lightened(0.20), aro.lightened(0.25), 8, 2, 12))
    b.add_theme_stylebox_override("focus", painel(fundo, aro, 8, 1, 12))
    var apagado := painel(Color(fundo.r, fundo.g, fundo.b, 0.45), Color(aro.r, aro.g, aro.b, 0.28), 8, 1, 12)
    b.add_theme_stylebox_override("disabled", apagado)
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
    b.add_theme_stylebox_override("normal", painel(fundo, aro, 8, 2 if escolhida else 1, 12))
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
