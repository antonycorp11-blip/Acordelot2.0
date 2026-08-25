extends Node3D

## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const MIRA := preload("res://scripts/botao_de_mira.gd")
const DialogoScript := preload("res://scripts/dialogo.gd")
## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const AquecimentoScript := preload("res://scripts/aquecimento.gd")
const AjustesScript := preload("res://scripts/ajustes.gd")
const TelaPersonagemScript := preload("res://scripts/tela_personagem_v3.gd")
const TelaSinteseScript := preload("res://scripts/tela_sintese_v3.gd")
const TelaEcosScript := preload("res://scripts/tela_ecos_v3.gd")
const TelaSkillsScript := preload("res://scripts/tela_skills_v3.gd")
const EcoDoNascenteCena := preload("res://scenes/ecos/EcoDoNascente.tscn")
const RessonanciaHUDScript := preload("res://scripts/ressonancia_hud.gd")
const DesempenhoAdaptativoScript := preload("res://scripts/desempenho_adaptativo.gd")

## A NPC ao alcance, se houver. E ela que decide o que o botao de ataque faz.
var _npc_perto: Node = null
var _btn_ataque: Node = null
var _dialogo: Node = null
var _tela_ecos: CanvasLayer = null
var _tela_skills: CanvasLayer = null
var _eco_companheiro: Node3D = null
var _eco_companheiro_id := ""
var _btn_skill_eco: Button = null
var _rotulo_cooldown_eco: Label = null
var _efeito_skill_eco: MeshInstance3D = null
var _cooldown_skill_eco := 0.0
var _hud_ressonancia = null
var _eco_captura: Node3D = null
var _ressonando := false
var _progresso_ressonancia := 0.0
var _ate_buscar_eco := 0.0
var _sorte_captura := RandomNumberGenerator.new()

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
        _zone_manager.zone_changed.connect(func(_z):
            registrar_npcs()
            _sincronizar_eco_companheiro(true)
            _eco_captura = null
            _progresso_ressonancia = 0.0)

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
    var adaptativo := DesempenhoAdaptativoScript.new()
    adaptativo.name = "DesempenhoAdaptativo"
    add_child(adaptativo)
    var ajustes: CanvasLayer = AjustesScript.new()
    ajustes.name = "Ajustes"
    add_child(ajustes)

    # A engrenagem passa a abrir os ajustes. O mapa continua a um toque de
    # distancia pelo proprio botao "Mapa do Reino", embaixo do minimapa.
    # A ficha do personagem, aberta pela aba do inventario.
    var ficha: CanvasLayer = TelaPersonagemScript.new()
    ficha.name = "TelaPersonagem"
    add_child(ficha)
    var sintese: CanvasLayer = TelaSinteseScript.new()
    sintese.name = "TelaSintese"
    add_child(sintese)
    if ficha.has_signal("tela_pedida"):
        ficha.tela_pedida.connect(func(qual: String):
            ficha.mostrar(false)
            if qual == "talentos":
                _abrir_tela_skills()
            elif qual == "sintese":
                sintese.mostrar(true))
    if inv_ui and inv_ui.has_signal("aba_pedida"):
        inv_ui.aba_pedida.connect(func(qual: String):
            if qual == "personagem":
                inv_ui.toggle_inventory(false)
                ficha.mostrar(true)
            elif qual == "melodia":
                inv_ui.toggle_inventory(false)
                sintese.mostrar(true)
            elif qual == "lira":
                inv_ui.toggle_inventory(false)
                _abrir_tela_ecos()
            elif qual == "talentos":
                inv_ui.toggle_inventory(false)
                _abrir_tela_skills())

    var progresso := get_node_or_null("/root/Progresso")
    _criar_botao_skill_eco()
    _criar_efeito_skill_eco()
    _hud_ressonancia = RessonanciaHUDScript.new()
    _hud_ressonancia.name = "HUDRessonancia"
    add_child(_hud_ressonancia)
    _hud_ressonancia.ressoar_iniciado.connect(func(): _ressonando = true)
    _hud_ressonancia.ressoar_parado.connect(func(): _ressonando = false)
    _sorte_captura.randomize()
    if progresso:
        if not progresso.alterado.is_connected(_sincronizar_eco_companheiro):
            progresso.alterado.connect(_sincronizar_eco_companheiro)
        if not progresso.alterado.is_connected(_atualizar_botoes_skill):
            progresso.alterado.connect(_atualizar_botoes_skill)
        call_deferred("_sincronizar_eco_companheiro")
        call_deferred("_atualizar_botoes_skill")

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


