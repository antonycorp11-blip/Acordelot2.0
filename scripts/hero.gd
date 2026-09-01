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
## O GOLPE FICOU MAIS RAPIDO.
##
## A 1,85 o swing durava perto de um segundo do toque ate a lamina voltar, e o
## que se sentia era atraso: o dedo pedia e o heroi respondia depois. Aqui a
## animacao corre mais e o impacto acontece mais cedo dentro dela.
const VELOCIDADE_DO_GOLPE := 2.35

## Alcance da lamina, em metros, medido do peito do heroi.
const ALCANCE_DO_GOLPE := 2.6
## Abertura do golpe em graus. Nao e cone estreito: espada larga acerta o que
## esta de lado, e exigir mira fina num jogo de toque so gera golpe no vazio.
const ABERTURA_DO_GOLPE := 120.0
const DANO := 34.0
## Em que ponto da animacao a lamina passa pelo alvo. Aplicar o dano no comeco
## faz o bicho voar antes do golpe sair, e no fim faz parecer que nao pegou.
const INSTANTE_DO_IMPACTO := 0.30

## Encaixe da espada na mao.
@export var comprimento_da_espada := 1.15
@export var fracao_do_cabo := 0.85
@export var ajuste_do_punho := Vector3.ZERO
## A LAMINA CAI AO LONGO DA PERNA, NAO CRUZANDO A FRENTE.
##
## Com o giro so em X a espada apontava para baixo E para a frente: a ponta
## terminava adiante dos pes, atravessando a perna de quem olha de lado, como se
## o heroi arrastasse a arma. Os vinte e oito graus em Z encostam a lamina no
## corpo — comparado lado a lado com cinco outros encaixes antes de ficar aqui.
@export var giro_do_punho := Vector3(180.0, 0.0, -28.0)

const ESCALA := ["do", "re", "mi", "fa", "sol", "la", "si"]
const SONS_NOTAS := [
    preload("res://audio/nota_do.wav"), preload("res://audio/nota_re.wav"),
    preload("res://audio/nota_mi.wav"), preload("res://audio/nota_fa.wav"),
    preload("res://audio/nota_sol.wav"), preload("res://audio/nota_la.wav"),
    preload("res://audio/nota_si.wav"),
]
const COMBO := ["corte_fora", "corte_dentro", "ataque_pulo"]
const PAUSA_DO_COMBO := 1.2

var _animador: AnimationPlayer
var _atacando := false
var _voz: AudioStreamPlayer
var _proxima_nota := 0
var _golpe := 0
var _ultimo_golpe_em := -100.0
var _golpe_pedido := false
var _golpe_acertou := false
var _espada: Node3D = null
var _lamina: Node3D = null
var _escala_do_modelo := 1.0

var _indicador_mira_chao: Node3D = null

var _buff_aura_azul: bool = false
var _buff_espada_gigante: bool = false
var _aura_fx_node: Node3D = null
var _espada_light: OmniLight3D = null
var _carga_fx: MeshInstance3D = null
var _feixe_fx_root: Node3D = null
var _feixe_fx_mesh: MeshInstance3D = null
var _tween_carga: Tween = null
var _tween_feixe: Tween = null

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
    _preparar_fx_skills()

    if _espada:
        _espada.visible = false
    _animador.play("heroi/parado")

func _construir_indicador_mira_chao() -> void:
    _indicador_mira_chao = Node3D.new()
    _indicador_mira_chao.name = "IndicadorMiraLaser"
    _indicador_mira_chao.top_level = true
    _indicador_mira_chao.visible = false
    add_child(_indicador_mira_chao)

    _malha_da_mira = ImmediateMesh.new()
    var mi := MeshInstance3D.new()
    mi.mesh = _malha_da_mira
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # A caixa e declarada na mao porque a malha muda toda vez: sem isto o motor
    # calcula os limites a partir do primeiro desenho e some com a seta quando
    # ela passa a subir a ladeira.
    mi.custom_aabb = AABB(Vector3(-6.0, -20.0, -2.0), Vector3(12.0, 40.0, 30.0))

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    # Nao escreve profundidade: a faixa se sobrepoe a si mesma nas dobras do
    # relevo, e escrevendo uma fatia recortaria a outra em degrau.
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mi.material_override = mat

    _indicador_mira_chao.add_child(mi)


