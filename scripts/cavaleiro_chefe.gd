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
    _criar_animacoes()


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


# ---------------------------------------------------------------- animacoes
## Este rig nao fala Mixamo. As poses abaixo sao DELTAS sobre o descanso do
## proprio Tripo, escritas nos ossos dele; assim nenhuma importacao troca UV,
## peso ou o encaixe da espada. O ataque reserva mais de meio segundo para o
## aviso e outro tanto para a recuperacao, deixando a esquiva ser uma decisao.
func _criar_animacoes() -> void:
    if _animador == null or _esqueleto == null:
        return
    if _animador.has_animation_library("cavaleiro"):
        return
    var lib := AnimationLibrary.new()
    lib.add_animation("parado", _animacao(2.4, true, {
        "Spine02": [[0.0, 1.2, 2.4], [_q(Vector3.RIGHT, -2), _q(Vector3.RIGHT, 2), _q(Vector3.RIGHT, -2)]],
        "R_Upperarm": [[0.0, 1.2, 2.4], [_q(Vector3.FORWARD, -3), _q(Vector3.FORWARD, 2), _q(Vector3.FORWARD, -3)]],
    }))
    lib.add_animation("andar", _passos(1.0, 20.0, 13.0))
    lib.add_animation("correr", _passos(0.68, 34.0, 24.0))
    lib.add_animation("atacar", _animacao(1.55, false, {
        "Waist": [[0.0, 0.48, 0.72, 1.55], [_q(Vector3.UP, 0), _q(Vector3.UP, -28), _q(Vector3.UP, 38), _q(Vector3.UP, 0)]],
        "Spine02": [[0.0, 0.48, 0.72, 1.55], [_q(Vector3.RIGHT, 0), _q(Vector3.RIGHT, -18), _q(Vector3.RIGHT, 24), _q(Vector3.RIGHT, 0)]],
        "R_Upperarm": [[0.0, 0.48, 0.72, 1.55], [_q(Vector3.FORWARD, 0), _q(Vector3.FORWARD, -72), _q(Vector3.FORWARD, 68), _q(Vector3.FORWARD, 0)]],
        "R_Forearm": [[0.0, 0.48, 0.72, 1.55], [_q(Vector3.RIGHT, 0), _q(Vector3.RIGHT, -42), _q(Vector3.RIGHT, 18), _q(Vector3.RIGHT, 0)]],
        "L_Upperarm": [[0.0, 0.48, 0.72, 1.55], [_q(Vector3.FORWARD, 0), _q(Vector3.FORWARD, 22), _q(Vector3.FORWARD, -18), _q(Vector3.FORWARD, 0)]],
    }))
    lib.add_animation("ataque_1", lib.get_animation("atacar").duplicate())
    lib.add_animation("ataque_2", _animacao(1.85, false, {
        "Waist": [[0.0, 0.62, 0.92, 1.85], [_q(Vector3.UP, 0), _q(Vector3.UP, -48), _q(Vector3.UP, 56), _q(Vector3.UP, 0)]],
        "Spine02": [[0.0, 0.62, 0.92, 1.85], [_q(Vector3.FORWARD, 0), _q(Vector3.FORWARD, -24), _q(Vector3.FORWARD, 28), _q(Vector3.FORWARD, 0)]],
        "R_Upperarm": [[0.0, 0.62, 0.92, 1.85], [_q(Vector3.UP, 0), _q(Vector3.UP, -82), _q(Vector3.UP, 88), _q(Vector3.UP, 0)]],
        "R_Forearm": [[0.0, 0.62, 0.92, 1.85], [_q(Vector3.RIGHT, 0), _q(Vector3.RIGHT, -34), _q(Vector3.RIGHT, 14), _q(Vector3.RIGHT, 0)]],
    }))
    lib.add_animation("morrer", _animacao(2.0, false, {
        "Hip": [[0.0, 0.55, 1.35, 2.0], [_q(Vector3.RIGHT, 0), _q(Vector3.RIGHT, -15), _q(Vector3.RIGHT, 76), _q(Vector3.RIGHT, 88)]],
        "Spine02": [[0.0, 0.55, 1.35, 2.0], [_q(Vector3.FORWARD, 0), _q(Vector3.FORWARD, 12), _q(Vector3.FORWARD, -18), _q(Vector3.FORWARD, -20)]],
        "R_Upperarm": [[0.0, 0.55, 1.35, 2.0], [_q(Vector3.FORWARD, 0), _q(Vector3.FORWARD, 24), _q(Vector3.FORWARD, 58), _q(Vector3.FORWARD, 64)]],
        "L_Upperarm": [[0.0, 0.55, 1.35, 2.0], [_q(Vector3.FORWARD, 0), _q(Vector3.FORWARD, -24), _q(Vector3.FORWARD, -58), _q(Vector3.FORWARD, -64)]],
    }))
    _animador.add_animation_library("cavaleiro", lib)


