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
@export var quantidade := 6
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
const RELEVO := preload("res://scripts/relevo.gd")

## Distribuicao de formas:
## 0: Shiker Comum (35%), 1: Shiker Voraz (25%), 2: Shiker Ancião (10%)
## 3: Golem de Pedra (20%), 4: Golem Cristalino (10%)
const RARIDADE := [35, 25, 10, 20, 10]

## Biomas onde NAO nasce nada. A vila e a cidade sao onde o jogador conversa,
## compra e respira; bicho ali nao e desafio, e mobilia hostil no unico lugar
## seguro do mapa. O gerador nao sabia disso — nascia em volta do jogador, e o
## jogador as vezes esta dentro de casa.
const BIOMAS_SEM_BICHO := ["cidade", "sagrado"]
## A masmorra fica longe do mapa por zonas, em 520,520, e tem gerador proprio.
## Sem esta guarda o gerador do mundo continuava povoando por cima dele.
const MASMORRA := Vector3(520.0, 0.0, 520.0)
const RAIO_DA_MASMORRA := 260.0

var _vivos: Array[Node3D] = []
var _proximo := 0.0
var _zona_segura := false


## Chamado pelo ZoneManager a cada troca de zona.
func definir_zona(z_data: Dictionary) -> void:
    var bioma := String(z_data.get("biome", z_data.get("bioma", "")))
    _zona_segura = BIOMAS_SEM_BICHO.has(bioma)


func _limpar_tudo() -> void:
    for bicho in _vivos:
        if is_instance_valid(bicho):
            bicho.queue_free()
    _vivos.clear()

func _process(delta: float) -> void:
    if jogador == null:
        return

    if _zona_segura or jogador.global_position.distance_to(MASMORRA) < RAIO_DA_MASMORRA:
        # Some com quem ja estava vivo tambem: entrar na vila com tres Shikers
        # na cola nao e diferente de eles nascerem la.
        _limpar_tudo()
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

## Sorteia a forma pelo peso, sem depender de o gerador saber quais existem.
func _sortear_forma() -> int:
    var dado := randi() % 100
    var acumulado := 0
    for i in RARIDADE.size():
        acumulado += RARIDADE[i]
        if dado < acumulado:
            return i
    return 0


func _nascer() -> void:
    var angulo := randf() * TAU
    var ponto := jogador.global_position + Vector3(
        cos(angulo) * distancia_de_nascimento, 0.0,
        sin(angulo) * distancia_de_nascimento)
    # Um pouco acima do CHAO DALI, nao acima do zero: com o terreno dobrado, um
    # y fixo faria o bicho nascer enterrado no morro ou despencando do ar.
    # A altura vem de quem construiu o chao que esta ali.
    #
    # O mundo por zonas tem o proprio relevo, e Relevo.altura descreve o mundo
    # ANTIGO, de pedacos. Perguntar ao mapa errado nasce o bicho no ar ou dentro
    # da terra — era o dragao sem chao.
    var construtor := get_tree().root.find_child("ZoneBuilder", true, false)
    if construtor and construtor.has_method("calcular_altura"):
        ponto.y = construtor.calcular_altura(ponto.x, ponto.z) + 1.5
    else:
        ponto.y = RELEVO.altura(ponto.x, ponto.z) + 1.5

    var bicho: Node3D = BICHO.new()
    bicho.monster_type = _sortear_forma()
    bicho.position = ponto
    add_child(bicho)
    _vivos.append(bicho)
