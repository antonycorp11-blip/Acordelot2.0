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

## CHEFE TEM DE IMPOR. A 2,30 ele mal passava do Shiker Anciao, que tem 2,9 —
## na tela isso nao le como chefe, le como mais um bicho. A 3,40 ele e quase o
## dobro do Akles e a camera isometrica ainda o pega inteiro.
##
## Este numero PRECISA bater com o "altura" do tipo 6 em `bicho.gd`: quem monta
## o chefe no jogo normaliza pela tabela de la, e este valor so vale quando o
## modelo e usado solto. Ter dois numeros diferentes foi o que entregou 2,58 m.
const ALTURA_ALVO := 3.40
## Uma espada de uma mao, em proporcao ao dono: metade da altura dele. Numero
## fixo em metros ficava curto assim que o chefe crescia.
const FRACAO_DA_ESPADA := 0.52

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
    var alvo := ALTURA_ALVO * FRACAO_DA_ESPADA
    var escala: float = alvo / caixa.size.y / maxf(_escala_do_modelo, 0.001)
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
## AS POSES SAO DELTAS SOBRE O DESCANSO — e agora sao de verdade.
##
## A versao anterior dizia isso no comentario e nao fazia: `TYPE_ROTATION_3D`
## num osso SUBSTITUI a rotacao dele, nao soma. Cada osso animado saltava para
## perto da identidade e o T-pose desabava — o braco entrava no corpo e a mao na
## cabeca. Aqui cada chave e `descanso * delta`, que e o que o comentario sempre
## prometeu.
##
## E O EIXO DE CADA JUNTA SAI DO ESQUELETO, nao de `Vector3.RIGHT` escrito na
## mao. Neste rig todo osso corre pelo +Y local — a medida do deslocamento de
## cada filho confirma —, mas o X e o Z de cada um apontam para lados
## diferentes. Escrever o eixo a mao acerta numa junta e erra na vizinha: a
## perna balanca para o lado em vez de para frente. `_eixo_local` pergunta ao
## descanso qual dos tres eixos do osso esta mais alinhado com o eixo do MUNDO
## que se quer, e devolve ele com o sinal certo.

## Os eixos do corpo, em espaco de mundo, para a animacao poder falar
## anatomia em vez de coordenada.
const LATERAL := Vector3.RIGHT   ## girar aqui = perna e braco para frente e para tras
const VERTICAL := Vector3.UP     ## girar aqui = torcer o tronco
const FRONTAL := Vector3.BACK    ## girar aqui = tombar para o lado


func _eixo_local(indice: int, eixo_do_mundo: Vector3) -> Vector3:
    var base := _esqueleto.get_bone_global_rest(indice).basis
    var melhor := Vector3.RIGHT
    var maior := -1.0
    for candidato in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
        var d: float = (base * candidato).normalized().dot(eixo_do_mundo)
        if absf(d) > maior:
            maior = absf(d)
            melhor = candidato * signf(d)
    return melhor


## Uma pose: o descanso do osso somado a um giro de tantos graus em volta do
## eixo do corpo pedido.
func _pose(osso: String, eixo_do_mundo: Vector3, graus: float) -> Quaternion:
    var i := _esqueleto.find_bone(osso)
    if i < 0:
        return Quaternion.IDENTITY
    var descanso := _esqueleto.get_bone_rest(i).basis.get_rotation_quaternion()
    if is_zero_approx(graus):
        return descanso
    return descanso * Quaternion(_eixo_local(i, eixo_do_mundo), deg_to_rad(graus))


func _criar_animacoes() -> void:
    if _animador == null or _esqueleto == null:
        return
    if _animador.has_animation_library("cavaleiro"):
        return
    var lib := AnimationLibrary.new()
    lib.add_animation("parado", _parado())
    lib.add_animation("andar", _passos(1.15, 24.0, 15.0, 0.035))
    lib.add_animation("correr", _passos(0.72, 38.0, 27.0, 0.075))
    lib.add_animation("atacar", _golpe_de_cima())
    lib.add_animation("ataque_1", _golpe_de_cima())
    lib.add_animation("ataque_2", _golpe_lateral())
    lib.add_animation("morrer", _queda())
    _animador.add_animation_library("cavaleiro", lib)