func _abrir_tela_ecos() -> void:
    # A tela nasce sob demanda e usa retratos leves próprios; não carrega as
    # dez folhas de animação só para ampliar uma miniatura no catálogo.
    if _tela_ecos == null:
        _tela_ecos = TelaEcosScript.new()
        _tela_ecos.name = "TelaEcos"
        add_child(_tela_ecos)
    _tela_ecos.mostrar(true)


func _abrir_tela_skills() -> void:
    if _tela_skills == null:
        _tela_skills = TelaSkillsScript.new()
        _tela_skills.name = "TelaSkills"
        add_child(_tela_skills)
    _tela_skills.mostrar(true)


func _atualizar_botoes_skill() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    for dados in [["BtnSkill1", "skill_1"], ["BtnSkill2", "skill_2"], ["BtnSkill3", "skill_3"]]:
        var botao := find_child(str(dados[0]), true, false) as BaseButton
        if botao:
            botao.disabled = not progresso.skill_desbloqueada(str(dados[1]))
            botao.modulate = Color.WHITE if not botao.disabled else Color(0.30, 0.32, 0.38, 0.72)


func _sincronizar_eco_companheiro(_forcar := false) -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    var dados: Dictionary = progresso.eco_equipado
    var id := str(dados.get("id", ""))
    if not _forcar and id == _eco_companheiro_id and is_instance_valid(_eco_companheiro):
        return
    if is_instance_valid(_eco_companheiro):
        _eco_companheiro.queue_free()
    _eco_companheiro = null
    _eco_companheiro_id = id
    var caminho := str(dados.get("arte", ""))
    if id.is_empty() or caminho.is_empty() or not ResourceLoader.exists(caminho):
        _atualizar_botao_skill_eco()
        return
    var eco := EcoDoNascenteCena.instantiate()
    eco.name = "EcoEquipado_" + id
    eco.usar_particulas = false
    eco.altura_aparente_m = 0.70
    var sprite := eco.get_node("Visual/AnimatedSprite3D") as AnimatedSprite3D
    sprite.sprite_frames = load(caminho) as SpriteFrames
    sprite.visibility_range_end = 34.0
    add_child(eco)
    eco.global_position = _player.global_position + Vector3(1.2, 0.2, 1.0)
    eco.definir_terreno(find_child("ZoneBuilder", true, false))
    eco.definir_seguidor(_player)
    _eco_companheiro = eco
    _atualizar_botao_skill_eco()


func _criar_botao_skill_eco() -> void:
    var grupo := find_child("BotoesCombate", true, false) as Control
    if grupo == null:
        return
    _btn_skill_eco = Button.new()
    _btn_skill_eco.name = "BtnSkillEco"
    _btn_skill_eco.position = Vector2(7, 98)
    _btn_skill_eco.size = Vector2(72, 72)
    _btn_skill_eco.expand_icon = true
    _btn_skill_eco.tooltip_text = "Habilidade do Eco equipado"
    var fundo := StyleBoxFlat.new()
    fundo.bg_color = Color(0.035, 0.10, 0.18, 0.94)
    fundo.border_color = Color(0.30, 0.84, 1.0, 0.95)
    fundo.set_border_width_all(3)
    fundo.set_corner_radius_all(36)
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        _btn_skill_eco.add_theme_stylebox_override(estado, fundo)
    grupo.add_child(_btn_skill_eco)
    _btn_skill_eco.pressed.connect(_usar_skill_eco)
    _rotulo_cooldown_eco = Label.new()
    _rotulo_cooldown_eco.set_anchors_preset(Control.PRESET_FULL_RECT)
    _rotulo_cooldown_eco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _rotulo_cooldown_eco.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _rotulo_cooldown_eco.add_theme_font_size_override("font_size", 22)
    _rotulo_cooldown_eco.add_theme_color_override("font_color", Color.WHITE)
    _rotulo_cooldown_eco.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    _rotulo_cooldown_eco.add_theme_constant_override("outline_size", 5)
    _rotulo_cooldown_eco.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _btn_skill_eco.add_child(_rotulo_cooldown_eco)
    _atualizar_botao_skill_eco()


