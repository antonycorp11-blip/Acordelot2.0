extends Control
class_name BotaoDeMira
## Botao de habilidade que vira manche de mira ao ser arrastado.
##
## E o gesto do Brawl Stars, e ele existe por um motivo pratico: no celular nao
## ha para onde apontar. A mira automatica escolhe o alvo errado quando ha mais
## de um inimigo perto, e o jogador nao tem como discordar dela.
##
## Encostar e soltar dispara na direcao em que o heroi ja olha — o toque rapido
## continua funcionando como antes. Arrastar mostra a seta e dispara para onde
## ela aponta ao soltar. Arrastar de volta ao centro cancela, que e a saida de
## quem se arrependeu no meio do gesto.

signal disparar(direcao: Vector2)
signal cancelado

## Arrasto menor que isto conta como toque simples, nao como mira. Sem essa
## folga, o tremor do dedo ao levantar transformaria todo toque num tiro torto.
const FOLGA_DO_TOQUE := 18.0
## Puxar para dentro deste raio cancela.
const RAIO_DE_CANCELAR := 26.0
## Ate onde a seta cresce, em pixels de tela.
const ALCANCE_DA_SETA := 130.0

@export var cor := Color(0.45, 0.82, 1.0)
@export var habilitado := true

var _apontando := false
var _dedo := -1
var _direcao := Vector2.ZERO
var _distancia := 0.0

var _arte: Texture2D = null


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP


func definir_arte(textura: Texture2D) -> void:
    _arte = textura
    queue_redraw()


func _gui_input(evento: InputEvent) -> void:
    if not habilitado:
        return

    if evento is InputEventScreenTouch or evento is InputEventMouseButton:
        var pressionado: bool = evento.pressed
        var indice: int = evento.index if evento is InputEventScreenTouch else -2
        if pressionado and not _apontando:
            _apontando = true
            _dedo = indice
            _direcao = Vector2.ZERO
            _distancia = 0.0
            queue_redraw()
        elif not pressionado and _apontando and indice == _dedo:
            _soltar()

    elif (evento is InputEventScreenDrag or evento is InputEventMouseMotion) and _apontando:
        if evento is InputEventScreenDrag and evento.index != _dedo:
            return
        var do_centro: Vector2 = evento.position - size * 0.5
        _distancia = minf(do_centro.length(), ALCANCE_DA_SETA)
        if _distancia > 0.001:
            _direcao = do_centro.normalized()
        queue_redraw()


func _soltar() -> void:
    _apontando = false
    _dedo = -1
    queue_redraw()

    if _distancia > FOLGA_DO_TOQUE and _distancia < RAIO_DE_CANCELAR:
        cancelado.emit()
        return
    # Toque curto tambem dispara: Vector2.ZERO diz "use a direcao do heroi".
    disparar.emit(_direcao if _distancia >= RAIO_DE_CANCELAR else Vector2.ZERO)


func _draw() -> void:
    var meio := size * 0.5
    var raio: float = minf(size.x, size.y) * 0.5

    if _arte:
        draw_texture_rect(_arte, Rect2(Vector2.ZERO, size), false,
            Color(1, 1, 1) if habilitado else Color(0.45, 0.45, 0.5))
    else:
        draw_circle(meio, raio, Color(0.08, 0.12, 0.18, 0.9))
        draw_arc(meio, raio - 2.0, 0.0, TAU, 32, cor, 3.0)

    if not _apontando or _distancia < FOLGA_DO_TOQUE:
        return

    # A seta e desenhada PARA FORA do botao, sobre o jogo: e ali que o jogador
    # esta olhando enquanto decide, e nao no proprio botao sob o polegar.
    var cancelando := _distancia < RAIO_DE_CANCELAR
    var tinta := Color(0.95, 0.35, 0.32) if cancelando else cor
    var ponta := meio + _direcao * _distancia

    draw_line(meio, ponta, Color(tinta.r, tinta.g, tinta.b, 0.55), 7.0)
    draw_circle(ponta, 13.0, Color(tinta.r, tinta.g, tinta.b, 0.30))

    var lado := _direcao.orthogonal() * 11.0
    draw_colored_polygon(PackedVector2Array([
        ponta + _direcao * 20.0, ponta + lado, ponta - lado]), tinta)

    if cancelando:
        draw_arc(meio, RAIO_DE_CANCELAR, 0.0, TAU, 24, tinta, 2.5)
