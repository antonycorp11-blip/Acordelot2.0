extends Control
## O direcional do polegar.

const AreaSeguraUI := preload("res://scripts/area_segura_ui.gd")

var movement_vector := Vector2.ZERO
var touch_index := -1
var knob_position := Vector2.ZERO
var _target_knob := Vector2.ZERO
var _is_dragging := false

## UM DONO POR VEZ — E O DEDO GANHA DO RATO.
##
## AQUI ESTAVA O BUG. `_is_dragging` era ligado tanto pelo toque quanto pelo
## rato, e o ramo de `InputEventMouseMotion` so perguntava por ele. No celular o
## Godot emula rato a partir do toque, e um Control que recebeu o clique
## continua recebendo o movimento MESMO FORA DO RETANGULO DELE. Resultado: com o
## primeiro dedo segurando o direcional, arrastar o SEGUNDO dedo para girar a
## camera chegava neste ramo e chamava `_update_joystick` com a posicao do dedo
## da camera. O knob pulava para la e a trajetoria do heroi ia junto — sem
## ninguem ter mexido no direcional.
##
## Agora quem pega o controle primeiro manda ate soltar, e depois do primeiro
## toque de verdade o rato e ignorado: aparelho que tem dedo nao precisa do rato
## emulado. No computador nada se perde, porque o projeto liga
## `emulate_touch_from_mouse` e o rato entra pelo caminho do toque.
const SEM_DONO := -2
const DONO_RATO := -1
var _dono := SEM_DONO
var _viu_toque := false

@export var outer_radius := 85.0
@export var knob_radius := 34.0
@export var deadzone := 0.1

const LADO := 210.0

func _ready() -> void:
    custom_minimum_size = Vector2(LADO, LADO)
    knob_position = size * 0.5
    _target_knob = knob_position
    _acomodar_na_tela()
    get_viewport().size_changed.connect(_acomodar_na_tela)
    queue_redraw()


## LONGE DA QUINA DO APARELHO.
##
## A cena punha o direcional a 15 pixels do rodape. Em celular com barra de
## gestos, canto arredondado ou recorte de camera, esses 15 pixels sao
## exatamente a faixa que o sistema come — e o polegar que buscava a beirada do
## circulo acabava arrastando a barra do navegador para cima no meio da luta.
##
## O recuo sai do mesmo AreaSeguraUI que as telas cheias ja usam: uma conta so
## para "onde a tela deste aparelho realmente comeca", e nao um numero chutado
## por controle.
func _acomodar_na_tela() -> void:
    var tela := get_viewport().get_visible_rect().size
    var margem := AreaSeguraUI.recuo(tela) + 10.0
    anchor_left = 0.0
    anchor_right = 0.0
    anchor_top = 1.0
    anchor_bottom = 1.0
    offset_left = margem
    offset_right = margem + LADO
    offset_top = -LADO - margem
    offset_bottom = -margem
    queue_redraw()


## So redesenha enquanto ha o que animar.
##
## As duas pernas do if chamavam queue_redraw() sem condicao: com o dedo fora da
## tela e o botao ja parado no centro, o direcional continuava se redesenhando
## sessenta vezes por segundo para pintar exatamente a mesma imagem. Num
## controle que passa a maior parte do tempo em repouso, isso e desenho puro
## jogado fora.
func _process(delta: float) -> void:
    var alvo: Vector2 = _target_knob if _is_dragging else size * 0.5
    # Forma exponencial em vez de lerp direto: o lerp por delta muda de
    # velocidade conforme os quadros por segundo, e o mesmo controle ficava mais
    # mole no celular do que no computador.
    var suavidade: float = 26.0 if _is_dragging else 18.0
    knob_position = knob_position.lerp(alvo, 1.0 - exp(-suavidade * delta))
    if knob_position.distance_to(alvo) < 0.15:
        knob_position = alvo
        if not _is_dragging:
            set_process(false)
    queue_redraw()

