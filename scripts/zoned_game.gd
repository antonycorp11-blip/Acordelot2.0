extends Node3D

## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const MIRA := preload("res://scripts/botao_de_mira.gd")
const DialogoScript := preload("res://scripts/dialogo.gd")
## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const AquecimentoScript := preload("res://scripts/aquecimento.gd")
const AjustesScript := preload("res://scripts/ajustes.gd")
const TelaPersonagemScript := preload("res://scripts/tela_personagem.gd")

## A NPC ao alcance, se houver. E ela que decide o que o botao de ataque faz.
var _npc_perto: Node = null
var _btn_ataque: Node = null
var _dialogo: Node = null

@onready var _player: CharacterBody3D = $Player
@onready var _zone_manager: ZoneManager = $ZoneManager

func _ready() -> void:
    var hud_vida: Node = find_child("PlayerHUD", true, false)
    var inv_ui: Node = find_child("InventoryUI", true, false)
    
    _btn_ataque = find_child("BtnAtaque", true, false)
    if _btn_ataque:
        # UM botao, duas funcoes. Perto de alguem ele conversa; longe, ataca.
        # Um segundo botao so para falar ficaria apagado 95% do jogo e roubaria
        # canto de tela num celular que ja tem seis controles.
        _btn_ataque.pressed.connect(func():
            if _npc_perto != null:
                _conversar()
            elif _player and _player.has_method("atacar"):
                _player.atacar()
        )

    # Assa os shaders enquanto o mapa ainda esta nascendo. Sem isto, a primeira
    # aparicao de cada coisa — Shiker, Mirella, skill — para o jogo por um
    # instante para compilar o shader dela.
    if OS.get_cmdline_user_args().has("--shot"):
        _tirar_print()

    var forno: Node3D = AquecimentoScript.new()
    forno.name = "Aquecimento"
    add_child(forno)

    # Cada zona nova traz os seus moradores: reconecta a cada troca.
    if _zone_manager:
        _zone_manager.zone_changed.connect(func(_z): registrar_npcs())

    # A caixa de conversa nasce com o mundo, escondida.
    _dialogo = DialogoScript.new()
    _dialogo.name = "Dialogo"
    add_child(_dialogo)
    _dialogo.terminou.connect(func():
        if _player:
            _player.set_physics_process(true)
        if _npc_perto and _npc_perto.has_method("voltar_a_rotina"):
            _npc_perto.voltar_a_rotina()
        _pintar_botao())
        
    # A mochila do PlayerHUD fica no canto de cima, atras do minimapa no
    # celular — na pratica ninguem achava. Este e o botao que se ve.
    # NAO ha botao proprio de inventario: quem abre e a mochila do PlayerHUD, na
    # coluna de utilitarios do canto de cima. Ter dois botoes para a mesma tela
    # so aumentava a HUD — e o que faltava era a mochila aparecer no lugar
    # certo, coisa que a ancoragem corrigida resolveu.

    var btn_voo := find_child("BtnVoo", true, false)
    if btn_voo:
        btn_voo.pressed.connect(func():
            if _player and _player.has_method("alternar_voo"):
                _player.alternar_voo()
        )
        
    # A mochila e a engrenagem sao do kit novo e nascem dentro do PlayerHUD, que
    # e quem sabe onde a arte encaixa. Aqui so se diz o que elas fazem.
    if hud_vida and inv_ui and hud_vida.has_signal("mochila_pedida"):
        hud_vida.mochila_pedida.connect(func():
            inv_ui.toggle_inventory()
        )
    # A ESCALA DO MUNDO, escolhida pelo jogador. Aplicada antes de qualquer
    # tela existir, para o primeiro quadro ja sair no tamanho certo.
    AjustesScript.aplicar_guardado(get_tree())
    var ajustes: CanvasLayer = AjustesScript.new()
    ajustes.name = "Ajustes"
    add_child(ajustes)

    # A engrenagem passa a abrir os ajustes. O mapa continua a um toque de
    # distancia pelo proprio botao "Mapa do Reino", embaixo do minimapa.
    # A ficha do personagem, aberta pela aba do inventario.
    var ficha: CanvasLayer = TelaPersonagemScript.new()
    ficha.name = "TelaPersonagem"
    add_child(ficha)
    if inv_ui and inv_ui.has_signal("aba_pedida"):
        inv_ui.aba_pedida.connect(func(qual: String):
            if qual == "personagem":
                inv_ui.toggle_inventory(false)
                ficha.mostrar(true))

    if hud_vida and hud_vida.has_signal("config_pedida"):
        hud_vida.config_pedida.connect(func(): ajustes.mostrar(true))
        
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

