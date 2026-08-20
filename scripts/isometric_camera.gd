extends Node3D
class_name IsometricCamera

@export var target: Node3D
@export var follow_speed := 12.0
@export var distance := 4.8
@export var height := 2.1
@export var pitch_angle := -11.0 # Graus olhando para frente/baixo estilo GTA
@export var yaw_angle := 0.0

var _camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = -11.0
var _zoom_dist: float = 4.8
var _is_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO
var _toques: Dictionary = {}
var _distancia_da_pinca := 0.0

func _ready() -> void:
    _camera = get_child(0) as Camera3D
    _yaw = yaw_angle
    _pitch = pitch_angle
    _zoom_dist = distance
    
    if target:
        global_position = target.global_position
        _yaw = target.rotation.y

func _unhandled_input(event: InputEvent) -> void:
    # 1. Mouse Drag para Orbitar Câmera estilo GTA
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
            _is_dragging = event.pressed
            _last_drag_pos = event.position
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _zoom_dist = clampf(_zoom_dist - 0.4, 2.0, 9.0)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _zoom_dist = clampf(_zoom_dist + 0.4, 2.0, 9.0)
            
    elif event is InputEventMouseMotion and _is_dragging:
        _yaw -= event.relative.x * 0.005
        _pitch = clampf(_pitch - event.relative.y * 0.25, -45.0, 25.0)
        
    # 2. Touch Drag e Pinça no Celular / Tablet
    elif event is InputEventScreenTouch:
        if event.pressed:
            _toques[event.index] = event.position
            # Se tocar na metade direita da tela e não for botão, inicia órbita
            if event.position.x > get_viewport().get_visible_rect().size.x * 0.35:
                _is_dragging = true
                _last_drag_pos = event.position
        else:
            _toques.erase(event.index)
            _distancia_da_pinca = 0.0
            if _toques.is_empty():
                _is_dragging = false
                
    elif event is InputEventScreenDrag:
        _toques[event.index] = event.position
        if _toques.size() >= 2:
            var pts: Array = _toques.values()
            var dist: float = pts[0].distance_to(pts[1])
            if _distancia_da_pinca > 0.0:
                _zoom_dist = clampf(_zoom_dist - (_distancia_da_pinca - dist) * 0.015, 2.0, 9.0)
            _distancia_da_pinca = dist
        elif _is_dragging and event.position.x > get_viewport().get_visible_rect().size.x * 0.30:
            _yaw -= event.relative.x * 0.006
            _pitch = clampf(_pitch - event.relative.y * 0.3, -45.0, 25.0)

func _process(delta: float) -> void:
    if not target or not is_instance_valid(target):
        return

    # Acompanha a posição do herói suavemente
    var target_pos := target.global_position
    global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))
    
    # Se o herói estiver correndo e o jogador não estiver arrastando a câmera, suaviza a rotação atrás dele
    if not _is_dragging and target is CharacterBody3D:
        var vel: Vector3 = target.velocity
        vel.y = 0.0
        if vel.length() > 1.2:
            var desired_yaw := atan2(vel.x, vel.z) + PI
            _yaw = lerp_angle(_yaw, desired_yaw, 2.5 * delta)

    # Posiciona a Câmera GTA atrás do ombro
    if _camera:
        var offset := Vector3(0.0, height, _zoom_dist)
        offset = offset.rotated(Vector3.RIGHT, deg_to_rad(_pitch))
        offset = offset.rotated(Vector3.UP, _yaw)
        
        _camera.global_position = global_position + offset
        _camera.look_at(global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
