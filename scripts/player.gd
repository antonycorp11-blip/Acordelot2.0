extends CharacterBody3D

@onready var _hero: Hero = $Hero

@export var move_speed := 6.0
@export var fly_speed := 18.0
@export var flight_altitude := 7.5
@export var acceleration := 18.0
@export var gravity := 24.0

var _voando := false

func alternar_voo() -> void:
    _voando = not _voando
    if _voando:
        velocity.y = 10.0

func esta_voando() -> bool:
    return _voando

func usar_skill(indice: int, direcao_na_tela := Vector2.ZERO) -> void:
    if _hero == null:
        return
    if direcao_na_tela.length() > 0.01:
        _virar_para_a_tela(direcao_na_tela)
    match indice:
        1:
            if _hero.has_method("ativar_aura_azul"):
                _hero.ativar_aura_azul()
        2:
            if _hero.has_method("ativar_espada_gigante"):
                _hero.ativar_espada_gigante()
        3:
            if _hero.has_method("lancar_raio_kamehameha"):
                _hero.lancar_raio_kamehameha()

## Vira o corpo para onde o dedo apontou na tela.
##
## A direcao vem em pixels e precisa virar direcao de MUNDO. A conversao e a
## mesma do joystick — pelos eixos da camera — porque senao apontar para cima na
## tela levaria o tiro para o norte do mundo, e nao para o "longe" que o jogador
## esta vendo. Y da tela cresce para baixo, dai o sinal trocado.
func _virar_para_a_tela(direcao: Vector2) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var frente := -camera.global_basis.z
    frente.y = 0.0
    frente = frente.normalized()
    var direita := camera.global_basis.x
    direita.y = 0.0
    direita = direita.normalized()

    var no_mundo := (direita * direcao.x - frente * direcao.y).normalized()
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
    if joystick and joystick.movement_vector.length() > 0.01:
        input_vector = joystick.movement_vector

    var camera := get_viewport().get_camera_3d()
    var move_direction := Vector3.ZERO

    if camera and input_vector.length() > 0.0:
        var camera_forward := -camera.global_basis.z
        camera_forward.y = 0.0
        camera_forward = camera_forward.normalized()
        var camera_right := camera.global_basis.x
        camera_right.y = 0.0
        camera_right = camera_right.normalized()
        # A INTENSIDADE do empurrao sobrevive ate a velocidade.
        #
        # Antes o vetor era normalizado aqui, e com isso qualquer toque alem da
        # zona morta virava velocidade cheia: nao havia andar devagar, so parado
        # ou disparado. Num polegar sobre vidro isso e o que faz o controle
        # parecer escorregadio e dificil de mirar.
        var bruto := camera_right * input_vector.x - camera_forward * input_vector.y
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
            rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
            
        move_and_slide()
        _hero.atualizar_movimento(Vector2(velocity.x, velocity.z).length(), true)
        return

    # Golpe segura os pes. O ataque com pulo dura 1,5 s mesmo acelerado, e nada
    # impedia o jogador de continuar andando o tempo todo: o heroi atravessava
    # metros no meio do swing, que e o "personagem mudando de posicao". Nao e a
    # animacao carregando avanco — medido, o quadril anda 2 cm.
    var velocidade := move_speed * (FREIO_NO_GOLPE if _hero.atacando() else 1.0)
    velocity.x = move_toward(velocity.x, move_direction.x * velocidade, acceleration * delta)
    velocity.z = move_toward(velocity.z, move_direction.z * velocidade, acceleration * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = -0.5

    # No meio do golpe o corpo NAO gira com o direcional. Sem isso o jogador
    # anda durante o swing, o heroi acompanha, e a lamina termina apontada para
    # outro lado — o golpe sai visualmente errado mesmo tendo acertado.
    if move_direction.length() > 0.01 and not _hero.atacando():
        var target_angle := atan2(move_direction.x, move_direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

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
