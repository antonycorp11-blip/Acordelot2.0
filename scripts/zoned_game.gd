extends Node3D

## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const MIRA := preload("res://scripts/botao_de_mira.gd")

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
        
    # Conexão dos 3 Botões de Habilidades (Skills)
    var btn_skill1 := find_child("BtnSkill1", true, false)
    if btn_skill1:
        btn_skill1.pressed.connect(func():
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(1)
        )
        
    var btn_skill2 := find_child("BtnSkill2", true, false)
    if btn_skill2:
        btn_skill2.pressed.connect(func():
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(2)
        )
        
    # O raio ganha mira por arrasto, no gesto do Brawl Stars.
    #
    # E a unica das tres em que errar o alvo custa caro, e a mira automatica
    # escolhe sozinha quando ha mais de um inimigo perto — sem o jogador poder
    # discordar. As outras duas seguem no toque simples, que basta para elas.
    var btn_skill3 := find_child("BtnSkill3", true, false)
    if btn_skill3 and btn_skill3 is Control:
        var alvo := btn_skill3 as Control
        var mira: Control = MIRA.new()
        mira.set_anchors_preset(Control.PRESET_FULL_RECT)
        alvo.add_child(mira)
        # A arte continua sendo a do botao embaixo; a mira so desenha a seta.
        if alvo is TextureButton and alvo.texture_normal:
            mira.definir_arte(null)
        mira.mirando.connect(func(direcao: Vector2):
            if _player and _player.has_method("atualizar_mira_skill"):
                _player.atualizar_mira_skill(3, direcao)
        )
        mira.mira_cancelada.connect(func():
            if _player and _player.has_method("cancelar_mira_skill"):
                _player.cancelar_mira_skill(3)
        )
        mira.cancelado.connect(func():
            if _player and _player.has_method("cancelar_mira_skill"):
                _player.cancelar_mira_skill(3)
        )
        mira.disparar.connect(func(direcao: Vector2):
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(3, direcao)
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
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_1:
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(1)
                get_viewport().set_input_as_handled()
        elif event.keycode == KEY_2:
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(2)
                get_viewport().set_input_as_handled()
        elif event.keycode == KEY_3:
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(3)
                get_viewport().set_input_as_handled()
        elif event.keycode == KEY_SPACE:
            if _player and _player.has_method("atacar"):
                _player.atacar()
                get_viewport().set_input_as_handled()
