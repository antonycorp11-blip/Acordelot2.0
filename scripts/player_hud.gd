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
    # TELA CHEIA, e a primeira coisa.
    #
    # O no vinha da cena com ancoragem zero — um retangulo de largura zero no
    # canto de cima a esquerda. Tudo aqui dentro que se ancora a DIREITA
    # resolvia contra essa largura zero e ia parar do lado errado da tela: era
    # por isso que a mochila e a engrenagem apareciam no meio do celular do
    # dono, e no computador nem apareciam.
    set_anchors_preset(Control.PRESET_FULL_RECT)
    # O painel em si nao come toque — senao ele engoliria o dedo em toda a
    # metade de cima da tela. Os botoes dentro dele pedem o toque por conta.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    add_to_group("player_hud")

    _montar_retrato_e_barras()
    # A BARRA DO ALVO FOI EMBORA.
    #
    # Com a barra sobre a cabeca do bicho, esta virou a terceira barra de vida
    # do mesmo inimigo na tela ao mesmo tempo — uma no alto, uma na cabeca e o
    # numero. Tres formas de dizer a mesma coisa e ruido, e a da cabeca e a que
    # o olho ja procura, porque esta onde a briga acontece.


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
    # O ROSTO E O DO AKLES, recortado da folha de retratos do dialogo.
    #
    # A miniatura antiga era um rosto generico que veio junto da moldura: nao
    # era o personagem, e o jogador percebe. A folha do dialogo ja tem o Akles
    # em dez expressoes; a neutra e a primeira da grade de cinco por dois.
    var moldura_retrato := _moldura("res://textures/ui/retrato.png",
        Vector2(LADO_DO_RETRATO, LADO_DO_RETRATO * 265.0 / 254.0), canto)
    moldura_retrato.position = Vector2.ZERO

    var folha := load("res://textures/dialogo/akles.png") as Texture2D
    if folha:
        var corte := AtlasTexture.new()
        corte.atlas = folha
        # So a cabeca e os ombros: a celula inteira e rosto e tronco, e o tronco
        # nao cabe numa miniatura redonda.
        var celula := Vector2(folha.get_width() / 5.0, folha.get_height() / 2.0)
        # Recorte QUADRADO em volta da cabeca. A faixa alta e estreita que
        # estava aqui, esticada num quadro quadrado, cortava o queixo e deixava
        # so os olhos: a celula da folha e rosto E tronco, e o tronco nao cabe
        # numa miniatura redonda.
        # Quadrado em volta da cabeca, com as fracoes MEDIDAS na folha: a
        # silhueta do Akles ocupa de 14,7% a 93,1% da largura da celula, e a
        # cabeca vai de 16,7% a 47,9% da altura. Chutar isso foi o que deu
        # barba ocupando a medalha inteira.
        corte.region = Rect2(celula.x * 0.147, celula.y * 0.115,
                             celula.x * 0.784, celula.y * 0.416)

        var rosto := TextureRect.new()
        rosto.texture = corte
        rosto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        rosto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        # Dentro do buraco da moldura, que nao ocupa a arte inteira.
        # Dentro do circulo da moldura, medido na propria arte: o buraco fica
        # centrado a 45% da largura e 42% da altura, com raio de um terco.
        # Centrado no buraco da moldura, que fica a 45% da largura e 42% da
        # altura da arte, com raio de um terco do lado.
        var lado_rosto := LADO_DO_RETRATO * 0.62
        rosto.size = Vector2(lado_rosto, lado_rosto)
        rosto.position = Vector2(LADO_DO_RETRATO * 0.45, LADO_DO_RETRATO * 0.42) - rosto.size * 0.5
        rosto.mouse_filter = Control.MOUSE_FILTER_IGNORE
        canto.add_child(rosto)
        # POR CIMA da moldura, e nao atras: a arte traz um rosto generico
        # pintado e opaco, e por baixo o Akles nunca apareceria. Como o recorte
        # tem fundo transparente — o magenta ja saiu dele — nao ha canto
        # quadrado para a moldura precisar esconder.

    # O NUMERO VAI EM CIMA DA MEDALHA QUE A ARTE JA TEM.
    #
    # A tentativa de desenhar um disco proprio ao lado dela deixou DOIS numeros
    # de nivel na tela — o da arte e o meu. A moldura ja traz a medalha
    # desenhada no pe do retrato; o que faltava era acertar onde ela cai, e a
    # medida saiu do proprio quadro: quarenta e quatro por cento da largura,
    # oitenta e dois por cento da altura.
    # O NUMERO 18 ESTA PINTADO NA ARTE.
    #
    # A medalha no pe do retrato nao e um espaco vazio esperando texto: ela vem
    # com um dezoito desenhado dentro, e nenhuma linha de codigo apaga tinta.
    # Por isso vai um disco escuro EM CIMA dela, do tamanho dela, e o nivel de
    # verdade por cima do disco. As medidas saem da imagem: a medalha esta
    # centrada a 84,5% da largura e 87% da altura.
    var medalha := Panel.new()
    var disco := StyleBoxFlat.new()
    disco.bg_color = Color(0.08, 0.07, 0.05, 1.0)
    disco.border_color = Color(0.80, 0.64, 0.30)
    disco.set_border_width_all(2)
    disco.set_corner_radius_all(int(LADO_DO_RETRATO * 0.15))
    medalha.add_theme_stylebox_override("panel", disco)
    medalha.size = Vector2(LADO_DO_RETRATO * 0.30, LADO_DO_RETRATO * 0.30)
    medalha.position = Vector2(LADO_DO_RETRATO * 0.845, LADO_DO_RETRATO * 0.87) - medalha.size * 0.5
    medalha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(medalha)

    var nivel := Label.new()
    nivel.position = medalha.position
    nivel.size = medalha.size
    nivel.text = str(player_level)
    nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nivel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    nivel.add_theme_font_size_override("font_size", 16)
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
    # AO LADO DO MAPA, no alto — o lugar padrao deste tipo de botao em jogo de
    # celular, e agora ele esta livre: o relogio do dia virou anel em volta do
    # minimapa e desocupou a faixa de cima.
    #
    # Por OFFSET e nao por position: com ancora num canto, "position" continua
    # medida a partir do canto de cima a esquerda do pai, e era isso que jogava
    # os dois para fora da tela.
    var lado := 62.0
    var topo := 20.0

    var inventario := _botao("res://textures/ui/btn_inventario.png", lado)
    inventario.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
    inventario.offset_left = -246.0 - lado
    inventario.offset_right = -246.0
    inventario.offset_top = topo
    inventario.offset_bottom = topo + lado
    inventario.pressed.connect(func(): mochila_pedida.emit())
    add_child(inventario)

    var config := _botao("res://textures/ui/btn_config.png", lado)
    config.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
    # AO LADO, na mesma fileira: empilhada embaixo ela descia para a altura do
    # anel do relogio e disputava espaco com ele.
    config.offset_left = -246.0 - lado * 2.0 - 10.0
    config.offset_right = -246.0 - lado - 10.0
    config.offset_top = topo
    config.offset_bottom = topo + lado
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
## Mantida so para nao quebrar quem chama: quem mostra a vida do inimigo agora
## e a barra sobre a cabeca dele, no proprio mundo.
func mostrar_alvo(_nome: String, _vida: float, _vida_maxima: float) -> void:
    return


func _mostrar_alvo_antigo(nome: String, vida: float, vida_maxima: float) -> void:
    if _alvo_caixa == null:
        return
    _alvo_caixa.visible = true
    _alvo_some_em = 4.0
    _alvo_nome.text = nome
    var largura: float = BURACOS["alvo"].size.x * 300.0
    var fracao: float = 0.0 if vida_maxima <= 0.0 else vida / vida_maxima
    _alvo_cheio.size.x = largura * clampf(fracao, 0.0, 1.0)
