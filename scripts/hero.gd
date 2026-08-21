extends Node3D
class_name Hero
## O Akles: malha, esqueleto e a maquina de animacao.
##
## A malha vem de UM arquivo (breathing_idle.fbx); o movimento vem da biblioteca
## assada por scripts/assar_animacoes.gd. Instanciar um FBX por animacao
## carregaria sete copias do heroi — 110 MB na build web.

## O Mixamo devolve o modelo cem vezes menor. 1.75 m e a altura que casa com a
## capsula de colisao do jogador e com a escala das arvores.
const ALTURA_ALVO := 1.75
const VELOCIDADE_DE_CORRIDA := 4.2
const MISTURA := 0.18

## As animacoes do Mixamo sao feitas para cinematica, nao para combate: no
## ritmo original o golpe parece que esta carregando. Acelerar a reproducao e o
## que da peso de jogo sem reanimar nada.
const VELOCIDADE_DO_GOLPE := 1.85

## Alcance da lamina, em metros, medido do peito do heroi.
const ALCANCE_DO_GOLPE := 2.6
## Abertura do golpe em graus. Nao e cone estreito: espada larga acerta o que
## esta de lado, e exigir mira fina num jogo de toque so gera golpe no vazio.
const ABERTURA_DO_GOLPE := 120.0
const DANO := 34.0
## Em que ponto da animacao a lamina passa pelo alvo. Aplicar o dano no comeco
## faz o bicho voar antes do golpe sair, e no fim faz parecer que nao pegou.
const INSTANTE_DO_IMPACTO := 0.38

## Encaixe da espada na mao.
@export var comprimento_da_espada := 1.15
@export var fracao_do_cabo := 0.85
@export var ajuste_do_punho := Vector3.ZERO
@export var giro_do_punho := Vector3(180.0, 0.0, 0.0)

const ESCALA := ["do", "re", "mi", "fa", "sol", "la", "si"]
const COMBO := ["corte_fora", "corte_dentro", "ataque_pulo"]
const PAUSA_DO_COMBO := 1.2

var _animador: AnimationPlayer
var _atacando := false
var _voz: AudioStreamPlayer
var _proxima_nota := 0
var _golpe := 0
var _ultimo_golpe_em := -100.0
var _golpe_pedido := false
var _espada: Node3D = null
var _lamina: Node3D = null
var _escala_do_modelo := 1.0

var _indicador_mira_chao: Node3D = null

var _buff_aura_azul: bool = false
var _buff_espada_gigante: bool = false
var _aura_fx_node: Node3D = null
var _espada_light: OmniLight3D = null

func _ready() -> void:
    var modelo := (load("res://personagem/heroi_base.fbx") as PackedScene).instantiate()
    add_child(modelo)

    _animador = modelo.find_child("AnimationPlayer", true, false)
    var biblioteca: AnimationLibrary = load("res://personagem/heroi_anims.res")
    for nome in COMBO:
        _fixar_no_lugar(biblioteca.get_animation(nome))
    _animador.add_animation_library("heroi", biblioteca)
    _animador.animation_finished.connect(_ao_terminar)

    # A ESCALA VEM ANTES DA ESPADA, e a ordem e o bug.
    #
    # O encaixe divide o tamanho da lamina pela escala do heroi para cancela-la,
    # senao a espada encolheria junto com o modelo. Mas o Mixamo devolve o heroi
    # cem vezes maior que o jogo, e ate aqui a espada era presa ANTES desse
    # ajuste: ela media a escala 1.0 e nao a ~0.01 real. O resultado era uma
    # lamina cem vezes fora de tamanho na mao — a "coisa estranha" no lugar da
    # espada.
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var altura: float = malha.get_aabb().size.y
        if altura > 0.0:
            modelo.scale = Vector3.ONE * (ALTURA_ALVO / altura)
            break

    _equipar_espada(modelo)
    _montar_audio()
    _construir_indicador_mira_chao()

    if _espada:
        _espada.visible = false
    _animador.play("heroi/parado")