## Gancho de teste, irmao do que ja existe no game.gd: rodar com `-- --shot`
## salva um quadro em user://shot.png e sai. E assim que se confere a HUD sem
## depender de alguem olhar a tela e descrever.
func _tirar_print() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(1.5).timeout
    # `-- --shot --inv` abre o inventario antes do clique: conferir tela de menu
    # sem isso exigiria alguem segurando o celular.
    # `-- --shot --bicho` planta um Shiker na frente do jogador antes do clique:
    # conferir barra de vida sem isso exige esperar um nascer sozinho.
    # `-- --norte` sobe o mapa de zona em zona, contando o que acontece em cada
    # borda: e a unica forma de conferir portal sem alguem andando ate la.
    if OS.get_cmdline_user_args().has("--norte"):
        var zm := find_child("ZoneManager", true, false)
        for salto in 2:
            await get_tree().create_timer(1.2).timeout
            var construtor := find_child("ZoneBuilder", true, false)
            var alvo := Vector3(0.0, 2.0, -68.0)
            if construtor and construtor.has_method("calcular_altura"):
                alvo.y = construtor.calcular_altura(alvo.x, alvo.z) + 1.5
            _player.global_position = alvo
            var portais := get_tree().root.find_children("Portal_*", "", true, false)
            var estado := []
            for pt in portais:
                estado.append("%s(ativo=%s, z=%.0f, dest=%s)" % [pt.name, str(pt._active), pt.global_position.z, pt.dest_zone_id])
            print("TESTE salto %d: saindo de %s em %s | portais: %s" % [salto,
                zm._current_zone_id if zm else "?", str(alvo), ", ".join(estado)])
            for i in 90:
                await get_tree().physics_frame
                _player.global_position.z -= 0.1
            print("TESTE salto %d: chegou em %s, heroi em %s" % [salto,
                zm._current_zone_id if zm else "?", str(_player.global_position)])

    if OS.get_cmdline_user_args().has("--bicho"):
        var Bicho := load("res://scripts/bicho.gd")
        for i in 2:
            var b: Node3D = Bicho.new()
            b.monster_type = i * 2
            add_child(b)
            b.global_position = _player.global_position + Vector3(2.5 - 5.0 * i, 0.5, -4.0)
            await get_tree().process_frame
            b.levar_dano(b.vida_maxima * 0.45, Vector3.FORWARD)
        await get_tree().create_timer(0.5).timeout
    if OS.get_cmdline_user_args().has("--ajustes"):
        var aj := find_child("Ajustes", true, false)
        if aj:
            aj.mostrar(true)
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--ficha"):
        var f := find_child("TelaPersonagem", true, false)
        if f:
            f.mostrar(true)
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--fala"):
        if _dialogo:
            _dialogo.comecar("renaldo_portao" if OS.get_cmdline_user_args().has("--renaldo") else "mirella_boas_vindas")
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--inv"):
        var inv := find_child("InventoryUI", true, false)
        if inv:
            inv.toggle_inventory(true)
        await get_tree().create_timer(0.4).timeout
    var imagem := get_viewport().get_texture().get_image()
    imagem.save_png("user://shot.png")
    print("SHOT ", ProjectSettings.globalize_path("user://shot.png"))
    get_tree().quit()


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


# -------------------------------------------------------------
# Conversa: quem esta perto, e o botao que troca de cara
# -------------------------------------------------------------
## Ligado pelo ZoneManager quando a zona termina de nascer, e a cada troca de
## zona: os NPCs sao criados junto com o cenario, entao nao da para conectar
## uma vez no _ready e esquecer.
func registrar_npcs() -> void:
    _npc_perto = null
    for npc in get_tree().get_nodes_in_group("npc"):
        if not npc.jogador_chegou.is_connected(_ao_chegar_perto):
            npc.jogador_chegou.connect(_ao_chegar_perto)
            npc.jogador_saiu.connect(_ao_afastar)
    _pintar_botao()


func _ao_chegar_perto(npc: Node) -> void:
    _npc_perto = npc
    if npc.has_method("olhar_para") and _player:
        npc.olhar_para(_player.global_position)
    _pintar_botao()


func _ao_afastar(npc: Node) -> void:
    if _npc_perto == npc:
        _npc_perto = null
    _pintar_botao()


func _conversar() -> void:
    if _npc_perto == null or _dialogo == null or _dialogo.esta_ativo():
        return
    if not _dialogo.comecar(str(_npc_perto.dialogo)):
        return
    if _npc_perto.has_method("parar_para_conversar"):
        _npc_perto.parar_para_conversar()
    # O heroi para enquanto conversa. Andar com a caixa aberta faria a NPC
    # ficar para tras falando sozinha.
    if _player:
        _player.set_physics_process(false)
    _pintar_botao()


## O botao de ataque vira botao de conversa e volta.
##
## Nao ha arte propria para "conversar": a mesma moldura entra esverdeada e com
## a legenda embaixo, que e o suficiente para o jogador entender que aquele
## toque mudou de assunto — e nao custa uma textura nova na build.
func _pintar_botao() -> void:
    if _btn_ataque == null:
        return
    var conversando: bool = _npc_perto != null and (_dialogo == null or not _dialogo.esta_ativo())
    _btn_ataque.modulate = Color(0.62, 1.0, 0.72) if conversando else Color.WHITE

    var legenda := _btn_ataque.get_node_or_null("Legenda") as Label
    if legenda == null:
        legenda = Label.new()
        legenda.name = "Legenda"
        legenda.add_theme_font_size_override("font_size", 13)
        legenda.add_theme_color_override("font_color", Color(0.95, 0.99, 0.9))
        legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        legenda.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        legenda.offset_top = -18.0
        legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _btn_ataque.add_child(legenda)
    legenda.text = "Conversar" if conversando else ""
