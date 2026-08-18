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
## Comprimento da espada no mundo, em metros. 1.15 m num heroi de 1.75 m e a
## proporcao da arte: lamina longa, quase montante.
const COMPRIMENTO_DA_ESPADA := 1.15
const MISTURA := 0.18

## A lamina do Akles e um teclado: cada golpe toca a proxima nota da escala de
## Do maior, afinada de verdade (A4 = 440 Hz). E jogo de educacao musical — som
## desafinado aqui ensinaria errado.
const ESCALA := ["do", "re", "mi", "fa", "sol", "la", "si"]

var _animador: AnimationPlayer
var _atacando := false
var _voz: AudioStreamPlayer
var _proxima_nota := 0

func _ready() -> void:
    var modelo := (load("res://personagem/heroi_base.fbx") as PackedScene).instantiate()
    add_child(modelo)

    _animador = modelo.find_child("AnimationPlayer", true, false)
    _animador.add_animation_library("heroi", load("res://personagem/heroi_anims.res"))
    _animador.animation_finished.connect(_ao_terminar)

    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var altura: float = malha.get_aabb().size.y
        if altura > 0.0:
            modelo.scale = Vector3.ONE * (ALTURA_ALVO / altura)
        # O modelo do Mixamo olha para +Z; o jogador gira para -Z ao andar.
        modelo.rotation.y = PI
        break

    _voz = AudioStreamPlayer.new()
    add_child(_voz)

    _equipar_espada(modelo)
    _animador.play("heroi/parado")

## Prende a espada na mao direita.
##
## O nome do osso muda conforme a versao do importador (mixamorig:RightHand,
## mixamorig_RightHand, RightHand), entao a busca e por sufixo em vez de nome
## exato — chutar o nome quebraria calado, com a espada no chao.
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

    var espada := (load("res://models/espada_akles.glb") as PackedScene).instantiate()
    suporte.add_child(espada)

    # A espada esta DENTRO do esqueleto, que foi ampliado ~176x para o heroi ter
    # 1.75 m. Sem descontar essa ampliacao, ela sairia do tamanho de uma casa.
    var altura_da_espada := 0.94
    var escala_do_modelo: float = modelo.scale.x
    espada.scale = Vector3.ONE * (COMPRIMENTO_DA_ESPADA / altura_da_espada / escala_do_modelo)
    # Punho na mao e lamina para fora: o modelo nasce com a lamina em +Y.
    espada.rotation_degrees = Vector3(0.0, 0.0, -90.0)
    espada.position = Vector3(0.0, 0.02 / escala_do_modelo, 0.0)

    for malha in espada.find_children("*", "MeshInstance3D", true, false):
        malha.material_override = load("res://Material_TripoSR.tres")

## Chamado pelo jogador a cada quadro com a velocidade no plano.
func atualizar_movimento(velocidade: float) -> void:
    if _atacando:
        return
    var desejada := "heroi/parado"
    if velocidade > VELOCIDADE_DE_CORRIDA:
        desejada = "heroi/correr"
    elif velocidade > 0.2:
        desejada = "heroi/andar"
    if _animador.current_animation != desejada:
        _animador.play(desejada, MISTURA)

func atacar() -> void:
    if _atacando:
        return
    _atacando = true
    _animador.play("heroi/corte_fora", MISTURA)
    _tocar_nota()

func _tocar_nota() -> void:
    var nota: String = ESCALA[_proxima_nota]
    _proxima_nota = (_proxima_nota + 1) % ESCALA.size()
    _voz.stream = load("res://audio/nota_%s.wav" % nota)
    _voz.play()

func _ao_terminar(animacao: StringName) -> void:
    if animacao == &"heroi/corte_fora":
        _atacando = false
        _animador.play("heroi/parado", MISTURA)