## A mira DESENHADA SOBRE O RELEVO, fatia por fatia.
##
## Antes era uma faixa plana, rigida, na altura dos pes do heroi: bastava a
## menor ladeira para a metade da frente entrar no barranco, e o jogador mirava
## no escuro. Agora a faixa e cortada em fatias e cada emenda pergunta ao chao
## em que altura ela cai — o raio vai de cinco metros acima do ponto ate cinco
## abaixo, que cobre qualquer degrau que a vila e a floresta tenham.
##
## Vinte raios por quadro, e so enquanto o dedo esta arrastando a mira. E o
## mesmo preco de um tiro de arma qualquer, pago apenas nos segundos em que a
## habilidade esta sendo apontada.
const FATIAS := 20
const ALCANCE_DA_MIRA := 24.5
## Onde a faixa comeca: colada no heroi ela desenha por cima dos proprios pes.
const INICIO_DA_MIRA := 0.8
## Um palmo acima do chao. Menos que isso e a faixa briga com o terreno pelo
## mesmo pixel e pisca; mais, e ela descola visivelmente na descida.
const ALTURA_SOBRE_O_CHAO := 0.12

var _malha_da_mira: ImmediateMesh = null


func _desenhar_mira(direcao: Vector3) -> void:
    if _malha_da_mira == null:
        return
    _malha_da_mira.clear_surfaces()
    _malha_da_mira.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

    var frente := direcao.normalized()
    var lado := Vector3(frente.z, 0.0, -frente.x)
    var origem := global_position

    var passo: float = (ALCANCE_DA_MIRA - INICIO_DA_MIRA) / float(FATIAS)
    var anterior_esq := Vector3.ZERO
    var anterior_dir := Vector3.ZERO

    for i in range(FATIAS + 1):
        var distancia: float = INICIO_DA_MIRA + passo * i
        var fracao: float = distancia / ALCANCE_DA_MIRA
        # A faixa afina ate o fim da haste e abre na ponta de flecha.
        var meia_largura: float = 0.45 if fracao < 0.82 else lerpf(1.7, 0.05, (fracao - 0.82) / 0.18)

        var centro := origem + frente * distancia
        centro.y = _altura_do_chao(centro) + ALTURA_SOBRE_O_CHAO

        var esq := centro - lado * meia_largura
        var dir := centro + lado * meia_largura

        if i > 0:
            var cor := Color(0.2, 0.85, 1.0, lerpf(0.55, 0.85, fracao))
            _malha_da_mira.surface_set_color(cor)
            _malha_da_mira.surface_add_vertex(anterior_esq)
            _malha_da_mira.surface_add_vertex(anterior_dir)
            _malha_da_mira.surface_add_vertex(dir)

            _malha_da_mira.surface_add_vertex(anterior_esq)
            _malha_da_mira.surface_add_vertex(dir)
            _malha_da_mira.surface_add_vertex(esq)

        anterior_esq = esq
        anterior_dir = dir

    _malha_da_mira.surface_end()


## Em que altura esta o chao sob um ponto.
##
## Raio de fisica e nao a formula do terreno: a mira tambem serve dentro das
## cidades e em cima das pontes, onde o chao que vale nao e a malha do relevo.
func _altura_do_chao(ponto: Vector3) -> float:
    var espaco := get_world_3d().direct_space_state
    var consulta := PhysicsRayQueryParameters3D.create(
        ponto + Vector3.UP * 5.0, ponto + Vector3.DOWN * 5.0)
    consulta.collide_with_areas = false
    var achado := espaco.intersect_ray(consulta)
    # Sem chao embaixo (beira de penhasco, agua): mantem a altura do heroi, que
    # e melhor do que a faixa despencar para o infinito.
    return float(achado.position.y) if achado.has("position") else global_position.y


