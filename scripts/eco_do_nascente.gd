extends Node3D
class_name EcoDoNascente

@export_range(0.55, 0.90, 0.01) var altura_aparente_m: float = 0.72
@export_range(0.0, 0.12, 0.005) var amplitude_flutuacao: float = 0.065
@export_range(1.0, 4.0, 0.1) var periodo_flutuacao: float = 2.1
@export var velocidade_normal: float = 1.55
@export var velocidade_corrida: float = 3.65
@export var eco_id: String = "do"
@export var capturavel: bool = false
@export var passeio_natural: bool = false
@export var usar_particulas: bool = true
@export_range(1.0, 8.0, 0.25) var raio_do_passeio: float = 3.5

@onready var visual: Node3D = $Visual
@onready var sprite: AnimatedSprite3D = $Visual/AnimatedSprite3D
@onready var area: Area3D = $Area3D
@onready var particulas: GPUParticles3D = $GPUParticles3D

var _direcao := Vector3.ZERO
var _rapido := false
var _acao_uma_vez := false
var _desaparecido := false
var _altura_visual_inicial := 0.46
var _tempo_flutuacao := 0.0
var _origem_do_passeio := Vector3.ZERO
var _destino_do_passeio := Vector3.ZERO
var _espera_do_passeio := 1.4
var _sorte := RandomNumberGenerator.new()
var _ate_assentar := 0.0
var _ate_conferir_distancia := 0.0
var _longe_da_camera := false
var _terreno: Node = null
var _alvo_seguidor: Node3D = null


func _ready() -> void:
    _altura_visual_inicial = visual.position.y
    # O primeiro Eco usa canvas de 220 px; os novos atlases usam 128 px para
    # economizar memoria. Ajuste pelos dois formatos sem exigir escala por cena.
    var quadro := sprite.sprite_frames.get_frame_texture(&"idle", 0)
    var altura_de_referencia := 150.0 if quadro == null or quadro.get_height() > 180 else float(quadro.get_height()) * 0.66
    sprite.pixel_size = altura_aparente_m / altura_de_referencia
    sprite.animation_finished.connect(_ao_terminar_animacao)
    sprite.play(&"idle")
    if not usar_particulas:
        particulas.emitting = false
        particulas.visible = false
        particulas.process_mode = Node.PROCESS_MODE_DISABLED
    _origem_do_passeio = global_position
    _destino_do_passeio = global_position
    _sorte.seed = hash(name + str(get_instance_id()))
    # Espalha as conferencias entre quadros. Onze temporizadores sincronizados
    # criavam um pequeno pico a cada meio segundo mesmo fazendo pouco trabalho.
    _ate_conferir_distancia = _sorte.randf_range(0.05, 0.50)
    _ate_assentar = _sorte.randf_range(0.05, 0.45)
    # A captura ainda nao existe. Manter onze Areas monitorando o mundo sem
    # qualquer sinal conectado so aumenta o broadphase de fisica.
    area.monitoring = false
    area.monitorable = false


func definir_terreno(terreno: Node) -> void:
    _terreno = terreno


func definir_seguidor(alvo: Node3D) -> void:
    _alvo_seguidor = alvo
    passeio_natural = false


func esta_disponivel_para_captura() -> bool:
    return capturavel and not _desaparecido and not _acao_uma_vez


func _process(delta: float) -> void:
    if _desaparecido:
        return
    _ate_conferir_distancia -= delta
    if _ate_conferir_distancia <= 0.0:
        _ate_conferir_distancia = 0.5
        var camera := get_viewport().get_camera_3d()
        var longe_agora := camera != null and global_position.distance_squared_to(camera.global_position) > 34.0 * 34.0
        if longe_agora != _longe_da_camera:
            _longe_da_camera = longe_agora
            if _longe_da_camera:
                sprite.pause()
            else:
                _atualizar_animacao_de_movimento()
    if _longe_da_camera:
        return
    _tempo_flutuacao += delta
    visual.position.y = _altura_visual_inicial + sin(_tempo_flutuacao * TAU / periodo_flutuacao) * amplitude_flutuacao

    if _alvo_seguidor and is_instance_valid(_alvo_seguidor) and not _acao_uma_vez:
        _processar_seguidor()
    elif passeio_natural and not _acao_uma_vez:
        _processar_passeio(delta)

    if not _acao_uma_vez and _direcao.length_squared() > 0.001:
        var velocidade := velocidade_corrida if _rapido else velocidade_normal
        position += _direcao * velocidade * delta
        _virar_para_o_movimento()
        _ate_assentar -= delta
        if _ate_assentar <= 0.0:
            _ate_assentar = 0.45
            _assentar_no_terreno()