func _construir_indicador_mira_chao() -> void:
    _indicador_mira_chao = Node3D.new()
    _indicador_mira_chao.name = "IndicadorMiraLaser"
    _indicador_mira_chao.top_level = true
    _indicador_mira_chao.visible = false
    add_child(_indicador_mira_chao)

    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var y_chao := 0.04 # 4 cm acima do solo global

    # 1. Haste principal (retângulo de 0.8m a 20m de alcance)
    var w := 0.45
    var z_ini := 0.8
    var z_fim := 20.0

    st.set_color(Color(0.2, 0.85, 1.0, 0.55))
    st.add_vertex(Vector3(-w, y_chao, z_ini))
    st.add_vertex(Vector3(w, y_chao, z_ini))
    st.add_vertex(Vector3(w, y_chao, z_fim))

    st.add_vertex(Vector3(-w, y_chao, z_ini))
    st.add_vertex(Vector3(w, y_chao, z_fim))
    st.add_vertex(Vector3(-w, y_chao, z_fim))

    # 2. Ponta de flecha (de 20m a 24.5m)
    var w_ponta := 1.7
    var z_bico := 24.5
    st.set_color(Color(0.3, 0.95, 1.0, 0.8))
    st.add_vertex(Vector3(-w_ponta, y_chao, z_fim))
    st.add_vertex(Vector3(w_ponta, y_chao, z_fim))
    st.add_vertex(Vector3(0.0, y_chao, z_bico))

    # 3. Linha central brilhante
    var w_linha := 0.08
    st.set_color(Color(1.0, 1.0, 1.0, 0.9))
    st.add_vertex(Vector3(-w_linha, y_chao + 0.01, z_ini))
    st.add_vertex(Vector3(w_linha, y_chao + 0.01, z_ini))
    st.add_vertex(Vector3(w_linha, y_chao + 0.01, z_bico - 0.5))

    st.add_vertex(Vector3(-w_linha, y_chao + 0.01, z_ini))
    st.add_vertex(Vector3(w_linha, y_chao + 0.01, z_bico - 0.5))
    st.add_vertex(Vector3(-w_linha, y_chao + 0.01, z_bico - 0.5))

    var mesh := st.commit()
    var mi := MeshInstance3D.new()
    mi.mesh = mesh

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mi.material_override = mat

    _indicador_mira_chao.add_child(mi)

func mostrar_mira_laser(direcao_mundo: Vector3) -> void:
    if _indicador_mira_chao:
        _indicador_mira_chao.visible = true
        _indicador_mira_chao.global_position = global_position
        if direcao_mundo.length_squared() > 0.01:
            _indicador_mira_chao.global_rotation.y = atan2(direcao_mundo.x, direcao_mundo.z)

func esconder_mira_laser() -> void:
    if _indicador_mira_chao:
        _indicador_mira_chao.visible = false

func _montar_audio() -> void:
    _voz = AudioStreamPlayer.new()
    add_child(_voz)

## Prende a espada na mao direita.
func _equipar_espada(modelo: Node3D) -> void:
    var esqueleto: Skeleton3D = null
    for node in modelo.find_children("*", "Skeleton3D", true, false):
        esqueleto = node
        break
    if esqueleto == null:
        push_warning("Sem esqueleto: a espada nao tem onde prender")
        return

    var indice := -1
    for osso in esqueleto.get_bone_count():
        if esqueleto.get_bone_name(osso).ends_with("RightHand"):
            indice = osso
            break
    if indice == -1:
        push_warning("Osso da mao direita nao encontrado")
        return

    var suporte := BoneAttachment3D.new()
    suporte.name = "MaoDireita"
    suporte.bone_idx = indice
    esqueleto.add_child(suporte)

    var punho := Node3D.new()
    punho.name = "Punho"
    suporte.add_child(punho)
    _espada = punho

    var espada: Node3D = (load("res://models/espada_akles.glb") as PackedScene).instantiate()
    punho.add_child(espada)
    _lamina = espada
    _escala_do_modelo = modelo.scale.x

    _atualizar_encaixe()

    # Copia propria do material, nao a compartilhada.
    #
    # A espada gigante acende emissao no material da lamina. Com o recurso
    # compartilhado essa emissao vazaria para tudo que usa a mesma cor de
    # vertice — o mapa inteiro — e nunca mais apagaria.
    var tinta: StandardMaterial3D = (
        load("res://materials/prop_cor_de_vertice.tres") as StandardMaterial3D).duplicate()
    for malha in espada.find_children("*", "MeshInstance3D", true, false):
        malha.material_override = tinta

