extends Control
class_name PlayerHUD
## O painel do jogador: retrato, vida, experiencia e a barra do alvo.
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
@export var player_level: int = 1

## O buraco de cada moldura, em fracao da imagem. Medido no proprio arquivo
## depois do recorte — nao chute.
const BURACOS := {
    "vida": Rect2(0.0189, 0.30, 0.9623, 0.60),
    "xp": Rect2(0.0189, 0.1304, 0.9623, 0.7391),
}

const LARGURA_DA_BARRA := 232.0
const LADO_DO_RETRATO := 78.0

var _hp_fundo: ColorRect
var _hp_cheio: ColorRect
var _hp_label: Label
var _xp_cheio: ColorRect
var _xp_label: Label
var _nivel_label: Label
var _poder_label: Label
## Quanto tempo sem apanhar antes de a vida voltar a subir, e o quanto ela sobe.
const ESPERA_PARA_REGENERAR := 6.0
const REGENERACAO_POR_SEGUNDO := 0.045

## CADA HEROI TEM O SEU PROPRIO FOLEGO.
##
## Ate aqui a barra era UMA so: trocar de personagem no meio da briga levava a
## vida junto, e a troca virava um botao de nada — o mesmo corpo com outra
## roupa. Com a vida separada, trocar passa a ser uma decisao: quem entra chega
## inteiro, quem sai leva o estrago consigo e so se refaz descansando.
##
## O tamanho do folego tambem muda com quem esta em campo. Akles e o corpo que
## apara golpe; Wins canta a alguns passos de distancia e paga por isso com
## menos vida. Os atributos da conta continuam sendo os mesmos para os dois — o
## que muda e o fator aplicado sobre eles.
const FATOR_DE_VIDA := {"akles": 1.0, "wins": 0.82}
## A vida de quem esta fora de campo, guardada como FRACAO da vida cheia dele.
## Fracao, e nao numero absoluto: subir de nivel entre uma troca e outra nao
## pode devolver nem roubar folego de quem estava esperando.
var _vida_guardada := {}
## A barrinha de vida da reserva, desenhada no proprio botao de trocar. Sem ela
## a troca e as cegas: o jogador so descobre que o outro esta em farrapos depois
## de ja estar com ele em campo.
var _barra_reserva: ColorRect = null

## Avisa quem cuida do mundo que a vida chegou a zero.
signal caiu

var _ultimo_dano_em := 0.0
var _escudo := 0.0
var _escudo_ate := 0.0

var _botao_missoes: Button
var _botao_personagem: Button
var _selo_missoes: Label
var _personagem_atual := "akles"
var _medalha: Panel

signal config_pedida
signal mochila_pedida
signal missoes_pedidas


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
    var progresso := get_node_or_null("/root/Progresso")
    if progresso:
        if not progresso.alterado.is_connected(_atualizar_progressao):
            progresso.alterado.connect(_atualizar_progressao)
        _atualizar_progressao()
    # A BARRA DO ALVO FOI EMBORA.
    #
    # Com a barra sobre a cabeca do bicho, esta virou a terceira barra de vida
    # do mesmo inimigo na tela ao mesmo tempo — uma no alto, uma na cabeca e o
    # numero. Tres formas de dizer a mesma coisa e ruido, e a da cabeca e a que
    # o olho ja procura, porque esta onde a briga acontece.