func _atualizar_botao_skill_eco() -> void:
    if _btn_skill_eco == null:
        return
    var progresso := get_node_or_null("/root/Progresso")
    var id := str(progresso.eco_equipado.get("id", "")) if progresso else ""
    _btn_skill_eco.visible = not id.is_empty()
    if id.is_empty():
        return
    var retrato := "res://textures/ui/ecos/%s.png" % id
    _btn_skill_eco.icon = load(retrato) if ResourceLoader.exists(retrato) else null


func _criar_efeito_skill_eco() -> void:
    _efeito_skill_eco = MeshInstance3D.new()
    _efeito_skill_eco.name = "PulsoDoEco"
    var disco := CylinderMesh.new()
    disco.top_radius = 0.7
    disco.bottom_radius = 0.7
    disco.height = 0.035
    disco.radial_segments = 24
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.10, 0.75, 1.0, 0.42)
    material.emission_enabled = true
    material.emission = Color(0.08, 0.58, 1.0)
    material.emission_energy_multiplier = 1.7
    _efeito_skill_eco.mesh = disco
    _efeito_skill_eco.material_override = material
    # Um ponto microscópico por dois quadros força a compilação deste material
    # durante o carregamento, não no primeiro toque da quarta skill.
    _efeito_skill_eco.scale = Vector3.ONE * 0.01
    _efeito_skill_eco.transparency = 0.99
    _efeito_skill_eco.visible = true
    add_child(_efeito_skill_eco)
    _ocultar_preparo_skill_eco()


func _ocultar_preparo_skill_eco() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if is_instance_valid(_efeito_skill_eco):
        _efeito_skill_eco.visible = false


func _usar_skill_eco() -> void:
    if _cooldown_skill_eco > 0.0 or _eco_companheiro == null or not is_instance_valid(_eco_companheiro):
        return
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null or str(progresso.eco_equipado.get("id", "")).is_empty():
        return
    _cooldown_skill_eco = 10.0
    _btn_skill_eco.disabled = true
    if _eco_companheiro.has_method("play_attack"):
        _eco_companheiro.play_attack()
    _efeito_skill_eco.global_position = _player.global_position + Vector3.UP * 0.08
    _efeito_skill_eco.scale = Vector3.ONE * 0.25
    _efeito_skill_eco.transparency = 0.0
    _efeito_skill_eco.visible = true
    var pulso := create_tween()
    pulso.set_parallel(true)
    pulso.tween_property(_efeito_skill_eco, "scale", Vector3.ONE * 5.0, 0.42)
    pulso.tween_property(_efeito_skill_eco, "transparency", 1.0, 0.42)
    pulso.chain().tween_callback(func(): _efeito_skill_eco.visible = false)
    var dano := float(progresso.estatisticas().get("poder_harmonico", 30)) * 1.35
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if is_instance_valid(bicho) and bicho.global_position.distance_to(_player.global_position) <= 5.0:
            bicho.levar_dano(dano, bicho.global_position - _player.global_position)
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud and hud.has_method("conceder_escudo"):
        hud.conceder_escudo(55.0 + float(progresso.valor_atributo("ressonancia")) * 5.0)


func _process(delta: float) -> void:
    if _cooldown_skill_eco > 0.0:
        _cooldown_skill_eco = maxf(0.0, _cooldown_skill_eco - delta)
        if _rotulo_cooldown_eco:
            _rotulo_cooldown_eco.text = str(ceili(_cooldown_skill_eco)) if _cooldown_skill_eco > 0.0 else ""
        if _cooldown_skill_eco <= 0.0 and _btn_skill_eco:
            _btn_skill_eco.disabled = false
    _ate_buscar_eco -= delta
    if _ate_buscar_eco <= 0.0:
        _ate_buscar_eco = 0.25
        _buscar_eco_para_captura()
    if not _ressonando:
        _progresso_ressonancia = maxf(0.0, _progresso_ressonancia - delta * 0.20)
        return
    if _eco_captura == null or not is_instance_valid(_eco_captura) or _player.global_position.distance_to(_eco_captura.global_position) > 4.8:
        _ressonando = false
        return
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null or progresso.quantidade("ressonador") <= 0:
        _ressonando = false
        return
    var bonus := 1.0 + maxf(0.0, float(progresso.valor_atributo("ressonancia")) - 6.0) * 0.02
    _progresso_ressonancia += delta / 4.5 * bonus
    _mostrar_estado_ressonancia()
    if _progresso_ressonancia >= 1.0:
        _concluir_ressonancia()


