extends CharacterBody3D

@onready var _hero: Hero = $Hero

@export var move_speed := 6.0
@export var acceleration := 18.0
@export var gravity := 24.0

func _physics_process(delta: float) -> void:
    var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

    var wasd_vector := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_A):
        wasd_vector.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D):
        wasd_vector.x += 1.0
    if Input.is_physical_key_pressed(KEY_W):
        wasd_vector.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S):
        wasd_vector.y += 1.0
    if wasd_vector.length() > 0.0:
        input_vector = wasd_vector.normalized()

    var joystick := get_tree().get_first_node_in_group("virtual_joystick")
    if joystick and joystick.movement_vector.length() > 0.01:
        input_vector = joystick.movement_vector

    var camera := get_viewport().get_camera_3d()
    var move_direction := Vector3.ZERO

    if camera and input_vector.length() > 0.0:
        var camera_forward := -camera.global_basis.z
        camera_forward.y = 0.0
        camera_forward = camera_forward.normalized()
        var camera_right := camera.global_basis.x
        camera_right.y = 0.0
        camera_right = camera_right.normalized()
        move_direction = (camera_right * input_vector.x - camera_forward * input_vector.y).normalized()

    velocity.x = move_toward(velocity.x, move_direction.x * move_speed, acceleration * delta)
    velocity.z = move_toward(velocity.z, move_direction.z * move_speed, acceleration * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = -0.5

    if move_direction.length() > 0.0:
        var target_angle := atan2(move_direction.x, move_direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

    move_and_slide()

    _hero.atualizar_movimento(Vector2(velocity.x, velocity.z).length())

func _unhandled_input(event: InputEvent) -> void:
    # O golpe agora sai do botao na tela; aqui fica so o atalho de teclado.
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        _hero.atacar()

## Ligado ao botao de ataque pelo game.gd.
func atacar() -> void:
    _hero.atacar()
