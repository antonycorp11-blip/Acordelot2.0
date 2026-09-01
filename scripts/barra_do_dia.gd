extends Control
## O relogio do mundo, desenhado como ANEL em volta do minimapa.
##
## Era uma barra reta no alto da tela, e ela ocupava justamente a faixa onde os
## botoes de menu precisam morar em jogo de celular. Como anel, a mesma
## informacao passa a caber no espaco que o minimapa ja gastava — e fica melhor
## do que era: o ciclo do dia E um circulo, e um ponteiro dando a volta le como
## relogio sem precisar de legenda.
##
## Meia volta e dia, meia volta e noite. O ponteiro anda em tempo real; a hora
## em numero fica embaixo, para quem quiser precisao.

## O sol nasce as seis e se poe as dezoito — as mesmas horas que o ciclo usa
## para virar a luz.
const NASCE := 6.0
const POE := 18.0

const COR_DO_DIA := Color(0.98, 0.82, 0.38)
const COR_DA_NOITE := Color(0.24, 0.30, 0.58)
const COR_DO_PONTEIRO := Color(1.0, 0.99, 0.92)
const COR_DO_FUNDO := Color(0.0, 0.0, 0.0, 0.45)

## O anel corre POR FORA da moldura do minimapa, que tem 170 de lado.
const RAIO := 96.0
const GROSSURA := 7.0
const RAIO_DO_PONTEIRO := 6.0

@export var ciclo: Node

var _fonte: Font


func _ready() -> void:
    _fonte = ThemeDB.fallback_font
    mouse_filter = Control.MOUSE_FILTER_IGNORE


## O ANEL SO SE REDESENHA QUANDO O PONTEIRO ANDA.
##
## Ele pedia redesenho a cada quadro, e o desenho sao tres arcos de 64, 48 e 48
## segmentos — cento e sessenta pedacos de linha remontados sessenta vezes por
## segundo. O dia inteiro dura oito minutos: o ponteiro anda tres quartos de grau
## por segundo. Redesenhar a cada quadro era pintar a mesma imagem.
##
## Um centesimo de hora e cerca de um quinto de segundo de jogo — cinco
## redesenhos por segundo no maximo, e o ponteiro continua andando liso.
const HORA_QUE_IMPORTA := 0.01

var _hora_desenhada := -99.0

func _process(_delta: float) -> void:
    if ciclo == null:
        return
    var agora := float(ciclo.hora)
    if absf(agora - _hora_desenhada) < HORA_QUE_IMPORTA:
        return
    _hora_desenhada = agora
    queue_redraw()


## O centro do anel PERGUNTA ao minimapa onde ele esta.
##
## Antes eram numeros copiados da pilha do minimapa — titulo, tier e o radar de
## 170 — e bastava alguem mexer numa fonte ou num espacamento de la para o anel
## sair do lugar, que foi o que aconteceu. Agora o proprio radar informa o
## retangulo dele, e o anel se encaixa sozinho.
var _radar: Control = null

func _centro() -> Vector2:
    if _radar == null or not is_instance_valid(_radar):
        var mapa := get_parent().find_child("ZoneMinimap", true, false)
        if mapa:
            for filho in mapa.find_children("*", "Control", true, false):
                # O radar e o unico quadrado de 170 da pilha.
                if absf(filho.size.x - 170.0) < 2.0 and absf(filho.size.y - 170.0) < 2.0:
                    _radar = filho
                    break
    if _radar and is_instance_valid(_radar):
        return _radar.get_global_rect().get_center() - get_global_rect().position
    return size * 0.5


func _draw() -> void:
    if ciclo == null:
        return

    var centro := _centro()
    var hora: float = float(ciclo.hora)

    # As duas metades. O zero do desenho fica no ALTO (meia-noite) e o giro segue
    # o sentido do relogio, que e como todo mundo le um mostrador.
    var inicio_dia := _angulo(NASCE)
    var fim_dia := _angulo(POE)

    draw_arc(centro, RAIO, 0.0, TAU, 64, COR_DO_FUNDO, GROSSURA + 4.0, true)
    draw_arc(centro, RAIO, inicio_dia, fim_dia, 48, COR_DO_DIA, GROSSURA, true)
    draw_arc(centro, RAIO, fim_dia, inicio_dia + TAU, 48, COR_DA_NOITE, GROSSURA, true)

    # O ponteiro: um disco claro com um miolo escuro, para nao sumir sobre o
    # amarelo do dia nem sobre o azul da noite.
    var ponta := centro + Vector2.from_angle(_angulo(hora)) * RAIO
    draw_circle(ponta, RAIO_DO_PONTEIRO + 2.0, Color(0.05, 0.04, 0.02, 0.9))
    draw_circle(ponta, RAIO_DO_PONTEIRO, COR_DO_PONTEIRO)

    # SEM NUMERO. O anel ja diz onde no dia o jogador esta, e o texto caia
    # exatamente sobre o botao do mapa logo abaixo do minimapa.


## Hora do dia para angulo de desenho: meia-noite no alto, sentido horario.
func _angulo(hora: float) -> float:
    return -PI * 0.5 + (fposmod(hora, 24.0) / 24.0) * TAU
