extends Node3D

@onready var _player: CharacterBody3D = $Player
@onready var _zone_manager: ZoneManager = $ZoneManager

func _ready() -> void:
    var hud_vida: Node = find_child("PlayerHUD", true, false)
    var inv_ui: Node = find_child("InventoryUI", true, false)
    
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
        
    var btn_inv := find_child("BtnInventario", true, false)
    if btn_inv and inv_ui:
        btn_inv.pressed.connect(func():
            inv_ui.toggle_inventory()
        )
        
    if inv_ui and hud_vida:
        inv_ui.item_used.connect(func(item_id: String):
            if item_id == "pocao_cura_g":
                hud_vida.curar(450.0)
            elif item_id == "carne_assada":
                hud_vida.curar(200.0)
        )
        
    var joystick := find_child("VirtualJoystick", true, false)
    if joystick:
        joystick.add_to_group("virtual_joystick")

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        if _player and _player.has_method("atacar"):
            _player.atacar()