func _buscar_eco_para_captura() -> void:
    var melhor: Node3D = null
    var menor := 4.8
    for candidato in get_tree().get_nodes_in_group("eco_capturavel"):
        if not is_instance_valid(candidato) or not candidato.has_method("esta_disponivel_para_captura") or not candidato.esta_disponivel_para_captura():
            continue
        var distancia := _player.global_position.distance_to(candidato.global_position)
        if distancia < menor:
            menor = distancia
            melhor = candidato
    if melhor != _eco_captura:
        _eco_captura = melhor
        _progresso_ressonancia = 0.0
        _ressonando = false
    if _eco_captura == null:
        _hud_ressonancia.esconder()
    else:
        _mostrar_estado_ressonancia()


func _mostrar_estado_ressonancia() -> void:
    if _eco_captura == null or not is_instance_valid(_eco_captura):
        return
    var progresso := get_node_or_null("/root/Progresso")
    var nomes := {"do":"Dó", "do_sustenido":"Dó#", "re":"Ré", "re_sustenido":"Ré#",
        "mi":"Mi", "fa":"Fá", "fa_sustenido":"Fá#", "sol":"Sol",
        "sol_sustenido":"Sol#", "la":"Lá", "la_sustenido":"Lá#", "si":"Si"}
    var id := str(_eco_captura.eco_id)
    _hud_ressonancia.mostrar_eco("Eco de " + str(nomes.get(id, id)), _progresso_ressonancia,
        progresso != null and progresso.quantidade("ressonador") > 0)


func _concluir_ressonancia() -> void:
    var eco := _eco_captura
    var id := str(eco.eco_id)
    var progresso := get_node_or_null("/root/Progresso")
    _ressonando = false
    _eco_captura = null
    _progresso_ressonancia = 0.0
    if progresso == null:
        return
    var fragmentos := _sorte_captura.randi_range(2, 4)
    progresso.adicionar_recurso("fragmento_" + id, fragmentos)
    var chance_alma := minf(0.18, 0.08 + float(progresso.valor_atributo("ressonancia")) * 0.003)
    var ganhou_alma := _sorte_captura.randf() < chance_alma
    if ganhou_alma:
        progresso.adicionar_recurso("alma_eco_" + id, 1)
    _hud_ressonancia.recompensa("+%d fragmentos%s" % [fragmentos, "  •  +1 Alma rara" if ganhou_alma else ""])
    eco.play_disappear()
    _reaparecer_eco_depois(eco)


func _reaparecer_eco_depois(eco: Node) -> void:
    await get_tree().create_timer(45.0).timeout
    if is_instance_valid(eco) and eco.has_method("reaparecer"):
        eco.reaparecer()

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
        var total_de_saltos := 1 if OS.get_cmdline_user_args().has("--vila") else 2
        for salto in total_de_saltos:
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
        if OS.get_cmdline_user_args().has("--centro"):
            var centro := Vector3.ZERO
            var construtor_centro := find_child("ZoneBuilder", true, false)
            if construtor_centro and construtor_centro.has_method("calcular_altura"):
                centro.y = construtor_centro.calcular_altura(0.0, 0.0) + 1.5
            _player.global_position = centro
            var camera_rig := find_child("CameraRig", true, false) as Node3D
            if camera_rig:
                camera_rig.global_position = centro
            await get_tree().create_timer(0.8).timeout

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
            for argumento in OS.get_cmdline_user_args():
                if argumento.begins_with("--aba=") and f.has_method("_mudar_aba_v3"):
                    f._mudar_aba_v3(argumento.trim_prefix("--aba="))
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--sintese"):
        var s := find_child("TelaSintese", true, false)
        if s:
            s.mostrar(true)
            if OS.get_cmdline_user_args().has("--partituras"):
                s._trocar_aba("partituras")
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--skills"):
        _abrir_tela_skills()
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--ecos"):
        _abrir_tela_ecos()
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
    if DisplayServer.get_name() == "headless":
        print("SHOT indisponível no renderizador headless; árvore validada.")
        get_tree().quit()
        return
    var imagem := get_viewport().get_texture().get_image()
    if imagem:
        imagem.save_png("user://shot.png")
        print("SHOT ", ProjectSettings.globalize_path("user://shot.png"))
    else:
        # O renderizador dummy do teste headless não possui textura. Ainda
        # assim o teste deve encerrar, em vez de deixar um Godot preso por horas.
        print("SHOT indisponível no renderizador headless; árvore validada.")
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
