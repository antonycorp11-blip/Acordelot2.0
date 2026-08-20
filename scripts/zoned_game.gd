extends Node3D

@onready var _player: CharacterBody3D = $Player
@onready var _zone_manager: ZoneManager = $ZoneManager

func _ready() -> void:
    var btn_ataque := find_child("BtnAtaque", true, false)
    if btn_ataque:
        btn_ataque.pressed.connect(func():
            if _player and _player.has_method("atacar"):
                _player.atacar()
        )
        
    var btn_voo := find_child("BtnVoo", true, false)
    if btn_voo:
        btn_voo.pressed.connect(func():
            if _player and _player.has_method("alternar_voo"):
                _player.alternar_voo()
        )
        
    var joystick := find_child("VirtualJoystick", true, false)
    if joystick:
        joystick.add_to_group("virtual_joystick")

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        if _player and _player.has_method("atacar"):
            _player.atacar()