## Respiracao e a espada pesando na mao. Sem isto ele fica de estatua, que num
## chefe parado antes da briga e o que mais denuncia que nada esta vivo.
func _parado() -> Animation:
    return _animacao(3.2, true, {
        "Spine01": [[0.0, 1.6, 3.2], [
            _pose("Spine01", LATERAL, -1.5), _pose("Spine01", LATERAL, 1.5),
            _pose("Spine01", LATERAL, -1.5)]],
        "Spine02": [[0.0, 1.6, 3.2], [
            _pose("Spine02", LATERAL, -2.0), _pose("Spine02", LATERAL, 2.5),
            _pose("Spine02", LATERAL, -2.0)]],
        "R_Upperarm": [[0.0, 1.6, 3.2], [
            _pose("R_Upperarm", FRONTAL, 3.0), _pose("R_Upperarm", FRONTAL, -2.0),
            _pose("R_Upperarm", FRONTAL, 3.0)]],
        "L_Upperarm": [[0.0, 1.6, 3.2], [
            _pose("L_Upperarm", FRONTAL, -3.0), _pose("L_Upperarm", FRONTAL, 2.0),
            _pose("L_Upperarm", FRONTAL, -3.0)]],
        "Head": [[0.0, 1.6, 3.2], [
            _pose("Head", VERTICAL, 2.0), _pose("Head", VERTICAL, -2.0),
            _pose("Head", VERTICAL, 2.0)]],
    })


## O CICLO DE PASSO, com as pernas em oposicao e os bracos contrariando.
##
## `sobe` e o quique do quadril: sem ele o corpo desliza sobre os pes e o passo
## nao tem peso. Sobe duas vezes por ciclo — uma por perna que apoia.
func _passos(duracao: float, perna: float, braco: float, sobe: float) -> Animation:
    var q := duracao * 0.25
    var meio := duracao * 0.5
    var tq := duracao * 0.75
    var t := [0.0, meio, duracao]
    var faixas := {
        "L_Thigh": [t, [_pose("L_Thigh", LATERAL, perna), _pose("L_Thigh", LATERAL, -perna),
            _pose("L_Thigh", LATERAL, perna)]],
        "R_Thigh": [t, [_pose("R_Thigh", LATERAL, -perna), _pose("R_Thigh", LATERAL, perna),
            _pose("R_Thigh", LATERAL, -perna)]],
        # O joelho so dobra para um lado. Manter o sinal unico evita a perna
        # quebrando ao contrario no meio do passo.
        "L_Calf": [[0.0, q, meio, tq, duracao], [
            _pose("L_Calf", LATERAL, 0.0), _pose("L_Calf", LATERAL, -perna * 0.9),
            _pose("L_Calf", LATERAL, -perna * 0.2), _pose("L_Calf", LATERAL, -perna * 0.35),
            _pose("L_Calf", LATERAL, 0.0)]],
        "R_Calf": [[0.0, q, meio, tq, duracao], [
            _pose("R_Calf", LATERAL, -perna * 0.2), _pose("R_Calf", LATERAL, -perna * 0.35),
            _pose("R_Calf", LATERAL, 0.0), _pose("R_Calf", LATERAL, -perna * 0.9),
            _pose("R_Calf", LATERAL, -perna * 0.2)]],
        "L_Upperarm": [t, [_pose("L_Upperarm", LATERAL, -braco),
            _pose("L_Upperarm", LATERAL, braco), _pose("L_Upperarm", LATERAL, -braco)]],
        "R_Upperarm": [t, [_pose("R_Upperarm", LATERAL, braco),
            _pose("R_Upperarm", LATERAL, -braco), _pose("R_Upperarm", LATERAL, braco)]],
        "Spine02": [t, [_pose("Spine02", VERTICAL, braco * 0.20),
            _pose("Spine02", VERTICAL, -braco * 0.20), _pose("Spine02", VERTICAL, braco * 0.20)]],
    }
    var a := _animacao(duracao, true, faixas)
    _quique(a, sobe, duracao)
    return a