## So corre enquanto ha escudo para expirar. A HUD passa a maior parte da partida
## sem nada a fazer por quadro, e um _process ligado o tempo todo para conferir
## um cronometro parado e custo puro num aparelho que ja esta no limite.
func _process(delta: float) -> void:
    var agora := Time.get_ticks_msec() / 1000.0
    if _escudo > 0.0 and agora >= _escudo_ate:
        _escudo = 0.0
        _pintar_vida()

    # A HARMONIA SE REFAZ SOZINHA FORA DA BRIGA.
    #
    # Ate aqui existia UMA fonte de cura no jogo inteiro: roubo de vida enquanto
    # a aura azul estava ligada. Com o dano do bicho passando a valer, o jogador
    # sangrava e nao tinha resposta nenhuma — so morrer, sem nem existir morte.
    # A regeneracao so comeca depois de alguns segundos sem apanhar, entao ela
    # nao apaga o perigo do combate: ela devolve o jogo depois dele.
    var descansando: bool = agora - _ultimo_dano_em >= ESPERA_PARA_REGENERAR
    if current_health > 0.0 and current_health < max_health and descansando:
        current_health = minf(current_health + max_health * REGENERACAO_POR_SEGUNDO * delta, max_health)
        _pintar_vida()

    # QUEM ESPERA TAMBEM SE REFAZ, pela metade.
    #
    # Sem isto, o heroi que saiu de campo machucado ficaria machucado para
    # sempre e trocar de personagem seria um caminho so — o jogador aprenderia a
    # nunca mais tocar no botao. Pela metade, e nao igual, para descansar em
    # campo continuar valendo mais do que revezar.
    var reserva := "wins" if _personagem_atual == "akles" else "akles"
    var guardada: float = float(_vida_guardada.get(reserva, 1.0))
    if descansando and guardada < 1.0:
        _vida_guardada[reserva] = minf(
            guardada + REGENERACAO_POR_SEGUNDO * 0.5 * delta, 1.0)
        _pintar_reserva()
        return

    if _escudo <= 0.0 and (current_health >= max_health or current_health <= 0.0):
        set_process(false)


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
    # A MINIATURA E A ARTE NOVA DO AKLES, e nada da antiga fica atras.
    #
    # A moldura do kit vinha com um rosto generico PINTADO nela — nao era o
    # personagem, e ficava aparecendo por baixo de qualquer recorte que se
    # pusesse em cima. Entao a moldura sai de cena: no lugar dela, um disco
    # escuro com aro dourado desenhado aqui, o rosto do Akles por cima e nada
    # mais. Um elemento, uma camada, sem nada herdado por baixo.
    var aro := Panel.new()
    var borda := StyleBoxFlat.new()
    borda.bg_color = Color(0.06, 0.05, 0.09, 1.0)
    borda.border_color = Color(0.78, 0.62, 0.30)
    borda.set_border_width_all(3)
    borda.set_corner_radius_all(int(LADO_DO_RETRATO * 0.5))
    aro.add_theme_stylebox_override("panel", borda)
    aro.size = Vector2(LADO_DO_RETRATO, LADO_DO_RETRATO)
    aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(aro)

    # A FOLHA DO AKLES, e nao a de outro personagem.
    #
    # Errei aqui: peguei a arte do Renaldo, que chegou na mesma leva, e pus a
    # cara dele no retrato do heroi. Quem manda na miniatura e a folha de
    # expressoes do Akles — a mesma que o dialogo usa, de cinco por dois.
    var folha := load("res://textures/dialogo/akles_corpo.png") as Texture2D
    if folha:
        var corte := AtlasTexture.new()
        corte.atlas = folha
        var l := float(folha.get_width())
        var a := float(folha.get_height())
        # Quadrado em volta da cabeca, MEDIDO na arte: centro em (534, 133) de
        # uma imagem de 1086 por 1448, lado de 204 pixels ja com folga para o
        # cabelo. Chutar essas fracoes foi o que encheu a medalha de barba na
        # primeira tentativa.
        corte.region = Rect2(l * 0.3978, a * 0.0214, l * 0.1878, a * 0.1409)

        var rosto := TextureRect.new()
        rosto.texture = corte
        rosto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        rosto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        rosto.size = Vector2(LADO_DO_RETRATO - 8.0, LADO_DO_RETRATO - 8.0)
        rosto.position = Vector2(4.0, 4.0)
        rosto.mouse_filter = Control.MOUSE_FILTER_IGNORE
        canto.add_child(rosto)

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
    _medalha = medalha

    _nivel_label = Label.new()
    _nivel_label.position = medalha.position
    _nivel_label.size = medalha.size
    _nivel_label.text = str(player_level)
    _nivel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _nivel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _nivel_label.add_theme_font_size_override("font_size", 16)
    _nivel_label.add_theme_color_override("font_color", Color(1, 1, 1))
    _nivel_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 0.95))
    _nivel_label.add_theme_constant_override("outline_size", 4)
    _nivel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(_nivel_label)

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

    # A segunda barra e experiencia. O jogo nao tem mana.
    var t_xp := Vector2(LARGURA_DA_BARRA, LARGURA_DA_BARRA * 46.0 / 424.0)
    var caixa_xp := Control.new()
    caixa_xp.position = Vector2(LADO_DO_RETRATO - 6.0, 8.0 + t_vida.y + 2.0)
    caixa_xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(caixa_xp)

    var partes_xp := _preencher(BURACOS["xp"], t_xp,
        Color(0.18, 0.52, 0.92), caixa_xp)
    _xp_cheio = partes_xp[1]
    _moldura("res://textures/ui/kit/barra_exp.png", t_xp, caixa_xp)
    _xp_label = _numero(t_xp, BURACOS["xp"], 11, caixa_xp)

    _poder_label = Label.new()
    _poder_label.position = Vector2(LADO_DO_RETRATO, 8.0 + t_vida.y + t_xp.y + 13.0)
    _poder_label.size = Vector2(LARGURA_DA_BARRA, 24)
    _poder_label.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    _poder_label.add_theme_font_size_override("font_size", 12)
    _poder_label.add_theme_color_override("font_color", Color(0.95, 0.79, 0.38))
    _poder_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    _poder_label.add_theme_constant_override("outline_size", 3)
    _poder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canto.add_child(_poder_label)

    _pintar_vida()
    _pintar_xp()

    _montar_coluna_de_utilitarios()


