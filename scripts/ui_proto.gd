extends RefCounted
class_name UiProto
## OS COMPONENTES DAS TELAS APROVADAS.
##
## Este arquivo e a linguagem visual que o Codex montou no projeto Godot dele e
## que voce aprovou olhando: painel azul-noite com fio de bronze, sobrancelha em
## versalete acima do titulo, cartao de item com a nota no canto e a quantidade
## embaixo, botao por variante e linha de status com valor a direita.
##
## Trouxe as pecas, nao a tela: a marcacao dele carregava dado de demonstracao —
## "18 / 24", "Nivel 18", "+21 de poder" em item que nao tem atributo. Aqui as
## pecas sao as mesmas e quem preenche e o Progresso. O que o jogo nao tem, a
## tela nao inventa.

const NAVY := Color("07101f")
const PANEL := Color("091426e8")
const PANEL_SOFT := Color("0d1b30d9")
const ARO := Color("806439")
const GOLD := Color("b68a45")
const GOLD_BRIGHT := Color("f1cf78")
const IVORY := Color("eadab7")
const MUTED := Color("8290a6")
const CYAN := Color("46c7f4")
const VIOLET := Color("a452ea")
const GREEN := Color("79df67")
const VERMELHO := Color("ff434f")

## As telas sao desenhadas em 900 px de altura e depois reduzidas no celular.
## Os tamanhos originais (9–14 px) viravam 5–7 px fisicos. Esta escala nao e
## um zoom da tela: ela preserva a composicao e garante corpo legivel ao toque.
static func tamanho_legivel(tamanho: int) -> int:
    return maxi(int(round(float(tamanho) * 1.25)), tamanho + 12)

const RARIDADE := {
    "Comum": Color("8290a6"), "Incomum": Color("79df67"), "Raro": Color("46c7f4"),
    "Épico": Color("a452ea"), "Lendário": Color("f1cf78"), "Valioso": Color("f1cf78"),
}


static func estilo(cor: Color, borda: Color, largura := 1, raio := 2) -> StyleBoxFlat:
    var e := StyleBoxFlat.new()
    e.bg_color = cor
    e.border_color = borda
    e.set_border_width_all(largura)
    e.set_corner_radius_all(raio)
    e.content_margin_left = 9
    e.content_margin_right = 9
    e.content_margin_top = 7
    e.content_margin_bottom = 7
    return e


static func painel(cor := PANEL) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", estilo(cor, ARO, 1, 1))
    return p


static func recheio(filho: Control, quanto: int) -> MarginContainer:
    var m := MarginContainer.new()
    for lado in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        m.add_theme_constant_override(lado, quanto)
    m.add_child(filho)
    return m


## A quebra automatica e OPCIONAL de proposito. Ligada em todo rotulo, ela
## destroi qualquer texto num Control sem largura: o motor quebra no ponto mais
## estreito que existe e o texto sai uma letra por linha. So paragrafo dentro de
## painel com largura definida pede quebra.
static func rotulo(texto: String, tamanho := 14, cor := IVORY, quebrar := false) -> Label:
    var l := Label.new()
    l.text = texto
    l.add_theme_font_size_override("font_size", tamanho_legivel(tamanho))
    l.add_theme_color_override("font_color", cor)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebrar else TextServer.AUTOWRAP_OFF
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return l


static func sobrancelha(texto: String) -> Label:
    var l := rotulo(texto, 10, Color("9ba9be"))
    l.add_theme_constant_override("outline_size", 1)
    l.add_theme_color_override("font_outline_color", Color("111827"))
    return l


static func estilo_de_botao(variante: String) -> StyleBoxFlat:
    match variante:
        "primary": return estilo(Color("17648f"), GOLD_BRIGHT, 1, 1)
        "violet": return estilo(Color("7c11b9"), Color("d067ff"), 1, 1)
        "gold": return estilo(Color("5a4322"), GOLD_BRIGHT, 1, 1)
        "danger": return estilo(Color("5c1f22"), Color("d2696e"), 1, 1)
        "item": return estilo(Color("07101fdc"), Color("56462f"), 1, 1)
        "hover": return estilo(Color("142540"), GOLD_BRIGHT, 1, 1)
        "pressed": return estilo(Color("20314a"), Color.WHITE, 1, 1)
        _: return estilo(Color("07101fbb"), Color("4d4538"), 1, 1)


static func botao(texto: String, variante := "quiet") -> Button:
    var b := Button.new()
    b.text = texto
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", tamanho_legivel(13))
    b.add_theme_color_override("font_color", IVORY)
    b.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
    b.add_theme_color_override("font_disabled_color", Color(IVORY.r, IVORY.g, IVORY.b, 0.34))
    b.add_theme_stylebox_override("normal", estilo_de_botao(variante))
    b.add_theme_stylebox_override("hover", estilo_de_botao("hover"))
    b.add_theme_stylebox_override("pressed", estilo_de_botao("pressed"))
    b.add_theme_stylebox_override("disabled", estilo(Color("0a101cbb"), Color("3a3529"), 1, 1))
    return b


static func cabecalho(sobre: String, titulo: String, fim := "") -> Control:
    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 8)
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(sobrancelha(sobre))
    var titulo_label := rotulo(titulo, 26, IVORY)
    var fonte_titulo := load("res://fontes/Cinzel.ttf")
    if fonte_titulo:
        titulo_label.add_theme_font_override("font", fonte_titulo)
    col.add_child(titulo_label)
    linha.add_child(col)
    if fim != "":
        linha.add_child(rotulo(fim, 11, GOLD_BRIGHT))
    return linha


static func arte(caminho: String, minimo := Vector2(90, 90)) -> TextureRect:
    var t := TextureRect.new()
    if caminho != "" and ResourceLoader.exists(caminho):
        t.texture = load(caminho)
    t.custom_minimum_size = minimo
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return t


static func risco() -> HSeparator:
    var s := HSeparator.new()
    s.add_theme_constant_override("separation", 8)
    return s


static func linha_de_barra(icone: String, fracao: float, cor: Color, valor: String) -> Control:
    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 8)
    linha.add_child(rotulo(icone, 16, cor))
    var barra := ProgressBar.new()
    barra.max_value = 1.0
    barra.value = clampf(fracao, 0.0, 1.0)
    barra.show_percentage = false
    barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    barra.custom_minimum_size.y = 8
    barra.add_theme_stylebox_override("background", estilo(Color("07101f"), Color("58472f"), 1, 1))
    barra.add_theme_stylebox_override("fill", estilo(cor, cor, 0, 1))
    linha.add_child(barra)
    linha.add_child(rotulo(valor, 11, IVORY))
    return linha


static func linha_de_status(icone: String, titulo: String, valor: String) -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 39
    linha.add_theme_constant_override("separation", 8)
    linha.add_child(rotulo(icone, 14, GOLD))
    var t := rotulo(titulo, 11, Color("c3b89f"))
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(t)
    linha.add_child(rotulo(valor, 12, IVORY))
    return linha


static func espaco_elastico() -> Control:
    var c := Control.new()
    c.size_flags_vertical = Control.SIZE_EXPAND_FILL
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return c
