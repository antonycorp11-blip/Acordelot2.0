extends Control
## A barra do topo: onde o dia esta e quanto falta para virar.
##
## Existe por uma queixa concreta de teste — o jogador passou minutos no celular
## sem perceber que havia ciclo. O ceu mudando devagar nao se nota quando se
## esta olhando o chao e batendo em bicho; um marcador andando, sim.
##
## Desenhada em _draw() e nao montada com nos: sao quatro retangulos, um circulo
## e um texto, e montar isso na cena daria seis nos para posicionar a mao a cada
## ajuste de tamanho.

## Amanhecer e anoitecer, nas mesmas horas que o ciclo usa para virar a luz.
const NASCE := 6.0
const POE := 18.0

const ALTURA_DA_TRILHA := 7.0
const RAIO_DO_MARCADOR := 7.0

const COR_DO_DIA := Color(0.98, 0.84, 0.46)
const COR_DA_NOITE := Color(0.22, 0.27, 0.52)
const COR_DO_MARCADOR := Color(1.0, 0.99, 0.92)
const COR_DA_MOLDURA := Color(0.0, 0.0, 0.0, 0.34)

@export var ciclo: Node

var _fonte: Font

func _ready() -> void:
    _fonte = ThemeDB.fallback_font

func _process(_delta: float) -> void:
    if ciclo:
        queue_redraw()

func _draw() -> void:
    if ciclo == null:
        return

    var largura := size.x
    var meio_y := size.y * 0.5

    # A trilha e o dia inteiro, da meia-noite a meia-noite. A parte clara vai do
    # nascer ao por do sol; o resto e noite. Assim a barra nao mostra so "quanto
    # falta", mostra ONDE no dia o jogador esta — e o tamanho de cada faixa ja
    # diz quanto dura cada uma.
    var comeco_do_dia := largura * (NASCE / 24.0)
    var fim_do_dia := largura * (POE / 24.0)

    var trilha := Rect2(0.0, meio_y - ALTURA_DA_TRILHA * 0.5, largura, ALTURA_DA_TRILHA)
    draw_rect(trilha.grow(2.0), COR_DA_MOLDURA, true)
    draw_rect(trilha, COR_DA_NOITE, true)
    draw_rect(Rect2(comeco_do_dia, trilha.position.y,
                    fim_do_dia - comeco_do_dia, ALTURA_DA_TRILHA), COR_DO_DIA, true)

    var hora: float = ciclo.hora
    var x := largura * (hora / 24.0)
    draw_circle(Vector2(x, meio_y), RAIO_DO_MARCADOR + 1.5, COR_DA_MOLDURA)
    draw_circle(Vector2(x, meio_y), RAIO_DO_MARCADOR, COR_DO_MARCADOR)

    var texto: String = ciclo.hora_do_relogio() + "  " + _quanto_falta(hora)
    var medida := _fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
    var onde := Vector2(largura * 0.5 - medida.x * 0.5, meio_y + 22.0)
    # Sombra atras do texto: a barra fica sobre o ceu, que muda de cor o dia
    # inteiro, e texto claro sumiria no amanhecer.
    draw_string(_fonte, onde + Vector2.ONE, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
                Color(0.0, 0.0, 0.0, 0.55))
    draw_string(_fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COR_DO_MARCADOR)

## "faltam 2 min de dia" — em minutos REAIS, nao em horas de jogo. E o numero
## que o jogador consegue usar: ele quer saber se espera ou se vai embora.
func _quanto_falta(hora: float) -> String:
    var e_dia := hora >= NASCE and hora < POE
    var horas_ate := (POE - hora) if e_dia else fposmod(NASCE - hora, 24.0)
    var minutos: float = horas_ate / 24.0 * float(ciclo.minutos_por_dia)
    var rotulo := "de dia" if e_dia else "de noite"
    if minutos < 1.0:
        return "· menos de 1 min %s" % rotulo
    return "· %d min %s" % [int(round(minutos)), rotulo]