func _atualizar_encaixe() -> void:
    if _lamina == null or _espada == null:
        return

    const ALTURA_DA_MALHA := 0.94
    var escala := comprimento_da_espada / ALTURA_DA_MALHA / _escala_do_modelo
    _lamina.scale = Vector3.ONE * escala

    _lamina.position = Vector3(
        0.0, -(fracao_do_cabo - 0.5) * ALTURA_DA_MALHA * escala, 0.0) + ajuste_do_punho
    _espada.rotation_degrees = giro_do_punho

func _process(_delta: float) -> void:
    if OS.is_debug_build():
        _atualizar_encaixe()
    if _indicador_mira_chao and _indicador_mira_chao.visible:
        _indicador_mira_chao.global_position = global_position

func _fixar_no_lugar(animacao: Animation) -> void:
    if animacao == null:
        return
    for trilha in animacao.get_track_count():
        if animacao.track_get_type(trilha) != Animation.TYPE_POSITION_3D:
            continue
        if not String(animacao.track_get_path(trilha)).ends_with("Hips"):
            continue
        for chave in animacao.track_get_key_count(trilha):
            var valor: Vector3 = animacao.track_get_key_value(trilha, chave)
            animacao.track_set_key_value(trilha, chave, Vector3(0.0, valor.y, 0.0))

func atacando() -> bool:
    return _atacando

func atualizar_movimento(velocidade: float, voando: bool = false) -> void:
    if _atacando:
        return
    var desejada := "heroi/parado"
    if voando:
        desejada = "heroi/voo"
    elif velocidade > VELOCIDADE_DE_CORRIDA:
        desejada = "heroi/correr"
    elif velocidade > 0.2:
        desejada = "heroi/andar"
    if _animador.current_animation != desejada:
        _animador.play(desejada, MISTURA)

func atacar() -> void:
    if _atacando:
        _golpe_pedido = true
        return

    if Time.get_ticks_msec() / 1000.0 - _ultimo_golpe_em > PAUSA_DO_COMBO:
        _golpe = 0

    _atacando = true
    if _espada:
        _espada.visible = true
    _animador.play("heroi/" + COMBO[_golpe], MISTURA, VELOCIDADE_DO_GOLPE)
    _golpe = (_golpe + 1) % COMBO.size()
    _tocar_nota()
    _marcar_impacto()

func _marcar_impacto() -> void:
    var duracao := _animador.current_animation_length / VELOCIDADE_DO_GOLPE
    await get_tree().create_timer(duracao * INSTANTE_DO_IMPACTO).timeout
    if not _atacando:
        return
    _atingir()

func ativar_aura_azul() -> void:
    # Sem esta guarda, tocar duas vezes cria a segunda aura e deixa DOIS
    # cronometros correndo: o primeiro a vencer apaga o buff, e o jogador perde
    # o efeito no meio do tempo que pagou por ele.
    if _buff_aura_azul:
        return
    _buff_aura_azul = true
    _criar_aura_azul_visual()
    var tw := create_tween()
    tw.tween_interval(10.0)
    tw.tween_callback(func():
        _buff_aura_azul = false
        if _aura_fx_node and is_instance_valid(_aura_fx_node):
            _aura_fx_node.queue_free()
    )

func _criar_aura_azul_visual() -> void:
    if _aura_fx_node and is_instance_valid(_aura_fx_node):
        _aura_fx_node.queue_free()
        
    _aura_fx_node = Node3D.new()
    _aura_fx_node.name = "AuraAzulFX"
    add_child(_aura_fx_node)
    
    var light := OmniLight3D.new()
    light.light_color = Color(0.2, 0.7, 1.0)
    light.light_energy = 3.5
    light.omni_range = 4.5
    light.position.y = 1.0
    _aura_fx_node.add_child(light)
    
    var ring := MeshInstance3D.new()
    var tor := TorusMesh.new()
    tor.inner_radius = 0.9
    tor.outer_radius = 1.2
    ring.mesh = tor
    
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.2, 0.85, 1.0, 0.85)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override = mat
    ring.position.y = 0.2
    _aura_fx_node.add_child(ring)

