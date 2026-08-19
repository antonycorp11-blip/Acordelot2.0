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
##
## Foi de 1,45 para 1,85 depois do teste no celular — a 45% mais rapido ainda
## estava "super lento". Passar muito disso comeca a mostrar que a animacao esta
## correndo, com o braco pulando etapa; se ainda parecer lento, o caminho e
## trocar a animacao no Mixamo por uma mais curta, nao acelerar mais esta.
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

## Encaixe da espada na mao. Sao @export e nao constantes porque nao existe
## numero certo deduzivel: o cabo do modelo, a pose da mao do Mixamo e a escala
## do heroi so batem olhando. Com a cena rodando, mexer nestes campos no
## inspetor move a lamina na hora — em compilacao de depuracao o encaixe e
## refeito a cada quadro.
##
## Comprimento da espada no mundo, em metros. 1.15 m num heroi de 1.75 m e a
## proporcao da arte: lamina longa, quase montante.
@export var comprimento_da_espada := 1.15
## Onde fica o cabo, medido de baixo para cima na imagem do modelo. Medido na
## malha: a fatia mais estreita esta a 85% da altura, com a guarda aos 65%.
@export var fracao_do_cabo := 0.85
## Correcao fina no espaco do punho, em metros, se a lamina ficar atravessada na
## palma em vez de dentro dela.
@export var ajuste_do_punho := Vector3.ZERO
## Meia volta em X leva a lamina para a direcao dos dedos: com o cabo na origem
## ela aponta para -Y, e os ossos do Mixamo encadeiam ao longo do +Y.
@export var giro_do_punho := Vector3(180.0, 0.0, 0.0)

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
## Toque dado no meio de um golpe. Sem guardar, quem aperta no ritmo do combate
## perde o toque e o combo nunca passa do primeiro golpe.
var _golpe_pedido := false
## O punho inteiro, para poder sumir com a espada fora do golpe.
var _espada: Node3D = null
## A malha da lamina e a ampliacao do heroi, guardadas para refazer o encaixe
## quando os campos do inspetor mudam.
var _lamina: Node3D = null
var _escala_do_modelo := 1.0

func _ready() -> void:
    var modelo := (load("res://personagem/heroi_base.fbx") as PackedScene).instantiate()
    add_child(modelo)

    _animador = modelo.find_child("AnimationPlayer", true, false)
    var biblioteca: AnimationLibrary = load("res://personagem/heroi_anims.res")
    for nome in COMBO:
        _fixar_no_lugar(biblioteca.get_animation(nome))
    _animador.add_animation_library("heroi", biblioteca)
    _animador.animation_finished.connect(_ao_terminar)

    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var altura: float = malha.get_aabb().size.y
        if altura > 0.0:
            modelo.scale = Vector3.ONE * (ALTURA_ALVO / altura)
        break

    _voz = AudioStreamPlayer.new()
    add_child(_voz)

    _equipar_espada(modelo)
    # O Akles nao anda pela floresta de lamina em punho: ela so aparece no
    # golpe. Como nao ha animacao de sacar, o corte entra junto com o swing e o
    # movimento da propria animacao cobre o aparecimento.
    if _espada:
        _espada.visible = false
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
    _espada = punho

    var espada: Node3D = (load("res://models/espada_akles.glb") as PackedScene).instantiate()
    punho.add_child(espada)
    _lamina = espada
    _escala_do_modelo = modelo.scale.x

    _atualizar_encaixe()

    for malha in espada.find_children("*", "MeshInstance3D", true, false):
        malha.material_override = load("res://Material_TripoSR.tres")