## QUATRO BOTOES REDONDOS, NUMA FILEIRA SO, LOGO ABAIXO DO MINIMAPA.
##
## Antes eram tres coisas em tres lugares e formatos: a troca de personagem era
## uma placa retangular larga na coluna do minimapa, "Missoes" era outra placa
## logo abaixo, e mochila e engrenagem eram dois quadrados mais embaixo ainda. O
## jogador tinha de aprender tres desenhos diferentes para a mesma ideia — "aqui
## eu abro alguma coisa".
##
## Agora sao quatro discos do mesmo tamanho, lado a lado, no canto de cima a
## direita: personagem, missoes, mochila e ajustes. Redondo tambem e o formato
## certo para o polegar, que nao acerta quina.
##
## A ENGRENAGEM CONTINUA LONGE DA BARRA DE VIDA. Ela vivia a -380 px da borda
## direita, e a tela do jogo estica em LARGURA: em celular deitado o bloco do
## jogador crescia para a direita e alcancava exatamente essa faixa.
func _montar_coluna_de_utilitarios() -> void:
    var lado := 54.0

    # OS TRES DE ABRIR TELA FICAM A ESQUERDA DO MAPA, NO ALTO.
    #
    # Embaixo do minimapa cabe uma coisa so, e essa coisa e o personagem: e o
    # unico botao que muda o que esta em campo, e faz sentido junto do radar que
    # mostra onde ele esta. Missoes, mochila e ajustes abrem tela — vao para a
    # faixa livre a esquerda do disco, onde nada mais disputa espaco em nenhuma
    # proporcao de tela (o bloco de vida termina por volta de 324 px).
    var fileira := HBoxContainer.new()
    fileira.anchor_left = 1.0
    fileira.anchor_right = 1.0
    fileira.anchor_top = 0.0
    fileira.anchor_bottom = 0.0
    fileira.offset_right = -226.0
    fileira.offset_left = -226.0 - (lado * 3.0 + 16.0)
    fileira.offset_top = 22.0
    fileira.offset_bottom = 22.0 + lado
    fileira.alignment = BoxContainer.ALIGNMENT_END
    fileira.add_theme_constant_override("separation", 8)
    add_child(fileira)

    _botao_missoes = _botao_redondo(lado, "res://textures/ui/kit/nav/missoes.png")
    _botao_missoes.pressed.connect(func(): missoes_pedidas.emit())
    fileira.add_child(_botao_missoes)

    # O contador vira SELO no canto do disco: "0/3" dentro de um botao redondo
    # de 54 px nao cabe como texto.
    _selo_missoes = Label.new()
    _selo_missoes.text = "0/3"
    _selo_missoes.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
    _selo_missoes.offset_left = -lado + 6.0
    _selo_missoes.offset_right = -5.0
    _selo_missoes.offset_top = -21.0
    _selo_missoes.offset_bottom = -3.0
    _selo_missoes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _selo_missoes.add_theme_font_size_override("font_size", 13)
    _selo_missoes.add_theme_color_override("font_color", Color(0.98, 0.90, 0.66))
    _selo_missoes.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
    _selo_missoes.add_theme_constant_override("outline_size", 4)
    _selo_missoes.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _botao_missoes.add_child(_selo_missoes)

    var mochila := _botao_redondo(lado, "res://textures/ui/btn_inventario.png")
    mochila.pressed.connect(func(): mochila_pedida.emit())
    fileira.add_child(mochila)

    var config := _botao_redondo(lado, "res://textures/ui/btn_config_novo.png")
    config.pressed.connect(func(): config_pedida.emit())
    fileira.add_child(config)

    # E, SOZINHO, EMBAIXO DO MAPA: o personagem. Centrado com o disco do radar,
    # que ocupa de -215 a -15 da borda direita, e abaixo do anel do dia.
    _botao_personagem = _botao_redondo(lado)
    _botao_personagem.anchor_left = 1.0
    _botao_personagem.anchor_right = 1.0
    _botao_personagem.anchor_top = 0.0
    _botao_personagem.anchor_bottom = 0.0
    _botao_personagem.offset_left = -115.0 - lado * 0.5
    _botao_personagem.offset_right = -115.0 + lado * 0.5
    _botao_personagem.offset_top = 262.0
    _botao_personagem.offset_bottom = 262.0 + lado
    _botao_personagem.pressed.connect(_trocar_personagem)
    add_child(_botao_personagem)

    _pintar_botao_personagem(_personagem_atual)
    _ligar_o_diario()
    _ligar_troca_de_personagem()


