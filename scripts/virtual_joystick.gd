extends Control


var movement_vector := Vector2.ZERO
var touch_index := -1
var knob_position := Vector2.ZERO
var _target_knob := Vector2.ZERO
var _is_dragging := false

@export var outer_radius := 85.0
@export var knob_radius := 34.0
@export var deadzone := 0.1

func _ready() -> void:
    custom_minimum_size = Vector2(210, 210)
    knob_position = size * 0.5
    _target_knob = knob_position
    queue_redraw()

func _process(delta: float) -> void:
    if not _is_dragging:
        knob_position = knob_position.lerp(size * 0.5, 18.0 * delta)
        queue_redraw()
    else:
        knob_position = knob_position.lerp(_target_knob, 26.0 * delta)
        queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1:
            touch_index = event.index
            _is_dragging = true
            _update_joystick(event.position)
            accept_event()
        elif not event.pressed and event.index == touch_index:
            _release_joystick()
            accept_event()
    elif event is InputEventScreenDrag and event.index == touch_index:
        _update_joystick(event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _is_dragging = true
            _update_joystick(event.position)
        else:
            _release_joystick()
        accept_event()
    elif event is InputEventMouseMotion and _is_dragging:
        _update_joystick(event.position)
        accept_event()

func _update_joystick(pointer_position: Vector2) -> void:
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
    touch_index = -1
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
        var lado_b := knob_radius * 2.5
        draw_texture_rect(_arte_botao,
            Rect2(knob_position - Vector2(lado_b, lado_b) * 0.5, Vector2(lado_b, lado_b)),
            false, Color(1.12, 1.12, 1.06) if _is_dragging else Color(1, 1, 1))
    else:
        draw_circle(knob_position, knob_radius,
            Color(0.18, 0.45, 0.7, 0.95) if _is_dragging else Color(0.12, 0.22, 0.32, 0.85))