## O quique do quadril. Faixa de POSICAO, entao tambem precisa somar o descanso
## — pelo mesmo motivo das rotacoes.
func _quique(a: Animation, altura: float, duracao: float) -> void:
    var i := _esqueleto.find_bone("Hip")
    if i < 0 or altura <= 0.0:
        return
    var descanso := _esqueleto.get_bone_rest(i).origin
    var faixa := a.add_track(Animation.TYPE_POSITION_3D)
    a.track_set_path(faixa, NodePath(_caminho_do_esqueleto() + ":Hip"))
    var passos := [0.0, duracao * 0.25, duracao * 0.5, duracao * 0.75, duracao]
    var alturas := [0.0, altura, 0.0, altura, 0.0]
    for k in passos.size():
        a.position_track_insert_key(faixa, float(passos[k]),
            descanso + Vector3(0.0, float(alturas[k]), 0.0))


## GOLPE DE CIMA: ele levanta a espada, segura o aviso, e desce.
##
## O tempo entre o alto e o impacto e o que o jogador usa para sair. Meio
## segundo de subida, um respiro no alto e um quarto de segundo de descida — e
## isso que faz o golpe ser LIDO em vez de so acontecer.
func _golpe_de_cima() -> Animation:
    var t := [0.0, 0.52, 0.72, 0.96, 1.70]
    return _animacao(1.70, false, {
        "Spine02": [t, [_pose("Spine02", LATERAL, 0), _pose("Spine02", LATERAL, -16),
            _pose("Spine02", LATERAL, -20), _pose("Spine02", LATERAL, 26),
            _pose("Spine02", LATERAL, 0)]],
        "R_Clavicle": [t, [_pose("R_Clavicle", LATERAL, 0), _pose("R_Clavicle", LATERAL, -18),
            _pose("R_Clavicle", LATERAL, -22), _pose("R_Clavicle", LATERAL, 10),
            _pose("R_Clavicle", LATERAL, 0)]],
        "R_Upperarm": [t, [_pose("R_Upperarm", LATERAL, 0), _pose("R_Upperarm", LATERAL, -104),
            _pose("R_Upperarm", LATERAL, -118), _pose("R_Upperarm", LATERAL, 52),
            _pose("R_Upperarm", LATERAL, 0)]],
        "R_Forearm": [t, [_pose("R_Forearm", LATERAL, 0), _pose("R_Forearm", LATERAL, -46),
            _pose("R_Forearm", LATERAL, -52), _pose("R_Forearm", LATERAL, 8),
            _pose("R_Forearm", LATERAL, 0)]],
        "L_Upperarm": [t, [_pose("L_Upperarm", LATERAL, 0), _pose("L_Upperarm", LATERAL, 26),
            _pose("L_Upperarm", LATERAL, 30), _pose("L_Upperarm", LATERAL, -14),
            _pose("L_Upperarm", LATERAL, 0)]],
        "L_Thigh": [t, [_pose("L_Thigh", LATERAL, 0), _pose("L_Thigh", LATERAL, 8),
            _pose("L_Thigh", LATERAL, 10), _pose("L_Thigh", LATERAL, -16),
            _pose("L_Thigh", LATERAL, 0)]],
    })


## GOLPE LATERAL: torce o tronco para tras e varre na horizontal. Ele cobre
## mais area que o de cima, e por isso avisa por mais tempo.
func _golpe_lateral() -> Animation:
    var t := [0.0, 0.62, 0.86, 1.12, 1.95]
    return _animacao(1.95, false, {
        "Waist": [t, [_pose("Waist", VERTICAL, 0), _pose("Waist", VERTICAL, -46),
            _pose("Waist", VERTICAL, -54), _pose("Waist", VERTICAL, 62),
            _pose("Waist", VERTICAL, 0)]],
        "Spine02": [t, [_pose("Spine02", VERTICAL, 0), _pose("Spine02", VERTICAL, -30),
            _pose("Spine02", VERTICAL, -34), _pose("Spine02", VERTICAL, 40),
            _pose("Spine02", VERTICAL, 0)]],
        "R_Clavicle": [t, [_pose("R_Clavicle", VERTICAL, 0), _pose("R_Clavicle", VERTICAL, -20),
            _pose("R_Clavicle", VERTICAL, -24), _pose("R_Clavicle", VERTICAL, 20),
            _pose("R_Clavicle", VERTICAL, 0)]],
        "R_Upperarm": [t, [_pose("R_Upperarm", FRONTAL, 0), _pose("R_Upperarm", FRONTAL, -58),
            _pose("R_Upperarm", FRONTAL, -66), _pose("R_Upperarm", FRONTAL, 24),
            _pose("R_Upperarm", FRONTAL, 0)]],
        "R_Forearm": [t, [_pose("R_Forearm", LATERAL, 0), _pose("R_Forearm", LATERAL, -34),
            _pose("R_Forearm", LATERAL, -30), _pose("R_Forearm", LATERAL, -6),
            _pose("R_Forearm", LATERAL, 0)]],
        "L_Upperarm": [t, [_pose("L_Upperarm", FRONTAL, 0), _pose("L_Upperarm", FRONTAL, 34),
            _pose("L_Upperarm", FRONTAL, 38), _pose("L_Upperarm", FRONTAL, -18),
            _pose("L_Upperarm", FRONTAL, 0)]],
    })