## A HUD PRECISA SABER A HORA DA TROCA — e nao pode depender do Diario para
## isso. Esta ligacao morava dentro de `_ligar_o_diario`, que sai fora quando o
## autoload do diario nao existe; com a vida separada por personagem, perder
## este sinal significa a barra continuar mostrando o folego de quem saiu.
## O jogador tambem pode nascer depois da HUD, entao tenta de novo no quadro
## seguinte enquanto nao achar.
func _ligar_troca_de_personagem() -> void:
    var jogador := get_tree().get_first_node_in_group("jogador")
    if jogador == null or not jogador.has_signal("personagem_trocado"):
        call_deferred("_ligar_troca_de_personagem")
        return
    if not jogador.personagem_trocado.is_connected(_ao_trocar_personagem):
        jogador.personagem_trocado.connect(_ao_trocar_personagem)


## Um disco: aro dourado, fundo navy, arte no meio. E a mesma placa dos botoes do
## minimapa, so que redonda — nenhum estilo novo entra na HUD por isto.
func _botao_redondo(lado: float, arte := "") -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(lado, lado)
    b.focus_mode = Control.FOCUS_NONE
    var placa := StyleBoxFlat.new()
    placa.bg_color = Color(0.035, 0.09, 0.17, 0.94)
    placa.border_color = Color(0.76, 0.60, 0.28, 0.95)
    placa.set_border_width_all(2)
    placa.set_corner_radius_all(int(lado * 0.5))
    b.add_theme_stylebox_override("normal", placa)
    var apertada := placa.duplicate() as StyleBoxFlat
    apertada.bg_color = Color(0.12, 0.32, 0.52, 0.98)
    b.add_theme_stylebox_override("pressed", apertada)
    b.add_theme_stylebox_override("hover", placa)
    b.add_theme_stylebox_override("focus", placa)
    if arte != "" and ResourceLoader.exists(arte):
        var icone := TextureRect.new()
        icone.texture = load(arte)
        icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icone.set_anchors_preset(Control.PRESET_FULL_RECT)
        icone.offset_left = 6.0
        icone.offset_top = 6.0
        icone.offset_right = -6.0
        icone.offset_bottom = -6.0
        icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(icone)
    return b


func _trocar_personagem() -> void:
    var jogador := get_tree().get_first_node_in_group("jogador")
    if jogador and jogador.has_method("trocar_personagem"):
        jogador.trocar_personagem()


## O RETRATO DE QUEM ENTRA, nao de quem esta em campo: o botao mostra para quem
## se troca. Akles tem folha de expressoes e vira miniatura de verdade; a Wins
## ainda nao tem — enquanto nao houver, entra o icone de personagem do kit, que
## e honesto e nao finge um rosto.
func _pintar_botao_personagem(atual: String) -> void:
    if _botao_personagem == null:
        return
    for filho in _botao_personagem.get_children():
        filho.queue_free()
    var destino := "wins" if atual == "akles" else "akles"
    var arte: Texture2D = null
    if destino == "akles":
        var folha := load("res://textures/dialogo/akles_corpo.png") as Texture2D
        if folha:
            var corte := AtlasTexture.new()
            corte.atlas = folha
            var l := float(folha.get_width())
            var a := float(folha.get_height())
            corte.region = Rect2(l * 0.3978, a * 0.0214, l * 0.1878, a * 0.1409)
            arte = corte
    else:
        arte = load("res://textures/ui/kit/nav/personagem.png") as Texture2D
    if arte != null:
        var rosto := TextureRect.new()
        rosto.texture = arte
        rosto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        rosto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        rosto.set_anchors_preset(Control.PRESET_FULL_RECT)
        rosto.offset_left = 4.0
        rosto.offset_top = 4.0
        rosto.offset_right = -4.0
        rosto.offset_bottom = -4.0
        rosto.mouse_filter = Control.MOUSE_FILTER_IGNORE
        rosto.tooltip_text = "Trocar para " + ("Wins" if destino == "wins" else "Akles")
        _botao_personagem.add_child(rosto)
    _montar_barra_da_reserva()


