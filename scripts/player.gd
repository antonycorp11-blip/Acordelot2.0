extends CharacterBody3D

const WinsScript := preload("res://scripts/wins.gd")

signal personagem_trocado(id: String, nome: String)

@onready var _hero = $Hero
@onready var _akles: Node3D = $Hero
var _wins: Node3D
var _personagem_atual := "akles"

@export var move_speed := 6.0
@export var fly_speed := 18.0
@export var flight_altitude := 7.5
## O QUANTO O HEROI OBEDECE AO DEDO.
##
## A 18 ele levava um terco de segundo para chegar na velocidade cheia e outro
## tanto para parar: o polegar mandava e o corpo respondia depois, que e o
## "escorregadio" do controle. A 60 a resposta e no quadro seguinte sem virar
## robo — a inercia continua existindo, so deixou de ser atraso.
@export var acceleration := 60.0
## Quao rapido o corpo se vira para o rumo novo.
@export var giro_por_segundo := 16.0
@export var gravity := 24.0

var _voando := false

## O CHAO DE ULTIMA INSTANCIA.
##
## Num mundo montado por streaming, cair para fora nao pode ser possivel — e era.
## Ao viajar para a Masmorra o heroi nascia dentro de uma torre (construcao que
## voltou quando o filtro por textura passou a valer so onde a planta pede) e a
## capsula era empurrada para baixo do terreno; dali descia para sempre, com a
## camera embaixo do mundo e a tela preta. A mesma coisa aconteceria em qualquer
## brecha de tempo entre o jogador chegar e o chao daquela celula existir.
##
## `Relevo.altura` e uma funcao pura de (x, z): ela sabe onde e o chao mesmo
## quando a malha ainda nao nasceu. Se o heroi estiver MUITO abaixo dela, ele
## volta. Nao substitui a colisao — quatro metros de folga deixam ladeira,
## buraco e salto em paz —, e so age no caso em que nao ha volta por si.
const QUEDA_QUE_NAO_VOLTA := 4.0
## Desligado dentro da DG, que tem chao proprio noutro nivel e nao segue o
## relevo do mundo aberto.
var chao_garantido := true

## O quadro de referência do direcional, guardado como DESVIO ANGULAR entre o
## rumo que o dedo escolheu e os eixos atuais da câmera. Ver `_physics_process`.
##
## Guardar um ÂNGULO, e não um par de vetores congelados, é o que torna o rumo
## contínuo: o desvio cresce e diminui junto com a câmera, quadro a quadro, em
## vez de ser trocado de uma vez por outro quando algum limiar é cruzado.
var _desvio_do_quadro := 0.0
var _giro_da_camera_anterior := 0.0
var _quadro_ativo := false
## Quanto o quadro pode se afastar da câmera antes de ser ARRASTADO por ela.
##
## Sem teto, meia volta de câmera com o dedo parado deixaria o alto do círculo
## apontando para as costas do jogador. Com teto, o desvio satura e o quadro
## passa a acompanhar a câmera na mesma velocidade — que é uma curva suave, não
## um salto, porque limitar um acumulador não cria degrau.
const DESVIO_MAXIMO := PI * 0.5

func alternar_voo() -> void:
    _voando = not _voando
    if _voando:
        velocity.y = 10.0

func esta_voando() -> bool:
    return _voando

func converter_direcao_tela_para_mundo(direcao: Vector2) -> Vector3:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return Vector3.FORWARD
    var frente := -camera.global_basis.z
    frente.y = 0.0
    frente = frente.normalized()
    var direita := camera.global_basis.x
    direita.y = 0.0
    direita = direita.normalized()

    var no_mundo := (direita * direcao.x - frente * direcao.y).normalized()
    return no_mundo

func atualizar_mira_skill(indice: int, direcao_na_tela: Vector2) -> void:
    if _hero == null:
        return
    if indice == 3 and direcao_na_tela.length() > 0.01:
        var dir_mundo := converter_direcao_tela_para_mundo(direcao_na_tela)
        if _hero.has_method("mostrar_mira_laser"):
            _hero.mostrar_mira_laser(dir_mundo)

