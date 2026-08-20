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

func _draw() -> void:
    var center := size * 0.5
    
    # 1. Base translúcida glassmorphism
    draw_circle(center, outer_radius, Color(0.05, 0.08, 0.12, 0.55))
    
    # 2. Anel externo com brilho ciano suave
    var ring_col := Color(0.3, 0.8, 1.0, 0.85) if _is_dragging else Color(0.5, 0.65, 0.8, 0.45)
    draw_arc(center, outer_radius, 0.0, TAU, 48, ring_col, 3.0)
    
    # 3. Vetor de direção sutil
    if _is_dragging and movement_vector.length() > 0.1:
        draw_line(center, knob_position, Color(0.3, 0.85, 1.0, 0.4), 2.5)
        
    # 4. Botão analógico central (Knob)
    var knob_col := Color(0.18, 0.45, 0.7, 0.95) if _is_dragging else Color(0.12, 0.22, 0.32, 0.85)
    draw_circle(knob_position, knob_radius, knob_col)
    
    var knob_border := Color(0.5, 0.9, 1.0, 0.95) if _is_dragging else Color(0.7, 0.8, 0.9, 0.7)
    draw_arc(knob_position, knob_radius, 0.0, TAU, 36, knob_border, 2.5)
    
    # Detalhe central do knob
    draw_circle(knob_position, knob_radius * 0.35, Color(1.0, 1.0, 1.0, 0.25 if not _is_dragging else 0.6))
