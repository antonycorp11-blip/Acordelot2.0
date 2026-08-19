extends Node3D
class_name GeradorDeBichos
## Mantem alguns Ecos Dissonantes vivos em volta do jogador.
##
## Nao ha lista de inimigos posta a mao no mapa: o mundo tem 110 regioes e
## carrega por pedaco, entao inimigo fixo em coordenada ou nasceria dentro de
## pedaco descarregado ou obrigaria a guardar o estado de milhares deles. Aqui e
## o contrario — nascem perto de quem joga e somem quando ficam para tras, que e
## o que o jogador percebe como "tem bicho no mundo".

## Quantos ao mesmo tempo. Poucos de proposito: sao para testar o combate, e
## uma horda esconderia se o alcance da espada esta bom.
@export var quantidade := 4
## Nascem fora da tela e caminham para dentro. Nascer na frente do jogador
## denuncia o truque.
@export var distancia_de_nascimento := 16.0
## Some daqui para fora. Maior que o raio de atencao do bicho, senao ele
## desapareceria bem quando desiste de perseguir, na cara do jogador.
@export var distancia_de_sumico := 34.0
@export var intervalo := 1.5

@export var jogador: Node3D

## Carregado pelo caminho, nao pelo nome da classe: o nome global so existe
## depois que o editor varre o projeto, e isso deixa a cena quebrada em
## exportacao limpa.
const BICHO := preload("res://scripts/bicho.gd")

var _vivos: Array[Node3D] = []
var _proximo := 0.0

func _process(delta: float) -> void:
    if jogador == null:
        return

    _vivos = _vivos.filter(func(b): return is_instance_valid(b))

    for bicho in _vivos:
        if bicho.global_position.distance_to(jogador.global_position) > distancia_de_sumico:
            bicho.queue_free()
    _vivos = _vivos.filter(func(b): return is_instance_valid(b))

    _proximo -= delta
    if _proximo > 0.0 or _vivos.size() >= quantidade:
        return
    _proximo = intervalo
    _nascer()

func _nascer() -> void:
    var angulo := randf() * TAU
    var ponto := jogador.global_position + Vector3(
        cos(angulo) * distancia_de_nascimento, 0.0,
        sin(angulo) * distancia_de_nascimento)
    # Um pouco acima do chao: o corpo cai pela gravidade ate assentar. Nascer
    # colado no chao as vezes prende dentro da colisao do terreno, que e
    # montada no mesmo quadro em que o pedaco entra.
    ponto.y = 1.5

    var bicho: Node3D = BICHO.new()
    bicho.position = ponto
    add_child(bicho)
    _vivos.append(bicho)