func cancelar_mira_skill(indice: int) -> void:
    if _hero == null:
        return
    if indice == 3:
        if _hero.has_method("esconder_mira_laser"):
            _hero.esconder_mira_laser()

## QUANTO TEMPO CADA HABILIDADE FICA GUARDADA DEPOIS DE USADA.
##
## Ate aqui nao havia nenhum: as tres saiam de novo no quadro seguinte, e o
## combate inteiro cabia em segurar o dedo nos tres botoes. Com espera, cada
## toque passa a ser uma escolha de QUANDO — que e onde mora a briga.
##
## Os numeros nao sao soltos: a aura azul dura dez segundos e a espada gigante
## oito. A espera tem de ser maior que o efeito, senao a habilidade estaria
## pronta antes de a anterior acabar e a espera nao existiria de verdade.
const RECARGA := {1: 12.0, 2: 12.0, 3: 18.0}
## A Ressonancia encurta a espera. E o atributo do jogo que fala de ouvir e
## responder, e ate aqui ele so mexia na captura de Eco — dar a ele um segundo
## uso, no combate, e o que faz distribuir ponto nele ser uma decisao.
const CORTE_POR_RESSONANCIA := 0.012
const CORTE_MAXIMO := 0.35

## Quando cada habilidade volta a ficar pronta, por personagem. Separado porque
## a vida tambem e separada: quem sai de campo leva as suas esperas junto, e
## trocar de heroi nao pode zerar o relogio das habilidades do outro.
var _pronta_em := {"akles": {}, "wins": {}}


## O tempo cheio de espera desta habilidade, ja com o desconto da Ressonancia.
func recarga_total(indice: int) -> float:
    var base: float = float(RECARGA.get(indice, 0.0))
    if base <= 0.0:
        return 0.0
    var progresso := get_node_or_null("/root/Progresso")
    var ressonancia := 0
    if progresso and progresso.has_method("valor_atributo"):
        ressonancia = int(progresso.valor_atributo("ressonancia"))
    var corte: float = minf(CORTE_MAXIMO, float(ressonancia) * CORTE_POR_RESSONANCIA)
    return base * (1.0 - corte)


## Quanto ainda falta, em segundos. Zero quer dizer pronta.
func recarga_restante(indice: int) -> float:
    var quadro: Dictionary = _pronta_em.get(_personagem_atual, {})
    return maxf(0.0, float(quadro.get(indice, 0.0)) - Time.get_ticks_msec() / 1000.0)


func usar_skill(indice: int, direcao_na_tela := Vector2.ZERO) -> void:
    if _hero == null:
        return
    # Guardada, ou com o corpo ocupado no golpe: nao sai e NAO cobra espera.
    # Cobrar por um toque que nao virou habilidade seria punir o jogador por
    # apertar no momento errado, que e coisa diferente de errar a hora.
    if recarga_restante(indice) > 0.0:
        return
    if _hero.has_method("atacando") and _hero.atacando():
        return
    _pronta_em[_personagem_atual][indice] = \
        Time.get_ticks_msec() / 1000.0 + recarga_total(indice)
    match indice:
        1:
            if _hero.has_method("ativar_aura_azul"):
                _hero.ativar_aura_azul()
        2:
            if _hero.has_method("ativar_espada_gigante"):
                _hero.ativar_espada_gigante()
        3:
            if _hero.has_method("lancar_raio_kamehameha"):
                var dir_mundo := Vector3.ZERO
                if direcao_na_tela.length() > 0.01:
                    dir_mundo = converter_direcao_tela_para_mundo(direcao_na_tela)
                    if dir_mundo.length() > 0.01:
                        rotation.y = atan2(dir_mundo.x, dir_mundo.z)
                _hero.lancar_raio_kamehameha(dir_mundo)

