extends Node3D
class_name CavaleiroChefe

## O CAVALEIRO — chefe de classe, com a espada na mao.
##
## O modelo vem do Tripo ja riggado, com 41 ossos de nome proprio (`R_Hand`,
## `L_Thigh`) e SEM animacao nenhuma. Nao passou pelo Mixamo: o rig que veio
## serve, e o que faltava era o movimento — que nasce aqui, escrito, e nao
## importado.
##
## Chegou com 1,89 milhao de triangulos e saiu com 30 mil pelo
## `.tools/decimar_riggado.py`. A espada, com 1,97 milhao, saiu com 45 mil: ela
## e ornamentada e a 8 mil a filigrana das asas virava entulho lascado.

const MODELO := preload("res://models/cavaleiro_chefe.glb")
const ESPADA := preload("res://models/espada_cavaleiro.glb")

## Ele e maior que os herois de proposito: Akles tem 1,75 e a Wins 1,70.
const ALTURA_ALVO := 2.30
## Uma espada de uma mao. O modelo normaliza tudo para uma unidade de altura,
## entao sem esta medida ela sairia do tamanho do dono.
const COMPRIMENTO_DA_ESPADA := 1.20

## ONDE A MAO FECHA NA ESPADA, medido no proprio arquivo.
##
## O perfil por fatia mostra a haste fina — raio 0,036 — entre 0,759 e 0,857 de
## altura, com a ponta da lamina em zero e o pomo dourado no topo. O meio dessa
## faixa e 0,824.
const FRACAO_DO_CABO := 0.824

## O EIXO DO PUNHO FECHADO, tirado da geometria da mao.
##
## Este rig nao tem osso de dedo — so `R_Hand` —, entao a linha dos nos que
## resolveu a lanca da Wins nao existe aqui. Em vez dela, os 241 vertices que a
## mao direita domina foram decompostos em componentes principais no espaco do
## proprio osso. As tres extensoes saem na proporcao exata de uma mao:
##
##   0,116 no maior  -> comprimento dos dedos
##   0,079 no meio   -> a linha dos nos, que E o eixo de quem segura
##   0,045 no menor  -> espessura da palma
##
## O sinal veio da assimetria: o polegar cria uma cauda de um lado so, e a
## medida deu -0,382 — polegar no lado negativo. A lamina sai por ali e o pomo
## pelo lado do mindinho, que e como se segura uma espada.
const EIXO_DO_PUNHO := Vector3(0.3475, 0.0396, -0.9368)

var _modelo: Node3D
var _esqueleto: Skeleton3D
var _animador: AnimationPlayer
var _espada: Node3D
var _escala_do_modelo := 1.0


func _ready() -> void:
    _modelo = MODELO.instantiate()
    add_child(_modelo)
    _esqueleto = _modelo.find_child("Skeleton3D", true, false) as Skeleton3D
    _animador = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if _animador == null:
        _animador = AnimationPlayer.new()
        _animador.name = "AnimationPlayer"
        _modelo.add_child(_animador)
    _normalizar()
    _encaixar_espada()


## O modelo nasce com uma unidade de altura. Aqui ele vira gente do tamanho de
## um chefe, e a escala fica guardada porque a espada precisa desfazer ela.
func _normalizar() -> void:
    var caixa := AABB()
    var achou := false
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local := _ate_a_raiz(mi, _modelo) * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou or caixa.size.y < 0.05:
        return
    _escala_do_modelo = ALTURA_ALVO / caixa.size.y
    _modelo.scale = Vector3.ONE * _escala_do_modelo
    _modelo.position.y = -caixa.position.y * _escala_do_modelo


func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var t := Transform3D.IDENTITY
    var atual: Node = no
    while atual and atual != raiz:
        if atual is Node3D:
            t = (atual as Node3D).transform * t
        atual = atual.get_parent()
    return t


func _encaixar_espada() -> void:
    if _esqueleto == null:
        push_warning("cavaleiro sem esqueleto: a espada nao tem onde prender")
        return
    var indice := _esqueleto.find_bone("R_Hand")
    if indice < 0:
        push_warning("cavaleiro sem R_Hand")
        return

    var suporte := BoneAttachment3D.new()
    suporte.name = "MaoDireita"
    suporte.bone_idx = indice
    _esqueleto.add_child(suporte)

    var punho := Node3D.new()
    punho.name = "Punho"
    # O +Y do modelo da espada vai do BICO DA LAMINA ate o pomo. Girado para o
    # eixo do punho, o pomo sai pelo lado do mindinho e a lamina pelo do
    # polegar — que e a mao fechada de verdade, e nao um giro chutado.
    punho.basis = Basis(Quaternion(Vector3.UP, EIXO_DO_PUNHO.normalized()))
    suporte.add_child(punho)

    _espada = ESPADA.instantiate()
    punho.add_child(_espada)
    _dimensionar_espada()


func _dimensionar_espada() -> void:
    var caixa := AABB()
    var achou := false
    for malha in _espada.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local := _ate_a_raiz(mi, _espada) * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou or caixa.size.y < 0.01:
        return
    # A escala do osso ja carrega a do modelo; desfaze-la aqui e o que impede a
    # espada de sair vinte vezes maior que o dono.
    var escala: float = COMPRIMENTO_DA_ESPADA / caixa.size.y / maxf(_escala_do_modelo, 0.001)
    _espada.scale = Vector3.ONE * escala
    # O ponto do cabo desliza ate a origem do punho; x e z centrados para o
    # eixo da lamina passar POR DENTRO da mao, e nao ao lado dela.
    var centro := caixa.position + caixa.size * 0.5
    _espada.position = Vector3(
        -centro.x,
        -(caixa.position.y + caixa.size.y * FRACAO_DO_CABO),
        -centro.z) * escala


func esqueleto() -> Skeleton3D:
    return _esqueleto


func animador() -> AnimationPlayer:
    return _animador