## A VIDA DE QUEM ESTA ESPERANDO, no proprio botao de troca.
##
## Uma tira fina no pe do disco. Com a vida separada por personagem, tocar em
## trocar sem saber como o outro esta seria apostar — e a aposta que sai errada
## e cair no quadro seguinte.
func _montar_barra_da_reserva() -> void:
    if _botao_personagem == null:
        return
    var trilho := ColorRect.new()
    trilho.color = Color(0.05, 0.03, 0.05, 0.85)
    trilho.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    trilho.offset_left = 8.0
    trilho.offset_right = -8.0
    trilho.offset_top = -11.0
    trilho.offset_bottom = -4.0
    trilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _botao_personagem.add_child(trilho)

    _barra_reserva = ColorRect.new()
    _barra_reserva.color = Color(0.55, 0.86, 0.62)
    _barra_reserva.set_anchors_preset(Control.PRESET_FULL_RECT)
    _barra_reserva.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trilho.add_child(_barra_reserva)
    _pintar_reserva()


func _pintar_reserva() -> void:
    if _barra_reserva == null or not is_instance_valid(_barra_reserva):
        return
    var reserva := "wins" if _personagem_atual == "akles" else "akles"
    var fracao: float = clampf(float(_vida_guardada.get(reserva, 1.0)), 0.0, 1.0)
    _barra_reserva.anchor_right = fracao
    _barra_reserva.color = Color(0.55, 0.86, 0.62) if fracao > 0.45 \
        else (Color(0.94, 0.78, 0.30) if fracao > 0.2 else Color(0.88, 0.28, 0.26))


func _ao_trocar_personagem(id: String, _nome: String) -> void:
    if id != _personagem_atual:
        _vida_guardada[_personagem_atual] = 0.0 if max_health <= 0.0 \
            else clampf(current_health / max_health, 0.0, 1.0)
        _personagem_atual = id
        max_health = _vida_maxima_de(id)
        # Nunca abaixo de um sopro: quem entra em campo tem de poder levar ao
        # menos um golpe antes de cair, senao a troca vira morte instantanea.
        current_health = clampf(
            float(_vida_guardada.get(id, 1.0)) * max_health, 1.0, max_health)
        _pintar_vida()
        set_process(true)
    _pintar_botao_personagem(id)
    _atualizar_progressao()


## A vida cheia DAQUELE heroi: o numero da conta vezes o fator dele.
func _vida_maxima_de(id: String) -> float:
    var base := 1000.0
    var progresso := get_node_or_null("/root/Progresso")
    if progresso and progresso.has_method("estatisticas"):
        base = float(progresso.estatisticas().get("vida_maxima", base))
    return maxf(1.0, base * float(FATOR_DE_VIDA.get(id, 1.0)))


## O contador 0/3 na propria HUD.
##
## Sem ele o jogador so descobre que fechou o dia se abrir a tela — e uma tarefa
## diaria que nao aparece na tela principal e uma tarefa que ninguem faz.
func _ligar_o_diario() -> void:
    var diario := get_node_or_null("/root/Diario")
    if diario == null:
        return
    if not diario.alterado.is_connected(_pintar_missoes):
        diario.alterado.connect(_pintar_missoes)
    _pintar_missoes()


func _pintar_missoes() -> void:
    var diario := get_node_or_null("/root/Diario")
    if diario == null or _selo_missoes == null:
        return
    var feitas: int = diario.concluidas()
    var total: int = diario.missoes.size()
    _selo_missoes.text = "%d/%d" % [feitas, total]
    _selo_missoes.add_theme_color_override("font_color",
        Color(0.62, 0.95, 0.62) if total > 0 and feitas >= total else Color(0.98, 0.90, 0.66))


func _botao(caminho: String, lado: float) -> TextureButton:
    var b := TextureButton.new()
    b.texture_normal = load(caminho)
    b.ignore_texture_size = true
    b.stretch_mode = TextureButton.STRETCH_SCALE
    b.custom_minimum_size = Vector2(lado, lado)
    b.size = Vector2(lado, lado)
    return b