func _passos(duracao: float, perna: float, braco: float) -> Animation:
    var meio := duracao * 0.5
    return _animacao(duracao, true, {
        "L_Thigh": [[0.0, meio, duracao], [_q(Vector3.RIGHT, perna), _q(Vector3.RIGHT, -perna), _q(Vector3.RIGHT, perna)]],
        "R_Thigh": [[0.0, meio, duracao], [_q(Vector3.RIGHT, -perna), _q(Vector3.RIGHT, perna), _q(Vector3.RIGHT, -perna)]],
        "L_Calf": [[0.0, meio, duracao], [_q(Vector3.RIGHT, -perna * 0.45), _q(Vector3.RIGHT, perna * 0.55), _q(Vector3.RIGHT, -perna * 0.45)]],
        "R_Calf": [[0.0, meio, duracao], [_q(Vector3.RIGHT, perna * 0.55), _q(Vector3.RIGHT, -perna * 0.45), _q(Vector3.RIGHT, perna * 0.55)]],
        "L_Upperarm": [[0.0, meio, duracao], [_q(Vector3.RIGHT, -braco), _q(Vector3.RIGHT, braco), _q(Vector3.RIGHT, -braco)]],
        "R_Upperarm": [[0.0, meio, duracao], [_q(Vector3.RIGHT, braco), _q(Vector3.RIGHT, -braco), _q(Vector3.RIGHT, braco)]],
    })


func _animacao(duracao: float, repetir: bool, faixas: Dictionary) -> Animation:
    var a := Animation.new()
    a.length = duracao
    a.loop_mode = Animation.LOOP_LINEAR if repetir else Animation.LOOP_NONE
    # AnimationPlayer resolve faixas a partir de `root_node` (por padrao, seu
    # pai), e nao a partir dele mesmo. Usar get_path_to no player acrescentava
    # um `../` e todas as faixas apontavam para fora do modelo.
    var raiz_da_animacao := _animador.get_node_or_null(_animador.root_node)
    var caminho := str(raiz_da_animacao.get_path_to(_esqueleto)) \
        if raiz_da_animacao else str(_animador.get_path_to(_esqueleto))
    for osso in faixas:
        if _esqueleto.find_bone(String(osso)) < 0:
            continue
        var dados: Array = faixas[osso]
        var faixa := a.add_track(Animation.TYPE_ROTATION_3D)
        a.track_set_path(faixa, NodePath(caminho + ":" + String(osso)))
        a.track_set_interpolation_type(faixa, Animation.INTERPOLATION_CUBIC_ANGLE)
        for i in (dados[0] as Array).size():
            a.rotation_track_insert_key(faixa, float(dados[0][i]), dados[1][i])
    return a


func _q(eixo: Vector3, graus: float) -> Quaternion:
    return Quaternion(eixo.normalized(), deg_to_rad(graus))
