extends Node3D

@export var target: Node3D
@export var follow_speed := 7.0
@export var look_ahead := 1.5

## Zoom por pinca no celular e roda do mouse no computador.
##
## Nao e so conforto: aproximar ENCOLHE o que a camera enxerga, e como o mundo
## carrega exatamente o que ela ve, menos pedaco entra em cena. Zoom perto e o
## botao de desempenho do jogador.
@export var zoom_minimo := 0.55
@export var zoom_maximo := 1.6
@export var velocidade_do_zoom := 8.0

var _camera: Camera3D
var _pouso: Vector3
var _zoom := 1.0
var _zoom_desejado := 1.0
var _distancia_da_pinca := 0.0
var _toques: Dictionary = {}

func _ready() -> void:
    _camera = get_child(0) as Camera3D
    if _camera:
        _pouso = _camera.position
    if target:
        global_position = target.global_position

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _mudar_zoom(-0.12)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _mudar_zoom(0.12)

    # Pinca: duas marcas na tela. A conta e pela DISTANCIA entre elas, entao
    # nao importa qual dedo se mexeu nem se um ficou parado.
    elif event is InputEventScreenTouch:
        if event.pressed:
            _toques[event.index] = event.position
        else:
            _toques.erase(event.index)
            _distancia_da_pinca = 0.0
    elif event is InputEventScreenDrag:
        _toques[event.index] = event.position
        if _toques.size() >= 2:
            var pontos: Array = _toques.values()
            var distancia: float = pontos[0].distance_to(pontos[1])
            if _distancia_da_pinca > 0.0:
                _mudar_zoom((_distancia_da_pinca - distancia) * 0.004)
            _distancia_da_pinca = distancia

## Zoom direto, sem transicao — usado pela captura de perto.
func definir_zoom(valor: float) -> void:
    _zoom_desejado = valor
    _zoom = _zoom_desejado

func _mudar_zoom(quanto: float) -> void:
    _zoom_desejado = clampf(_zoom_desejado + quanto, zoom_minimo, zoom_maximo)

func _process(delta: float) -> void:
    if not target:
        return

    var desired := target.global_position
    var horizontal_velocity := Vector3.ZERO
    if target is CharacterBody3D:
        horizontal_velocity = target.velocity
        horizontal_velocity.y = 0.0
    if horizontal_velocity.length() > 0.1:
        desired += horizontal_velocity.normalized() * look_ahead

    global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

    if _camera:
        _zoom = lerpf(_zoom, _zoom_desejado, 1.0 - exp(-velocidade_do_zoom * delta))
        _camera.position = _pouso * _zoom
