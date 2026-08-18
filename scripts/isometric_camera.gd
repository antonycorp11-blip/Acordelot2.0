extends Node3D

@export var target: Node3D
@export var follow_speed := 7.0
@export var look_ahead := 1.5

func _ready() -> void:
    if target:
        global_position = target.global_position

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
