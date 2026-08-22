extends Control
class_name PlayerHUD
## O painel do jogador: retrato, vida, mana e a barra do alvo.
##
## As pecas vem do kit de arte com o preenchimento PINTADO DENTRO — a barra de
## vida chega com o vermelho em 89% e os numeros ja desenhados. Colada assim ela
## seria um adesivo. O remendo .tools/recortar_hud.py vaza o miolo de cada peca,
## e o que sobra e moldura; a barra de verdade fica por baixo, aparecendo pelo
## buraco.
##
## Por isso cada peca precisa saber ONDE fica o buraco dela. As medidas abaixo
## sao fracoes do tamanho da imagem, e nao pixels, para a moldura poder ser
## desenhada em qualquer tamanho de tela sem o preenchimento sair do lugar.

@export var max_health: float = 1000.0
@export var current_health: float = 1000.0
@export var max_mana: float = 500.0
@export var current_mana: float = 500.0
@export var player_level: int = 12

## O buraco de cada moldura, em fracao da imagem. Medido no proprio arquivo
## depois do recorte — nao chute.
const BURACOS := {
    "vida": Rect2(0.0189, 0.30, 0.9623, 0.60),
    "mana": Rect2(0.0189, 0.1304, 0.9623, 0.7391),
    "alvo": Rect2(0.0748, 0.2131, 0.8866, 0.5738),
}

const LARGURA_DA_BARRA := 232.0
const LADO_DO_RETRATO := 78.0

var _hp_fundo: ColorRect
var _hp_cheio: ColorRect
var _hp_label: Label
var _mana_cheio: ColorRect
var _mana_label: Label

var _alvo_caixa: Control
var _alvo_cheio: ColorRect
var _alvo_nome: Label
var _alvo_some_em := 0.0

signal config_pedida
signal mochila_pedida


func _ready() -> void:
    # O painel em si nao come toque — senao ele engoliria o dedo em toda a
    # metade de cima da tela. Os botoes dentro dele pedem o toque por conta.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    add_to_group("player_hud")

    _montar_retrato_e_barras()
    _montar_barra_do_alvo()


func _process(delta: float) -> void:
    if _alvo_caixa and _alvo_caixa.visible:
        _alvo_some_em -= delta
        if _alvo_some_em <= 0.0:
            _alvo_caixa.visible = false


# ---------------------------------------------------------------- construcao

func _moldura(caminho: String, tamanho: Vector2, pai: Control) -> TextureRect:
    var arte: Texture2D = load(caminho)
    var quadro := TextureRect.new()
    quadro.texture = arte
    quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    quadro.stretch_mode = TextureRect.STRETCH_SCALE
    quadro.size = tamanho
    quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pai.add_child(quadro)
    return quadro


## Cria o preenchimento que aparece pelo buraco da moldura.
##
## Vem ANTES da moldura na ordem dos filhos, para a borda dourada ficar por
## cima e esconder a quina reta do retangulo colorido.
func _preencher(buraco: Rect2, tamanho: Vector2, cor: Color, pai: Control) -> Array:
    var area := Rect2(
        buraco.position * tamanho, buraco.size * tamanho)

    var fundo := ColorRect.new()
    fundo.color = Color(0.04, 0.03, 0.05, 0.85)
    fundo.position = area.position
    fundo.size = area.size
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pai.add_child(fundo)

    var cheio := ColorRect.new()
    cheio.color = cor
    cheio.position = area.position
    cheio.size = area.size
    cheio.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pai.add_child(cheio)

    return [fundo, cheio]


func _numero(tamanho: Vector2, area: Rect2, corpo: int, pai: Control) -> Label:
    var texto := Label.new()
    texto.position = area.position * tamanho
    texto.size = area.size * tamanho
    texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    texto.add_theme_font_size_override("font_size", corpo)
    texto.add_theme_color_override("font_color", Color(1, 1, 1))
    texto.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02, 0.95))
    texto.add_theme_constant_override("outline_size", 4)
    texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pai.add_child(texto)
    return texto