func mostrar_mira_laser(direcao_mundo: Vector3) -> void:
    if _indicador_mira_chao == null:
        return
    _indicador_mira_chao.visible = true
    # A faixa e desenhada em coordenadas do mundo: o no fica na origem para o
    # desenho nao ser deslocado duas vezes.
    _indicador_mira_chao.global_position = Vector3.ZERO
    _indicador_mira_chao.global_rotation = Vector3.ZERO
    if direcao_mundo.length_squared() > 0.01:
        _direcao_da_mira = direcao_mundo.normalized()
    _desenhar_mira(_direcao_da_mira)


var _direcao_da_mira := Vector3.FORWARD


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
    # A mira acompanha o heroi enquanto ele anda: a faixa nasce nos pes dele e
    # segue o relevo a frente, e as duas coisas mudam quando ele se move.
    if _indicador_mira_chao and _indicador_mira_chao.visible:
        _desenhar_mira(_direcao_da_mira)

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


## ANDAR CANCELA O RESTO DA ANIMACAO.
##
## O golpe tem duas metades: a que vai ate a lamina passar pelo alvo, e a
## recuperacao depois. A primeira e o ataque; a segunda e so o heroi voltando a
## posicao, e e nela que o controle parecia travado e desajeitado — o jogador ja
## queria andar e o boneco ainda estava guardando a espada. Depois do impacto,
## qualquer movimento corta o resto. Antes do impacto nao corta: golpe que some
## no meio do caminho toda vez que o polegar encosta no direcional e pior ainda.
func pode_cancelar_golpe() -> bool:
    return _atacando and _golpe_acertou


func cancelar_golpe() -> void:
    if not _atacando:
        return
    _atacando = false
    _golpe_acertou = false
    _golpe_pedido = false
    _ultimo_golpe_em = Time.get_ticks_msec() / 1000.0
    if _espada:
        _espada.visible = _buff_espada_gigante

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
    _golpe_acertou = false
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
    _golpe_acertou = true
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
            _aura_fx_node.visible = false
    )

func _criar_aura_azul_visual() -> void:
    if _aura_fx_node and is_instance_valid(_aura_fx_node):
        _aura_fx_node.visible = true
        return

    _aura_fx_node = Node3D.new()
    _aura_fx_node.name = "AuraAzulFX"
    add_child(_aura_fx_node)
    
    var light := OmniLight3D.new()
    light.light_color = Color(0.2, 0.7, 1.0)
    light.light_energy = 3.5
    light.omni_range = 4.5
    light.position.y = 1.0
    _aura_fx_node.add_child(light)
    
    # PARTICULA EM VOLTA, NAO UM ARO NO CHAO.
    #
    # Isto era um TorusMesh deitado nos pes: um circulo azul solido, que parecia
    # marcador de area de skill e nao poder acumulado no corpo de quem esta
    # buffado. O que a skill pede e brilho subindo em volta do heroi — entao sao
    # fagulhas nascendo num anel na altura do corpo e subindo, que e o que se
    # enxerga de qualquer angulo e nao suja o chao.
    var fagulhas := CPUParticles3D.new()
    fagulhas.name = "FagulhasDoBuff"
    fagulhas.amount = 46
    fagulhas.lifetime = 1.15
    fagulhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
    fagulhas.emission_ring_axis = Vector3.UP
    fagulhas.emission_ring_radius = 0.62
    fagulhas.emission_ring_inner_radius = 0.40
    fagulhas.emission_ring_height = 1.7
    fagulhas.direction = Vector3.UP
    fagulhas.spread = 6.0
    fagulhas.initial_velocity_min = 0.5
    fagulhas.initial_velocity_max = 1.5
    fagulhas.gravity = Vector3(0.0, 1.4, 0.0)
    fagulhas.scale_amount_min = 0.5
    fagulhas.scale_amount_max = 1.1
    fagulhas.position.y = 0.15

    var brilho := QuadMesh.new()
    brilho.size = Vector2(0.20, 0.20)
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = load("res://textures/brilho_poste.png")
    mat.albedo_color = Color(0.40, 0.85, 1.0)
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    brilho.material = mat
    fagulhas.mesh = brilho
    _aura_fx_node.add_child(fagulhas)