func ativar_espada_gigante() -> void:
    if _buff_espada_gigante:
        return
    _buff_espada_gigante = true
    if _espada:
        _espada.scale = Vector3.ONE * 2.5
        # A espada fica GUARDADA fora do golpe, e por isso a skill nao aparecia:
        # o jogador acionava, pagava a mana e nao via nada ate atacar. Enquanto
        # o buff dura, a lamina fica na mao.
        _espada.visible = true
        _fazer_espada_brilhar(true)
        
    var tw := create_tween()
    tw.tween_interval(8.0)
    tw.tween_callback(func():
        _buff_espada_gigante = false
        if _espada:
            _espada.scale = Vector3.ONE
            _fazer_espada_brilhar(false)
            _espada.visible = _atacando
    )

func _fazer_espada_brilhar(brilhar: bool) -> void:
    if not _espada:
        return
    if brilhar:
        if _espada_light == null or not is_instance_valid(_espada_light):
            _espada_light = OmniLight3D.new()
            _espada_light.light_color = Color(1.0, 0.85, 0.25)
            _espada_light.light_energy = 5.0
            _espada_light.omni_range = 6.0
            _espada.add_child(_espada_light)
        for malha in _espada.find_children("*", "MeshInstance3D", true, false):
            var mat = malha.material_override as StandardMaterial3D
            if mat:
                mat.emission_enabled = true
                mat.emission = Color(1.0, 0.85, 0.2)
                mat.emission_energy_multiplier = 4.0
    else:
        if _espada_light and is_instance_valid(_espada_light):
            _espada_light.queue_free()
            _espada_light = null
        for malha in _espada.find_children("*", "MeshInstance3D", true, false):
            var mat = malha.material_override as StandardMaterial3D
            if mat:
                mat.emission_enabled = false

func lancar_raio_kamehameha(direcao_manual := Vector3.ZERO) -> void:
    if _atacando:
        return
    esconder_mira_laser()
    _atacando = true
    _destravar_em(2.2)
    _animador.play("heroi/golpe_pesado", 0.1, 1.2)
    
    var frente: Vector3
    if direcao_manual.length_squared() > 0.01:
        frente = direcao_manual.normalized()
        frente.y = 0.0
        var corpo := get_parent() as Node3D
        if corpo:
            corpo.rotation.y = atan2(frente.x, frente.z)
        rotation.y = 0.0
    else:
        frente = global_transform.basis.z.normalized()
        var melhor_alvo: Node3D = null
        var menor_dist: float = 30.0
        
        for bicho in get_tree().get_nodes_in_group("bicho"):
            if not is_instance_valid(bicho):
                continue
            var ate: Vector3 = bicho.global_position - global_position
            ate.y = 0.0
            var d := ate.length()
            if d < menor_dist and frente.angle_to(ate.normalized()) < deg_to_rad(60.0):
                menor_dist = d
                melhor_alvo = bicho
                
        if melhor_alvo:
            frente = (melhor_alvo.global_position - global_position)
            frente.y = 0.0
            frente = frente.normalized()
            var corpo := get_parent() as Node3D
            if corpo:
                corpo.rotation.y = atan2(frente.x, frente.z)
            rotation.y = 0.0
        
    var origem := global_position + Vector3(0, 1.15, 0)
    
    # 2. Esfera de Carga de Energia nas Mãos (0.15s)
    var carga := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.4
    sphere.height = 0.8
    carga.mesh = sphere
    
    var mat_orb := StandardMaterial3D.new()
    mat_orb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_orb.albedo_color = Color(0.4, 0.9, 1.0, 0.95)
    carga.material_override = mat_orb
    carga.position = Vector3(0, 1.15, -0.6)
    add_child(carga)
    
    var tw_charge := create_tween()
    tw_charge.tween_property(carga, "scale", Vector3(1.6, 1.6, 1.6), 0.18)
    tw_charge.tween_callback(func():
        carga.queue_free()
        _disparar_feixe_laser(origem, frente)
    )

