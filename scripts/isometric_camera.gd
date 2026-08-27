extends Node3D
class_name IsometricCamera

@export var target: Node3D
@export var follow_speed := 8.0
@export var look_ahead := 1.5

@export var zoom_minimo := 0.4
@export var zoom_maximo := 2.0
@export var zoom_inicial := 1.0

## A CAMERA DE OMBRO, ligavel nos ajustes.
##
## Nao substitui a de cima: convive com ela. As duas mudam MUITO o custo de
## desenho — camera alta enxerga um punhado de casas, camera de ombro olha para
## o horizonte e traz tudo o que houver ate o plano distante para dentro do
## quadro. Deixar as duas disponiveis e o unico jeito honesto de comparar, com o
## medidor ligado, qual delas o aparelho aguenta.
@export var modo_gta := false
## Atras e um pouco acima do ombro. Distancia curta de proposito: cada metro a
## mais de camera e mais mundo dentro do quadro.
const POUSO_GTA := Vector3(0.7, 2.35, 6.0)
const INCLINACAO_GTA := -11.0
const FOV_GTA := 68.0
## A camera gira para o lado que o heroi olha, mas devagar: acompanhar o giro no
## mesmo quadro embrulha o estomago e tira a leitura do movimento.
const GIRO_DA_CAMERA := 4.5
@export var velocidade_do_zoom := 8.0

var _camera: Camera3D
var _pouso: Vector3
var _zoom := 1.0
var _zoom_desejado := 1.0
var _distancia_da_pinca := 0.0
var _giro_pouso := Vector3.ZERO
var _fov_pouso := 50.0


## Volta a camera de cima ao lugar dela quando o jogador desliga o modo ombro.
func usar_modo_gta(sim: bool) -> void:
    modo_gta = sim
    if _camera == null:
        return
    if not sim:
        rotation.y = 0.0
        _camera.rotation_degrees = _giro_pouso
        _camera.fov = _fov_pouso
var _toques: Dictionary = {}

func _ready() -> void:
    _camera = get_child(0) as Camera3D
    if _camera:
        _pouso = _camera.position
        _giro_pouso = _camera.rotation_degrees
        _fov_pouso = _camera.fov
    _zoom = zoom_inicial
    _zoom_desejado = zoom_inicial
    if target:
        global_position = target.global_position

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _mudar_zoom(-0.10)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _mudar_zoom(0.10)
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
                _mudar_zoom((_distancia_da_pinca - distancia) * 0.005)
            _distancia_da_pinca = distancia

func _mudar_zoom(quanto: float) -> void:
    _zoom_desejado = clampf(_zoom_desejado + quanto, zoom_minimo, zoom_maximo)

func _process(delta: float) -> void:
    if not target or not is_instance_valid(target):
        return

    var desired := target.global_position
    var horizontal_velocity := Vector3.ZERO
    if target is CharacterBody3D:
        horizontal_velocity = target.velocity
        horizontal_velocity.y = 0.0
    if horizontal_velocity.length() > 0.1:
        desired += horizontal_velocity.normalized() * look_ahead

    global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

    if modo_gta and _camera:
        # O rig gira junto com o heroi; a camera fica parada atras dele.
        rotation.y = rotate_toward(rotation.y, target.rotation.y, GIRO_DA_CAMERA * delta)
        _camera.position = POUSO_GTA * lerpf(0.85, 1.25, (_zoom - zoom_minimo) / maxf(zoom_maximo - zoom_minimo, 0.01))
        _camera.rotation_degrees.x = INCLINACAO_GTA
        _camera.rotation_degrees.y = 0.0
        _camera.fov = FOV_GTA
        return

    if _camera:
        _zoom = lerpf(_zoom, _zoom_desejado, 1.0 - exp(-velocidade_do_zoom * delta))
        _camera.position = _pouso * _zoom