## Os efeitos vivem durante toda a sessao e apenas alternam visibilidade.
## Criar malha, material e luz no quadro do toque era a fonte dos engasgos
## recorrentes das skills, mesmo depois do primeiro aquecimento.
func _preparar_fx_skills() -> void:
    _criar_aura_azul_visual()
    _aura_fx_node.visible = false

    _espada_light = OmniLight3D.new()
    _espada_light.light_color = Color(1.0, 0.85, 0.25)
    _espada_light.light_energy = 5.0
    _espada_light.omni_range = 6.0
    _espada_light.visible = false
    _espada.add_child(_espada_light)

    _carga_fx = MeshInstance3D.new()
    var esfera := SphereMesh.new()
    esfera.radius = 0.4
    esfera.height = 0.8
    _carga_fx.mesh = esfera
    var mat_orbe := StandardMaterial3D.new()
    mat_orbe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_orbe.albedo_color = Color(0.4, 0.9, 1.0, 0.95)
    _carga_fx.material_override = mat_orbe
    _carga_fx.position = Vector3(0, 1.15, -0.6)
    _carga_fx.visible = false
    add_child(_carga_fx)

    _feixe_fx_root = Node3D.new()
    _feixe_fx_root.name = "KamehamehaBeamPool"
    _feixe_fx_root.top_level = true
    _feixe_fx_root.visible = false
    add_child(_feixe_fx_root)
    _feixe_fx_mesh = MeshInstance3D.new()
    var cilindro := CylinderMesh.new()
    cilindro.top_radius = 0.95
    cilindro.bottom_radius = 0.35
    cilindro.height = 28.0
    _feixe_fx_mesh.mesh = cilindro
    _feixe_fx_mesh.position.z = -14.0
    _feixe_fx_mesh.rotation_degrees.x = 90.0
    var mat_feixe := StandardMaterial3D.new()
    mat_feixe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_feixe.albedo_color = Color(0.25, 0.85, 1.0, 0.95)
    mat_feixe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _feixe_fx_mesh.material_override = mat_feixe
    _feixe_fx_root.add_child(_feixe_fx_mesh)
    var luz_feixe := OmniLight3D.new()
    luz_feixe.light_color = Color(0.4, 0.9, 1.0)
    luz_feixe.light_energy = 9.0
    luz_feixe.omni_range = 16.0
    luz_feixe.position.z = -10.0
    _feixe_fx_root.add_child(luz_feixe)

func ativar_espada_gigante() -> void:
    if _buff_espada_gigante:
        return
    _buff_espada_gigante = true
    if _espada:
        # A LAMINA CRESCE, NAO TROCA DE TAMANHO.
        #
        # Antes ela pulava de 1 para 2,5 num quadro: parecia troca de modelo, e
        # nao uma espada ganhando poder. Um quarto de segundo com folga no fim
        # da peso ao crescimento — o mesmo tempo que a luz leva para acender.
        _espada.scale = Vector3.ONE
        var crescer := create_tween()
        crescer.tween_property(_espada, "scale", Vector3.ONE * 2.5, 0.26) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
            var encolher := create_tween()
            encolher.tween_property(_espada, "scale", Vector3.ONE, 0.20) \
                .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
            _fazer_espada_brilhar(false)
            _espada.visible = _atacando
    )

