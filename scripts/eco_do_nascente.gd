extends Node3D
class_name EcoDoNascente

@export_range(0.55, 0.90, 0.01) var altura_aparente_m: float = 0.72
@export_range(0.0, 0.12, 0.005) var amplitude_flutuacao: float = 0.065
@export_range(1.0, 4.0, 0.1) var periodo_flutuacao: float = 2.1
@export var velocidade_normal: float = 1.15
@export var velocidade_corrida: float = 2.25
@export var modo_demonstracao: bool = false

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
var _fase_demo := 0
var _tempo_demo := 2.0


func _ready() -> void:
    _altura_visual_inicial = visual.position.y
    # A arte ocupa aproximadamente 150 px de altura dentro do canvas comum.
    # Assim a escala exposta representa metros aparentes, e nao um fator magico.
    sprite.pixel_size = altura_aparente_m / 150.0
    sprite.animation_finished.connect(_ao_terminar_animacao)
    sprite.play(&"idle")


func _process(delta: float) -> void:
    if _desaparecido:
        return
    _tempo_flutuacao += delta
    visual.position.y = _altura_visual_inicial + sin(_tempo_flutuacao * TAU / periodo_flutuacao) * amplitude_flutuacao

    if not _acao_uma_vez and _direcao.length_squared() > 0.001:
        var velocidade := velocidade_corrida if _rapido else velocidade_normal
        position += _direcao * velocidade * delta

    if modo_demonstracao:
        _processar_demonstracao(delta)


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
    particulas.emitting = true
    area.monitoring = true
    area.monitorable = true
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
        sprite.play(&"idle")
    elif _rapido:
        sprite.play(&"run")
    else:
        sprite.play(&"walk")


## Exercita, em um quadrado pequeno, idle/walk/run/attack/hurt no unico Eco
## de validacao. As idas e voltas se anulam para ele nao abandonar o jogador.
func _processar_demonstracao(delta: float) -> void:
    if _acao_uma_vez:
        return
    _tempo_demo -= delta
    if _tempo_demo > 0.0:
        return
    match _fase_demo:
        0:
            definir_movimento(Vector3.RIGHT)
            _tempo_demo = 0.9
        1:
            definir_movimento(Vector3.LEFT)
            _tempo_demo = 0.9
        2:
            definir_movimento(Vector3.FORWARD, true)
            _tempo_demo = 0.45
        3:
            definir_movimento(Vector3.BACK, true)
            _tempo_demo = 0.45
        4:
            parar()
            play_attack()
            _tempo_demo = 0.85
        5:
            play_hurt()
            _tempo_demo = 0.70
        _:
            parar()
            _tempo_demo = 2.0
    _fase_demo = (_fase_demo + 1) % 7