## Vira o corpo para onde o dedo apontou na tela.
##
## A direcao vem em pixels e precisa virar direcao de MUNDO. A conversao e a
## mesma do joystick — pelos eixos da camera — porque senao apontar para cima na
## tela levaria o tiro para o norte do mundo, e nao para o "longe" que o jogador
## esta vendo. Y da tela cresce para baixo, dai o sinal trocado.
func _virar_para_a_tela(direcao: Vector2) -> void:
    var no_mundo := converter_direcao_tela_para_mundo(direcao)
    if no_mundo.length() > 0.01:
        rotation.y = atan2(no_mundo.x, no_mundo.z)

## Ate onde a mira procura um alvo, em metros. Um pouco alem do alcance da
## espada: e o que deixa o jogador comecar o golpe ja se virando para o bicho
## que esta chegando, em vez de errar e ter que se reposicionar.
const ALCANCE_DA_MIRA := 4.5
## Abertura da busca, em graus. Larga de proposito — no celular a direcao vem de
## um polegar num circulo de plastico, e exigir pontaria fina so gera golpe no
## vazio. Mas nao e volta completa: bicho atras das costas nao vira alvo, senao
## o heroi se vira sozinho para longe do que o jogador esta olhando.
const ABERTURA_DA_MIRA := 200.0
## Quanto da velocidade sobra durante o golpe. Nao e zero de proposito: travar o
## pe por completo faz o combate parecer preso, e um passo curto ainda deixa
## ajustar a posicao entre um golpe e outro.
const FREIO_NO_GOLPE := 0.25

func _ready() -> void:
    # Os bichos procuram o alvo pelo grupo. Marcar aqui, e nao na cena, mantem
    # o vinculo mesmo se o jogador for instanciado por codigo mais tarde.
    add_to_group("jogador")
    # Os portais procuram por este nome em ingles; manter os dois evita depender
    # de qual dos dois quem escreveu o portal usou.
    add_to_group("player")
    # A Wins nasce escondida no carregamento. Assim modelo, materiais e
    # animações já estão preparados quando o jogador toca em trocar.
    _wins = WinsScript.new()
    _wins.name = "Wins"
    _wins.position = _akles.position
    _wins.visible = false
    _wins.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(_wins)


func trocar_personagem(id := "") -> void:
    var destino := id
    if destino.is_empty():
        destino = "wins" if _personagem_atual == "akles" else "akles"
    if destino == _personagem_atual or not destino in ["akles", "wins"]:
        return
    # ANTES A TROCA ERA PROIBIDA DURANTE O GOLPE — e isso virava prisao quando
    # o golpe nao terminava. Em vez de recusar, o heroi que sai SOLTA o estado
    # de ataque: trocar no meio do swing e uma escolha do jogador, ficar sem
    # botao nenhum nao e.
    if _hero and _hero.has_method("soltar_ataque"):
        _hero.soltar_ataque()
    _akles.visible = destino == "akles"
    _akles.process_mode = Node.PROCESS_MODE_INHERIT if destino == "akles" else Node.PROCESS_MODE_DISABLED
    _wins.visible = destino == "wins"
    _wins.process_mode = Node.PROCESS_MODE_INHERIT if destino == "wins" else Node.PROCESS_MODE_DISABLED
    _hero = _wins if destino == "wins" else _akles
    _personagem_atual = destino
    _hero.atualizar_movimento(Vector2(velocity.x, velocity.z).length(), _voando)
    personagem_trocado.emit(destino, "Wins" if destino == "wins" else "Akles")


func personagem_atual() -> String:
    return _personagem_atual

