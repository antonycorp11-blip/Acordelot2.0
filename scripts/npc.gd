extends Node3D
class_name Npc
## Uma moradora da vila: malha, respiro, uma volta pelo bairro e raio de conversa.
##
## A rotina e de proposito burra — parar, escolher um ponto perto, ir ate la,
## parar de novo. Nao ha rota, nao ha desvio, nao ha hora de dormir. Uma NPC de
## vila precisa parecer que mora ali, e para isso bastam passos de vez em
## quando; caminho calculado e patrulha sao problema de quem tem guarda e
## inimigo, e nao e o caso aqui.
##
## A malha vem do FBX de respiro; o movimento vem da biblioteca assada ao lado.
## O FBX de caminhada trazia a malha inteira outra vez — 29 MB para nove
## segundos de passo.

## O Mixamo devolve o modelo numa escala propria. 1,68 m e a altura que casa com
## o heroi de 1,75 e com as portas das casas da vila.
const ALTURA_ALVO := 1.68
## Onde o botao de conversar aparece. Tres metros e perto o bastante para ser
## claro de quem se trata e longe o bastante para nao precisar encostar nela.
const RAIO_DE_CONVERSA := 3.2

## A cerca invisivel da rotina, em metros a partir de onde ela nasceu. Doze
## metros a mantem no largo e nas duas esquinas dele — perto o bastante para o
## jogador que a viu de longe ainda a encontrar quando chegar.
const RAIO_DE_PASSEIO := 12.0
const VELOCIDADE := 1.15
## Quanto tempo ela fica parada entre uma caminhada e outra. Faixa larga de
## proposito: pausa fixa vira metronomo e o olho percebe o padrao.
const PAUSA := Vector2(2.5, 7.0)
const GIRO_POR_SEGUNDO := 4.0

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
@export var animacoes_path := "res://personagem/mirella_anims.res"
@export var dialogo := "mirella_boas_vindas"
## NPC de missao fica no lugar marcado. Quem espera o jogador num ponto nao pode
## estar do outro lado da praca quando ele chegar.
@export var fixa := false

var _animador: AnimationPlayer
var _perto := false
var _casa := Vector3.ZERO
var _alvo := Vector3.ZERO
var _andando := false
var _espera := 0.0
var _conversando := false
var _terreno: Node = null


func _ready() -> void:
    # O jogo encontra os NPCs pelo grupo depois que a zona nasce — sao criados
    # junto com o cenario, entao nao ha como liga-los uma vez so no comeco.
    add_to_group("npc")
    _casa = position
    _espera = randf_range(PAUSA.x, PAUSA.y)

    var cena := load(modelo_path) as PackedScene
    if cena == null:
        return
    var modelo := cena.instantiate()
    add_child(modelo)
    _vestir(modelo)
    _assentar(modelo)

    _animador = modelo.find_child("AnimationPlayer", true, false)
    if _animador:
        var biblioteca := load(animacoes_path) as AnimationLibrary
        if biblioteca:
            _animador.add_animation_library("mirella", biblioteca)
            _animador.play("mirella/parado")
        else:
            var lista := _animador.get_animation_list()
            if lista.size() > 0:
                _animador.play(lista[0])

    _montar_area()
    set_physics_process(not fixa)


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


## Poe o PE dela no chao, nao a origem do arquivo.
##
## Era so escalar pela altura e pronto, e por isso ela flutuava: o Mixamo grava
## a origem do modelo na cintura ou abaixo dos pes conforme o exportador, e a
## distancia entre a origem e a sola muda de arquivo para arquivo. Medir a caixa
## e descontar o pe dela e o que funciona para qualquer modelo — e a mesma conta
## que o construtor de cenario faz com as casas.
func _assentar(modelo: Node3D) -> void:
    var caixa := AABB()
    var achou := false
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local: AABB = mi.transform * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou or caixa.size.y <= 0.001:
        return
    var fator: float = ALTURA_ALVO / caixa.size.y
    modelo.scale = Vector3.ONE * fator
    modelo.position.y = -caixa.position.y * fator


## O raio de conversa, como area de fisica.
##
## Area3D e nao distancia medida a cada quadro: o motor ja faz essa conta uma vez
## por par de corpos, e uma NPC parada nao precisa de um _process seu so para
## perguntar "ja chegou?" sessenta vezes por segundo.
func _montar_area() -> void:
    var area := Area3D.new()
    area.name = "RaioDeConversa"
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


# -------------------------------------------------------------
# A rotina
# -------------------------------------------------------------
func _physics_process(delta: float) -> void:
    if _conversando:
        return

    if not _andando:
        _espera -= delta
        if _espera <= 0.0:
            _escolher_destino()
        return

    var passo := _alvo - position
    passo.y = 0.0
    if passo.length() < 0.35:
        _parar()
        return

    var direcao := passo.normalized()
    position += direcao * VELOCIDADE * delta
    _colar_no_chao()
    _virar_para(direcao, delta)


## Um ponto qualquer dentro da cerca invisivel, longe o bastante para valer a
## caminhada — destino a meio metro daria um passo e uma parada.
func _escolher_destino() -> void:
    var angulo := randf() * TAU
    var distancia := randf_range(3.0, RAIO_DE_PASSEIO)
    var candidato := _casa + Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
    _alvo = candidato
    _andando = true
    if _animador and _animador.has_animation("mirella/andar"):
        _animador.play("mirella/andar", 0.25)


func _parar() -> void:
    _andando = false
    _espera = randf_range(PAUSA.x, PAUSA.y)
    if _animador and _animador.has_animation("mirella/parado"):
        _animador.play("mirella/parado", 0.3)


## Mantem a sola no relevo enquanto ela anda.
##
## O terreno da zona nao e plano: e uma malha dobrada, e uma NPC que anda numa
## altura fixa afunda na subida e flutua na descida. Quem sabe a altura de cada
## ponto e o construtor da zona, que a calcula por formula — mais barato que um
## raio de fisica por quadro.
func _colar_no_chao() -> void:
    if _terreno == null:
        var p := get_parent()
        while p != null and not p.has_method("calcular_altura"):
            p = p.get_parent()
        _terreno = p
    if _terreno:
        position.y = _terreno.calcular_altura(position.x, position.z)


func _virar_para(direcao: Vector3, delta: float) -> void:
    var desejado := atan2(direcao.x, direcao.z)
    rotation.y = rotate_toward(rotation.y, desejado, GIRO_POR_SEGUNDO * delta)


## Vira o rosto para quem chegou. So o eixo Y: NPC que inclina para olhar o
## jogador de cima parece que vai cair.
func olhar_para(alvo: Vector3) -> void:
    var direcao := alvo - global_position
    direcao.y = 0.0
    if direcao.length_squared() < 0.01:
        return
    rotation.y = atan2(direcao.x, direcao.z)


## Enquanto a caixa de conversa esta aberta ela nao sai andando: a fala ficaria
## saindo de alguem que ja esta do outro lado da rua.
func parar_para_conversar() -> void:
    _conversando = true
    _andando = false
    if _animador and _animador.has_animation("mirella/parado"):
        _animador.play("mirella/parado", 0.2)


func voltar_a_rotina() -> void:
    _conversando = false
    _espera = randf_range(PAUSA.x, PAUSA.y)