func _disparar_feixe_laser(origem: Vector3, frente: Vector3) -> void:
    var feixe_root := Node3D.new()
    feixe_root.name = "KamehamehaBeam"
    get_parent().add_child(feixe_root)
    feixe_root.global_position = origem
    
    if frente.length_squared() > 0.001:
        feixe_root.look_at(origem + frente, Vector3.UP)
        
    var mesh_inst := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.95
    cyl.bottom_radius = 0.35
    cyl.height = 28.0
    mesh_inst.mesh = cyl
    mesh_inst.position.z = -14.0
    mesh_inst.rotation_degrees.x = 90.0
    
    var mat_beam := StandardMaterial3D.new()
    mat_beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_beam.albedo_color = Color(0.25, 0.85, 1.0, 0.95)
    mat_beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh_inst.material_override = mat_beam
    feixe_root.add_child(mesh_inst)
    
    var l_beam := OmniLight3D.new()
    l_beam.light_color = Color(0.4, 0.9, 1.0)
    l_beam.light_energy = 9.0
    l_beam.omni_range = 16.0
    l_beam.position.z = -10.0
    feixe_root.add_child(l_beam)
    
    # Dano Massivo (350 DMG) a todos os inimigos no cone do feixe
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if not is_instance_valid(bicho):
            continue
        var ate: Vector3 = bicho.global_position - global_position
        ate.y = 0.0
        var dist := ate.length()
        if dist > 28.0:
            continue
        if frente.angle_to(ate.normalized()) < deg_to_rad(40.0):
            bicho.levar_dano(350.0, frente)
            
    var tw := create_tween()
    tw.tween_property(mesh_inst, "scale", Vector3(1.5, 1.0, 1.5), 0.15)
    tw.tween_property(mesh_inst, "scale", Vector3(0.0, 1.0, 0.0), 0.45)
    tw.tween_callback(func():
        feixe_root.queue_free()
        _atacando = false
        _animador.play("heroi/parado", 0.2)
    )

## Solta o heroi se a animacao longa nao se encerrar sozinha.
##
## O raio marca _atacando e so desmarca no fim de uma corrente de tweens. Se
## essa corrente se perder — troca de zona, no liberado no meio, animacao
## interrompida — a marca fica presa para sempre, e dai em diante atacar() so
## enfileira um golpe que nunca sai: o ataque basico morre em silencio ate
## recarregar a pagina. Era o "skill 3 e o basico bugados" juntos.
func _destravar_em(segundos: float) -> void:
    await get_tree().create_timer(segundos).timeout
    if not _atacando:
        return
    _atacando = false
    if _animador and _animador.current_animation != "heroi/parado":
        _animador.play("heroi/parado", MISTURA)


func _atingir() -> void:
    var origem := global_position
    # +Z e a frente, como no resto do projeto.
    #
    # Aqui estava -Z: o cone do golpe apontava para as COSTAS do heroi. A mira
    # em player.gd virava o corpo certo para o bicho, o swing saia bonito, e a
    # conferencia de quem foi atingido olhava para o lado oposto. O ataque
    # basico literalmente nao acertava nada que estivesse na frente.
    var frente := global_transform.basis.z.normalized()
    var alcance: float = 5.5 if _buff_espada_gigante else ALCANCE_DO_GOLPE
    var abertura: float = 360.0 if _buff_espada_gigante else ABERTURA_DO_GOLPE
    var dano_base: float = DANO * 1.8 if _buff_aura_azul else DANO
    
    var acertou := false
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if not is_instance_valid(bicho):
            continue
        var ate: Vector3 = bicho.global_position - origem
        ate.y = 0.0
        var distancia := ate.length()
        if distancia > alcance or distancia < 0.05:
            continue
        if abertura < 350.0 and frente.angle_to(ate.normalized()) > deg_to_rad(abertura * 0.5):
            continue
        bicho.levar_dano(dano_base, ate.normalized())
        acertou = true
        
    if acertou and _buff_aura_azul:
        var hud = get_tree().get_first_node_in_group("player_hud")
        if hud == null:
            hud = get_node_or_null("/root/ZonedWorld/HUD/PlayerHUD")
        if hud and hud.has_method("curar"):
            hud.curar(35.0)

func _tocar_nota() -> void:
    var nota: String = ESCALA[_proxima_nota]
    _proxima_nota = (_proxima_nota + 1) % ESCALA.size()
    _voz.stream = load("res://audio/nota_%s.wav" % nota)
    _voz.play()

func _ao_terminar(animacao: StringName) -> void:
    if not String(animacao).trim_prefix("heroi/") in COMBO:
        return

    _atacando = false
    _ultimo_golpe_em = Time.get_ticks_msec() / 1000.0

    if _golpe_pedido:
        _golpe_pedido = false
        atacar()
        return

    if _espada:
        # Guarda a espada — a nao ser que a skill da espada gigante ainda esteja
        # correndo, que e justamente quando ela tem de ficar a mostra.
        _espada.visible = _buff_espada_gigante
    _animador.play("heroi/parado", MISTURA)
