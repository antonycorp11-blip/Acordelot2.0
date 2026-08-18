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

## Sequencia de golpes: cada toque puxa o proximo. Um so golpe repetido faz o
## combate parecer quebrado mesmo quando esta funcionando.
const COMBO := ["corte_fora", "corte_dentro", "ataque_pulo"]
## Parado este tempo, o combo recomeca do primeiro golpe.
const PAUSA_DO_COMBO := 1.2

var _animador: AnimationPlayer
var _atacando := false
var _voz: AudioStreamPlayer
var _proxima_nota := 0
var _golpe := 0
var _ultimo_golpe_em := -100.0

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

    # A espada entra dentro de um suporte de orientacao. Sem ele, deslocar o
    # punho e girar a lamina brigam entre si: a posicao vale no espaco do OSSO e
    # a rotacao vale dentro da espada, entao somar os dois na mesma pessoa punha
    # a mao no meio da lamina — foi o que aconteceu.
    var punho := Node3D.new()
    punho.name = "Punho"
    suporte.add_child(punho)

    var espada := (load("res://models/espada_akles.glb") as PackedScene).instantiate()
    punho.add_child(espada)

    # A espada esta DENTRO do esqueleto, ampliado ~176x para o heroi ter 1.75 m.
    # Sem descontar essa ampliacao ela sairia do tamanho de uma casa.
    var altura_da_espada := 0.94
    var escala_do_modelo: float = modelo.scale.x
    var escala := COMPRIMENTO_DA_ESPADA / altura_da_espada / escala_do_modelo
    espada.scale = Vector3.ONE * escala

    # Medido na malha: a fatia mais estreita (o cabo) fica a 85% da altura, com a
    # guarda — a mais larga — aos 65%, e a lamina descendo dai. Entao o cabo esta
    # ACIMA do centro, e trazer esse ponto para a origem e o que poe a mao no
    # lugar certo em vez de no meio da lamina.
    const FRACAO_DO_CABO := 0.85
    espada.position = Vector3(0.0, -(FRACAO_DO_CABO - 0.5) * altura_da_espada * escala, 0.0)

    # Com o cabo na origem, a lamina aponta para -Y da espada. Os ossos do
    # Mixamo encadeiam ao longo do +Y, entao meia volta em X leva a lamina para a
    # direcao dos dedos.
    punho.rotation_degrees = Vector3(180.0, 0.0, 0.0)

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
    var agora := Time.get_ticks_msec() / 1000.0
    if agora - _ultimo_golpe_em > PAUSA_DO_COMBO:
        _golpe = 0
    _ultimo_golpe_em = agora

    _atacando = true
    _animador.play("heroi/" + COMBO[_golpe], MISTURA)
    _golpe = (_golpe + 1) % COMBO.size()
    _tocar_nota()

func _tocar_nota() -> void:
    var nota: String = ESCALA[_proxima_nota]
    _proxima_nota = (_proxima_nota + 1) % ESCALA.size()
    _voz.stream = load("res://audio/nota_%s.wav" % nota)
    _voz.play()

func _ao_terminar(animacao: StringName) -> void:
    if String(animacao).trim_prefix("heroi/") in COMBO:
        _atacando = false
        _animador.play("heroi/parado", MISTURA)