## Move a raiz fisica no plano X/Z. O sprite jamais simula deslocamento.
func definir_movimento(direcao: Vector3, rapido: bool = false) -> void:
    if _desaparecido or _acao_uma_vez:
        return
    _direcao = Vector3(direcao.x, 0.0, direcao.z).normalized()
    _rapido = rapido
    _atualizar_animacao_de_movimento()


func parar() -> void:
    _direcao = Vector3.ZERO
    _rapido = false
    if not _acao_uma_vez and not _desaparecido:
        sprite.play(&"idle")


func play_attack() -> void:
    _tocar_uma_vez(&"attack")


func play_hurt() -> void:
    _tocar_uma_vez(&"hurt")


func play_disappear() -> void:
    if _desaparecido:
        return
    _acao_uma_vez = true
    _direcao = Vector3.ZERO
    sprite.play(&"disappear")
    await sprite.animation_finished
    _desaparecido = true
    visual.visible = false
    particulas.emitting = false
    area.monitoring = false
    area.monitorable = false


func reaparecer() -> void:
    # Gancho barato para pooling futuro; nao recria recursos nem a cena.
    _desaparecido = false
    _acao_uma_vez = false
    visual.visible = true
    particulas.emitting = usar_particulas
    area.monitoring = false
    area.monitorable = false
    sprite.play(&"idle")


func _tocar_uma_vez(animacao: StringName) -> void:
    if _desaparecido or _acao_uma_vez:
        return
    _acao_uma_vez = true
    sprite.play(animacao)


func _ao_terminar_animacao() -> void:
    if sprite.animation == &"disappear":
        return
    _acao_uma_vez = false
    _atualizar_animacao_de_movimento()


func _atualizar_animacao_de_movimento() -> void:
    if _desaparecido or _acao_uma_vez:
        return
    if _direcao.length_squared() <= 0.001:
        if sprite.animation != &"idle" or not sprite.is_playing():
            sprite.play(&"idle")
    elif _rapido:
        if sprite.animation != &"run" or not sprite.is_playing():
            sprite.play(&"run")
    else:
        if sprite.animation != &"walk" or not sprite.is_playing():
            sprite.play(&"walk")


## O Eco e pacifico com humanos: esta rotina apenas escolhe pequenos destinos,
## caminha, muda de direcao e descansa. Nenhum ataque e disparado por ela.
func _processar_passeio(delta: float) -> void:
    if _direcao.length_squared() > 0.001:
        var restante := Vector2(_destino_do_passeio.x - global_position.x,
            _destino_do_passeio.z - global_position.z)
        if restante.length() <= 0.18:
            parar()
            _espera_do_passeio = _sorte.randf_range(1.2, 3.2)
        return
    _espera_do_passeio -= delta
    if _espera_do_passeio > 0.0:
        return
    var angulo := _sorte.randf_range(0.0, TAU)
    var distancia := _sorte.randf_range(1.4, raio_do_passeio)
    _destino_do_passeio = _origem_do_passeio + Vector3(cos(angulo), 0.0, sin(angulo)) * distancia
    definir_movimento(_destino_do_passeio - global_position)


func _processar_seguidor() -> void:
    var destino := _alvo_seguidor.global_position
    destino += _alvo_seguidor.global_basis.x * 0.72
    destino -= _alvo_seguidor.global_basis.z * 0.58
    var ate := destino - global_position
    ate.y = 0.0
    var distancia := ate.length()
    if distancia < 0.88:
        if _direcao.length_squared() > 0.001:
            parar()
        return
    definir_movimento(ate, distancia > 2.8)


func _virar_para_o_movimento() -> void:
    var camera := get_viewport().get_camera_3d()
    if camera:
        # As folhas originais olham para a esquerda. Ao mover para a direita
        # da tela, espelhe a arte; a condicao anterior fazia o oposto.
        sprite.flip_h = _direcao.dot(camera.global_basis.x) > 0.0
    else:
        sprite.flip_h = _direcao.x > 0.0


func _assentar_no_terreno() -> void:
    # Nas zonas do jogo a altura ja e uma funcao pura do construtor. Usa-la
    # evita dezenas de raycasts por segundo quando todos os Ecos estao juntos.
    if _terreno != null and _terreno.has_method("calcular_altura"):
        global_position.y = float(_terreno.calcular_altura(global_position.x, global_position.z)) + 0.03
        return
    var mundo := get_world_3d()
    if mundo == null:
        return
    var inicio := global_position + Vector3.UP * 4.0
    var fim := global_position + Vector3.DOWN * 8.0
    var consulta := PhysicsRayQueryParameters3D.create(inicio, fim, 1)
    consulta.collide_with_areas = false
    var impacto := mundo.direct_space_state.intersect_ray(consulta)
    if not impacto.is_empty():
        global_position.y = (impacto.position as Vector3).y + 0.03
