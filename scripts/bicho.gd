extends CharacterBody3D
class_name Bicho
## Eco Dissonante: o alvo dos golpes do Akles.
##
## Nasce sem arte propria. O corpo e o cristal que ja existe no mundo, tingido
## de roxo e flutuando — cristal desafinado e justamente o que a historia do
## jogo chama de dissonante, entao serve de inimigo de verdade e nao de caixa
## cinza de teste. Quando houver modelo de bicho, troca-se MODELO e o resto
## continua valendo.
##
## O combate e sentido antes de existir arte: e a unica forma de descobrir se o
## alcance da espada, o tempo do golpe e o empurrao estao bons.

const MODELO := "res://models/crystal_cluster_1787078933118.glb"

const VIDA_CHEIA := 100.0
const VELOCIDADE := 2.6
## Daqui para dentro ele persegue. Maior que isso e o bicho atravessa o mapa
## atras do jogador e o mundo vira corrida.
const RAIO_DE_ATENCAO := 14.0
## Nao encosta: para a esta distancia. Sem isso ele empurra o jogador para longe
## e o golpe nunca alcanca, porque o alvo esta sempre entrando no corpo dele.
const DISTANCIA_DE_PARADA := 1.6
const GRAVIDADE := 24.0

## Quanto tempo ele fica bobo depois de apanhar. E a janela que deixa emendar o
## combo: sem ela o bicho volta a avancar entre um golpe e outro.
const ATORDOAMENTO := 0.45
const EMPURRAO := 7.0

## Flutua. O cristal nao tem perna, e parado no chao parecia cenario, nao bicho.
const ALTURA_DE_VOO := 0.9
const BALANCO := 0.18

var vida := VIDA_CHEIA

var _modelo: Node3D
var _material: StandardMaterial3D
var _atordoado_ate := -1.0
var _fase := 0.0
var _jogador: Node3D

func _ready() -> void:
    add_to_group("bicho")
    _fase = randf() * TAU

    var forma := CollisionShape3D.new()
    var capsula := CapsuleShape3D.new()
    capsula.radius = 0.55
    capsula.height = 1.5
    forma.shape = capsula
    forma.position.y = 0.75
    add_child(forma)

    _modelo = (load(MODELO) as PackedScene).instantiate()
    add_child(_modelo)

    # Material proprio, nunca o compartilhado do mundo. O piscar de dano escreve
    # na emissao: no material comum, um bicho apanhando acenderia todas as
    # arvores do mapa junto.
    _material = StandardMaterial3D.new()
    _material.albedo_color = Color(0.42, 0.24, 0.62)
    _material.emission_enabled = true
    _material.emission = Color(0.55, 0.30, 0.95)
    _material.emission_energy_multiplier = 0.9
    var alto := 0.0
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        malha.material_override = _material
        alto = maxf(alto, malha.get_aabb().size.y)
    if alto > 0.0:
        _modelo.scale = Vector3.ONE * (1.3 / alto)

func _physics_process(delta: float) -> void:
    _fase += delta
    if _modelo:
        _modelo.position.y = ALTURA_DE_VOO + sin(_fase * 2.2) * BALANCO
        _modelo.rotation.y += delta * 0.8

    if not is_on_floor():
        velocity.y -= GRAVIDADE * delta
    else:
        velocity.y = -0.5

    var agora := Time.get_ticks_msec() / 1000.0
    if agora < _atordoado_ate:
        # Apanhando, ele so desliza: o empurrao dado em levar_dano continua
        # valendo e vai perdendo forca sozinho.
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        move_and_slide()
        return

    var alvo := _achar_jogador()
    var desejada := Vector3.ZERO
    if alvo:
        var ate := alvo.global_position - global_position
        ate.y = 0.0
        var distancia := ate.length()
        if distancia < RAIO_DE_ATENCAO and distancia > DISTANCIA_DE_PARADA:
            desejada = ate.normalized() * VELOCIDADE

    velocity.x = move_toward(velocity.x, desejada.x, 14.0 * delta)
    velocity.z = move_toward(velocity.z, desejada.z, 14.0 * delta)
    move_and_slide()

func _achar_jogador() -> Node3D:
    if _jogador == null or not is_instance_valid(_jogador):
        _jogador = get_tree().get_first_node_in_group("jogador") as Node3D
    return _jogador

## Chamado pela espada do Akles.
func levar_dano(quantidade: float, direcao: Vector3) -> void:
    if vida <= 0.0:
        return
    vida -= quantidade

    var empurrao := direcao
    empurrao.y = 0.0
    velocity += empurrao.normalized() * EMPURRAO
    _atordoado_ate = Time.get_ticks_msec() / 1000.0 + ATORDOAMENTO

    if vida <= 0.0:
        _morrer()
        return
    _piscar()

## Clarao branco de um quinto de segundo. E o unico sinal de que o golpe pegou:
## sem ele nao da para saber se a espada acertou ou passou perto.
func _piscar() -> void:
    var brilho := create_tween()
    _material.emission = Color(1.0, 0.95, 1.0)
    _material.emission_energy_multiplier = 4.0
    brilho.tween_property(_material, "emission_energy_multiplier", 0.9, 0.2)
    brilho.parallel().tween_property(_material, "emission", Color(0.55, 0.30, 0.95), 0.2)

func _morrer() -> void:
    remove_from_group("bicho")
    # Sai de cena encolhendo e subindo: some sem o susto de desaparecer no meio
    # da tela, e ainda avisa que aquele acabou.
    var fim := create_tween()
    fim.tween_property(_modelo, "scale", Vector3.ZERO, 0.35)
    fim.parallel().tween_property(_modelo, "position:y", ALTURA_DE_VOO + 1.2, 0.35)
    fim.tween_callback(queue_free)