## Poe a lamina na mao a partir dos campos do inspetor.
##
## A espada esta DENTRO do esqueleto, que foi ampliado ~176x para o heroi ter
## 1.75 m: sem descontar essa ampliacao ela sairia do tamanho de uma casa.
func _atualizar_encaixe() -> void:
    if _lamina == null or _espada == null:
        return

    # Altura da malha da espada no arquivo, antes de qualquer escala.
    const ALTURA_DA_MALHA := 0.94
    var escala := comprimento_da_espada / ALTURA_DA_MALHA / _escala_do_modelo
    _lamina.scale = Vector3.ONE * escala

    # O cabo esta ACIMA do centro da malha. Trazer esse ponto para a origem e o
    # que poe a mao no punho em vez de no meio da lamina.
    _lamina.position = Vector3(
        0.0, -(fracao_do_cabo - 0.5) * ALTURA_DA_MALHA * escala, 0.0) + ajuste_do_punho
    _espada.rotation_degrees = giro_do_punho

func _process(_delta: float) -> void:
    # So enquanto se ajusta. Na build final os campos nao mudam, e refazer o
    # encaixe a cada quadro seria conta jogada fora.
    if OS.is_debug_build():
        _atualizar_encaixe()

## Tira o avanco do quadril de um golpe.
##
## As animacoes de espada do Mixamo carregam deslocamento: o "great sword jump
## attack" avanca quase dois metros. Quem move o personagem no mundo e o codigo,
## entao esse avanco nao leva o corpo junto — leva so a MALHA, que sai de dentro
## da propria capsula de colisao e volta de tranco no fim do golpe. Era o
## personagem "mudando de posicao" no ultimo ataque do combo.
##
## Feito ao carregar, e nao ao assar a biblioteca, porque os FBX do Mixamo vivem
## fora do projeto (16 MB cada) e reassar exigiria traze-los de volta. Aqui vale
## para qualquer biblioteca, inclusive uma assada antes desta correcao.
##
## O sobe-e-desce (Y) fica: e ele que da peso ao golpe.
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

## Para o jogador saber que nao pode girar o corpo no meio do swing.
func atacando() -> bool:
    return _atacando

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
        _golpe_pedido = true
        return

    # A contagem da pausa corre a partir do FIM do ultimo golpe, nao do comeco.
    # Medindo do comeco, a propria animacao (mais longa que PAUSA_DO_COMBO) ja
    # estourava o prazo: quando o jogador podia atacar de novo, o combo se dava
    # por expirado e voltava ao primeiro golpe — sempre o mesmo ataque, por mais
    # rapido que se apertasse.
    if Time.get_ticks_msec() / 1000.0 - _ultimo_golpe_em > PAUSA_DO_COMBO:
        _golpe = 0

    _atacando = true
    if _espada:
        _espada.visible = true
    _animador.play("heroi/" + COMBO[_golpe], MISTURA, VELOCIDADE_DO_GOLPE)
    _golpe = (_golpe + 1) % COMBO.size()
    _tocar_nota()
    _marcar_impacto()

## Espera a lamina chegar no alvo e entao cobra o dano.
##
## O contato nao vem de area de colisao seguindo a espada: a lamina esta presa
## ao osso, e area de colisao em osso animado dispara varias vezes no mesmo
## swing e erra quando dois quadros pulam por cima do alvo. Uma checagem unica
## no instante do impacto e mais previsivel — e e o que jogo de acao costuma
## fazer.
func _marcar_impacto() -> void:
    var duracao := _animador.current_animation_length / VELOCIDADE_DO_GOLPE
    await get_tree().create_timer(duracao * INSTANTE_DO_IMPACTO).timeout
    if not _atacando:
        return
    _atingir()

func _atingir() -> void:
    var origem := global_position
    var frente := global_transform.basis.z.normalized()
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if not is_instance_valid(bicho):
            continue
        var ate: Vector3 = bicho.global_position - origem
        ate.y = 0.0
        var distancia := ate.length()
        if distancia > ALCANCE_DO_GOLPE or distancia < 0.05:
            continue
        if frente.angle_to(ate.normalized()) > deg_to_rad(ABERTURA_DO_GOLPE * 0.5):
            continue
        bicho.levar_dano(DANO, ate.normalized())

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
        _espada.visible = false
    _animador.play("heroi/parado", MISTURA)