# -------------------------------------------------------------------- estado

func _pintar_vida() -> void:
    if _hp_cheio == null:
        return
    var fracao: float = 0.0 if max_health <= 0.0 else current_health / max_health
    _hp_cheio.size.x = _hp_fundo.size.x * clampf(fracao, 0.0, 1.0)
    if _hp_label:
        _hp_label.text = "%d / %d%s" % [int(current_health), int(max_health),
            "  +%d" % int(_escudo) if _escudo > 0.0 else ""]


func _pintar_xp() -> void:
    if _xp_cheio == null:
        return
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    var largura: float = BURACOS["xp"].size.x * LARGURA_DA_BARRA
    var necessario: float = float(progresso.xp_para_nivel())
    var fracao: float = 0.0 if necessario <= 0.0 else float(progresso.experiencia) / necessario
    _xp_cheio.size.x = largura * clampf(fracao, 0.0, 1.0)
    if _xp_label == null:
        return
    # SUBIR DE NIVEL E MANUAL neste jogo — quem sobe e o botao da ficha. Sem um
    # aviso aqui, o jogador acumulava XP suficiente e nunca ficava sabendo:
    # a unica pista morava dentro de uma tela que ele nao tinha motivo de abrir.
    if progresso.pode_subir_nivel():
        _xp_label.text = "PRONTO PARA SUBIR DE NÍVEL"
        _xp_label.add_theme_color_override("font_color", Color(0.66, 1.0, 0.62))
        _acender_medalha(true)
    else:
        _xp_label.text = "%d / %d XP" % [progresso.experiencia, int(necessario)]
        _xp_label.add_theme_color_override("font_color", Color(1, 1, 1))
        _acender_medalha(false)


## A medalha do nivel acende junto com o aviso da barra: dois sinais no mesmo
## canto, para o recado nao depender de o jogador estar lendo o texto pequeno.
func _acender_medalha(pronto: bool) -> void:
    if _medalha == null:
        return
    var disco := _medalha.get_theme_stylebox("panel") as StyleBoxFlat
    if disco == null:
        return
    disco.border_color = Color(0.55, 1.0, 0.52) if pronto else Color(0.80, 0.64, 0.30)
    disco.set_border_width_all(3 if pronto else 2)


func _atualizar_progressao() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    player_level = progresso.nivel
    if _nivel_label:
        _nivel_label.text = str(player_level)
    if _poder_label:
        _poder_label.text = "%s   ·   PODER  %s" % [
            "WINS" if _personagem_atual == "wins" else "AKLES",
            _milhar(progresso.poder_de_luta_da_conta())]
    var nova_vida := _vida_maxima_de(_personagem_atual)
    var estava_cheio := current_health >= max_health - 0.01
    max_health = nova_vida
    if estava_cheio or current_health > max_health:
        current_health = max_health
    _pintar_vida()
    _pintar_xp()


## O ANUNCIO DA LUTA.
##
## Quatro lugares ja chamavam `hud.anunciar` — as falas do Cavaleiro, o aviso de
## desafio iniciado, o de desafio encerrado e o do espolio de chefe — e o metodo
## nao existia. Todas passavam por `has_method`, entao nada quebrava: elas so
## nao aconteciam. O jogador matava o chefe e nada dizia o que tinha caido.
##
## A faixa entra abaixo do nome da zona (que vive na camada 100, a 80 px do
## topo) para as duas nao se sobreporem quando o jogador cruza uma divisa no
## meio da briga. Chamar de novo TROCA o texto e reinicia o relogio, em vez de
## empilhar faixa — numa luta de chefe as falas vem em rajada.
const SEGUNDOS_DO_ANUNCIO := 3.4

var _faixa: PanelContainer
var _faixa_texto: Label
var _tempo_da_faixa: Tween


func anunciar(texto: String) -> void:
    if texto.strip_edges().is_empty():
        return
    if _faixa == null or not is_instance_valid(_faixa):
        _montar_faixa()
    _faixa_texto.text = texto
    if _tempo_da_faixa and _tempo_da_faixa.is_valid():
        _tempo_da_faixa.kill()
    _faixa.visible = true
    _faixa.modulate.a = 0.0
    _tempo_da_faixa = create_tween()
    _tempo_da_faixa.tween_property(_faixa, "modulate:a", 1.0, 0.18)
    _tempo_da_faixa.tween_interval(SEGUNDOS_DO_ANUNCIO)
    _tempo_da_faixa.tween_property(_faixa, "modulate:a", 0.0, 0.45)
    _tempo_da_faixa.tween_callback(func():
        if is_instance_valid(_faixa):
            _faixa.visible = false)