func _physics_process(delta: float) -> void:
    var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

    var wasd_vector := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_A):
        wasd_vector.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D):
        wasd_vector.x += 1.0
    if Input.is_physical_key_pressed(KEY_W):
        wasd_vector.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S):
        wasd_vector.y += 1.0
    if wasd_vector.length() > 0.0:
        input_vector = wasd_vector.normalized()

    var joystick := get_tree().get_first_node_in_group("virtual_joystick")
    var veio_do_dedo := false
    if joystick and joystick.movement_vector.length() > 0.01:
        input_vector = joystick.movement_vector
        veio_do_dedo = true

    var camera := get_viewport().get_camera_3d()
    var move_direction := Vector3.ZERO

    if camera:
        # Girar a câmera NÃO desvia quem já está andando — e não dá solavanco.
        #
        # O movimento é relativo à tela, e tem de ser: "para cima no círculo" é
        # "para longe na tela". Ler os eixos da câmera a cada quadro amarra as
        # duas coisas, e o segundo dedo passa a fazer o herói curvar sozinho.
        #
        # A versão anterior congelava os eixos e só os renovava quando o polegar
        # andava mais que um limiar no círculo. Era ali que nascia o salto: com
        # a câmera já girada, qualquer TREMOR de dedo acima do limiar trocava o
        # quadro de uma vez, e o rumo no mundo pulava de golpe o tanto que a
        # câmera tinha girado desde a última renovação. Quanto mais câmera, maior
        # o pulo — que é exatamente o "personagem muda de trajetória do nada".
        #
        # Agora o que se guarda é o DESVIO entre o quadro do dedo e a câmera, e
        # ele é corrigido pelo giro da câmera a cada quadro. Dedo parado, rumo
        # parado; dedo mexeu, o rumo muda só o quanto o dedo mudou. Não existe
        # limiar, logo não existe degrau. No teclado o desvio é sempre zero, que
        # é o relativo-à-câmera puro que se espera de mouse com WASD.
        var frente := -camera.global_basis.z
        frente.y = 0.0
        frente = frente.normalized()
        var direita := camera.global_basis.x
        direita.y = 0.0
        direita = direita.normalized()
        var giro_da_camera := atan2(frente.x, frente.z)

        if veio_do_dedo and input_vector.length() > 0.0:
            if _quadro_ativo:
                # `frente` e `direita` são colunas do mesmo giro: as duas rodam
                # com a câmera, e o desvio desconta exatamente esse giro.
                _desvio_do_quadro = clampf(
                    _desvio_do_quadro - angle_difference(
                        _giro_da_camera_anterior, giro_da_camera),
                    -DESVIO_MAXIMO, DESVIO_MAXIMO)
            else:
                _quadro_ativo = true
                _desvio_do_quadro = 0.0
        else:
            # Dedo fora do círculo: o próximo toque começa do quadro da tela.
            _quadro_ativo = false
            _desvio_do_quadro = 0.0
        _giro_da_camera_anterior = giro_da_camera

        if input_vector.length() > 0.0:
            # A INTENSIDADE do empurrao sobrevive ate a velocidade.
            #
            # Antes o vetor era normalizado aqui, e com isso qualquer toque alem
            # da zona morta virava velocidade cheia: nao havia andar devagar, so
            # parado ou disparado. Num polegar sobre vidro isso e o que faz o
            # controle parecer escorregadio e dificil de mirar.
            var bruto := direita * input_vector.x - frente * input_vector.y
            if not is_zero_approx(_desvio_do_quadro):
                bruto = bruto.rotated(Vector3.UP, _desvio_do_quadro)
            var forca: float = clampf(input_vector.length(), 0.0, 1.0)
            move_direction = bruto.normalized() * forca

    if _voando:
        velocity.x = move_toward(velocity.x, move_direction.x * fly_speed, acceleration * 1.5 * delta)
        velocity.z = move_toward(velocity.z, move_direction.z * fly_speed, acceleration * 1.5 * delta)
        
        var altura_chao := Relevo.altura(global_position.x, global_position.z)
        var altura_alvo := altura_chao + flight_altitude
        velocity.y = (altura_alvo - global_position.y) * 6.0
        
        if move_direction.length() > 0.0:
            var target_angle := atan2(move_direction.x, move_direction.z)
            rotation.y = lerp_angle(rotation.y, target_angle, giro_por_segundo * delta)
            
        move_and_slide()
        _hero.atualizar_movimento(Vector2(velocity.x, velocity.z).length(), true)
        return

    # Golpe segura os pes. O ataque com pulo dura 1,5 s mesmo acelerado, e nada
    # impedia o jogador de continuar andando o tempo todo: o heroi atravessava
    # metros no meio do swing, que e o "personagem mudando de posicao". Nao e a
    # animacao carregando avanco — medido, o quadril anda 2 cm.
    # ANDAR CORTA A RECUPERACAO DO GOLPE.
    #
    # A lamina ja passou pelo alvo; o que sobra da animacao e o heroi voltando a
    # guarda, e e nesse pedaco que o jogo parecia travar quando o jogador ja
    # queria sair. Antes do impacto nada e cortado, para o golpe nao sumir toda
    # vez que o polegar encosta no direcional.
    if move_direction.length() > 0.01 and _hero.has_method("pode_cancelar_golpe") \
            and _hero.pode_cancelar_golpe():
        _hero.cancelar_golpe()

    var velocidade := move_speed * (FREIO_NO_GOLPE if _hero.atacando() else 1.0)
    velocity.x = move_toward(velocity.x, move_direction.x * velocidade, acceleration * delta)
    velocity.z = move_toward(velocity.z, move_direction.z * velocidade, acceleration * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = -0.5

    if chao_garantido:
        var chao := Relevo.altura(global_position.x, global_position.z)
        if global_position.y < chao - QUEDA_QUE_NAO_VOLTA:
            global_position.y = chao + 0.6
            velocity.y = 0.0

    # No meio do golpe o corpo NAO gira com o direcional. Sem isso o jogador
    # anda durante o swing, o heroi acompanha, e a lamina termina apontada para
    # outro lado — o golpe sai visualmente errado mesmo tendo acertado.
    if move_direction.length() > 0.01 and not _hero.atacando():
        var target_angle := atan2(move_direction.x, move_direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, giro_por_segundo * delta)

    move_and_slide()

    _hero.atualizar_movimento(Vector2(velocity.x, velocity.z).length(), false)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_SPACE:
            _hero.atacar()
        elif event.keycode in [KEY_F, KEY_V]:
            alternar_voo()

## Ligado ao botao de ataque pelo game.gd.
func atacar() -> void:
    _mirar()
    _hero.atacar()

## Vira o heroi para o bicho mais perto antes de o golpe sair.
##
## E mira macia, sem botao de travar e sem marcador na tela: o jogador aperta
## atacar e o corpo se alinha sozinho. Trava dura pediria um segundo controle no
## polegar, num celular que ja tem direcional e botao de golpe — e resolveria um
## problema que a mira macia resolve sem custo de interface.
##
## Vira de uma vez, nao suave: o dano e cobrado poucos decimos depois do inicio
## da animacao, e uma virada gradual ainda estaria no meio do caminho na hora de
## conferir quem esta na frente.
func _mirar() -> void:
    var alvo := _bicho_mais_perto()
    if alvo == null:
        return
    var ate := alvo.global_position - global_position
    ate.y = 0.0
    if ate.length() < 0.05:
        return
    rotation.y = atan2(ate.x, ate.z)

func _bicho_mais_perto() -> Node3D:
    var frente := global_transform.basis.z.normalized()
    var melhor: Node3D = null
    var menor := ALCANCE_DA_MIRA
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if not is_instance_valid(bicho):
            continue
        var ate: Vector3 = bicho.global_position - global_position
        ate.y = 0.0
        var distancia := ate.length()
        if distancia > menor or distancia < 0.05:
            continue
        if frente.angle_to(ate.normalized()) > deg_to_rad(ABERTURA_DA_MIRA * 0.5):
            continue
        menor = distancia
        melhor = bicho
    return melhor