func _queda() -> Animation:
    var t := [0.0, 0.5, 1.3, 2.0]
    var a := _animacao(2.0, false, {
        "Hip": [t, [_pose("Hip", LATERAL, 0), _pose("Hip", LATERAL, -14),
            _pose("Hip", LATERAL, 62), _pose("Hip", LATERAL, 82)]],
        "Spine01": [t, [_pose("Spine01", LATERAL, 0), _pose("Spine01", LATERAL, 10),
            _pose("Spine01", LATERAL, -22), _pose("Spine01", LATERAL, -28)]],
        "Spine02": [t, [_pose("Spine02", LATERAL, 0), _pose("Spine02", LATERAL, 12),
            _pose("Spine02", LATERAL, -18), _pose("Spine02", LATERAL, -22)]],
        "Head": [t, [_pose("Head", LATERAL, 0), _pose("Head", LATERAL, -12),
            _pose("Head", LATERAL, 24), _pose("Head", LATERAL, 30)]],
        "R_Upperarm": [t, [_pose("R_Upperarm", LATERAL, 0), _pose("R_Upperarm", LATERAL, 20),
            _pose("R_Upperarm", LATERAL, 52), _pose("R_Upperarm", LATERAL, 58)]],
        "L_Upperarm": [t, [_pose("L_Upperarm", LATERAL, 0), _pose("L_Upperarm", LATERAL, -20),
            _pose("L_Upperarm", LATERAL, -52), _pose("L_Upperarm", LATERAL, -58)]],
        "L_Thigh": [t, [_pose("L_Thigh", LATERAL, 0), _pose("L_Thigh", LATERAL, -10),
            _pose("L_Thigh", LATERAL, 34), _pose("L_Thigh", LATERAL, 42)]],
        "R_Thigh": [t, [_pose("R_Thigh", LATERAL, 0), _pose("R_Thigh", LATERAL, -10),
            _pose("R_Thigh", LATERAL, 30), _pose("R_Thigh", LATERAL, 38)]],
    })
    # O corpo tambem AFUNDA ao cair; so girar o quadril deixa ele de joelhos no
    # ar. A altura sai do proprio tamanho do chefe.
    var i := _esqueleto.find_bone("Hip")
    if i >= 0:
        var descanso := _esqueleto.get_bone_rest(i).origin
        var faixa := a.add_track(Animation.TYPE_POSITION_3D)
        a.track_set_path(faixa, NodePath(_caminho_do_esqueleto() + ":Hip"))
        var queda := 0.22 / maxf(_escala_do_modelo, 0.001)
        for k in t.size():
            var fundo: float = [0.0, 0.02, -queda * 0.8, -queda][k]
            a.position_track_insert_key(faixa, float(t[k]),
                descanso + Vector3(0.0, fundo, 0.0))
    return a


## AnimationPlayer resolve faixas a partir de `root_node`, e nao dele mesmo:
## usar `get_path_to` no player acrescenta um `../` e as faixas apontam para
## fora do modelo.
func _caminho_do_esqueleto() -> String:
    var raiz := _animador.get_node_or_null(_animador.root_node)
    return str(raiz.get_path_to(_esqueleto)) if raiz \
        else str(_animador.get_path_to(_esqueleto))


func _animacao(duracao: float, repetir: bool, faixas: Dictionary) -> Animation:
    var a := Animation.new()
    a.length = duracao
    a.loop_mode = Animation.LOOP_LINEAR if repetir else Animation.LOOP_NONE
    var caminho := _caminho_do_esqueleto()
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