func _montar_faixa() -> void:
    _faixa = PanelContainer.new()
    _faixa.name = "FaixaDoAnuncio"
    _faixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _faixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _faixa.offset_top = 158.0
    _faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _faixa.visible = false
    var moldura := StyleBoxFlat.new()
    moldura.bg_color = Color(0.02, 0.03, 0.07, 0.86)
    moldura.border_color = Color(0.76, 0.60, 0.28, 0.95)
    moldura.set_border_width_all(1)
    moldura.set_corner_radius_all(4)
    moldura.content_margin_left = 22
    moldura.content_margin_right = 22
    moldura.content_margin_top = 9
    moldura.content_margin_bottom = 9
    _faixa.add_theme_stylebox_override("panel", moldura)
    add_child(_faixa)

    _faixa_texto = Label.new()
    _faixa_texto.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    _faixa_texto.add_theme_font_size_override("font_size", 20)
    _faixa_texto.add_theme_color_override("font_color", Color(0.97, 0.87, 0.58))
    _faixa_texto.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
    _faixa_texto.add_theme_constant_override("outline_size", 4)
    _faixa_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _faixa_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _faixa.add_child(_faixa_texto)


## A BARRA DO CHEFE, no alto e no meio.
##
## A barra sobre a cabeca serve para o Shiker: ela vive onde a briga acontece e
## some junto com ele. Num chefe ela nao serve — o dono nao conseguia enxergar a
## dele. Chefe e uma luta longa contra UM alvo, e a barra dele pertence ao topo
## da tela, larga, com o nome e a forma ao lado. E o desenho que Genshin, Monster
## Hunter e Elden Ring usam pela mesma razao.
##
## As formas aparecem como marcas na propria barra: com duas formas ela vale
## metade cada, e ver a primeira acabar e o jogador entender que nao acabou.
const LARGURA_DA_BARRA_DE_CHEFE := 620.0

var _chefe: Control
var _chefe_nome: Label
var _chefe_cheio: ColorRect
var _chefe_numero: Label
var _chefe_formas := 1


func mostrar_chefe(nome: String, formas := 1) -> void:
    if _chefe == null or not is_instance_valid(_chefe):
        _montar_barra_de_chefe()
    _chefe_formas = maxi(formas, 1)
    _chefe_nome.text = nome.to_upper()
    _desenhar_marcas()
    _chefe.visible = true
    _chefe.modulate.a = 0.0
    create_tween().tween_property(_chefe, "modulate:a", 1.0, 0.35)


func atualizar_chefe(vida: float, vida_maxima: float, forma := 1) -> void:
    if _chefe == null or not is_instance_valid(_chefe) or not _chefe.visible:
        return
    # A barra mostra a luta INTEIRA, nao a forma atual: cada forma ocupa a sua
    # fatia. Sem isso ela enche de novo do zero e o jogador acha que perdeu todo
    # o progresso quando o chefe troca de forma.
    var fatia: float = 1.0 / float(_chefe_formas)
    var dentro: float = 0.0 if vida_maxima <= 0.0 else clampf(vida / vida_maxima, 0.0, 1.0)
    var restantes: float = float(_chefe_formas - forma)
    _chefe_cheio.anchor_right = clampf((restantes + dentro) * fatia, 0.0, 1.0)
    _chefe_numero.text = "%d / %d" % [int(maxf(vida, 0.0)), int(vida_maxima)]


func esconder_chefe() -> void:
    if _chefe == null or not is_instance_valid(_chefe):
        return
    var tw := create_tween()
    tw.tween_property(_chefe, "modulate:a", 0.0, 0.5)
    tw.tween_callback(func():
        if is_instance_valid(_chefe):
            _chefe.visible = false)