## QUEM PEGA DECIDE O `_gui_input`; QUEM SEGUE O DEDO E O `_input`.
##
## Os dois existem por motivos diferentes e nenhum dos dois sozinho funciona.
##
## `_gui_input` so entrega evento cuja POSICAO cai dentro do controle, e nao
## captura: o polegar sai da caixa de 210 px assim que encosta na borda do
## circulo, e a partir dali nem o arrasto nem o SOLTAR voltam para ca. Foi o que
## eu quebrei na tentativa anterior — o direcional pegava o dedo, perdia o
## soltar, ficava com dono para sempre e morria depois do primeiro toque.
##
## `_input` recebe tudo, de qualquer lugar da tela — mas se ele tambem decidisse
## quem pega o controle, um toque num painel aberto POR CIMA do direcional seria
## roubado por ele, porque `_input` corre antes da interface.
##
## Entao: o PRESS passa pelo `_gui_input`, que respeita ordem de camada e painel
## modal; e o ARRASTO e o SOLTAR do dedo que ja e nosso passam pelo `_input`,
## que enxerga a tela inteira. E marcado como tratado, para a camera nao girar
## com o mesmo dedo que esta andando.
func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _viu_toque = true
        if event.pressed and _dono == SEM_DONO:
            _tomar_posse(event.index, event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        # No computador o projeto liga `emulate_touch_from_mouse`, entao o rato
        # ja entra pelo caminho do toque acima. Isto e so a rede de seguranca.
        if _viu_toque:
            return
        if event.pressed and _dono == SEM_DONO:
            _tomar_posse(DONO_RATO, event.position)
        accept_event()


func _tomar_posse(quem: int, onde_local: Vector2) -> void:
    _dono = quem
    touch_index = quem if quem >= 0 else -1
    _is_dragging = true
    _update_joystick(onde_local)


## O dedo que ja e nosso, seguido pela tela inteira.
func _input(event: InputEvent) -> void:
    if _dono == SEM_DONO:
        return
    if event is InputEventScreenTouch:
        _viu_toque = true
        if not event.pressed and event.index == _dono:
            _release_joystick()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if event.index == _dono:
            _update_joystick(_para_local(event.position))
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if not event.pressed and _dono == DONO_RATO:
            _release_joystick()
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _dono == DONO_RATO and not _viu_toque:
        _update_joystick(_para_local(event.position))
        get_viewport().set_input_as_handled()


## Da tela para dentro do controle. `_gui_input` ja entrega em coordenada local,
## `_input` entrega em coordenada de tela — e o direcional vive num CanvasLayer,
## entao a conta tem de passar pela transformacao da camada.
func _para_local(na_tela: Vector2) -> Vector2:
    return get_global_transform_with_canvas().affine_inverse() * na_tela


## Perder o foco solta o dedo. Sem isto, trocar de aba no navegador com o
## polegar apoiado deixava o heroi andando sozinho e o controle sem dono.
func _notification(o_que: int) -> void:
    if o_que == NOTIFICATION_APPLICATION_FOCUS_OUT or o_que == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        if _dono != SEM_DONO:
            _release_joystick()


func _update_joystick(pointer_position: Vector2) -> void:
    set_process(true)
    var center := size * 0.5
    var offset := pointer_position - center
    var dist := offset.length()
    
    if dist > outer_radius:
        offset = offset.normalized() * outer_radius
        
    _target_knob = center + offset
    
    var norm_dist := dist / outer_radius
    if norm_dist < deadzone:
        movement_vector = Vector2.ZERO
    else:
        var remapped := (norm_dist - deadzone) / (1.0 - deadzone)
        movement_vector = offset.normalized() * clampf(remapped, 0.0, 1.0)

func _release_joystick() -> void:
    set_process(true)
    touch_index = -1
    _dono = SEM_DONO
    _is_dragging = false
    movement_vector = Vector2.ZERO
    _target_knob = size * 0.5

## A arte do kit no lugar do desenho de teste.
##
## Carregadas uma vez e guardadas: o desenho roda a cada quadro, e pedir a
## textura ao disco dentro dele seria buscar o mesmo arquivo sessenta vezes por
## segundo. Se faltarem, cai no circulo desenhado — melhor um joystick feio que
## um joystick invisivel.
static var _arte_base: Texture2D = null
static var _arte_botao: Texture2D = null
static var _arte_carregada := false

static func _carregar_arte() -> void:
    if _arte_carregada:
        return
    _arte_carregada = true
    if ResourceLoader.exists("res://textures/ui/joystick_base.png"):
        _arte_base = load("res://textures/ui/joystick_base.png")
    if ResourceLoader.exists("res://textures/ui/joystick_botao.png"):
        _arte_botao = load("res://textures/ui/joystick_botao.png")

func _draw() -> void:
    _carregar_arte()
    var center := size * 0.5

    if _arte_base:
        var lado := outer_radius * 2.25
        draw_texture_rect(_arte_base,
            Rect2(center - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false,
            Color(1, 1, 1, 1.0 if _is_dragging else 0.86))
    else:
        draw_circle(center, outer_radius, Color(0.05, 0.08, 0.12, 0.55))
        draw_arc(center, outer_radius, 0.0, TAU, 48,
            Color(0.5, 0.65, 0.8, 0.45), 3.0)

    if _arte_botao:
        # 2,15 e nao 2,5: a arte agora e um circulo recortado que ocupa o
        # quadrado inteiro, entao o multiplicador antigo desenhava um botao
        # visivelmente maior que o raio que o codigo usa para mover.
        var lado_b := knob_radius * 2.15
        draw_texture_rect(_arte_botao,
            Rect2(knob_position - Vector2(lado_b, lado_b) * 0.5, Vector2(lado_b, lado_b)),
            false, Color(1.12, 1.12, 1.06) if _is_dragging else Color(1, 1, 1))
    else:
        draw_circle(knob_position, knob_radius,
            Color(0.18, 0.45, 0.7, 0.95) if _is_dragging else Color(0.12, 0.22, 0.32, 0.85))
