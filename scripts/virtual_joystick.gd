extends Control

var movement_vector := Vector2.ZERO
var touch_index := -1
var knob_position := Vector2.ZERO

@export var outer_radius := 92.0
@export var knob_radius := 38.0

func _ready() -> void:
    custom_minimum_size = Vector2(220, 220)
    knob_position = size * 0.5
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1:
            touch_index = event.index
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
            _update_joystick(event.position)
        else:
            _release_joystick()
        accept_event()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _update_joystick(event.position)
        accept_event()

func _update_joystick(pointer_position: Vector2) -> void:
    var center := size * 0.5
    var offset := pointer_position - center
    if offset.length() > outer_radius:
        offset = offset.normalized() * outer_radius
    knob_position = center + offset
    movement_vector = offset / outer_radius
    queue_redraw()

func _release_joystick() -> void:
    touch_index = -1
    movement_vector = Vector2.ZERO
    knob_position = size * 0.5
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    draw_circle(center, outer_radius, Color(0.04, 0.07, 0.08, 0.48))
    draw_arc(center, outer_radius, 0.0, TAU, 64, Color(0.72, 0.82, 0.72, 0.62), 4.0)
    draw_circle(knob_position, knob_radius, Color(0.62, 0.78, 0.62, 0.82))
    draw_arc(knob_position, knob_radius, 0.0, TAU, 48, Color(0.9, 0.96, 0.9, 0.9), 3.0)