func _montar_barra_de_chefe() -> void:
    _chefe = Control.new()
    _chefe.name = "BarraDoChefe"
    _chefe.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _chefe.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _chefe.custom_minimum_size = Vector2(LARGURA_DA_BARRA_DE_CHEFE, 62)
    _chefe.size = Vector2(LARGURA_DA_BARRA_DE_CHEFE, 62)
    _chefe.position = Vector2(-LARGURA_DA_BARRA_DE_CHEFE * 0.5, 22.0)
    _chefe.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _chefe.visible = false
    add_child(_chefe)

    _chefe_nome = Label.new()
    _chefe_nome.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    _chefe_nome.add_theme_font_size_override("font_size", 22)
    _chefe_nome.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62))
    _chefe_nome.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.04, 0.95))
    _chefe_nome.add_theme_constant_override("outline_size", 5)
    _chefe_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _chefe_nome.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _chefe_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _chefe.add_child(_chefe_nome)

    var trilho := ColorRect.new()
    trilho.name = "Trilho"
    trilho.color = Color(0.05, 0.03, 0.05, 0.88)
    trilho.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    trilho.offset_top = -20.0
    trilho.offset_bottom = -4.0
    trilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _chefe.add_child(trilho)

    _chefe_cheio = ColorRect.new()
    _chefe_cheio.color = Color(0.80, 0.20, 0.24)
    _chefe_cheio.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    _chefe_cheio.offset_left = 2.0
    _chefe_cheio.offset_top = 2.0
    _chefe_cheio.offset_bottom = -2.0
    _chefe_cheio.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trilho.add_child(_chefe_cheio)

    var aro := Panel.new()
    var borda := StyleBoxFlat.new()
    borda.bg_color = Color(0, 0, 0, 0)
    borda.border_color = Color(0.76, 0.60, 0.28, 0.95)
    borda.set_border_width_all(1)
    aro.add_theme_stylebox_override("panel", borda)
    aro.set_anchors_preset(Control.PRESET_FULL_RECT)
    aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trilho.add_child(aro)

    _chefe_numero = Label.new()
    _chefe_numero.add_theme_font_size_override("font_size", 12)
    _chefe_numero.add_theme_color_override("font_color", Color(1, 1, 1))
    _chefe_numero.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02, 0.95))
    _chefe_numero.add_theme_constant_override("outline_size", 4)
    _chefe_numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _chefe_numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _chefe_numero.set_anchors_preset(Control.PRESET_FULL_RECT)
    _chefe_numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
    trilho.add_child(_chefe_numero)


func _desenhar_marcas() -> void:
    var trilho := _chefe.get_node_or_null("Trilho") as ColorRect
    if trilho == null:
        return
    for velho in trilho.get_children():
        if velho.name.begins_with("Marca"):
            velho.queue_free()
    for k in range(1, _chefe_formas):
        var marca := ColorRect.new()
        marca.name = "Marca%d" % k
        marca.color = Color(0.02, 0.01, 0.03, 0.95)
        marca.set_anchors_preset(Control.PRESET_LEFT_WIDE)
        marca.anchor_left = float(k) / float(_chefe_formas)
        marca.anchor_right = marca.anchor_left
        marca.offset_left = -1.5
        marca.offset_right = 1.5
        marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
        trilho.add_child(marca)


func curar(qtd: float) -> void:
    current_health = clampf(current_health + qtd, 0.0, max_health)
    _pintar_vida()


## Devolve os DOIS herois inteiros. Chamada por quem trata a queda.
##
## Nao so quem caiu: a reserva volta cheia junto. Sem isso, quem estivesse
## guardado em farrapos seria uma armadilha esperando o jogador tocar em trocar,
## e o preco da queda ja foi cobrado em Claves.
func reerguer() -> void:
    _vida_guardada.clear()
    max_health = _vida_maxima_de(_personagem_atual)
    current_health = max_health
    _escudo = 0.0
    _ultimo_dano_em = 0.0
    _pintar_vida()
    _pintar_reserva()


func tomar_dano(qtd: float) -> void:
    if current_health <= 0.0:
        return
    var absorvido := minf(_escudo, qtd)
    _escudo -= absorvido
    current_health = clampf(current_health - (qtd - absorvido), 0.0, max_health)
    _ultimo_dano_em = Time.get_ticks_msec() / 1000.0
    _pintar_vida()
    set_process(true)
    if current_health <= 0.0:
        caiu.emit()


func conceder_escudo(qtd: float) -> void:
    _escudo = maxf(_escudo, qtd)
    _escudo_ate = Time.get_ticks_msec() / 1000.0 + 8.0
    _pintar_vida()
    set_process(true)


## Mostra a barra do alvo por alguns segundos. Chamada por quem leva o dano.
## Mantida so para nao quebrar quem chama: quem mostra a vida do inimigo agora
## e a barra sobre a cabeca dele, no proprio mundo.
func mostrar_alvo(_nome: String, _vida: float, _vida_maxima: float) -> void:
    return


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