func _montar_retrato_e_barras() -> void:
    var canto := Control.new()
    canto.position = Vector2(14, 12)
    canto.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(canto)

    # --- retrato, com o nivel na medalha que ja vem desenhada na arte
    var retrato := _moldura("res://textures/ui/retrato.png",
        Vector2(LADO_DO_RETRATO, LADO_DO_RETRATO * 265.0 / 254.0), canto)
    retrato.position = Vector2.ZERO

    var nivel := Label.new()
    # A medalha esta no canto inferior direito do desenho, a uns 78% da largura
    # e 82% da altura.
    nivel.position = Vector2(LADO_DO_RETRATO * 0.62, LADO_DO_RETRATO * 0.70)
    nivel.size = Vector2(LADO_DO_RETRATO * 0.34, LADO_DO_RETRATO * 0.22)
    nivel.text = str(player_level)
    nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nivel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    nivel.add_theme_font_size_override("font_size", 15)
    nivel.add_theme_color_override("font_color", Color(1, 1, 1))
    nivel.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 0.95))
    nivel.add_theme_constant_override("outline_size", 4)
    nivel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(nivel)

    # --- vida
    var t_vida := Vector2(LARGURA_DA_BARRA, LARGURA_DA_BARRA * 60.0 / 424.0)
    var caixa_vida := Control.new()
    caixa_vida.position = Vector2(LADO_DO_RETRATO - 6.0, 8.0)
    caixa_vida.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(caixa_vida)

    var partes_vida := _preencher(BURACOS["vida"], t_vida,
        Color(0.86, 0.16, 0.14), caixa_vida)
    _hp_fundo = partes_vida[0]
    _hp_cheio = partes_vida[1]
    _moldura("res://textures/ui/barra_vida.png", t_vida, caixa_vida)
    _hp_label = _numero(t_vida, BURACOS["vida"], 13, caixa_vida)

    # --- mana
    var t_mana := Vector2(LARGURA_DA_BARRA, LARGURA_DA_BARRA * 46.0 / 424.0)
    var caixa_mana := Control.new()
    caixa_mana.position = Vector2(LADO_DO_RETRATO - 6.0, 8.0 + t_vida.y + 2.0)
    caixa_mana.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(caixa_mana)

    var partes_mana := _preencher(BURACOS["mana"], t_mana,
        Color(0.12, 0.48, 0.92), caixa_mana)
    _mana_cheio = partes_mana[1]
    _moldura("res://textures/ui/barra_mana.png", t_mana, caixa_mana)
    _mana_label = _numero(t_mana, BURACOS["mana"], 11, caixa_mana)

    _pintar_vida()
    _pintar_mana()

    # --- engrenagem e mochila, no canto de cima a direita
    # Abaixo do minimapa, nao ao lado dele: o canto de cima a direita ja e do
    # radar, e os dois ali por cima cobririam a bussola.
    var lado := 50.0
    var topo := 250.0

    var mochila := _botao("res://textures/ui/btn_mochila.png", lado)
    mochila.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    mochila.position = Vector2(-lado - 16.0, topo)
    mochila.pressed.connect(func(): mochila_pedida.emit())
    add_child(mochila)

    var config := _botao("res://textures/ui/btn_config.png", lado)
    config.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    config.position = Vector2(-lado - 16.0, topo + lado + 10.0)
    config.pressed.connect(func(): config_pedida.emit())
    add_child(config)


func _botao(caminho: String, lado: float) -> TextureButton:
    var b := TextureButton.new()
    b.texture_normal = load(caminho)
    b.ignore_texture_size = true
    b.stretch_mode = TextureButton.STRETCH_SCALE
    b.custom_minimum_size = Vector2(lado, lado)
    b.size = Vector2(lado, lado)
    return b


func _montar_barra_do_alvo() -> void:
    var t := Vector2(300.0, 300.0 * 61.0 / 441.0)
    _alvo_caixa = Control.new()
    _alvo_caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
    # Centralizada no alto, no lugar que era do indicador de dia e noite.
    #
    # Ela ja esteve aqui e batia no bloco do jogador, entao desceu; o erro foi
    # medir a tela pela largura de um celular. A base do jogo e 1280 de largura
    # e o esticamento so alarga: o bloco da esquerda acaba nos 318 pixels e a
    # barra do alvo comeca nos 490. Nao ha encontro entre os dois.
    # DESCEU de vez. A conta de largura estava certa na base 1280, mas o celular
    # do dono e ultralargo: com a tela esticada, o bloco do jogador cresce para
    # a direita e alcanca o centro, onde esta esta barra. Em vez de calcular o
    # encontro, ela sai da faixa: cento e vinte pixels ja e abaixo do bloco
    # inteiro, e nao ha largura de tela em que os dois se cruzem.
    _alvo_caixa.position = Vector2(-t.x * 0.5, 120.0)
    _alvo_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _alvo_caixa.visible = false
    add_child(_alvo_caixa)

    var partes := _preencher(BURACOS["alvo"], t, Color(0.82, 0.14, 0.12), _alvo_caixa)
    _alvo_cheio = partes[1]
    _moldura("res://textures/ui/barra_alvo.png", t, _alvo_caixa)

    _alvo_nome = Label.new()
    _alvo_nome.position = Vector2(0.0, -19.0)
    _alvo_nome.size = Vector2(t.x, 18.0)
    _alvo_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _alvo_nome.add_theme_font_size_override("font_size", 14)
    _alvo_nome.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
    _alvo_nome.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.0, 0.95))
    _alvo_nome.add_theme_constant_override("outline_size", 4)
    _alvo_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _alvo_caixa.add_child(_alvo_nome)


# -------------------------------------------------------------------- estado

func _pintar_vida() -> void:
    if _hp_cheio == null:
        return
    var fracao: float = 0.0 if max_health <= 0.0 else current_health / max_health
    _hp_cheio.size.x = _hp_fundo.size.x * clampf(fracao, 0.0, 1.0)
    if _hp_label:
        _hp_label.text = "%d / %d" % [int(current_health), int(max_health)]


func _pintar_mana() -> void:
    if _mana_cheio == null:
        return
    var largura: float = BURACOS["mana"].size.x * LARGURA_DA_BARRA
    var fracao: float = 0.0 if max_mana <= 0.0 else current_mana / max_mana
    _mana_cheio.size.x = largura * clampf(fracao, 0.0, 1.0)
    if _mana_label:
        _mana_label.text = "%d / %d" % [int(current_mana), int(max_mana)]


func curar(qtd: float) -> void:
    current_health = clampf(current_health + qtd, 0.0, max_health)
    _pintar_vida()


func tomar_dano(qtd: float) -> void:
    current_health = clampf(current_health - qtd, 0.0, max_health)
    _pintar_vida()


## Mostra a barra do alvo por alguns segundos. Chamada por quem leva o dano.
func mostrar_alvo(nome: String, vida: float, vida_maxima: float) -> void:
    if _alvo_caixa == null:
        return
    _alvo_caixa.visible = true
    _alvo_some_em = 4.0
    _alvo_nome.text = nome
    var largura: float = BURACOS["alvo"].size.x * 300.0
    var fracao: float = 0.0 if vida_maxima <= 0.0 else vida / vida_maxima
    _alvo_cheio.size.x = largura * clampf(fracao, 0.0, 1.0)
