extends Node3D
class_name Npc
## Uma pessoa parada na vila, com nome, animacao de respiro e raio de conversa.
##
## Nao tem IA e nao vai ter agora: NPC que anda precisa de rota, desvio e volta
## para casa, e nada disso ajuda a testar o dialogo. O que ela precisa fazer e
## estar em pe no lugar certo, respirar, e avisar quando o jogador chegou perto.
##
## A malha e a animacao vem do MESMO arquivo — o Mixamo devolve o modelo com o
## esqueleto e a animacao juntos, e para uma animacao so nao compensa assar
## biblioteca separada como o heroi faz com as sete dele.

## O Mixamo devolve o modelo numa escala propria. 1,68 m e a altura que casa com
## o heroi de 1,75 e com as portas das casas da vila.
const ALTURA_ALVO := 1.68
## Onde o botao de conversar aparece. Tres metros e perto o bastante para ser
## claro de quem se trata e longe o bastante para nao precisar encostar nela.
const RAIO_DE_CONVERSA := 3.2

signal jogador_chegou(npc: Npc)
signal jogador_saiu(npc: Npc)

@export var nome := "Mirella"
@export var modelo_path := "res://personagem/mirella_idle.fbx"
## A textura ORIGINAL da personagem.
##
## A que veio no FBX do Mixamo e uma reassada que perdeu o rosto — o auto-rigger
## recomprime a imagem e devolve a pele lavada. Esta e a que saiu do gerador do
## modelo, e o UV e o mesmo, entao trocar so a imagem basta.
@export var textura_path := "res://personagem/mirella_cor.png"
@export var dialogo := "mirella_boas_vindas"

var _animador: AnimationPlayer
var _perto := false


func _ready() -> void:
    # O jogo encontra os NPCs pelo grupo depois que a zona nasce — sao criados
    # junto com o cenario, entao nao ha como liga-los uma vez so no comeco.
    add_to_group("npc")
    var cena := load(modelo_path) as PackedScene
    if cena == null:
        return
    var modelo := cena.instantiate()
    add_child(modelo)

    _vestir(modelo)

    # Ao tamanho de gente, medido pela propria malha.
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var altura: float = (malha as MeshInstance3D).get_aabb().size.y
        if altura > 0.0:
            modelo.scale = Vector3.ONE * (ALTURA_ALVO / altura)
            break

    _animador = modelo.find_child("AnimationPlayer", true, false)
    if _animador:
        var lista := _animador.get_animation_list()
        if lista.size() > 0:
            # Em laco: e respiro, nao um gesto que acaba.
            _animador.get_animation(lista[0]).loop_mode = Animation.LOOP_LINEAR
            _animador.play(lista[0])

    _montar_area()


## Troca a imagem do Mixamo pela original, mantendo o resto do material.
func _vestir(modelo: Node3D) -> void:
    var textura := load(textura_path) as Texture2D
    if textura == null:
        return
    var pele := StandardMaterial3D.new()
    pele.albedo_texture = textura
    # Sem metal: o FBX chega com o fator do exportador, e metal puro sem reflexo
    # do ambiente aparece preto no renderizador de compatibilidade — foi o que
    # aconteceu com as casas de enxaimel.
    pele.metallic = 0.0
    pele.roughness = 0.9
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        (malha as MeshInstance3D).material_override = pele


## O raio de conversa, como area de fisica.
##
## Area3D e nao distancia medida a cada quadro: o motor ja faz essa conta uma vez
## por par de corpos, e uma NPC parada nao precisa de um _process seu so para
## perguntar "ja chegou?" sessenta vezes por segundo.
func _montar_area() -> void:
    var area := Area3D.new()
    area.name = "RaioDeConversa"
    # So o corpo do jogador acorda a area.
    area.collision_layer = 0
    area.monitorable = false

    var forma := CollisionShape3D.new()
    var esfera := SphereShape3D.new()
    esfera.radius = RAIO_DE_CONVERSA
    forma.shape = esfera
    forma.position.y = 1.0
    area.add_child(forma)

    area.body_entered.connect(func(corpo: Node3D):
        if _perto or not corpo.is_in_group("jogador"):
            return
        _perto = true
        jogador_chegou.emit(self))
    area.body_exited.connect(func(corpo: Node3D):
        if not _perto or not corpo.is_in_group("jogador"):
            return
        _perto = false
        jogador_saiu.emit(self))
    add_child(area)


## Vira o rosto para quem chegou. So o eixo Y: NPC que inclina para olhar o
## jogador de cima parece que vai cair.
func olhar_para(alvo: Vector3) -> void:
    var direcao := alvo - global_position
    direcao.y = 0.0
    if direcao.length_squared() < 0.01:
        return
    rotation.y = atan2(direcao.x, direcao.z)