func _fazer_espada_brilhar(brilhar: bool) -> void:
    if not _espada:
        return
    if brilhar:
        if _espada_light:
            _espada_light.visible = true
        for malha in _espada.find_children("*", "MeshInstance3D", true, false):
            var mat = malha.material_override as StandardMaterial3D
            if mat:
                mat.emission_enabled = true
                mat.emission = Color(1.0, 0.85, 0.2)
                mat.emission_energy_multiplier = 4.0
    else:
        if _espada_light and is_instance_valid(_espada_light):
            _espada_light.visible = false
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
    
    # A esfera ja esta pronta: o toque so a mostra e anima.
    if _tween_carga and _tween_carga.is_valid():
        _tween_carga.kill()
    _carga_fx.visible = true
    _carga_fx.scale = Vector3.ONE
    _tween_carga = create_tween()
    _tween_carga.tween_property(_carga_fx, "scale", Vector3(1.6, 1.6, 1.6), 0.18)
    _tween_carga.tween_callback(func():
        _carga_fx.visible = false
        _disparar_feixe_laser(origem, frente)
    )

func _disparar_feixe_laser(origem: Vector3, frente: Vector3) -> void:
    var feixe_root := _feixe_fx_root
    feixe_root.visible = true
    feixe_root.global_position = origem
    
    if frente.length_squared() > 0.001:
        feixe_root.look_at(origem + frente, Vector3.UP)
        
    var mesh_inst := _feixe_fx_mesh
    mesh_inst.scale = Vector3.ONE
    
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
            bicho.levar_dano(_dano_atual() * 5.8 * (1.0 + (_nivel_da_skill("skill_3") - 1) * 0.08), frente)
            
    if _tween_feixe and _tween_feixe.is_valid():
        _tween_feixe.kill()
    _tween_feixe = create_tween()
    _tween_feixe.tween_property(mesh_inst, "scale", Vector3(1.5, 1.0, 1.5), 0.15)
    _tween_feixe.tween_property(mesh_inst, "scale", Vector3(0.0, 1.0, 0.0), 0.45)
    _tween_feixe.tween_callback(func():
        feixe_root.visible = false
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
    var multiplicador_aura := 1.0 + 0.8 + (_nivel_da_skill("skill_1") - 1) * 0.07
    var multiplicador_espada := 1.0 + (_nivel_da_skill("skill_2") - 1) * 0.06
    var dano_base: float = _dano_atual() * (multiplicador_aura if _buff_aura_azul else 1.0)
    if _buff_espada_gigante:
        dano_base *= multiplicador_espada
    var stats := _estatisticas_atuais()
    
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
        var dano_final := dano_base
        if randf() * 100.0 < float(stats.get("critico", 0.0)):
            dano_final *= float(stats.get("dano_critico", 135.0)) / 100.0
        bicho.levar_dano(dano_final, ate.normalized())
        acertou = true
        
    if acertou and _buff_aura_azul:
        var hud = get_tree().get_first_node_in_group("player_hud")
        if hud == null:
            hud = get_node_or_null("/root/ZonedWorld/HUD/PlayerHUD")
        if hud and hud.has_method("curar"):
            hud.curar(35.0)


func _estatisticas_atuais() -> Dictionary:
    var progresso := get_node_or_null("/root/Progresso")
    return progresso.estatisticas() if progresso else {"ataque": DANO}


func _dano_atual() -> float:
    var progresso := get_node_or_null("/root/Progresso")
    var nivel_skill := int(progresso.niveis_skills.get("ataque_basico", 1)) if progresso else 1
    return float(_estatisticas_atuais().get("ataque", DANO)) * (1.0 + (nivel_skill - 1) * 0.05)


func _nivel_da_skill(id: String) -> int:
    var progresso := get_node_or_null("/root/Progresso")
    return int(progresso.niveis_skills.get(id, 1)) if progresso else 1

func _tocar_nota() -> void:
    _voz.stream = SONS_NOTAS[_proxima_nota]
    _proxima_nota = (_proxima_nota + 1) % ESCALA.size()
    _voz.play()

func _ao_terminar(animacao: StringName) -> void:
    if not String(animacao).trim_prefix("heroi/") in COMBO:
        return

    _atacando = false
    _golpe_acertou = false
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
